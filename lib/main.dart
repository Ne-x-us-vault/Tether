import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/constants/supabase_constants.dart';
import 'core/router/app_router.dart';
import 'services/encryption_service.dart';
import 'services/location_sync_service.dart';
import 'services/notification_service.dart';

/// Application bootstrap: initialize platform plugins and services, build the
/// router, and hand everything to [LovitApp].
///
/// This file intentionally owns no UI — routing lives in `core/router`, the
/// root widget in `app.dart` and the authenticated shell in
/// `features/shell/home_shell.dart`.

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'locationSync':
        await LocationSyncService.performBackgroundSync();
        break;
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MediaKit.ensureInitialized();

  // Initialize Firebase (required before any Firebase service).
  await Firebase.initializeApp();

  // Register the background FCM handler (must be a top-level function).
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Workmanager asynchronously.
  unawaited(Workmanager().initialize(callbackDispatcher));

  // Initialize Supabase gracefully — do not crash if offline.
  try {
    await Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase init failed (likely offline): $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final router = AppRouter(prefs: prefs);

  // Services start asynchronously so they don't block app startup.
  unawaited(LocationSyncService().initialize());

  // Listen to auth state changes and re-run router redirects.
  unawaited(
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      router.refresh();
      // Persist the current user id so background isolates (Workmanager) can
      // identify the authenticated user.
      final session = data.session;
      if (session != null) {
        await prefs.setString('auth_user_id', session.user.id);
        // Publish this device's E2EE public key so the partner can derive the
        // shared message key (no-op once published).
        unawaited(EncryptionService.instance.ensureKeyPairAndUpload());
      } else {
        await prefs.remove('auth_user_id');
      }
    }).asFuture(),
  );

  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF09080E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize the notification service after Firebase is ready.
  unawaited(NotificationService.instance.init());

  runApp(LovitApp(routerConfig: router.goRouter));
}
