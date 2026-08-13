import 'package:flutter/foundation.dart';
// ══════════════════════════════════════════════════════════════════════════════
// battery_sync_service.dart — Lovit App
// Background battery level syncing to keep partner always updated
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import 'supabase_service.dart';

class BatterySyncService {
  static final BatterySyncService _instance = BatterySyncService._internal();
  factory BatterySyncService() => _instance;
  BatterySyncService._internal();

  final _battery = Battery();
  final _sb = SupabaseService();

  Timer? _syncTimer;
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  int _lastSyncedLevel = -1;
  DateTime? _lastSyncTime;

  static const _syncInterval = Duration(minutes: 5); // Sync every 5 minutes
  static const _minTimeBetweenSyncs = Duration(
    seconds: 30,
  ); // Min 30 seconds between syncs
  static const _minLevelChange = 2; // Only sync if level changes by 2% or more

  /// Initialize battery sync service
  /// Call this once when the app starts
  Future<void> initialize() async {
    debugLog('Initializing Battery Sync Service');

    // Start periodic sync
    _startPeriodicSync();

    // Listen to battery state changes for immediate sync on state change
    _listenToBatteryStateChanges();

    // Perform initial sync
    await _syncBatteryLevel();
  }

  /// Cleanup resources
  Future<void> dispose() async {
    debugLog('Disposing Battery Sync Service');
    _syncTimer?.cancel();
    await _batteryStateSubscription?.cancel();
  }

  /// Start periodic battery sync (every 5 minutes)
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      await _syncBatteryLevel();
    });
  }

  /// Listen to battery state changes (charging, discharging, etc.)
  void _listenToBatteryStateChanges() {
    _batteryStateSubscription?.cancel();
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((state) {
      debugLog('Battery state changed: $state');
      // Sync immediately when state changes (e.g., when plugged in)
      unawaited(_syncBatteryLevel(force: true));
    });
  }

  /// Sync current battery level to Supabase
  /// Returns true if sync was successful, false otherwise
  Future<bool> _syncBatteryLevel({bool force = false}) async {
    try {
      // Check if user is authenticated
      if (_sb.currentUserId == null) {
        debugLog('Battery Sync: User not authenticated');
        return false;
      }

      // Check if enough time has passed since last sync
      if (!force && _lastSyncTime != null) {
        final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
        if (timeSinceLastSync < _minTimeBetweenSyncs) {
          return false;
        }
      }

      // Get current battery level
      final currentLevel = await _battery.batteryLevel;

      // Check if level changed significantly (or force sync)
      if (!force && _lastSyncedLevel >= 0) {
        final levelChange = (currentLevel - _lastSyncedLevel).abs();
        if (levelChange < _minLevelChange) {
          debugLog(
            'Battery Sync: Level change too small ($levelChange%), skipping',
          );
          return false;
        }
      }

      // Perform the sync
      await _sb.updateBatteryLevel(currentLevel);

      _lastSyncedLevel = currentLevel;
      _lastSyncTime = DateTime.now();

      debugLog(
        'Battery Sync: Synced level $currentLevel% at ${_lastSyncTime!.toIso8601String()}',
      );
      return true;
    } catch (error) {
      debugLog('Battery Sync Error: $error');
      return false;
    }
  }

  /// Get current battery level without syncing
  Future<int> getCurrentBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (error) {
      debugLog('Error getting battery level: $error');
      return -1;
    }
  }

  /// Get current battery state
  Future<BatteryState> getCurrentBatteryState() async {
    try {
      return await _battery.batteryState;
    } catch (error) {
      debugLog('Error getting battery state: $error');
      return BatteryState.unknown;
    }
  }

  /// Manually trigger a battery sync (useful for testing or forcing an update)
  Future<bool> syncNow() async {
    debugLog('Manually triggering battery sync');
    return await _syncBatteryLevel(force: true);
  }

  /// Task for Workmanager to execute in the background
  static Future<void> performBackgroundSync() async {
    try {
      // Ensure Supabase is initialized in the background isolate
      try {
        Supabase.instance.client;
      } catch (_) {
        await Supabase.initialize(
          url: SupabaseConstants.url,
          anonKey: SupabaseConstants.anonKey,
        );
      }
      // Restore the persisted auth session in this fresh isolate; otherwise the
      // client has no user and _syncBatteryLevel silently no-ops.
      await SupabaseService.restoreBackgroundSession();
      await BatterySyncService().syncNow();
    } catch (e) {
      debugPrint('Battery Background Sync Failed: $e');
    }
  }

  /// Enable/disable battery sync
  void setEnabled(bool enabled) {
    if (enabled) {
      debugLog('Battery Sync: Enabled');
      _startPeriodicSync();
      _listenToBatteryStateChanges();
    } else {
      debugLog('Battery Sync: Disabled');
      _syncTimer?.cancel();
      _batteryStateSubscription?.cancel();
    }
  }
}

// Debug logging helper
void debugLog(String message) {
  debugPrint('[Lovit/BatterySync] $message');
}
