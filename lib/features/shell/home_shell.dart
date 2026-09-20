import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/call_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/navigation/floating_nav_bar.dart';
import '../../widgets/navigation/nav_destination.dart';
import '../home/home_screen.dart';
import '../../screens/budget_screen.dart';
import '../../screens/calendar_screen.dart';
import '../../screens/chat_list_screen.dart';
import '../../screens/maps_screen.dart';

/// The authenticated app shell.
///
/// Hosts the five primary tabs (Home, Budget, Log, Calendar, Maps) inside a
/// swipeable [PageView] and floats the [FloatingNavBar] beneath them.
///
/// Also owns the lifecycle glue the tabs depend on: online presence
/// heartbeats, unread-message badge counts, and consuming push-notification
/// "open tab" payloads.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late final PageController _pageController;
  Timer? _presenceTimer;
  StreamSubscription<List<dynamic>>? _unreadSub;
  int _unreadCount = 0;
  int _currentIndex = 0;
  final SupabaseService _sb = SupabaseService();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();

    // Page order must match NavDestination.appTabs order.
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
      ), // 2 — Log
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
      // App came to foreground — go online immediately via DB + instant broadcast.
      _sb.setOnline();
      _sb.broadcastPresenceChange(isOnline: true);
      _sb.startBroadcastHeartbeat();
      _startPresenceTimer();
      unawaited(_consumePendingNotificationTab(animate: true));
      unawaited(CallService.instance.consumePendingCallPayload());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // App went to background / killed — go offline immediately.
      _presenceTimer?.cancel();
      _sb.stopBroadcastHeartbeat();
      _sb.broadcastPresenceChange(isOnline: false); // instant signal first
      _sb.setOffline(); // then persist to DB
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
    // Save the FCM token to Supabase so the Edge Function can reach this device.
    NotificationService.instance.getToken().then((token) {
      if (token != null) _sb.saveFcmToken(token);
    });
    // Heartbeat every 20 s keeps the DB "last seen" timestamp fresh.
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

    // The controller may not be attached yet on first frame — retry once the
    // page view is laid out.
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
    _pageController.dispose();
    _presenceTimer?.cancel();
    _unreadSub?.cancel();
    super.dispose();
  }

  void _onPageChanged(int page) {
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
      backgroundColor: const Color(0xFF0B0A12),
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FloatingNavBar(
            destinations: NavDestination.appTabs,
            currentIndex: _currentIndex,
            badgeCounts: {2: _unreadCount},
            onDestinationSelected: _navigateToPage,
          ),
        ),
      ),
    );
  }
}
