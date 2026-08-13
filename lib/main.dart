import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'core/constants/supabase_constants.dart';
import 'services/battery_sync_service.dart';
import 'services/call_service.dart';
import 'services/encryption_service.dart';
import 'services/location_sync_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/pairing_debug_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/maps_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'widgets/floating_nav_bar.dart';
import 'widgets/glass.dart';

late final SharedPreferences _prefs;
late final GoRouter _router;
final ValueNotifier<bool> _routerNotifier = ValueNotifier(false);

const double kNavBarPad = 12 + 64 + 20;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'locationSync':
        await LocationSyncService.performBackgroundSync();
        break;
      case 'batterySync':
        await BatterySyncService.performBackgroundSync();
        break;
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (required before any Firebase service)
  await Firebase.initializeApp();

  // Register background FCM handler (must be top-level fn)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Workmanager asynchronously (isInDebugMode removed — deprecated in 0.9.x)
  unawaited(
    Workmanager().initialize(callbackDispatcher),
  );

  // Initialize Supabase gracefully (Do not crash if offline)
  try {
    await Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase init failed (likely offline): $e');
  }

  // Note: Email auth is handled in the router
  // Users must log in or sign up before accessing the app

  // ... (Test prints removed for brevity)

  _prefs = await SharedPreferences.getInstance();

  // Initialize Services asynchronously so they don't block app startup
  unawaited(LocationSyncService().initialize());
  unawaited(BatterySyncService().initialize());

  // Listen to auth state changes and update router
  unawaited(
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      _routerNotifier.value = !_routerNotifier.value;
      // Persist the current user id so background isolates (Workmanager) can
      // identify the authenticated user.
      final session = data.session;
      if (session != null) {
        await _prefs.setString('auth_user_id', session.user.id);
        // Publish this device's E2EE public key so the partner can derive the
        // shared message key (no-op once published).
        unawaited(EncryptionService.instance.ensureKeyPairAndUpload());
      } else {
        await _prefs.remove('auth_user_id');
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

  _router = _buildRouter();

  // Initialize notification service after Firebase is ready
  unawaited(NotificationService.instance.init());

  runApp(const LovitApp());
}

GoRouter _buildRouter() {
  return GoRouter(
    navigatorKey: NotificationService.navigatorKey,
    initialLocation: '/',
    refreshListenable: _routerNotifier,
    redirect: (context, state) async {
      // The /debug route is a developer-only pairing test harness — never
      // reachable in release builds.
      if (state.matchedLocation == '/debug' && !kDebugMode) {
        return '/home';
      }

      // Check initial onboarding (before login)
      final initialOnboarded = _prefs.getBool('initial_onboarding_done') ?? false;
      final isInitialOnboarding = state.matchedLocation == '/initial_onboarding';

      // If initial onboarding not done, show it first
      if (!initialOnboarded) {
        return isInitialOnboarding ? null : '/initial_onboarding';
      }

      // Check if user is authenticated
      final isAuthenticated = Supabase.instance.client.auth.currentSession != null;
      final isAuthRoute = state.matchedLocation == '/';

      // If not authenticated, must go to login
      if (!isAuthenticated) {
        return isAuthRoute ? null : '/';
      }

      // Check if user changed (different user logged in) - only then clear flags
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final lastUserId = _prefs.getString('last_user_id');
      
      if (currentUserId != null && currentUserId != lastUserId) {
        // Different user or first time - clear their flow flags
        _prefs.remove('profile_setup_done');
        _prefs.remove('pairing_done');
        await _prefs.setString('last_user_id', currentUserId);
      }

      // If authenticated, check post-login flow (skip onboarding - shown before login)
      var profileSetup = _prefs.getBool('profile_setup_done') ?? false;
      var paired = _prefs.getBool('pairing_done') ?? false;

      final isProfileSetup = state.matchedLocation == '/profile_setup';
      final isPairing = state.matchedLocation == '/pairing';

      // Post-login flow: Profile Setup → Pairing
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
      
      // Check if there's an active pairing - if yes, skip pairing screen and use existing credentials
      if (!paired) {
        final sb = SupabaseService();
        final activePairing = await sb.getActivePairing();
        if (activePairing != null) {
          // Pairing already exists, mark as done
          await _prefs.setBool('pairing_done', true);
          paired = true;
        }
      }
      
      if (!paired) {
        return isPairing ? null : '/pairing';
      }

      // If all steps completed, don't stay on flow screens
      if (isAuthRoute || isProfileSetup || isPairing) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Initial onboarding (before login)
      GoRoute(
        path: '/initial_onboarding',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: Builder(
            builder: (ctx) => OnboardingScreen(
              onComplete: () async {
                await _prefs.setBool('initial_onboarding_done', true);
                _routerNotifier.value = !_routerNotifier.value;
              },
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: Builder(
            builder: (ctx) => OnboardingScreen(
              onComplete: () async {
                await _prefs.setBool('onboarding_done', true);
                _routerNotifier.value = !_routerNotifier.value;
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
      // Debug route (no redirect protection)
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
                _routerNotifier.value = !_routerNotifier.value;
              },
              onSkip: () async {
                await _prefs.setBool('pairing_done', true);
                _routerNotifier.value = !_routerNotifier.value;
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
}

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

class LovitApp extends StatelessWidget {
  const LovitApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lovit',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09080E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC9BFFF),
          secondary: Color(0xFFFF9BAB),
          surface: Color(0xFF131318),
          onPrimary: Color(0xFF1A1530),
          onSecondary: Colors.white,
          onSurface: Color(0xFFF2EFF9),
        ),
        useMaterial3: true,
      ),
    );
  }
}

// HomeShell (unchanged – placeholder pages remain)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _presenceTimer;
  StreamSubscription? _unreadSub;
  int _unreadCount = 0;
  final _sb = SupabaseService();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _pageController.addListener(_onScroll);

    // Initialize pages with navigation callbacks wired to PageController
    _pages = [
      HomeScreen(
        onOpenChat: () => _navigateToPage(2),
        onOpenBudget: () => _navigateToPage(1),
        onOpenCalendar: () => _navigateToPage(3),
        onOpenMaps: () => _navigateToPage(4),
      ), // 0 — Home
      BudgetScreen(), // 1 — Budget
      ChatListScreen(
        onOpenBudget: () => _navigateToPage(1),
        onOpenCalendar: () => _navigateToPage(3),
        onOpenTasks: () => _navigateToPage(0),
        onOpenMaps: () => _navigateToPage(4),
      ), // 2 — Chat (Log Page)
      CalendarScreen(), // 3 — Calendar
      MapsScreen(), // 4 — Maps
    ];

    _startPresenceTimer();
    _initUnreadListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumePendingNotificationTab());
      unawaited(CallService.instance.consumePendingCallPayload());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground — go online immediately via DB + instant broadcast
      _sb.setOnline();
      _sb.broadcastPresenceChange(isOnline: true);
      _sb.startBroadcastHeartbeat();
      _startPresenceTimer();
      unawaited(_consumePendingNotificationTab(animate: true));
      unawaited(CallService.instance.consumePendingCallPayload());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // App went to background / killed — go offline immediately
      _presenceTimer?.cancel();
      _sb.stopBroadcastHeartbeat();
      _sb.broadcastPresenceChange(isOnline: false); // instant signal first
      _sb.setOffline();                              // then persist to DB
    }
    // NOTE: AppLifecycleState.inactive is intentionally NOT handled here.
    // It fires transiently (notification shade, phone call UI, etc.) and
    // would cause false offline flickers.
  }

  void _initUnreadListener() async {
    final pairing = await _sb.getActivePairing();
    if (pairing != null) {
      _unreadSub?.cancel();
      _unreadSub = _sb.watchMessages(pairing.id).listen((msgs) {
        final count = msgs
            .where((m) => !m.isRead && m.senderId != _sb.currentUserId)
            .length;
        if (mounted && count != _unreadCount) {
          setState(() => _unreadCount = count);
        }
      });
    }
  }

  void _startPresenceTimer() {
    _presenceTimer?.cancel();
    _sb.setOnline();
    // Save FCM token to Supabase so Edge Function can reach this device
    NotificationService.instance.getToken().then((token) {
      if (token != null) _sb.saveFcmToken(token);
    });
    // Heartbeat every 20 s keeps the DB timestamp fresh for "last seen" fallback
    _presenceTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _sb.setOnline();
    });
  }

  Future<void> _consumePendingNotificationTab({bool animate = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final tab = prefs.getInt('notification_tab');
    if (tab == null) return;
    await prefs.remove('notification_tab');
    if (!mounted || tab < 0 || tab >= _pages.length) return;

    if (!_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_consumePendingNotificationTab(animate: animate));
        }
      });
      return;
    }

    setState(() => _currentIndex = tab);
    if (animate) {
      _pageController.animateToPage(
        tab,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.jumpToPage(tab);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    _presenceTimer?.cancel();
    _unreadSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentIndex) setState(() => _currentIndex = page);
  }

  void _navigateToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: LovitBackground(
              blurSigma: 26,
              darkOverlayOpacity: 0.56,
              vignetteOpacity: 0.30,
            ),
          ),
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
            children: _pages,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FloatingNavBar(
            currentIndex: _currentIndex,
            unreadCount: _unreadCount,
            onTap: (i) => _navigateToPage(i),
          ),
        ),
      ),
    );
  }
}



