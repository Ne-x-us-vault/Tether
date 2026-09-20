import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/shell/home_shell.dart';
import '../../screens/edit_profile_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/notification_screen.dart';
import '../../screens/onboarding_screen.dart';
import '../../screens/pairing_debug_screen.dart';
import '../../screens/pairing_screen.dart';
import '../../screens/profile_setup_screen.dart';
import '../../screens/settings_screen.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';

/// Owns the [GoRouter] configuration, re-dispatch logic and the notifier that
/// forces a redirect re-evaluation whenever auth / onboarding / pairing state
/// changes.
class AppRouter {
  AppRouter({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  /// Flip to re-run redirects (auth state, onboarding, pairing, user switch).
  final ValueNotifier<bool> notifier = ValueNotifier<bool>(false);

  late final GoRouter goRouter = GoRouter(
    navigatorKey: NotificationService.navigatorKey,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: _redirect,
    routes: <RouteBase>[
      GoRoute(
        path: '/initial_onboarding',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: Builder(
            builder: (ctx) => OnboardingScreen(
              onComplete: () async {
                await _prefs.setBool('initial_onboarding_done', true);
                refresh();
              },
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _fadePage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: Builder(
            builder: (ctx) => OnboardingScreen(
              onComplete: () async {
                await _prefs.setBool('onboarding_done', true);
                refresh();
              },
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/profile_setup',
        pageBuilder: (context, state) =>
            _fadePage(state: state, child: const ProfileSetupScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _fadePage(state: state, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _fadePage(state: state, child: const NotificationScreen()),
      ),
      GoRoute(
        path: '/edit_profile',
        pageBuilder: (context, state) =>
            _fadePage(state: state, child: const EditProfileScreen()),
      ),
      // Developer-only pairing test harness — not reachable in release builds
      // (the redirect below bounces /debug to /home when !kDebugMode).
      GoRoute(
        path: '/debug',
        pageBuilder: (context, state) =>
            _fadePage(state: state, child: const PairingDebugScreen()),
      ),
      GoRoute(
        path: '/pairing',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: Builder(
            builder: (ctx) => PairingScreen(
              onPaired: () async {
                await _prefs.setBool('pairing_done', true);
                refresh();
              },
              onSkip: () async {
                await _prefs.setBool('pairing_done', true);
                refresh();
              },
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) =>
            _fadePage(state: state, child: const HomeShell()),
      ),
    ],
  );

  void refresh() => notifier.value = !notifier.value;

  Future<String?> _redirect(BuildContext context, GoRouterState state) async {
    // The /debug route is a developer-only pairing test harness — never
    // reachable in release builds.
    if (state.matchedLocation == '/debug' && !kDebugMode) {
      return '/home';
    }

    // Check initial onboarding (before login)
    final initialOnboarded = _prefs.getBool('initial_onboarding_done') ?? false;
    final isInitialOnboarding = state.matchedLocation == '/initial_onboarding';

    if (!initialOnboarded) {
      return isInitialOnboarding ? null : '/initial_onboarding';
    }

    // Check if the user is authenticated
    final isAuthenticated =
        Supabase.instance.client.auth.currentSession != null;
    final isAuthRoute = state.matchedLocation == '/';

    if (!isAuthenticated) {
      return isAuthRoute ? null : '/';
    }

    // If the user changed (different account), clear the previous user's flow
    // flags.
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final lastUserId = _prefs.getString('last_user_id');

    if (currentUserId != null && currentUserId != lastUserId) {
      _prefs.remove('profile_setup_done');
      _prefs.remove('pairing_done');
      await _prefs.setString('last_user_id', currentUserId);
    }

    // Post-login flow: Profile Setup → Pairing
    var profileSetup = _prefs.getBool('profile_setup_done') ?? false;
    var paired = _prefs.getBool('pairing_done') ?? false;

    final isProfileSetup = state.matchedLocation == '/profile_setup';
    final isPairing = state.matchedLocation == '/pairing';

    if (!profileSetup) {
      final sb = SupabaseService();
      final profile = await sb.getMyProfile();
      final partnerNickname =
          profile?.preferences['partner_nickname']?.toString().trim() ?? '';
      if (partnerNickname.isNotEmpty) {
        await _prefs.setBool('profile_setup_done', true);
        profileSetup = true;
      } else {
        return isProfileSetup ? null : '/profile_setup';
      }
    }

    // If there's an active pairing, skip the pairing screen and reuse the
    // existing credentials.
    if (!paired) {
      final sb = SupabaseService();
      final activePairing = await sb.getActivePairing();
      if (activePairing != null) {
        await _prefs.setBool('pairing_done', true);
        paired = true;
      }
    }

    if (!paired) {
      return isPairing ? null : '/pairing';
    }

    // All flow steps complete — never leave the user stranded on flow screens.
    if (isAuthRoute || isProfileSetup || isPairing) {
      return '/home';
    }

    return null;
  }
}

/// Consistent soft fade + slide transition for every route.
CustomTransitionPage<void> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
  );
}
