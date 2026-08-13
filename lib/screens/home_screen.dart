// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// home_screen.dart â€” Lovlet App (final + profile nav + redesigned tasks)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../models/cycle_models.dart';
import '../services/location_sync_service.dart';
import '../services/nearby_places_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';
import 'notification_screen.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Palette
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
const Color _kCard = Color(0x66111814);
const Color _kCardBorder = Color(0x26FFFFFF);
const Color _kTextPrimary = Color(0xFFEDEAF4);
const Color _kTextSub = Color(0xFFABA7B8);
const Color _kTextMuted = Color(0xFF8A8799);
const Color _kRose = Color(0xFFFF9BAB);
const Color _kPink = Color(0xFFFF6EC7);
const Color _kPurple = Color(0xFFB39DFF);
const Color _kPurpleDim = Color(0xFF6C5CE7);
const Color _kGold = Color(0xFFFFD88A);
const Color _kGreen = Color(0xFF4ADE80);

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Helpers
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
String _getGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'GOOD MORNING,';
  if (h < 17) return 'GOOD AFTERNOON,';
  return 'GOOD EVENING,';
}

String _fmtDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

String _dueLabel(DateTime? d) {
  if (d == null) return '';
  return _fmtDate(d);
}

String _fmtMoney(double value) {
  if (value >= 100000) {
    return '₹${(value / 100000).toStringAsFixed(1)}L';
  }
  final s = value.toStringAsFixed(0);
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  final result = s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  return '₹$result';
}

Color _dueLabelColor(DateTime? d) {
  if (d == null) return _kPurple;
  final today = DateTime.now();
  final diff = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff < 0) return _kRose;
  if (diff == 0) return _kPurple;
  return _kTextSub;
}

Color _taskAccentColor(DateTime? d) {
  if (d == null) return const Color(0xFF44435A);
  final today = DateTime.now();
  final diff = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff < 0) return _kRose.withValues(alpha: 0.65);
  if (diff == 0) return _kPurple.withValues(alpha: 0.65);
  return const Color(0xFF44435A);
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Models
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _Task {
  _Task({
    required this.id,
    required this.text,
    this.description,
    this.dueDate,
    this.addedBy,
    this.createdAt,
    this.tags = const [],
  });
  final String id;
  final String text;
  final String? description;
  final DateTime? dueDate;
  final String? addedBy;
  final DateTime? createdAt;
  final List<String> tags;
  bool isDone = false;
  DateTime? doneAt;
}

class _MemoryItem {
  const _MemoryItem({
    required this.imagePath,
    required this.caption,
    required this.location,
    // ignore: unused_element_parameter
    this.gradientStart = const Color(0xFF1A0533),
    // ignore: unused_element_parameter
    this.gradientMid = const Color(0xFF6B2FA0),
    // ignore: unused_element_parameter
    this.gradientEnd = const Color(0xFFFF6B35),
  });
  final String imagePath;
  final String caption;
  final String location;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// HomeScreen
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenChat,
    this.onOpenBudget,
    this.onOpenCalendar,
    this.onOpenMaps,
  });

  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenBudget;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenMaps;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  final ScrollController _scrollCtrl = ScrollController();
  late AnimationController _staggerCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _lunarBarCtrl;

  late List<Animation<double>> _fades;
  late List<Animation<Offset>> _slides;
  late Animation<double> _glowAnim;
  late Animation<double> _lunarBarAnim;

  String _greeting = _getGreeting();
  double _headerOpacity = 0.0;
  int _memPage = 0;
  final PageController _memCtrl = PageController();
  late List<_MemoryItem> _activeMemories;

  final SupabaseService _sb = SupabaseService();
  final LocationSyncService _locationSync = LocationSyncService();
  final NearbyPlacesService _nearbyPlaces = NearbyPlacesService();
  Pairing? _pairing;
  UserProfile? _myProfile;
  UserProfile? _partnerProfile;
  CycleInfo? _cycle;
  DateTime? _localLastPeriodStart;

  final _battery = Battery();
  StreamSubscription<BatteryState>? _batSub;
  StreamSubscription<List<UserProfile>>? _profileSub;
  StreamSubscription<UserProfile>? _presenceSub;
  Timer? _presenceDebounceTimer;
  StreamSubscription<BatteryUpdate>? _batteryUpdateSub;
  StreamSubscription<List<Task>>? _taskSub;
  StreamSubscription<List<PeriodLog>>? _periodSub;
  StreamSubscription<List<BudgetEntry>>? _budgetSub;
  int _myBattery = -1;
  int _partnerBattery = -1;
  DateTime? _myBatteryLastUpdated;
  DateTime? _partnerBatteryLastUpdated;
  double _budgetSpentThisMonth = 0;
  NearbyPlaceSuggestion? _smartSuggestion;
  String? _lastSuggestionKey;
  bool _isRefreshing = false;
  bool _suggestionLoading = false;
  // ignore: unused_field
  bool _loading = true;
  StreamSubscription? _reconnectSub;

  List<_Task> _tasks = [];
  static const String _kPrefLastPeriod = 'cycle_last_period_start';

  static const _memories = [
    _MemoryItem(
      imagePath: 'assets/memories/1000009172.jpg',
      caption: 'every moment with you is my favourite 🌸',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/1000017376-03.jpeg',
      caption: 'just us and all the good vibes ✨',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/1000029737.jpg',
      caption: 'my happy place is wherever you are 💛',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/1777727640636.png',
      caption: 'stealing moments, making memories 📸',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/20240812_012247-COLLAGE.jpg',
      caption: 'a collage of us, the best kind 🎞️',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/91190e5474edf59b59f6ff0489c4aab8.jpg',
      caption: 'laughing a little too loud with you 😄',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG-20240512-WA0000.jpg',
      caption: 'sent with love, always 💌',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG-20240815-WA0004.jpg',
      caption: 'a little adventure, a lot of love 🌿',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG-20250911-WA0031.jpg',
      caption: 'this one is my favourite 🥰',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG-20250911-WA0051.jpg',
      caption: 'the best kind of chaos — with you 💫',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG-20260505-WA0005(1).jpg',
      caption: 'already missing this day 🫶',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20250111133953.jpg',
      caption: 'sunlight and you — perfect combo ☀️',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20250111133959.jpg',
      caption: 'holding onto this feeling forever 🤍',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20250111134000.jpg',
      caption: 'the world is better when you\'re in it 🌍',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20250111185809.jpg',
      caption: 'evening strolls with my favourite person 🌙',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20250111190352.jpg',
      caption: 'not all sunsets need words 🌇',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20250426151117.jpg',
      caption: 'april adventures, priceless laughs 🌺',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20250923164439.jpg',
      caption: 'the kind of day you never want to end 🍂',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20250923164452.jpg',
      caption: 'us against the world, always 💪',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20251205125020.jpg',
      caption: 'december day, december love ❄️',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20251205143857.jpg',
      caption: 'sneaking glances and stealing smiles 😊',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20251205143858.jpg',
      caption: 'more of this, always more of this 🎀',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20251205143858_1.jpg',
      caption: 'the best things in life aren\'t things 💞',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20251217164445.jpg',
      caption: 'matching energy, matching hearts 💜',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20251217164501.jpg',
      caption: 'winter light and warm feelings 🕯️',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20251217164508.jpg',
      caption: 'every picture tells our story 📖',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20260113155009.jpg',
      caption: 'new year, same us — and i love it 🎉',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20260113155010.jpg',
      caption: 'january magic with my person 🌠',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20260130160058.jpg',
      caption: 'a lazy afternoon worth remembering 🌤️',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20260205152051.jpg',
      caption: 'february feels, forever feelings 🫀',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20260205152052.jpg',
      caption: 'the way you look at me 🥹',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20260205152113.jpg',
      caption: 'making memories in our city 🏙️',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG20260221161154.jpg',
      caption: 'chasing sunsets and each other 🌸',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20240213_162006_459.jpg',
      caption: 'valentine\'s day, every day with you 💝',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20240213_162007_099.jpg',
      caption: 'love looks good on us 💑',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20240213_162009_813.jpg',
      caption: 'candid and perfect, just like you 🎠',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20240213_162014_186.jpg',
      caption: 'the simplest moments hit different 🌾',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20240213_162022_050.jpg',
      caption: 'i choose you, every single time 🌹',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20240218_003433_951.jpg',
      caption: 'late nights, best vibes 🌙',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20241102_163350.jpg',
      caption: 'november nostalgia with you 🍁',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20241102_163439.jpg',
      caption: 'just another beautiful day together 🌻',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20241102_163533_844.webp',
      caption: 'even screenshots become memories 📱',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20250114_000128.jpg',
      caption: 'midnight moments, morning smiles 🌛',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20250912_201821.jpg',
      caption: 'september us is my favourite us 🌊',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20260114_220111.jpg',
      caption: 'night sky, bright us ⭐',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20260130_110957.jpg',
      caption: 'morning walks and warm hearts 🌄',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20260130_111008.jpg',
      caption: 'this view, and then there\'s you 🏞️',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20260130_172235.jpg',
      caption: 'afternoon light, lifetime love ☀️',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/IMG_20260201_150110.jpg',
      caption: 'february begins the best way 🌷',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/Snapchat-1160993944~2.jpg',
      caption: 'snap. save. cherish. repeat 💛',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/Snapchat-2128652172~2.jpg',
      caption: 'unfiltered and absolutely lovely 🎈',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/Snapchat-284442228.jpg',
      caption: 'you + me = everything 💕',
      location: 'COIMBATORE',
    ),
    _MemoryItem(
      imagePath: 'assets/memories/Screenshot_20240331-232515.png',
      caption: 'even the screens remember us 💻',
      location: 'COIMBATORE',
    ),
  ];

  Timer? _greetTimer, _memTimer, _batteryPollTimer, _presenceTimer;

  @override
  void initState() {
    super.initState();
    _activeMemories = List.from(_memories)..shuffle();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.pendingHomeAction.addListener(
      _handlePendingHomeNotificationAction,
    );

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _fades = List.generate(6, (i) {
      final s = (i * 0.09).clamp(0.0, 0.80);
      final e = (s + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(s, e, curve: Curves.easeOut),
        ),
      );
    });
    _slides = List.generate(6, (i) {
      final s = (i * 0.09).clamp(0.0, 0.80);
      final e = (s + 0.35).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(s, e, curve: Curves.easeOutCubic),
        ),
      );
    });

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    _lunarBarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _lunarBarAnim = CurvedAnimation(
      parent: _lunarBarCtrl,
      curve: Curves.easeOutCubic,
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _lunarBarCtrl.forward();
    });

    _scrollCtrl.addListener(() {
      final op = (_scrollCtrl.offset / 60.0).clamp(0.0, 1.0);
      if ((op - _headerOpacity).abs() > 0.005) {
        setState(() => _headerOpacity = op);
      }
    });

    _greetTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final g = _getGreeting();
      if (g != _greeting && mounted) {
        setState(() => _greeting = g);
      }
    });

    _memTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _memCtrl.animateToPage(
        (_memPage + 1) % _activeMemories.length,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });

    _loadBattery();
    _batSub = _battery.onBatteryStateChanged.listen((_) {
      unawaited(_loadBattery());
    });
    _batteryPollTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_loadBattery());
      unawaited(_refreshBatteryProfiles());
    });
    cycleTrackerSync.addListener(_handleCycleTrackerSync);
    unawaited(_initializeSharedState());

    _reconnectSub = _sb.onReconnect.listen((_) {
      debugPrint('[HomeScreen] Connectivity restored, auto-refreshing...');
      unawaited(_initializeSharedState(refresh: true));
    });

    _presenceTimer?.cancel();
    // _presenceTimer replaced by realtime watchPartnerPresence subscription
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingHomeNotificationAction();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadBattery());
      unawaited(_initializeSharedState(refresh: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.pendingHomeAction.removeListener(
      _handlePendingHomeNotificationAction,
    );
    _scrollCtrl.dispose();
    _staggerCtrl.dispose();
    _glowCtrl.dispose();
    _lunarBarCtrl.dispose();
    _memCtrl.dispose();
    _batSub?.cancel();
    _profileSub?.cancel();
    _batteryUpdateSub?.cancel();
    _taskSub?.cancel();
    _periodSub?.cancel();
    _budgetSub?.cancel();
    _reconnectSub?.cancel();
    cycleTrackerSync.removeListener(_handleCycleTrackerSync);
    _greetTimer?.cancel();
    _memTimer?.cancel();
    _batteryPollTimer?.cancel();
    _presenceTimer?.cancel();
    _presenceDebounceTimer?.cancel();
    super.dispose();
  }

  void _handlePendingHomeNotificationAction() {
    if (!mounted) return;
    final action = NotificationService.pendingHomeAction.value;
    if (action == NotificationService.homeTasksAction) {
      NotificationService.pendingHomeAction.value = null;
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _scrollToTasks();
        }
      });
    }
  }

  Future<void> _loadBattery() async {
    try {
      final lvl = await _battery.batteryLevel;
      final measuredAt = DateTime.now().toUtc();
      if (mounted) {
        setState(() {
          _myBattery = lvl;
          _myBatteryLastUpdated = measuredAt;
        });
      }
      await _sb.updateBatteryLevel(lvl);
    } catch (e) {
      debugPrint('[Lovlet/Battery] $e');
    }
  }

  Future<void> _refreshBatteryProfiles() async {
    final pairing = _pairing;
    if (pairing == null) {
      return;
    }

    try {
      final me = await _sb.getMyProfile();
      final partner = await _sb.getPartnerProfile(pairing.id);
      if (!mounted) {
        return;
      }
      _applyProfiles(me, partner);
    } catch (e) {
      debugPrint('[Lovlet/BatteryRefresh] $e');
    }
  }

  // ignore: unused_element
  Future<Pairing?> _resolvePairing() async {
    final active = await _sb.getActivePairing();
    if (active != null) {
      return active;
    }

    final prefs = await SharedPreferences.getInstance();
    final pairingId = prefs.getString('active_pairing_id');
    if (pairingId == null || pairingId.isEmpty) {
      return null;
    }
    return _sb.getPairing(pairingId);
  }

  bool _isPartnerOnline() {
    if (_partnerProfile == null) return false;
    return _partnerProfile!.isOnline;
  }

  String _getPartnerStatusText() {
    if (_partnerProfile == null) return 'Partner offline';
    if (_isPartnerOnline()) return 'Partner online';

    final ts = _partnerProfile!.lastSeen ?? _partnerProfile!.updatedAt;
    final local = ts.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inDays == 0 && now.day == local.day) {
      return 'Last seen today at ${DateFormat('h:mm a').format(local)}';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != local.day)) {
      return 'Last seen yesterday at ${DateFormat('h:mm a').format(local)}';
    } else {
      return 'Last seen ${DateFormat('MMM d').format(local)} at ${DateFormat('h:mm a').format(local)}';
    }
  }

  CycleInfo? _localCycleInfo() {
    final start = _localLastPeriodStart;
    if (start == null) {
      return null;
    }
    return cycleInfoFromPeriodData(startDate: start, cycleLength: 28);
  }

  double _budgetTotalForCurrentMonth(Iterable<BudgetEntry> entries) {
    final now = DateTime.now();
    return entries
        .where(
          (entry) =>
              entry.spentAt.month == now.month &&
              entry.spentAt.year == now.year,
        )
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  String? _suggestionKeyFromProfiles(UserProfile? me, UserProfile? partner) {
    final meLat = me?.currentLatitude;
    final meLng = me?.currentLongitude;
    if (meLat == null || meLng == null) {
      return null;
    }

    final partnerLat = partner?.currentLatitude;
    final partnerLng = partner?.currentLongitude;
    return [
      meLat.toStringAsFixed(3),
      meLng.toStringAsFixed(3),
      partnerLat?.toStringAsFixed(3) ?? 'na',
      partnerLng?.toStringAsFixed(3) ?? 'na',
    ].join(':');
  }

  Future<void> _refreshSmartSuggestion({
    UserProfile? me,
    UserProfile? partner,
    bool force = false,
  }) async {
    final primaryProfile = me ?? _myProfile;
    final partnerProfile = partner ?? _partnerProfile;
    final meLat = primaryProfile?.currentLatitude;
    final meLng = primaryProfile?.currentLongitude;

    if (meLat == null || meLng == null || !_nearbyPlaces.isConfigured) {
      if (mounted) {
        setState(() {
          _smartSuggestion = null;
          _suggestionLoading = false;
        });
      }
      return;
    }

    final key = _suggestionKeyFromProfiles(primaryProfile, partnerProfile);
    if (!force && key != null && key == _lastSuggestionKey) {
      return;
    }
    _lastSuggestionKey = key;

    if (mounted) {
      setState(() => _suggestionLoading = true);
    }

    final suggestion = await _nearbyPlaces.findBestSuggestion(
      latitude: meLat,
      longitude: meLng,
      partnerLatitude: partnerProfile?.currentLatitude,
      partnerLongitude: partnerProfile?.currentLongitude,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _smartSuggestion = suggestion;
      _suggestionLoading = false;
    });
  }

  Future<void> _loadLocalCyclePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDate = prefs.getString(_kPrefLastPeriod);
    final storedDate = rawDate == null ? null : DateTime.tryParse(rawDate);

    if (!mounted) {
      return;
    }

    setState(() {
      _localLastPeriodStart = storedDate == null
          ? null
          : normalizeCalendarDate(storedDate);
      final localCycle = _localCycleInfo();
      if (_pairing == null || _cycle == null) {
        _cycle = localCycle;
      }
    });
  }

  Future<void> _saveLocalCycleStart(DateTime date) async {
    final normalized = normalizeCalendarDate(date);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefLastPeriod, normalized.toIso8601String());
    cycleTrackerSync.value = normalized;

    if (!mounted) {
      return;
    }

    setState(() {
      _localLastPeriodStart = normalized;
      _cycle = _localCycleInfo();
    });
  }

  Future<void> _maybeSendUpcomingPeriodReminder() async {
    final cycle = _cycle;
    if (cycle == null || cycle.isPeriodActive || cycle.daysUntilNext != 3) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final nextStart = normalizeCalendarDate(cycle.nextPeriodStart);
    final key =
        'period_reminder_${nextStart.toIso8601String()}_${_pairing?.id ?? _sb.currentUserId ?? 'self'}';
    if (prefs.getBool(key) == true) {
      return;
    }
    await prefs.setBool(key, true);

    final selfId = _sb.currentUserId;
    if (selfId != null && selfId.isNotEmpty) {
      unawaited(
        _sb.sendPushNotification(
          toUserId: selfId,
          type: 'period',
          title: 'Period reminder',
          body: 'Your cycle is expected in about 3 days.',
        ),
      );
    }

    final pairing = _pairing;
    if (pairing != null) {
      final partnerId = pairing.user1Id == _sb.currentUserId
          ? pairing.user2Id
          : pairing.user1Id;
      if (partnerId != null && partnerId.isNotEmpty) {
        final senderName =
            _partnerProfile?.preferences['partner_nickname'] ??
            _myProfile?.displayName ??
            'Your partner';
        unawaited(
          _sb.sendPushNotification(
            toUserId: partnerId,
            type: 'period',
            title: 'Period reminder',
            body: '$senderName may be 3 days away from their next cycle.',
          ),
        );
      }
    }
  }

  void _handleCycleTrackerSync() {
    final syncedStart = cycleTrackerSync.value;
    if (!mounted || syncedStart == null) {
      return;
    }

    setState(() {
      _localLastPeriodStart = normalizeCalendarDate(syncedStart);
      _cycle = _localCycleInfo();
    });
  }

  void _setupListeners(Pairing pairing) {
    _profileSub?.cancel();
    _profileSub = _sb
        .watchProfiles([
          pairing.user1Id,
          if (pairing.user2Id != null) pairing.user2Id!,
        ])
        .listen(
          _handleProfileUpdate,
          onError: (e) {
            debugPrint('[HomeScreen] Profile stream error: $e');
          },
        );

    // Realtime partner presence (is_online + last_seen)
    _presenceSub?.cancel();
    _presenceDebounceTimer?.cancel();
    final partnerId = pairing.user1Id == _sb.currentUserId
        ? pairing.user2Id
        : pairing.user1Id;
    if (partnerId != null) {
      _presenceSub = _sb.watchPartnerPresence(partnerId).listen((profile) {
        if (!mounted) return;
        // Debounce rapid presence changes (300ms) to avoid UI flicker
        _presenceDebounceTimer?.cancel();
        _presenceDebounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _partnerProfile = profile);
          }
        });
      });
    }

    // Realtime partner battery updates (24/7 tracking)
    _batteryUpdateSub?.cancel();
    if (partnerId != null) {
      _batteryUpdateSub = _sb
          .watchPartnerBattery(partnerId)
          .listen(
            (batteryUpdate) {
              if (!mounted) return;
              debugPrint(
                '[HomeScreen] Partner battery update: ${batteryUpdate.level}% from ${batteryUpdate.userId}',
              );
              setState(() {
                if (_shouldApplyBatteryUpdate(
                  incomingLevel: batteryUpdate.level,
                  incomingUpdatedAt: batteryUpdate.lastUpdated,
                  currentLevel: _partnerBattery,
                  currentUpdatedAt: _partnerBatteryLastUpdated,
                )) {
                  _partnerBattery = batteryUpdate.level;
                  _partnerBatteryLastUpdated = _normalizeBatteryTime(
                    batteryUpdate.lastUpdated,
                  );
                }
              });
            },
            onError: (e) {
              debugPrint('[HomeScreen] Battery stream error: $e');
            },
          );
    }

    _taskSub?.cancel();
    _taskSub = _sb
        .watchTasks(pairing.id)
        .listen(
          (tasks) {
            if (!mounted) {
              return;
            }
            setState(() {
              _tasks = tasks.map(_taskFromShared).toList();
            });
          },
          onError: (e) {
            debugPrint('[HomeScreen] Task stream error: $e');
          },
        );

    _periodSub?.cancel();
    _periodSub = _sb
        .watchPeriodLogs(pairing.id)
        .listen(
          (logs) {
            if (!mounted) {
              return;
            }
            setState(() {
              final latest = logs.isEmpty ? null : logs.first;
              _cycle = latest == null
                  ? _localCycleInfo()
                  : cycleInfoFromPeriodData(
                      id: latest.id,
                      startDate: latest.startDate,
                      endDate: latest.endDate,
                      cycleLength: latest.cycleLength,
                    );
            });
            final latest = logs.isEmpty ? null : logs.first;
            if (latest != null) {
              unawaited(_saveLocalCycleStart(latest.startDate));
            }
            unawaited(_maybeSendUpcomingPeriodReminder());
          },
          onError: (e) {
            debugPrint('[HomeScreen] Period stream error: $e');
          },
        );

    _budgetSub?.cancel();
    _budgetSub = _sb
        .watchBudgetEntries(pairing.id)
        .listen(
          (entries) {
            if (!mounted) {
              return;
            }
            setState(() {
              _budgetSpentThisMonth = _budgetTotalForCurrentMonth(entries);
            });
          },
          onError: (e) {
            debugPrint('[HomeScreen] Budget stream error: $e');
          },
        );
  }

  Future<void> _initializeSharedState({bool refresh = false}) async {
    await _loadLocalCyclePrefs();

    if (_pairing != null && !refresh) {
      return;
    }

    // Attempt instant cache resolution first
    final prefs = _sb.prefsSync ?? await SharedPreferences.getInstance();
    final cachedPairingStr = prefs.getString('cache_active_pairing');
    if (cachedPairingStr != null && _pairing == null) {
      try {
        final cachedPairing = Pairing.fromJson(jsonDecode(cachedPairingStr));
        if (mounted) {
          setState(() {
            _pairing = cachedPairing;
            _loading = false;
          });
          _setupListeners(cachedPairing);
        }
      } catch (e) {
        debugPrint('[HomeScreen] Cache parse error: $e');
      }
    }

    try {
      // Resolve fresh pairing from network (with timeout inside service)
      final pairing = await _sb.getActivePairing();
      if (!mounted) return;

      if (pairing != null && (_pairing == null || _pairing!.id != pairing.id)) {
        setState(() {
          _pairing = pairing;
          _loading = false;
        });
        _setupListeners(pairing);
      } else if (pairing == null && _pairing != null) {
        // Pairing was removed/invalidated
        _cancelSubscriptions();
        setState(() {
          _pairing = null;
          _budgetSpentThisMonth = 0;
          _smartSuggestion = null;
        });
      }

      if (_pairing != null) {
        unawaited(_fetchProfilesAndSuggestions(_pairing!, refresh: refresh));
      }
    } catch (e) {
      debugPrint('[HomeScreen/Init] $e');
    }
  }

  void _cancelSubscriptions() {
    _profileSub?.cancel();
    _profileSub = null;
    _presenceSub?.cancel();
    _presenceSub = null;
    _presenceDebounceTimer?.cancel();
    _presenceDebounceTimer = null;
    _batteryUpdateSub?.cancel();
    _batteryUpdateSub = null;
    _taskSub?.cancel();
    _taskSub = null;
    _periodSub?.cancel();
    _periodSub = null;
    _budgetSub?.cancel();
    _budgetSub = null;
  }

  Future<void> _fetchProfilesAndSuggestions(
    Pairing pairing, {
    bool refresh = false,
  }) async {
    try {
      final me = await _sb.getMyProfile();
      final partner = await _sb.getPartnerProfile(pairing.id);
      if (!mounted) {
        return;
      }
      // Explicitly apply profiles to ensure battery is loaded
      _applyProfiles(me, partner);
    } catch (error) {
      debugPrint('[Lovlet/HomeSync] $error');
    }
  }

  Future<void> _toggleTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final original = _tasks[idx];
    final originalState = original.isDone;

    setState(() {
      _tasks[idx].isDone = !originalState;
      _tasks[idx].doneAt = !originalState ? DateTime.now() : null;
    });

    try {
      HapticFeedback.lightImpact();
      final nextValue = !originalState;
      await _sb.updateTask(taskId, {
        'is_completed': nextValue,
        'completed_at': nextValue
            ? DateTime.now().toUtc().toIso8601String()
            : null,
        'completed_by': nextValue ? _sb.currentUserId : null,
      });

      if (nextValue) {
        final pairing = _pairing;
        if (pairing != null) {
          final partnerId = pairing.user1Id == _sb.currentUserId
              ? pairing.user2Id
              : pairing.user1Id;
          if (partnerId != null && partnerId.isNotEmpty) {
            final senderName =
                _partnerProfile?.preferences['partner_nickname'] ??
                _myProfile?.displayName ??
                'Your partner';
            unawaited(
              _sb.sendPushNotification(
                toUserId: partnerId,
                type: 'task',
                title: '✅ Task Completed',
                body: '$senderName completed: ${original.text}',
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tasks[idx].isDone = original.isDone;
          _tasks[idx].doneAt = original.doneAt;
        });
        _showToast('Sync failed. Reverting task state.');
      }
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final original = _tasks[idx];
    final originalTasks = List<_Task>.from(_tasks);

    setState(() {
      _tasks.removeAt(idx);
    });

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text('Task "${original.text}" deleted'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                setState(() {
                  _tasks = originalTasks;
                });
              },
            ),
          ),
        )
        .closed
        .then((reason) async {
          if (reason != SnackBarClosedReason.action) {
            try {
              await _sb.deleteTask(taskId);
              final pairing = _pairing;
              if (pairing != null) {
                final partnerId = pairing.user1Id == _sb.currentUserId
                    ? pairing.user2Id
                    : pairing.user1Id;
                if (partnerId != null && partnerId.isNotEmpty) {
                  final senderName =
                      _partnerProfile?.preferences['partner_nickname'] ??
                      _myProfile?.displayName ??
                      'Your partner';
                  unawaited(
                    _sb.sendPushNotification(
                      toUserId: partnerId,
                      type: 'task',
                      title: 'Task removed',
                      body: '$senderName deleted: ${original.text}',
                    ),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                setState(() {
                  _tasks = originalTasks;
                });
                _showToast('Failed to delete task.');
              }
            }
          }
        });
  }

  Future<void> _handlePullToRefresh() async {
    if (_isRefreshing) {
      return;
    }

    HapticFeedback.mediumImpact();
    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      try {
        await _loadBattery();
      } catch (error) {
        debugPrint('[Lovlet/HomeRefresh/Battery] $error');
      }
      try {
        await _locationSync.syncNow();
      } catch (error) {
        debugPrint('[Lovlet/HomeRefresh/Location] $error');
      }
      await _initializeSharedState(refresh: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _isRefreshing = false;
      });
    } catch (error) {
      debugPrint('[Lovlet/HomeRefresh] $error');
      if (!mounted) {
        return;
      }
      setState(() => _isRefreshing = false);
      _showToast('Refresh hit a snag. Pull down again in a moment.');
    }
  }

  void _handleProfileUpdate(List<UserProfile> profiles) {
    final currentUserId = _sb.currentUserId;
    UserProfile? me;
    UserProfile? partner;

    for (final profile in profiles) {
      if (profile.id == currentUserId) {
        me = profile;
      } else {
        partner ??= profile;
      }
    }

    if (!mounted) {
      return;
    }

    _applyProfiles(me, partner);
    unawaited(_refreshSmartSuggestion(me: me, partner: partner));
  }

  DateTime? _normalizeBatteryTime(DateTime? value) => value?.toUtc();

  bool _shouldApplyBatteryUpdate({
    required int? incomingLevel,
    required DateTime? incomingUpdatedAt,
    required int currentLevel,
    required DateTime? currentUpdatedAt,
  }) {
    if (incomingLevel == null) {
      return false;
    }
    if (currentLevel < 0) {
      return true;
    }

    final nextTime = _normalizeBatteryTime(incomingUpdatedAt);
    final currentTime = _normalizeBatteryTime(currentUpdatedAt);

    if (nextTime == null) {
      return currentTime == null;
    }
    if (currentTime == null) {
      return true;
    }
    return !nextTime.isBefore(currentTime);
  }

  void _applyProfiles(UserProfile? me, UserProfile? partner) {
    debugPrint(
      '[HomeScreen] Applying profiles - Me: ${me?.displayName} (bat: ${me?.batteryLevel}), Partner: ${partner?.displayName} (bat: ${partner?.batteryLevel})',
    );
    setState(() {
      _myProfile = me ?? _myProfile;
      _partnerProfile = partner ?? _partnerProfile;
      if (_shouldApplyBatteryUpdate(
        incomingLevel: me?.batteryLevel,
        incomingUpdatedAt: me?.batteryLastUpdated,
        currentLevel: _myBattery,
        currentUpdatedAt: _myBatteryLastUpdated,
      )) {
        _myBattery = me!.batteryLevel!;
        _myBatteryLastUpdated = _normalizeBatteryTime(me.batteryLastUpdated);
        debugPrint('[HomeScreen] Set my battery to ${me.batteryLevel}%');
      } else if (me?.batteryLevel != null) {
        debugPrint(
          '[HomeScreen] Ignored stale my battery ${me!.batteryLevel}% '
          '(current: $_myBattery%)',
        );
      }
      if (_shouldApplyBatteryUpdate(
        incomingLevel: partner?.batteryLevel,
        incomingUpdatedAt: partner?.batteryLastUpdated,
        currentLevel: _partnerBattery,
        currentUpdatedAt: _partnerBatteryLastUpdated,
      )) {
        _partnerBattery = partner!.batteryLevel!;
        _partnerBatteryLastUpdated = _normalizeBatteryTime(
          partner.batteryLastUpdated,
        );
        debugPrint(
          '[HomeScreen] Set partner battery to ${partner.batteryLevel}%',
        );
      } else if (partner?.batteryLevel != null) {
        debugPrint(
          '[HomeScreen] Ignored stale partner battery ${partner!.batteryLevel}% '
          '(current: $_partnerBattery%)',
        );
      } else if (partner != null) {
        debugPrint(
          '[HomeScreen] Partner battery is NULL in database - waiting for sync',
        );
      }
    });
  }

  _Task _taskFromShared(Task task) {
    final localTask = _Task(
      id: task.id,
      text: task.title,
      description: task.description,
      dueDate: task.dueDate,
      addedBy: task.createdBy == _sb.currentUserId
          ? 'You'
          : (_myProfile?.preferences['partner_nickname'] ??
                _partnerProfile?.displayName ??
                'Partner'),
      createdAt: task.createdAt,
      tags: task.tags,
    );
    localTask.isDone = task.isCompleted;
    localTask.doneAt = task.completedAt;
    return localTask;
  }

  Future<void> _createTask(
    String title,
    String description,
    DateTime? due,
  ) async {
    final pairing = _pairing;
    if (pairing == null) {
      _showToast('Pair with your partner to add shared tasks.');
      return;
    }

    try {
      await _sb.createTask(
        pairingId: pairing.id,
        title: title,
        description: description.isEmpty ? null : description,
        dueDate: due,
      );

      final partnerId = pairing.user1Id == _sb.currentUserId
          ? pairing.user2Id
          : pairing.user1Id;
      if (partnerId != null && partnerId.isNotEmpty) {
        final senderName =
            _partnerProfile?.preferences['partner_nickname'] ??
            _myProfile?.displayName ??
            'Your partner';
        unawaited(
          _sb.sendPushNotification(
            toUserId: partnerId,
            type: 'task',
            title: '📝 New Task Added',
            body: '$senderName added: $title',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _showToast('Could not add the shared task.');
      }
    }
  }

  void _openAddTask() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTaskSheet(
        onAdd: (title, description, due) {
          unawaited(_createTask(title, description, due));
        },
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF201B2D),
      ),
    );
  }

  // ignore: unused_element
  void _openProfile() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FadeTransition(opacity: animation, child: const _ProfilePage()),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _scrollToTasks() {
    // Smoothly scroll to the tasks section
    _scrollCtrl.animateTo(
      750, // Approximate offset for the tasks card
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutQuart,
    );
  }

  void _openNotifications() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            NotificationScreen(
              onOpenChat: widget.onOpenChat,
              onOpenBudget: widget.onOpenBudget,
              onOpenCalendar: widget.onOpenCalendar,
              onOpenTasks: _scrollToTasks,
              onOpenMaps: widget.onOpenMaps,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuart;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mq = MediaQuery.of(context);
    final topInset = mq.padding.top;
    final botInset = mq.padding.bottom;
    const headerH = 64.0;
    final navPad = botInset + 12 + 64 + 20.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: RefreshIndicator(
        onRefresh: _handlePullToRefresh,
        color: _kPurple,
        backgroundColor: const Color(0xCC181E1A),
        edgeOffset: topInset + 10,
        displacement: headerH + 14,
        child: Stack(
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (context, child) => Stack(
                  children: [
                    Positioned(
                      top: -140,
                      left: -120,
                      child: _GlowBlob(
                        300,
                        _kPurpleDim.withValues(
                          alpha: 0.04 + 0.02 * _glowAnim.value,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 500,
                      right: -80,
                      child: _GlowBlob(
                        220,
                        _kPink.withValues(
                          alpha: 0.025 + 0.01 * _glowAnim.value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            CustomScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: topInset + headerH + 16),
                ),

                _spad(
                  _SI(
                    f: _fades[0],
                    s: _slides[0],
                    child: _GreetingSection(greeting: _greeting),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                _spad(
                  _SI(
                    f: _fades[1],
                    s: _slides[1],
                    child: _WellbeingCard(
                      myBattery: _myBattery,
                      partnerBattery: _partnerBattery,
                      budgetSpent: _budgetSpentThisMonth,
                      onBudgetTap: widget.onOpenBudget,
                      myName: 'You',
                      partnerName:
                          _myProfile?.preferences['partner_nickname'] ??
                          _partnerProfile?.displayName ??
                          'Partner',
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                _spad(
                  _SI(
                    f: _fades[2],
                    s: _slides[2],
                    child: _MemoryCard(
                      memories: _activeMemories,
                      pageCtrl: _memCtrl,
                      currentPage: _memPage,
                      onPageChanged: (i) => setState(() => _memPage = i),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                if (_suggestionLoading || _smartSuggestion != null)
                  _spad(
                    _SI(
                      f: _fades[3],
                      s: _slides[3],
                      child: _smartSuggestion == null
                          ? const _SmartSuggestionLoadingCard()
                          : _SmartSuggestionCard(
                              suggestion: _smartSuggestion!,
                              onTap: widget.onOpenMaps,
                            ),
                    ),
                  ),
                if (_suggestionLoading || _smartSuggestion != null)
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                _spad(
                  _SI(
                    f: _fades[4],
                    s: _slides[4],
                    child: _SharedTasksCard(
                      tasks: _tasks,
                      glowAnim: _glowAnim,
                      onDelete: (id) {
                        unawaited(_deleteTask(id));
                      },
                      onAdd: _openAddTask,
                      onToggleComplete: (id) {
                        unawaited(_toggleTask(id));
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                _spad(
                  _SI(
                    f: _fades[5],
                    s: _slides[5],
                    child: _LunarCycleCard(
                      barAnim: _lunarBarAnim,
                      cycle: _cycle,
                      onTap: widget.onOpenCalendar,
                    ),
                  ),
                ),

                SliverToBoxAdapter(child: SizedBox(height: navPad)),
              ],
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _StickyHeader(
                topInset: topInset,
                bgOpacity: _headerOpacity,
                height: headerH,
                statusText: _getPartnerStatusText(),
                isOnline: _isPartnerOnline(),
                onNotificationTap: _openNotifications,
                onSettingsTap: () {
                  HapticFeedback.mediumImpact();
                  context.push('/settings');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverPadding _spad(Widget child) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    sliver: SliverToBoxAdapter(child: child),
  );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Shared helpers
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _GlowBlob extends StatelessWidget {
  const _GlowBlob(this.size, this.color);
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

class _SI extends StatelessWidget {
  const _SI({required this.f, required this.s, required this.child});
  final Animation<double> f;
  final Animation<Offset> s;
  final Widget child;
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: f,
    child: SlideTransition(position: s, child: child),
  );
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20.0,
    this.glowColor,
    this.glowStrength = 0.04,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glowColor;
  final double glowStrength;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: radius,
    padding: padding as EdgeInsets,
    shadowColor: glowColor?.withValues(alpha: glowStrength),
    child: child,
  );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// _StickyHeader
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// _StickyHeader
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _StickyHeader extends StatelessWidget {
  const _StickyHeader({
    required this.topInset,
    required this.bgOpacity,
    required this.height,
    required this.statusText,
    required this.isOnline,
    this.onNotificationTap,
    this.onSettingsTap,
  });
  final double topInset, bgOpacity, height;
  final String statusText;
  final bool isOnline;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18 * bgOpacity,
          sigmaY: 18 * bgOpacity,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: Color.lerp(
            Colors.transparent,
            const Color(0xCC0B120D),
            bgOpacity,
          ),
          padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF9BAB).withValues(alpha: 0.12),
                  border: Border.all(
                    color: const Color(0xFFFF9BAB).withValues(alpha: 0.28),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9BAB).withValues(alpha: 0.20),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.home_rounded,
                    color: Color(0xFFFF9BAB),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      if (isOnline) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4ADE80,
                                ).withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        statusText,
                        style: TextStyle(
                          color: isOnline
                              ? const Color(0xFF4ADE80)
                              : Colors.white70,
                          fontSize: 15,
                          fontWeight: isOnline
                              ? FontWeight.w800
                              : FontWeight.w600,
                          letterSpacing: -0.3,
                          shadows: const [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: onNotificationTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: _kTextPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSettingsTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: _kTextPrimary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// _GreetingSection
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _GreetingSection extends StatelessWidget {
  const _GreetingSection({required this.greeting});
  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_kGold, _kPurple, Color(0xFFFF6EC7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            greeting,
            key: ValueKey(greeting),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -1.2,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _todayLabel(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            shadows: const [
              Shadow(
                color: Colors.black87,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _todayLabel() {
    final n = DateTime.now();
    const months = [
      '',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    const days = [
      '',
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    return '${days[n.weekday]}, ${months[n.month]} ${n.day}';
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// _WellbeingCard
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _WellbeingCard extends StatelessWidget {
  const _WellbeingCard({
    required this.myBattery,
    required this.partnerBattery,
    required this.budgetSpent,
    required this.myName,
    required this.partnerName,
    this.onBudgetTap,
  });
  final int myBattery, partnerBattery;
  final double budgetSpent;
  final String myName, partnerName;
  final VoidCallback? onBudgetTap;

  static const _syncLabel = 'LIVE BATTERY SYNC';

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: 32,
      tintColor: const Color(
        0xFF131318,
      ), // Deep dark gray for better visibility
      shadowColor: Colors.black.withValues(
        alpha: 0.6,
      ), // Stronger drop shadow for separation
      borderColor: Colors.white.withValues(
        alpha: 0.15,
      ), // Brighter edge highlight
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9BFFF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: Color(0xFFC9BFFF),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Daily Wellbeing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              _PillChip(
                label: _syncLabel,
                color: const Color(0xFF9B6FFF),
                icon: Icons.sync_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onBudgetTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFF4ADE80),
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONTHLY BUDGET',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Text(
                          'Shared Expenses',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmtMoney(budgetSpent),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'SPENT',
                      style: TextStyle(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _BatterySubCard(
                  label: myName.toUpperCase(),
                  batteryPct: myBattery,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BatterySubCard(
                  label: partnerName.toUpperCase(),
                  batteryPct: partnerBattery,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatterySubCard extends StatelessWidget {
  const _BatterySubCard({required this.label, required this.batteryPct});
  final String label;
  final int batteryPct;

  @override
  Widget build(BuildContext context) {
    final loading = batteryPct < 0;
    final pct = loading ? 0 : batteryPct;
    final batColor = loading
        ? _kTextMuted
        : pct > 50
        ? _kGreen
        : pct > 20
        ? _kGold
        : _kRose;

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderRadius: 14,
      blurSigma: 16,
      tintColor: batColor.withValues(alpha: 0.05), // Subtle colored tint
      shadowColor: batColor.withValues(
        alpha: 0.15,
      ), // Soft ambient colored glow
      borderColor: batColor.withValues(alpha: 0.20), // Colored edge highlight
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    loading ? '--' : '$pct%',
                    style: TextStyle(
                      color: batColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: batColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (!loading) _BatteryIcon(pct: pct, color: batColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: batColor.withValues(
                    alpha: 0.15,
                  ), // Colored translucent track
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  widthFactor: pct / 100.0,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: batColor,
                      boxShadow: [
                        BoxShadow(
                          color: batColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryIcon extends StatelessWidget {
  const _BatteryIcon({required this.pct, required this.color});
  final int pct;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 10,
    child: CustomPaint(painter: _BatteryPainter(pct / 100, color)),
  );
}

class _BatteryPainter extends CustomPainter {
  const _BatteryPainter(this.level, this.color);
  final double level;
  final Color color;
  @override
  void paint(Canvas canvas, Size sz) {
    final p = Paint()..isAntiAlias = true;
    const r = Radius.circular(2);
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = color.withValues(alpha: 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, sz.width - 3, sz.height), r),
      p,
    );
    p
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sz.width - 2.5, sz.height * 0.28, 2.5, sz.height * 0.44),
        r,
      ),
      p,
    );
    final w = ((sz.width - 6) * level).clamp(0.0, sz.width - 6);
    if (w > 0) {
      p.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(1.5, 1.5, w, sz.height - 3), r),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_BatteryPainter o) => o.level != level || o.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// _MemoryCard
// ══════════════════════════════════════════════════════════════════════════════
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memories,
    required this.pageCtrl,
    required this.currentPage,
    required this.onPageChanged,
  });
  final List<_MemoryItem> memories;
  final PageController pageCtrl;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final cur = memories[currentPage.clamp(0, memories.length - 1)];
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: pageCtrl,
              onPageChanged: onPageChanged,
              itemCount: memories.length,
              itemBuilder: (_, i) {
                final m = memories[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Blurred background image
                    Image.asset(
                      m.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                m.gradientStart,
                                m.gradientMid,
                                m.gradientEnd,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        );
                      },
                    ),
                    // Blur effect
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    // Crisp foreground image fitted correctly
                    Image.asset(
                      m.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                    // Dark overlay for readable text
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.82),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: Colors.white.withValues(alpha: 0.65),
                        size: 10,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'MEMORY · ${cur.location}',
                        style: const TextStyle(
                          color: Color(0xFFCCCCDD),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Align(
                      key: ValueKey(currentPage),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        cur.caption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _SmartSuggestionCard
// ══════════════════════════════════════════════════════════════════════════════
class _SmartSuggestionLoadingCard extends StatelessWidget {
  const _SmartSuggestionLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1710),
              shape: BoxShape.circle,
              border: Border.all(
                color: _kPurple.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_kPurple),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMART SUGGESTION',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checking nearby places from your latest shared location...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartSuggestionCard extends StatelessWidget {
  const _SmartSuggestionCard({required this.suggestion, this.onTap});

  final NearbyPlaceSuggestion suggestion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _DarkCard(
        padding: const EdgeInsets.all(20),
        radius: 28,
        glowColor: suggestion.isHalfwayPick
            ? _kPurple
            : suggestion.rating > 4.5
            ? _kGold
            : _kGreen,
        glowStrength: 0.1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PillChip(
                  label: suggestion.isHalfwayPick
                      ? 'MEETING HALFWAY'
                      : suggestion.rating > 4.5
                      ? 'HIGHLY RATED ★'
                      : 'NEARBY PICK ✦',
                  color: suggestion.isHalfwayPick
                      ? _kPurple
                      : suggestion.rating > 4.5
                      ? _kGold
                      : _kGreen,
                  icon: suggestion.isHalfwayPick
                      ? Icons.people_outline
                      : Icons.auto_awesome_rounded,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'AI PICK',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.isHalfwayPick
                            ? 'The perfect middle ground for both of you.'
                            : '${suggestion.name} is trending in your area.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        (suggestion.isHalfwayPick
                                ? _kPurple
                                : suggestion.rating > 4.5
                                ? _kGold
                                : _kGreen)
                            .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: suggestion.isHalfwayPick
                        ? _kPurple
                        : suggestion.rating > 4.5
                        ? _kGold
                        : _kGreen,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _MetricItem(
                  icon: Icons.location_on_rounded,
                  label: '${suggestion.distanceKm.toStringAsFixed(1)} km',
                  color: _kPurple,
                ),
                const SizedBox(width: 16),
                _MetricItem(
                  icon: Icons.star_rounded,
                  label: suggestion.rating.toStringAsFixed(1),
                  color: _kGold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SharedTasksCard extends StatelessWidget {
  const _SharedTasksCard({
    required this.tasks,
    required this.glowAnim,
    required this.onDelete,
    required this.onAdd,
    required this.onToggleComplete,
  });
  final List<_Task> tasks;
  final Animation<double> glowAnim;
  final ValueChanged<String> onDelete;
  final VoidCallback onAdd;
  final ValueChanged<String> onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final hasTasks = tasks.isNotEmpty;
    final pending = tasks.where((t) => !t.isDone).length;

    return AnimatedBuilder(
      animation: glowAnim,
      builder: (context, child) => GlassPanel(
        padding: EdgeInsets.zero,
        borderRadius: 22,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        tintColor: const Color(0xFF1A1A24),
        borderColor: Colors.white.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _IconBadge(
                        icon: Icons.sticky_note_2_rounded,
                        color: _kGold,
                        size: 14,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Shared Tasks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (pending > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _kGold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$pending',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _kGold.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, color: _kGold, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'ADD',
                            style: TextStyle(
                              color: _kGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            if (!hasTasks)
              _TaskEmptyState()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: tasks
                      .map(
                        (t) => _TaskRow(
                          task: t,
                          onToggleComplete: () => onToggleComplete(t.id),
                          onDelete: () => onDelete(t.id),
                        ),
                      )
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hasTasks
                        ? '✦ Tap checkbox to complete • Tap task for details'
                        : 'Start planning together',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white.withValues(alpha: 0.65),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggleComplete,
    required this.onDelete,
  });
  final _Task task;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = _taskAccentColor(task.dueDate);
    final due = _dueLabel(task.dueDate);
    final dueCol = _dueLabelColor(task.dueDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: task.isDone
              ? _kGreen.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.isDone
                ? _kGreen.withValues(alpha: 0.18)
                : _kGold.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 3,
              height: 54,
              color: task.isDone ? _kGreen.withValues(alpha: 0.45) : accent,
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onToggleComplete,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isDone
                      ? _kGreen.withValues(alpha: 0.18)
                      : Colors.transparent,
                  border: Border.all(
                    color: task.isDone
                        ? _kGreen
                        : Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: task.isDone
                    ? const Icon(Icons.check_rounded, color: _kGreen, size: 11)
                    : null,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: GestureDetector(
                onTap: () => _showTaskDetail(
                  context,
                  task,
                  onDelete: onDelete,
                  onToggle: onToggleComplete,
                ),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.text,
                        style: TextStyle(
                          color: task.isDone
                              ? Colors.white.withValues(alpha: 0.35)
                              : _kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          shadows: [
                            if (!task.isDone)
                              Shadow(
                                color: accent.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (task.addedBy != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                task.addedBy!.toUpperCase(),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (due.isNotEmpty)
                            Text(
                              due,
                              style: TextStyle(
                                color: task.isDone
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : dueCol.withValues(alpha: 0.9),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      if (task.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          children: task.tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kPurple.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _kPurple.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    tag.toUpperCase(),
                                    style: const TextStyle(
                                      color: _kPurple,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (task.description != null &&
                          task.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          task.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kRose.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: _kRose.withValues(alpha: 0.6),
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showTaskDetail(
  BuildContext context,
  _Task task, {
  VoidCallback? onDelete,
  VoidCallback? onToggle,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'StickyNote',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (context, anim1, anim2, child) {
      final curve = Curves.easeOutBack;
      final scale = Tween<double>(
        begin: 1.4,
        end: 1.0,
      ).animate(CurvedAnimation(parent: anim1, curve: curve));
      final rotate = Tween<double>(
        begin: 0.1,
        end: -0.02,
      ).animate(CurvedAnimation(parent: anim1, curve: curve));
      final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: anim1, curve: const Interval(0.0, 0.6)),
      );

      return Transform.scale(
        scale: scale.value,
        child: Transform.rotate(
          angle: rotate.value,
          child: Opacity(
            opacity: opacity.value,
            child: _StickyNoteDetail(
              task: task,
              onToggle: () {
                HapticFeedback.selectionClick();
                onToggle?.call();
                Navigator.pop(context);
              },
              onClose: () => Navigator.pop(context),
              onDelete: () {
                onDelete?.call();
                Navigator.pop(context);
              },
            ),
          ),
        ),
      );
    },
  );
}

class _TaskEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGold.withValues(alpha: 0.08),
                border: Border.all(
                  color: _kGold.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.favorite_outline_rounded,
                color: _kGold,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Plan something together ✦',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kTextSub,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your shared list is empty.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.28),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _StickyNoteDetail — Premium sticky note UI
// ══════════════════════════════════════════════════════════════════════════════
class _StickyNoteDetail extends StatefulWidget {
  const _StickyNoteDetail({
    required this.task,
    required this.onToggle,
    required this.onClose,
    this.onDelete,
  });

  final _Task task;
  final VoidCallback onToggle;
  final VoidCallback onClose;
  final VoidCallback? onDelete;

  @override
  State<_StickyNoteDetail> createState() => _StickyNoteDetailState();
}

class _StickyNoteDetailState extends State<_StickyNoteDetail>
    with SingleTickerProviderStateMixin {
  late AnimationController _tearCtrl;
  late Animation<double> _tearAnim;
  bool _isTearing = false;

  @override
  void initState() {
    super.initState();
    _tearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tearAnim = CurvedAnimation(parent: _tearCtrl, curve: Curves.easeInQuint);
  }

  @override
  void dispose() {
    _tearCtrl.dispose();
    super.dispose();
  }

  Color _getNoteColor() {
    final colors = [
      const Color(0xFFFFD88A),
      const Color(0xFFFF9BAB),
      const Color(0xFF8AD4FF),
      const Color(0xFF4ADE80),
      const Color(0xFFB39DFF),
      const Color(0xFFBFFFC7),
      const Color(0xFFFFB7B2),
    ];
    return colors[widget.task.id.hashCode % colors.length];
  }

  void _handleToggle() async {
    if (widget.task.isDone) {
      widget.onToggle();
      return;
    }

    setState(() => _isTearing = true);
    HapticFeedback.heavyImpact();
    await _tearCtrl.forward();
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final noteColor = _getNoteColor();

    return AnimatedBuilder(
      animation: _tearAnim,
      builder: (context, child) {
        if (!_isTearing) return Center(child: child!);

        final progress = _tearAnim.value;
        return Center(
          child: SizedBox(
            width: 320,
            height: 320,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _TearPiece(
                  progress: progress,
                  isLeft: true,
                  color: noteColor,
                  child: child!,
                ),
                _TearPiece(
                  progress: progress,
                  isLeft: false,
                  color: noteColor,
                  child: child,
                ),
              ],
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          height: 320,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          decoration: BoxDecoration(
            color: noteColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(12, 18),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.onDelete != null)
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.black.withValues(alpha: 0.25),
                        size: 19,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.black.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.text.toUpperCase(),
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.85),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (widget.task.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.task.tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          widget.task.description ?? 'No extra notes... ✦',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.55),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POSTED BY',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        widget.task.addedBy?.toUpperCase() ?? 'LOVIT',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _handleToggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.task.isDone
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: Colors.black87,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.task.isDone ? 'DONE' : 'CHECK',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TearPiece extends StatelessWidget {
  const _TearPiece({
    required this.progress,
    required this.isLeft,
    required this.color,
    required this.child,
  });
  final double progress;
  final bool isLeft;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final xOff = isLeft ? -progress * 180 : progress * 180;
    final yOff = progress * progress * 250;
    final rot = isLeft ? -progress * 0.45 : progress * 0.25;
    final opacity = (1.0 - progress * 1.2).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(xOff, yOff),
      child: Transform.rotate(
        angle: rot,
        alignment: isLeft ? Alignment.bottomRight : Alignment.bottomLeft,
        child: Opacity(
          opacity: opacity,
          child: Stack(
            children: [
              ClipPath(
                clipper: _TearClipper(isLeft: isLeft),
                child: child,
              ),
              CustomPaint(
                painter: _TearEdgePainter(isLeft: isLeft),
                size: const Size(320, 320),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TearClipper extends CustomClipper<Path> {
  const _TearClipper({required this.isLeft});
  final bool isLeft;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    if (isLeft) {
      path.moveTo(0, 0);
      path.lineTo(w * 0.5, 0);
      path.lineTo(w * 0.52, h * 0.1);
      path.lineTo(w * 0.48, h * 0.2);
      path.lineTo(w * 0.53, h * 0.3);
      path.lineTo(w * 0.47, h * 0.4);
      path.lineTo(w * 0.54, h * 0.5);
      path.lineTo(w * 0.46, h * 0.6);
      path.lineTo(w * 0.52, h * 0.7);
      path.lineTo(w * 0.48, h * 0.8);
      path.lineTo(w * 0.51, h * 0.9);
      path.lineTo(w * 0.5, h);
      path.lineTo(0, h);
    } else {
      path.moveTo(w * 0.5, 0);
      path.lineTo(w, 0);
      path.lineTo(w, h);
      path.lineTo(w * 0.5, h);
      path.lineTo(w * 0.51, h * 0.9);
      path.lineTo(w * 0.48, h * 0.8);
      path.lineTo(w * 0.52, h * 0.7);
      path.lineTo(w * 0.46, h * 0.6);
      path.lineTo(w * 0.54, h * 0.5);
      path.lineTo(w * 0.47, h * 0.4);
      path.lineTo(w * 0.53, h * 0.3);
      path.lineTo(w * 0.48, h * 0.2);
      path.lineTo(w * 0.52, h * 0.1);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TearClipper old) => false;
}

class _TearEdgePainter extends CustomPainter {
  const _TearEdgePainter({required this.isLeft});
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isLeft) {
      path.moveTo(w * 0.5, 0);
      path.lineTo(w * 0.52, h * 0.1);
      path.lineTo(w * 0.48, h * 0.2);
      path.lineTo(w * 0.53, h * 0.3);
      path.lineTo(w * 0.47, h * 0.4);
      path.lineTo(w * 0.54, h * 0.5);
      path.lineTo(w * 0.46, h * 0.6);
      path.lineTo(w * 0.52, h * 0.7);
      path.lineTo(w * 0.48, h * 0.8);
      path.lineTo(w * 0.51, h * 0.9);
      path.lineTo(w * 0.5, h);
    } else {
      path.moveTo(w * 0.5, h);
      path.lineTo(w * 0.51, h * 0.9);
      path.lineTo(w * 0.48, h * 0.8);
      path.lineTo(w * 0.52, h * 0.7);
      path.lineTo(w * 0.46, h * 0.6);
      path.lineTo(w * 0.54, h * 0.5);
      path.lineTo(w * 0.47, h * 0.4);
      path.lineTo(w * 0.53, h * 0.3);
      path.lineTo(w * 0.48, h * 0.2);
      path.lineTo(w * 0.52, h * 0.1);
      path.lineTo(w * 0.5, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TearEdgePainter old) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// _AddTaskSheet — with description field
// ══════════════════════════════════════════════════════════════════════════════
class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({required this.onAdd});
  final void Function(String title, String description, DateTime? due) onAdd;
  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _due;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kPurple,
            onPrimary: Color(0xFF1A1530),
            surface: Color(0xFF1E1828),
            onSurface: _kTextPrimary,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF1A1525),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _due = picked);
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final desc = _descCtrl.text.trim();
    widget.onAdd(title, desc, _due);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final botInset = MediaQuery.of(context).viewInsets.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, botInset + 28),
          decoration: BoxDecoration(
            color: const Color(0xFF17141E).withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add a shared task',
                style: TextStyle(
                  color: _kTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _titleCtrl,
                  autofocus: true,
                  style: const TextStyle(color: _kTextPrimary, fontSize: 15),
                  cursorColor: _kPurple,
                  decoration: const InputDecoration(
                    hintText: 'What do you need to do?',
                    hintStyle: TextStyle(
                      color: Color(0x48FFFFFF),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _descCtrl,
                  style: const TextStyle(color: _kTextSub, fontSize: 14),
                  cursorColor: _kPurple,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Add a description (optional)',
                    hintStyle: TextStyle(
                      color: Color(0x48FFFFFF),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDate,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _due != null
                        ? _kPurple.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _due != null
                          ? _kPurple.withValues(alpha: 0.28)
                          : Colors.white.withValues(alpha: 0.09),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: _due != null
                            ? _kPurple
                            : Colors.white.withValues(alpha: 0.38),
                        size: 14,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _due == null
                            ? 'Pick a due date (optional)'
                            : _fmtDate(_due!),
                        style: TextStyle(
                          color: _due != null
                              ? _kPurple
                              : Colors.white.withValues(alpha: 0.40),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      if (_due != null)
                        GestureDetector(
                          onTap: () => setState(() => _due = null),
                          child: Icon(
                            Icons.close_rounded,
                            color: _kPurple.withValues(alpha: 0.65),
                            size: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _kPurple.withValues(alpha: 0.20),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Add to our list',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _LunarCycleCard
// ══════════════════════════════════════════════════════════════════════════════
class _LunarCycleCard extends StatelessWidget {
  const _LunarCycleCard({
    required this.barAnim,
    required this.cycle,
    this.onTap,
  });
  final Animation<double> barAnim;
  final CycleInfo? cycle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activeCycle = cycle;
    final progress = activeCycle?.progress.clamp(0.0, 1.0) ?? 0.0;
    final headline = activeCycle == null
        ? 'Connect your care calendar ✨'
        : activeCycle.isPeriodActive
        ? 'Your gentle cycle is here. Take extra care! ❤️'
        : 'Your cycle approaches in ${activeCycle.daysUntilNext} days. Stay cozy! ✨';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _DarkCard(
        padding: const EdgeInsets.all(22),
        radius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _IconBadge(
                      icon: Icons.nightlight_round,
                      color: _kPink,
                      size: 14,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'LUNAR CYCLE',
                      style: TextStyle(
                        color: _kPink,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kPink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _kPink.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'LIVE SYNC',
                    style: TextStyle(
                      color: _kPink,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              headline,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.15,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 24),
            RepaintBoundary(
              child: LayoutBuilder(
                builder: (_, c) => Stack(
                  children: [
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _kPink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: barAnim,
                      builder: (context, child) => Container(
                        height: 6,
                        width: c.maxWidth * progress * barAnim.value,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_kPink.withValues(alpha: 0.80), _kRose],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: _kPink.withValues(alpha: 0.40),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  activeCycle == null
                      ? 'Set this in Calendar'
                      : 'Day ${activeCycle.currentCycleDay}',
                  style: TextStyle(
                    color: _kPink.withValues(alpha: 0.75),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  activeCycle == null
                      ? 'Shared period tracker'
                      : '${(progress * 100).round()}% through cycle',
                  style: const TextStyle(
                    color: _kTextMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  activeCycle == null
                      ? 'Waiting'
                      : '${activeCycle.cycleLength} days',
                  style: const TextStyle(
                    color: _kTextMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (activeCycle != null) ...[
              const SizedBox(height: 12),
              Text(
                activeCycle.cyclePhase,
                style: TextStyle(
                  color: _kPink.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// _ProfilePage â€“ placeholder (replace with your real profile screen)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: LovitBackground(
              blurSigma: 24,
              darkOverlayOpacity: 0.56,
              vignetteOpacity: 0.28,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _kTextPrimary,
                          size: 18,
                        ),
                      ),
                      const Text(
                        'Profile',
                        style: TextStyle(
                          color: _kTextPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9B6FFF), Color(0xFFFF6EC7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Transform.translate(
                        offset: const Offset(0, -86),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF202028),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Color(0xFF9E8FCC),
                            size: 40,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -80),
                        child: Column(
                          children: [
                            const Text(
                              'Jaswa',
                              style: TextStyle(
                                color: _kTextPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@jaswa',
                              style: TextStyle(
                                color: _kTextMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DarkCard(
                    radius: 18,
                    child: Column(
                      children: [
                        _ProfileRow(
                          icon: Icons.edit_outlined,
                          label: 'Edit profile',
                        ),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.05),
                          height: 1,
                        ),
                        _ProfileRow(
                          icon: Icons.notifications_none_rounded,
                          label: 'Notifications',
                        ),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.05),
                          height: 1,
                        ),
                        _ProfileRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'Privacy & Security',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Icon(icon, color: _kPurple, size: 18),
        const SizedBox(width: 14),
        Text(
          label,
          style: const TextStyle(
            color: _kTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Icon(Icons.chevron_right_rounded, color: _kTextMuted, size: 18),
      ],
    ),
  );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Missing Helpers Restored
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, this.size = 14});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
