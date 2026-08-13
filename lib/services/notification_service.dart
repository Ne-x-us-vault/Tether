// ══════════════════════════════════════════════════════════════════════════════
// notification_service.dart — Lovit App
// Handles FCM token registration, foreground/background notification display,
// and tap-to-navigate deep linking.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'call_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background message handler — must be a top-level function
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // When app is killed FCM shows the notification automatically.
  // We just log here — no Flutter UI access in background isolate.
  debugPrint('[FCM/BG] ${message.notification?.title}: ${message.notification?.body}');
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static const String homeTasksAction = 'home_tasks';
  static final ValueNotifier<String?> pendingHomeAction = ValueNotifier(null);

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  String? _activeChatPairingId;
  String? _activeChatThreadId;

  // Global navigator key so we can navigate from notification taps
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Monotonic id for local notifications — stable within the session and
  // avoids the hashCode() collisions/unpredictability of the old approach.
  int _nextNotificationId = 1;

  // Channel definition — high importance so heads-up banners show
  static const _channel = AndroidNotificationChannel(
    'lovit_channel',
    'Lovit Notifications',
    description: 'Messages, reactions, reminders and updates from Lovit',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    ledColor: Color(0xFF9B6FFF),
  );

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Auth status: ${settings.authorizationStatus}');

    // 2. Create the Android notification channel
    await _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Init flutter_local_notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 4. Save token to Supabase (via SharedPreferences bridge — SupabaseService
    //    reads it on next run if needed; we also save directly here)
    await _saveToken();

    // 5. Listen for token refreshes
    _fcm.onTokenRefresh.listen(_onTokenRefresh);

    // 6. Foreground message handler
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 7. Tap handler when app is in background (not killed)
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedApp);

    // 8. Check if app was launched from a notification tap (killed state)
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleNavigation(initial.data);
  }

  // ── Token management ──────────────────────────────────────────────────────

  Future<void> _saveToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      debugPrint('[FCM] Token: $token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      // SupabaseService.saveFcmToken() will be called from HomeShell
    } catch (e) {
      debugPrint('[FCM] Token error: $e');
    }
  }

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  void _onTokenRefresh(String token) async {
    debugPrint('[FCM] Token refreshed: $token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    // SupabaseService will pick this up on next presence heartbeat
  }

  // ── Foreground messages ───────────────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM/FG] ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    final messageType = message.data['type'] as String?;
    final messagePairingId = message.data['pairing_id'] as String?;
    final isActiveChatMessage =
        messageType == 'message' &&
        _activeChatPairingId != null &&
        messagePairingId != null &&
        messagePairingId == _activeChatPairingId;

    if (isActiveChatMessage) {
      debugPrint(
        '[FCM/FG] Suppressed local chat banner for active chat '
        'pairing=$_activeChatPairingId thread=$_activeChatThreadId',
      );
      return;
    }

    // Trigger custom vibration for message notifications
    if (messageType == 'message') {
      _playMessageVibration();
    }

    if (CallService.instance.isCallNotificationType(messageType)) {
      HapticFeedback.heavyImpact();
    }

    // Show a local notification banner (FCM suppresses these when app is open)
    _local.show(
      _nextNotificationId++,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF9B6FFF),
          icon: '@mipmap/ic_launcher',
          // Pass payload so tap can navigate
          ticker: notification.title,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void setActiveChat({
    required String pairingId,
    String? threadId,
  }) {
    _activeChatPairingId = pairingId;
    _activeChatThreadId = threadId;
    debugPrint(
      '[FCM] Active chat set: pairing=$pairingId thread=${threadId ?? "default"}',
    );
  }

  void clearActiveChat({
    String? pairingId,
    String? threadId,
  }) {
    if (pairingId != null &&
        _activeChatPairingId != null &&
        pairingId != _activeChatPairingId) {
      return;
    }
    if (threadId != null &&
        _activeChatThreadId != null &&
        threadId != _activeChatThreadId) {
      return;
    }
    debugPrint(
      '[FCM] Active chat cleared: pairing=${_activeChatPairingId ?? "-"} '
      'thread=${_activeChatThreadId ?? "-"}',
    );
    _activeChatPairingId = null;
    _activeChatThreadId = null;
  }

  // ── Custom vibration patterns ─────────────────────────────────────────────

  Future<void> _playMessageVibration() async {
    try {
      // Create a distinctive triple-tap pattern: 3 heavy impacts in a row
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('[Vibration] Error: $e');
    }
  }

  // ── Tap handlers ──────────────────────────────────────────────────────────

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleNavigation(data);
      // Quick tap feedback
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  void _onNotificationOpenedApp(RemoteMessage message) {
    _handleNavigation(message.data);
  }

  void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    if (CallService.instance.isCallNotificationType(type)) {
      final hasContext = navigatorKey.currentContext != null;
      if (hasContext) {
        unawaited(CallService.instance.handleCallPayload(data));
      } else {
        unawaited(CallService.instance.queuePendingCallPayload(data));
      }
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'message':
      case 'reaction':
      case 'pin':
        // Navigate to home → chat tab (index 2)
        _navigateToTab(2);
        _routeToHome(context);
        break;
      case 'calendar':
        _navigateToTab(3);
        _routeToHome(context);
        break;
      case 'budget':
        _navigateToTab(1);
        _routeToHome(context);
        break;
      case 'task':
        _navigateToTab(0);
        _setPendingHomeAction(homeTasksAction);
        _routeToHome(context);
        break;
      case 'location':
        _navigateToTab(4);
        _routeToHome(context);
        break;
      case 'period':
        _navigateToTab(0);
        _routeToHome(context);
        break;
    }
  }

  void _navigateToTab(int index) {
    // We store the pending tab in SharedPreferences; HomeShell reads it on build
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('notification_tab', index);
    });
  }

  void _setPendingHomeAction(String action) {
    pendingHomeAction.value = action;
  }

  void _routeToHome(BuildContext context) {
    try {
      GoRouter.of(context).go('/home');
    } catch (e) {
      debugPrint('[FCM] Route-to-home error: $e');
    }
  }
}
