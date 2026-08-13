import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../core/constants/supabase_constants.dart';
import 'supabase_service.dart';

class LocationSyncService {
  static final LocationSyncService _instance = LocationSyncService._internal();
  factory LocationSyncService() => _instance;
  LocationSyncService._internal();

  static const _backgroundSyncInterval = Duration(minutes: 15);

  final SupabaseService _sb = SupabaseService();
  StreamSubscription<Position>? _positionSub;
  bool _backgroundTaskScheduled = false;

  Future<void> initialize() async {
    await _registerBackgroundSync();
    final hasPermission = await ensurePermissions(prompt: false);
    if (hasPermission) {
      await syncNow();
      _startForegroundTracking();
    }
  }

  Future<bool> ensurePermissions({bool prompt = true}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (prompt) {
        await Geolocator.openLocationSettings();
      }
      await _sb.updateLocationSharingEnabled(false);
      return false;
    }

    var permission = await Geolocator.checkPermission();
    
    // Specifically request "Always" for never-ending tracking
    if (permission == LocationPermission.denied && prompt) {
      permission = await Geolocator.requestPermission();
    }

    // On Android, we often need to request "Always" separately after "While in Use"
    if (permission == LocationPermission.whileInUse && prompt) {
       // Optional: You can prompt the user specifically for "Always" here
       // For now, we'll try to proceed with Always if possible
       permission = await Geolocator.requestPermission(); 
    }

    if (permission == LocationPermission.deniedForever) {
      if (prompt) {
        await Geolocator.openAppSettings();
      }
      await _sb.updateLocationSharingEnabled(false);
      return false;
    }

    final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;

    if (granted) {
      // Only flip sharing ON the first time permission is granted, or when the
      // user still has it enabled. If the user previously opted out, do not
      // silently re-enable live location on every app start / sync.
      final myProfile = await _sb.getMyProfile();
      final hasEnabledSharing =
          myProfile != null && myProfile.locationSharingEnabled;
      if (myProfile == null || hasEnabledSharing) {
        await _sb.updateLocationSharingEnabled(true);
      }
      _startForegroundTracking();
    } else {
      await _sb.updateLocationSharingEnabled(false);
      await _positionSub?.cancel();
      _positionSub = null;
    }
    return granted;
  }

  Future<void> syncNow() async {
    final hasPermission = await ensurePermissions(prompt: false);
    if (!hasPermission) {
      return;
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // More frequent updates for "Live" feel
          forceLocationManager: true,
        ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }

    if (position == null) {
      return;
    }

    // Do not touch the sharing flag on routine syncs — the user's opt-out must
    // stick. The flag is only changed by ensurePermissions() on permission
    // grant/denial (see above).
    await _sb.updateLocation(
      position.latitude,
      position.longitude,
    );
  }

  Future<void> dispose() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  void _startForegroundTracking() {
    if (_positionSub != null) {
      return;
    }

    // Configure Foreground Service Notification for Android
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      forceLocationManager: true,
      intervalDuration: const Duration(seconds: 10),
      // This is the key for "Never-Ending" tracking on Android
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Lovit is active to keep you and your partner connected.",
        notificationTitle: "Live Location Sharing Active",
        enableWakeLock: true,
      ),
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((position) async {
      try {
        await _sb.updateLocation(
          position.latitude,
          position.longitude,
        );
      } catch (error) {
        debugPrint('[Lovit/LocationSync] $error');
      }
    });
  }

  Future<void> _registerBackgroundSync() async {
    if (_backgroundTaskScheduled) {
      return;
    }

    try {
      await Workmanager().registerPeriodicTask(
        'location_sync_background',
        'locationSync',
        frequency: _backgroundSyncInterval,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        tag: 'location_sync_background',
        constraints: Constraints(networkType: NetworkType.connected),
      );
      _backgroundTaskScheduled = true;
    } catch (error) {
      debugPrint('[Lovit/LocationSyncInit] $error');
    }
  }

  static Future<void> performBackgroundSync() async {
    try {
      try {
        Supabase.instance.client;
      } catch (_) {
        await Supabase.initialize(
          url: SupabaseConstants.url,
          anonKey: SupabaseConstants.anonKey,
        );
      }

      // Restore the persisted auth session in this fresh isolate; otherwise the
      // Supabase client has no user and every write silently no-ops.
      await SupabaseService.restoreBackgroundSession();
      if (Supabase.instance.client.auth.currentUser == null) {
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      final permission = await Geolocator.checkPermission();
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) {
        return;
      }

      final sb = SupabaseService();
      final myProfile = await sb.getMyProfile();
      if (myProfile != null && !myProfile.locationSharingEnabled) {
        // User has opted out of location sharing — do not publish coordinates.
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        return;
      }

      await sb.updateLocation(
        position.latitude,
        position.longitude,
      );
    } catch (error) {
      debugPrint('[Lovit/LocationSyncBackground] $error');
    }
  }
}
