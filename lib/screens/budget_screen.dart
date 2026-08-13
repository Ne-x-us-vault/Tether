// ══════════════════════════════════════════════════════════════════════════════
// budget_screen.dart — Lovit App
// Shared monthly budget tracker — dark glassmorphic theme
// TODO(backend): Replace all local state with Supabase realtime table
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../main.dart' show kNavBarPad;
import '../services/supabase_service.dart';
import '../widgets/glass.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Palette
// ══════════════════════════════════════════════════════════════════════════════
const Color _kTextPrimary = Color(0xFFEDEAF4);
const Color _kTextMuted = Color(0xFF5A5768);
const Color _kPurple = Color(0xFFB39DFF);
const Color _kPurpleViv = Color(0xFF9B6FFF);
const Color _kPurpleDim = Color(0xFF6C5CE7);
const Color _kRose = Color(0xFFFF9BAB);
const Color _kGreen = Color(0xFF4ADE80);

// ══════════════════════════════════════════════════════════════════════════════
// Models — UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
enum _Category { food, shopping, travel, bills, other }

extension _CatExt on _Category {
  String get label {
    switch (this) {
      case _Category.food:
        return 'Food';
      case _Category.shopping:
        return 'Shopping';
      case _Category.travel:
        return 'Travel';
      case _Category.bills:
        return 'Bills';
      case _Category.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case _Category.food:
        return Icons.restaurant_rounded;
      case _Category.shopping:
        return Icons.shopping_cart_rounded;
      case _Category.travel:
        return Icons.directions_car_rounded;
      case _Category.bills:
        return Icons.bolt_rounded;
      case _Category.other:
        return Icons.more_horiz_rounded;
    }
  }

  Color get color {
    switch (this) {
      case _Category.food:
        return const Color(0xFFFFD88A);
      case _Category.shopping:
        return const Color(0xFFFB923C);
      case _Category.travel:
        return const Color(0xFF818CF8);
      case _Category.bills:
        return const Color(0xFF4ADE80);
      case _Category.other:
        return const Color(0xFF38BDF8);
    }
  }
}

class _Expense {
  _Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.paidByMe,
    required this.transactionDate,
  });
  final String id;
  final double amount;
  final String description;
  final _Category category;
  final bool paidByMe;
  final DateTime transactionDate;
}

// ══════════════════════════════════════════════════════════════════════════════
// Helpers — UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
String _fmtAmount(double v) {
  if (v >= 100000) {
    return '₹${(v / 100000).toStringAsFixed(1)}L';
  }
  final s = v.toStringAsFixed(0);
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  final result = s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  return '₹$result';
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays}d ago';
}

String _formatExpenseDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final comparisonDate = DateTime(dt.year, dt.month, dt.day);

  if (comparisonDate == today) {
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  } else if (comparisonDate == yesterday) {
    return 'Yesterday';
  } else if (dt.year == now.year) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  } else {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

String _monthLabel(DateTime d) {
  const months = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[d.month]} ${d.year}';
}

// ══════════════════════════════════════════════════════════════════════════════
// BudgetScreen — LOGIC UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key, this.onOpenMaps});
  final VoidCallback? onOpenMaps;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final SupabaseService _sb = SupabaseService();

  late TabController _tabCtrl;
  Pairing? _pairing;
  StreamSubscription<List<BudgetEntry>>? _budgetSub;
  StreamSubscription<List<UserProfile>>? _profileSub;
  UserProfile? _myProfile;
  UserProfile? _partnerProfile;
  bool _loading = true;
  String? _error;
  StreamSubscription? _reconnectSub;

  List<_Expense> _expenses = [];
  String _myName = 'You';
  String _partnerName = 'Partner';

  // Filter state
  _Category? _filterCategory;
  String _filterPayer = 'all'; // 'all' | 'me' | 'partner'
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  double get _totalThisMonth {
    final now = DateTime.now();
    return _expenses
        .where(
          (e) =>
              e.transactionDate.month == now.month &&
              e.transactionDate.year == now.year,
        )
        .fold(0.0, (s, e) => s + e.amount);
  }

  double get _myContribution {
    final now = DateTime.now();
    return _expenses
        .where(
          (e) =>
              e.paidByMe &&
              e.transactionDate.month == now.month &&
              e.transactionDate.year == now.year,
        )
        .fold(0.0, (s, e) => s + e.amount);
  }

  double get _partnerContribution => _totalThisMonth - _myContribution;

  List<_Expense> get _thisMonthExpenses {
    final now = DateTime.now();
    return _expenses
        .where(
          (e) =>
              e.transactionDate.month == now.month &&
              e.transactionDate.year == now.year,
        )
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
  }

  List<_Expense> get _filteredExpenses {
    return _thisMonthExpenses.where((e) {
      if (_filterCategory != null && e.category != _filterCategory) {
        return false;
      }
      if (_filterPayer == 'me' && !e.paidByMe) return false;
      if (_filterPayer == 'partner' && e.paidByMe) return false;
      return true;
    }).toList();
  }

  Map<String, List<_Expense>> get _historyByMonth {
    final now = DateTime.now();
    final past = _expenses
        .where(
          (e) =>
              !(e.transactionDate.month == now.month &&
                  e.transactionDate.year == now.year),
        )
        .toList();
    final Map<String, List<_Expense>> map = {};
    for (final e in past) {
      map.putIfAbsent(_monthLabel(e.transactionDate), () => []).add(e);
    }
    for (final list in map.values) {
      list.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _initializeBudgets();

    _reconnectSub = _sb.onReconnect.listen((_) {
      debugPrint('[Budget] Connectivity restored, auto-refreshing...');
      _initializeBudgets();
    });
  }

  Future<void> _initializeBudgets() async {
    try {
      final pairing = await _resolvePairing();

      // Fetch dynamic names
      final uid = _sb.currentUserId;
      UserProfile? me;
      UserProfile? partner;

      if (uid != null) {
        me = await _sb.getMyProfile();
      }

      if (pairing != null) {
        partner = await _sb.getPartnerProfile(pairing.id);
      }

      if (!mounted) return;

      setState(() {
        _pairing = pairing;
        _myProfile = me;
        _partnerProfile = partner;
        _myName = 'You';
        _partnerName =
            me?.preferences['partner_nickname'] ??
            partner?.displayName ??
            'Partner';
        _error = null;
      });

      if (pairing != null) {
        _profileSub?.cancel();
        _profileSub = _sb
            .watchProfiles([pairing.user1Id, pairing.user2Id ?? ''])
            .listen((profiles) {
              if (!mounted) return;
              final currentUserId = _sb.currentUserId;
              for (final p in profiles) {
                if (p.id == currentUserId) {
                  _myProfile = p;
                } else {
                  _partnerProfile = p;
                }
              }
              setState(() {
                _partnerName =
                    _myProfile?.preferences['partner_nickname'] ??
                    _partnerProfile?.displayName ??
                    'Partner';
              });
            });
      }

      final effectivePairingId = pairing?.id ?? _sb.currentUserId;
      if (effectivePairingId == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'User not identified.';
          });
        }
        return;
      }

      await _budgetSub?.cancel();
      _budgetSub = _sb
          .watchBudgetEntries(effectivePairingId)
          .listen(
            (entries) {
              if (!mounted) return;
              setState(() {
                _expenses.clear();
                _expenses.addAll(entries.map(_expenseFromBudgetEntry));
                _loading = false;
                _error = null;
              });
            },
            onError: (error) {
              if (!mounted) return;
              debugPrint('[Budget] Stream error: $error');
              setState(() {
                _loading = false;
                if (_expenses.isEmpty) {
                  _error = 'Failed to sync budget data.';
                } else {
                  _error = null; // Keep showing cached data
                }
              });
            },
          );
    } catch (e) {
      debugPrint('[Budget] Init error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load budget data.';
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    await _initializeBudgets();
  }

  Future<Pairing?> _resolvePairing() async {
    try {
      final active = await _sb.getActivePairing();
      if (active != null) return active;

      final prefs = await SharedPreferences.getInstance();
      final pairingId = prefs.getString('active_pairing_id');
      if (pairingId == null || pairingId.isEmpty) return null;
      return _sb.getPairing(pairingId);
    } catch (e) {
      debugPrint('[Budget] Pairing resolution error: $e');
      return null;
    }
  }

  _Expense _expenseFromBudgetEntry(BudgetEntry entry) {
    // Determine who paid by comparing the paidByUserId with current user
    // This works correctly from each user's perspective
    final currentUserId = _sb.currentUserId;
    final paidByMe = entry.effectivePaidByUserId == currentUserId;

    return _Expense(
      id: entry.id,
      amount: entry.amount,
      description: entry.title,
      category: _categoryFromString(entry.category),
      paidByMe: paidByMe,
      transactionDate: entry.transactionDate,
    );
  }

  _Category _categoryFromString(String cat) {
    return _Category.values.firstWhere(
      (c) => c.name == cat.toLowerCase(),
      orElse: () => _Category.other,
    );
  }

  String _categoryToString(_Category cat) => cat.name;

  @override
  void dispose() {
    _tabCtrl.dispose();
    _budgetSub?.cancel();
    _profileSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }

  Future<void> _addExpense(_Expense e) async {
    final pairing = _pairing;
    final effectivePairingId = pairing?.id ?? _sb.currentUserId;
    if (effectivePairingId == null) {
      _showToast('Please sign in to add expenses.');
      return;
    }

    try {
      HapticFeedback.lightImpact();

      final currentUserId = _sb.currentUserId;
      String? paidByUserId; // null means current user paid (default)

      if (!e.paidByMe && pairing != null) {
        // Partner paid — resolve their user ID from the pairing
        final partnerId = pairing.user1Id == currentUserId
            ? pairing.user2Id
            : pairing.user1Id;
        if (partnerId == null || partnerId.isEmpty) {
          debugPrint('[Budget] Partner ID could not be resolved');
          _showToast('Could not identify partner. Please try again.');
          return;
        }
        paidByUserId = partnerId;
      } else if (!e.paidByMe && pairing == null) {
        // Cannot have partner pay if not paired
        _showToast('Pair with a partner to add expenses paid by them.');
        return;
      }
      // e.paidByMe == true → paidByUserId stays null (service defaults to currentUser)

      debugPrint(
        '[Budget] Adding expense — title: ${e.description}, '
        'amount: ${e.amount}, paidByMe: ${e.paidByMe}, '
        'paidByUserId: $paidByUserId',
      );

      await _sb.createBudgetEntry(
        pairingId: effectivePairingId,
        title: e.description,
        amount: e.amount,
        category: _categoryToString(e.category),
        notes: null,
        transactionDate: e.transactionDate,
        paidByUserId: paidByUserId,
      );

      debugPrint('[Budget] Expense created successfully');

      // Send push notification to partner
      if (pairing != null) {
        final partnerId = pairing.user1Id == currentUserId
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
              type: 'budget',
              title: '💰 Budget update',
              body:
                  '$senderName added ₹${e.amount.toStringAsFixed(0)} for ${e.category.label}',
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('[Budget] Add error: $error');
      if (mounted) {
        _showToast('Could not add expense: ${error.toString()}');
      }
    }
  }

  Future<void> _deleteExpense(String id) async {
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    final original = _expenses[idx];
    final originalExpenses = List<_Expense>.from(_expenses);

    setState(() {
      _expenses.removeAt(idx);
    });

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text('Expense "${original.description}" removed'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                setState(() {
                  _expenses = originalExpenses;
                });
              },
            ),
          ),
        )
        .closed
        .then((reason) async {
          if (reason != SnackBarClosedReason.action) {
            try {
              await _sb.deleteBudgetEntry(id);
              final pairing = _pairing;
              final currentUserId = _sb.currentUserId;
              if (pairing != null && currentUserId != null) {
                final partnerId = pairing.user1Id == currentUserId
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
                      type: 'budget',
                      title: 'Budget update',
                      body:
                          '$senderName deleted ${original.description} for ${_fmtAmount(original.amount)}',
                    ),
                  );
                }
              }
            } catch (error) {
              debugPrint('[Budget] Delete error: $error');
              if (mounted) {
                setState(() {
                  _expenses = originalExpenses;
                });
                _showToast('Could not delete expense.');
              }
            }
          }
        });
  }

  Future<void> _updateExpense(
    String id, {
    required String title,
    required double amount,
    required _Category category,
    required bool paidByMe,
    required DateTime transactionDate,
  }) async {
    final pairing = _pairing;
    try {
      HapticFeedback.lightImpact();
      final cu = _sb.currentUserId ?? '';
      final paidBy = paidByMe
          ? cu
          : (pairing == null
                ? cu
                : (pairing.user1Id == cu
                      ? (pairing.user2Id ?? cu)
                      : pairing.user1Id));
      await _sb.updateBudgetEntry(id, {
        'title': title,
        'amount': amount,
        'category': category.name,
        'paid_by': paidBy,
        'transaction_date': transactionDate,
      });
    } catch (error) {
      debugPrint('[Budget] Update error: $error');
      if (mounted) _showToast('Could not update expense.');
    }
  }

  void _showExpenseDetail(_Expense expense) {
    final cu = _sb.currentUserId ?? '';
    final p = _pairing;
    final partnerId = p == null
        ? ''
        : (p.user1Id == cu ? (p.user2Id ?? '') : p.user1Id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseDetailSheet(
        expense: expense,
        currentUserId: cu,
        partnerId: partnerId,
        myName: _myName,
        partnerName: _partnerName,
        onOpenMaps: widget.onOpenMaps,
        onDelete: () {
          Navigator.pop(context);
          _deleteExpense(expense.id);
        },
        onUpdate: (title, amount, category, paidByMe, transactionDate) =>
            _updateExpense(
              expense.id,
              title: title,
              amount: amount,
              category: category,
              paidByMe: paidByMe,
              transactionDate: transactionDate,
            ),
      ),
    );
  }

  void _showToast(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF201B2D),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openAddSheet() {
    final pairing = _pairing;
    final effectivePairingId = pairing?.id ?? _sb.currentUserId;
    if (effectivePairingId == null) {
      _showToast('Please sign in to add expenses.');
      return;
    }

    final currentUserId = _sb.currentUserId ?? '';
    final partnerId = pairing == null
        ? ''
        : (pairing.user1Id == currentUserId
              ? (pairing.user2Id ?? '')
              : pairing.user1Id);

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExpenseSheet(
        onAdd: _addExpense,
        currentUserId: currentUserId,
        partnerId: partnerId,
        myName: _myName,
        partnerName: _partnerName,
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _selectAll() {
    setState(() {
      final ids = _filteredExpenses.map((e) => e.id).toList();
      if (_selectedIds.length == ids.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(ids);
        _isSelectionMode = true;
      }
    });
    HapticFeedback.mediumImpact();
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final idsToDelete = _selectedIds.toList();
    final count = idsToDelete.length;
    final originalExpenses = List<_Expense>.from(_expenses);

    // Optimistic UI update
    setState(() {
      _expenses.removeWhere((e) => idsToDelete.contains(e.id));
      _exitSelectionMode();
    });

    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text('Deleted $count expenses'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                setState(() {
                  _expenses = originalExpenses;
                });
              },
            ),
          ),
        )
        .closed
        .then((reason) async {
          if (reason != SnackBarClosedReason.action) {
            try {
              for (final id in idsToDelete) {
                await _sb.deleteBudgetEntry(id);
              }
            } catch (e) {
              if (mounted) {
                setState(() {
                  _expenses = originalExpenses;
                });
                _showToast('Failed to delete some expenses');
              }
            }
          }
        });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mq = MediaQuery.of(context);
    final topInset = mq.padding.top;
    final botInset = mq.padding.bottom;
    final navPad = botInset + kNavBarPad;

    // Show error state (even after loading finishes, if no pairing)
    if (_error != null && !_loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: _kTextMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Loading budget...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _kTextMuted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Glassmorphic ambient background ──────────────────────────────
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_kPurpleDim.withValues(alpha: 0.06), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 300,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_kRose.withValues(alpha: 0.04), Colors.transparent],
                ),
              ),
            ),
          ),

          Column(
            children: [
              SizedBox(height: topInset),

              // ── Header ───────────────────────────────────────────────────────
              // ── Premium Glass Header ───────────────────────────────────────
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Glassmorphic icon badge with glow
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _kPurple.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: _kPurple.withValues(alpha: 0.28),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kPurple.withValues(alpha: 0.20),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: _kPurple,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Budget',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _monthLabel(DateTime.now()).toUpperCase(),
                                  style: TextStyle(
                                    color: _kPurple.withValues(alpha: 0.6),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Sync indicator with pulse effect feel
                        if (!_loading)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _kGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _kGreen.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _kGreen,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _kGreen.withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: _kGreen.withValues(alpha: 0.9),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Tab bar ───────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _BudgetTabBar(ctrl: _tabCtrl),
              ),
              const SizedBox(height: 4),

              // ── Tab content ───────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _HomeTab(
                      total: _totalThisMonth,
                      myContribution: _myContribution,
                      partnerContribution: _partnerContribution,
                      myName: _myName,
                      partnerName: _partnerName,
                      allExpenses: _thisMonthExpenses,
                      expenses: _filteredExpenses,
                      navPad: navPad,
                      onDelete: _deleteExpense,
                      onAdd: _openAddSheet,
                      onTap: _showExpenseDetail,
                      onLongPress: _toggleSelection,
                      isSelectionMode: _isSelectionMode,
                      selectedIds: _selectedIds,
                      onExitSelection: _exitSelectionMode,
                      onSelectAll: _selectAll,
                      onDeleteSelected: _deleteSelected,
                      isLoading: _loading,
                      error: _error,
                      filterCategory: _filterCategory,
                      filterPayer: _filterPayer,
                      onCategoryFilter: (c) =>
                          setState(() => _filterCategory = c),
                      onPayerFilter: (p) => setState(() => _filterPayer = p),
                      onRefresh: _handleRefresh,
                    ),
                    _HistoryTab(
                      historyByMonth: _historyByMonth,
                      allExpenses: _expenses,
                      navPad: navPad,
                      onTap: _showExpenseDetail,
                      onRefresh: _handleRefresh,
                      myName: _myName,
                      partnerName: _partnerName,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // FAB — glassmorphic style (unified with Calendar)
          if (_tabCtrl.index == 0 && !_loading && !_isSelectionMode)
            Positioned(
              bottom:
                  botInset +
                  12, // Side-by-side with the navigation bar (approx 46px)
              right: 16,
              child: GestureDetector(
                onTap: _openAddSheet,
                child: GlassPanel(
                  borderRadius: 28,
                  padding: EdgeInsets.zero,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kPurple.withValues(alpha: 0.85),
                      boxShadow: [
                        BoxShadow(
                          color: _kPurple.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab bar — LOGIC UNCHANGED, glassmorphic pill container added
// ══════════════════════════════════════════════════════════════════════════════
class _BudgetTabBar extends StatelessWidget {
  const _BudgetTabBar({required this.ctrl});
  final TabController ctrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final activeIndex = ctrl.index;
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Sliding glass bubble
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    alignment: activeIndex == 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _kPurple.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _kPurple.withValues(alpha: 0.40),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _kPurple.withValues(alpha: 0.20),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Tab Texts
                  Row(
                    children: ['Home', 'History'].asMap().entries.map((e) {
                      final active = activeIndex == e.key;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ctrl.animateTo(e.key);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: active ? Colors.white : _kTextMuted,
                                fontSize: active ? 14 : 13,
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                              child: Text(e.value),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Home tab — LOGIC UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.total,
    required this.myContribution,
    required this.partnerContribution,
    required this.myName,
    required this.partnerName,
    required this.allExpenses,
    required this.expenses,
    required this.navPad,
    required this.onDelete,
    required this.onAdd,
    required this.onTap,
    required this.onLongPress,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onExitSelection,
    required this.onSelectAll,
    required this.onDeleteSelected,
    required this.filterCategory,
    required this.filterPayer,
    required this.onCategoryFilter,
    required this.onPayerFilter,
    required this.onRefresh,
    this.isLoading = false,
    this.error,
  });
  final double total, myContribution, partnerContribution;
  final String myName, partnerName;
  final List<_Expense> allExpenses, expenses;
  final double navPad;
  final ValueChanged<String> onDelete;
  final VoidCallback onAdd;
  final ValueChanged<_Expense> onTap;
  final ValueChanged<String> onLongPress;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final VoidCallback onExitSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onDeleteSelected;
  final _Category? filterCategory;
  final String filterPayer;
  final ValueChanged<_Category?> onCategoryFilter;
  final ValueChanged<String> onPayerFilter;
  final RefreshCallback onRefresh;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _kPurple,
      backgroundColor: const Color(0xFF1E1E24),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _HeroCard(
                total: total,
                myContribution: myContribution,
                partnerContribution: partnerContribution,
                myName: myName,
                partnerName: partnerName,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _ContributionRow(
                myAmount: myContribution,
                partnerAmount: partnerContribution,
                myName: myName,
                partnerName: partnerName,
              ),
            ),
          ),
          if (allExpenses.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _StatisticsCard(
                  expenses: allExpenses,
                  myContribution: myContribution,
                  partnerContribution: partnerContribution,
                  myName: myName,
                  partnerName: partnerName,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: _FilterPills(
              selected: filterCategory,
              payer: filterPayer,
              onCategory: onCategoryFilter,
              onPayer: onPayerFilter,
              myName: myName,
              partnerName: partnerName,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Transactions',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          // --- Selection Toolbar ---
          if (isSelectionMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  borderRadius: 20,
                  shadowColor: _kPurple.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      Text(
                        '${selectedIds.length} SELECTED',
                        style: const TextStyle(
                          color: _kPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: onSelectAll,
                        child: Text(
                          selectedIds.length == expenses.length
                              ? 'DESELECT ALL'
                              : 'SELECT ALL',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onDeleteSelected,
                        icon: const Icon(
                          Icons.delete_sweep_rounded,
                          color: _kRose,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: onExitSelection,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          expenses.isEmpty && !isLoading
              ? SliverToBoxAdapter(child: _BudgetEmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        if (isLoading && expenses.isEmpty) {
                          return const _ExpenseSkeleton();
                        }
                        final exp = expenses[i];
                        final isSelected = selectedIds.contains(exp.id);
                        return _ExpenseRow(
                          expense: exp,
                          isSelected: isSelected,
                          isSelectionMode: isSelectionMode,
                          myName: myName,
                          partnerName: partnerName,
                          onDelete: () => onDelete(exp.id),
                          onTap: () {
                            if (isSelectionMode) {
                              onLongPress(exp.id); // Toggle
                            } else {
                              onTap(exp);
                            }
                          },
                          onLongPress: () => onLongPress(exp.id),
                        );
                      },
                      childCount: (isLoading && expenses.isEmpty)
                          ? 5
                          : expenses.length,
                    ),
                  ),
                ),
          SliverToBoxAdapter(child: SizedBox(height: navPad + 64)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HeroCard
// ══════════════════════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.total,
    required this.myContribution,
    required this.partnerContribution,
    required this.myName,
    required this.partnerName,
  });
  final double total, myContribution, partnerContribution;
  final String myName, partnerName;

  @override
  Widget build(BuildContext context) {
    final myPct = total > 0 ? (myContribution / total) : 0.5;

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      tintColor: const Color(0xFF131318), // Home theme continuity
      shadowColor: Colors.black.withValues(alpha: 0.6), // Home theme continuity
      borderColor: Colors.white.withValues(alpha: 0.15), // Home theme continuity
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'TOTAL MONTHLY EXPENSE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              shadows: const [
                Shadow(
                  color: Colors.black45,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _fmtAmount(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              width: double.infinity,
              child: Row(
                children: [
                  if (myPct > 0)
                    Expanded(
                      flex: (myPct * 1000).toInt(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kPurple, _kPurpleViv],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _kPurple.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (myPct < 1)
                    Expanded(
                      flex: ((1 - myPct) * 1000).toInt(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7DAF), _kRose],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _kRose.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${myName.toUpperCase()} ',
                style: const TextStyle(
                  color: Color(0xFFB39DFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${(myPct * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFFB39DFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${partnerName.toUpperCase()} ${((1 - myPct) * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFFFF9BAB), // _kRose
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ContributionRow — LOGIC UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.myAmount,
    required this.partnerAmount,
    required this.myName,
    required this.partnerName,
  });
  final double myAmount, partnerAmount;
  final String myName, partnerName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ContribCard(
            label: myName.toUpperCase(),
            amount: myAmount,
            color: _kPurple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContribCard(
            label: partnerName.toUpperCase(),
            amount: partnerAmount,
            color: _kRose,
          ),
        ),
      ],
    );
  }
}

// ── Contribution card — glassmorphic ──────────────────────────────────────────
class _ContribCard extends StatelessWidget {
  const _ContribCard({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      tintColor: const Color(0xFF131318), // Home theme continuity
      shadowColor: Colors.black.withValues(alpha: 0.5), // Home theme continuity
      borderColor: Colors.white.withValues(alpha: 0.12), // Home theme continuity
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8),
              ],
            ),
            child: Icon(Icons.person_rounded, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'CONTRIBUTION',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fmtAmount(amount),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ExpenseRow — glassmorphic upgrade, LOGIC UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.onDelete,
    required this.myName,
    required this.partnerName,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });
  final _Expense expense;
  final VoidCallback onDelete;
  final String myName;
  final String partnerName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    final cat = expense.category;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: _kPurple.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? _kPurple.withValues(alpha: 0.25)
                  : (expense.paidByMe
                        ? _kPurple.withValues(alpha: 0.12)
                        : _kRose.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? _kPurple.withValues(alpha: 0.7)
                    : (expense.paidByMe
                          ? _kPurple.withValues(alpha: 0.20)
                          : _kRose.withValues(alpha: 0.20)),
                width: isSelected ? 2.0 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: _kPurple.withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: -2,
                  ),
                const BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Animated Checkbox
                if (isSelectionMode) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? _kPurple
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: isSelected
                            ? _kPurple
                            : Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                ],

                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cat.color.withValues(alpha: 0.22),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cat.color.withValues(alpha: 0.10),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            expense.paidByMe
                                ? myName.toUpperCase()
                                : partnerName.toUpperCase(),
                            style: TextStyle(
                              color: expense.paidByMe
                                  ? _kPurple.withValues(alpha: 0.75)
                                  : _kRose.withValues(alpha: 0.75),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            ' · ${_formatExpenseDate(expense.transactionDate)}',
                            style: const TextStyle(
                              color: _kTextMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmtAmount(expense.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onDelete,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white.withValues(alpha: 0.14),
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// History tab — LOGIC UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
class _HistoryTab extends StatefulWidget {
  const _HistoryTab({
    required this.historyByMonth,
    required this.allExpenses,
    required this.navPad,
    required this.onTap,
    required this.onRefresh,
    required this.myName,
    required this.partnerName,
  });
  final Map<String, List<_Expense>> historyByMonth;
  final List<_Expense> allExpenses;
  final double navPad;
  final ValueChanged<_Expense> onTap;
  final RefreshCallback onRefresh;
  final String myName, partnerName;
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final months = widget.historyByMonth.keys.toList();
    if (months.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: _kPurple,
        backgroundColor: const Color(0xFF1E1E24),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Text(
                'No history yet.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.22),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: _kPurple,
      backgroundColor: const Color(0xFF1E1E24),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (widget.allExpenses.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _StatisticsCard(
                  expenses: widget.allExpenses,
                  myContribution: widget.allExpenses
                      .where((e) => e.paidByMe)
                      .fold(0.0, (s, e) => s + e.amount),
                  partnerContribution: widget.allExpenses
                      .where((e) => !e.paidByMe)
                      .fold(0.0, (s, e) => s + e.amount),
                  myName: widget.myName,
                  partnerName: widget.partnerName,
                  title: 'All-Time Statistics',
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: const SliverToBoxAdapter(
              child: Text(
                'Monthly History',
                style: TextStyle(
                  color: _kTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final month = months[i];
                final expenses = widget.historyByMonth[month]!;
                final total = expenses.fold(0.0, (s, e) => s + e.amount);
                final isOpen = _expanded.contains(month);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            isOpen
                                ? _expanded.remove(month)
                                : _expanded.add(month);
                          }),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _kPurple.withValues(alpha: 0.12),
                                    border: Border.all(
                                      color: _kPurple.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month_rounded,
                                    color: _kPurple,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        month,
                                        style: const TextStyle(
                                          color: _kTextPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${expenses.length} expenses · ${_fmtAmount(total)}',
                                        style: TextStyle(
                                          color: _kTextMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isOpen
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: _kTextMuted,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isOpen) ...[
                          Divider(
                            color: Colors.white.withValues(alpha: 0.06),
                            height: 1,
                          ),
                          ...expenses.map(
                            (e) => Padding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                              child: _ExpenseRow(
                                expense: e,
                                myName: widget.myName,
                                partnerName: widget.partnerName,
                                onDelete: () {},
                                onTap: () => widget.onTap(e),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ],
                    ),
                  ),
                );
              }, childCount: months.length),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: widget.navPad + 32)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ArchiveCard — glassmorphic upgrade, LOGIC UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
// ignore: unused_element
class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.month,
    required this.total,
    required this.count,
    required this.settlement,
  });
  final String month;
  final double total, settlement;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
            boxShadow: [
              const BoxShadow(
                color: Color(0x16000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                month,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _fmtAmount(total),
                style: const TextStyle(
                  color: _kTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _AvatarStack(),
                  const SizedBox(width: 10),
                  Text(
                    'Both contributors',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$count Expenses',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.20),
                    size: 18,
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

// ══════════════════════════════════════════════════════════════════════════════
// _TimelineItem — glassmorphic inner card, LOGIC UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
// ignore: unused_element
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.month,
    required this.settlement,
    required this.isLast,
  });
  final String month;
  final double settlement;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kPurple.withValues(alpha: 0.12),
                      border: Border.all(
                        color: _kPurple.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kPurple.withValues(alpha: 0.12),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: _kPurple,
                      size: 16,
                    ),
                  ),
                ),
              ),
              if (!isLast) ...[
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _kPurple.withValues(alpha: 0.18),
                            _kPurple.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              month,
                              style: const TextStyle(
                                color: _kTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Final Settlement: ${_fmtAmount(settlement)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white.withValues(alpha: 0.14),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AvatarStack — UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
class _AvatarStack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 24,
      child: Stack(
        children: [
          Positioned(left: 0, child: _MiniAvatar(color: _kPurple)),
          Positioned(left: 18, child: _MiniAvatar(color: _kRose)),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.16),
      border: Border.all(color: const Color(0xFF131316), width: 2),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6)],
    ),
    child: Icon(Icons.person_rounded, color: color.withValues(alpha: 0.70), size: 12),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// _AddExpenseSheet — glassmorphic upgrade, ALL LOGIC UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet({
    required this.onAdd,
    required this.currentUserId,
    required this.partnerId,
    required this.myName,
    required this.partnerName,
  });
  final ValueChanged<_Expense> onAdd;
  final String currentUserId;
  final String partnerId;
  final String myName;
  final String partnerName;

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _paidByMe = true;
  _Category _category = _Category.food;
  DateTime _spentOn = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _kPurple,
              onPrimary: Colors.black,
              surface: Color(0xFF17141E),
              onSurface: _kTextPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _kPurple),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF17141E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _spentOn) {
      setState(() {
        _spentOn = picked;
      });
      HapticFeedback.lightImpact();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final comparisonDate = DateTime(date.year, date.month, date.day);

    if (comparisonDate == today) {
      return 'Today';
    } else if (comparisonDate == yesterday) {
      return 'Yesterday';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  void _submit() {
    final raw = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (raw == null || raw <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF201B2D),
        ),
      );
      return;
    }
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF201B2D),
        ),
      );
      return;
    }
    // _paidByMe == true  → the person opening this sheet paid
    // _paidByMe == false → the partner paid
    // _addExpense in BudgetScreen resolves the actual user IDs from
    // widget.currentUserId / widget.partnerId before calling Supabase
    widget.onAdd(
      _Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: raw,
        description: desc,
        category: _category,
        paidByMe: _paidByMe,
        transactionDate: _spentOn,
      ),
    );
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final botInset = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, botInset + 28),
          decoration: BoxDecoration(
            color: const Color(0xFF17141E).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09), width: 1),
            boxShadow: [
              BoxShadow(
                color: _kPurple.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'NEW TRANSACTION',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add Expense',
                        style: TextStyle(
                          color: _kTextPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Main input card — glassmorphic
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                          width: 1,
                        ),
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '₹',
                                style: TextStyle(
                                  color: _kPurple,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _amountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: const TextStyle(
                                    color: _kTextPrimary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  cursorColor: _kPurple,
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Who paid?',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _PayerBtn(
                                    label: widget.myName.toUpperCase(),
                                    active: _paidByMe,
                                    color: _kPurple,
                                    onTap: () =>
                                        setState(() => _paidByMe = true),
                                  ),
                                ),
                                Expanded(
                                  child: _PayerBtn(
                                    label: widget.partnerName.toUpperCase(),
                                    active: !_paidByMe,
                                    color: _kRose,
                                    onTap: () =>
                                        setState(() => _paidByMe = false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Description',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.edit_note_rounded,
                                  color: Colors.white.withValues(alpha: 0.25),
                                  size: 18,
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _descCtrl,
                                    style: const TextStyle(
                                      color: _kTextPrimary,
                                      fontSize: 14,
                                    ),
                                    cursorColor: _kPurple,
                                    decoration: InputDecoration(
                                      hintText: 'What was this for?',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.20),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 14,
                                          ),
                                    ),
                                    onSubmitted: (_) => _submit(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Spent On',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _selectDate,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    color: _kPurple,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _formatDate(_spentOn),
                                      style: const TextStyle(
                                        color: _kTextPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white.withValues(alpha: 0.25),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Category',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _Category.values.map((cat) {
                              final active = _category == cat;
                              return GestureDetector(
                                onTap: () => setState(() => _category = cat),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? cat.color.withValues(alpha: 0.18)
                                        : Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: active
                                          ? cat.color.withValues(alpha: 0.50)
                                          : Colors.white.withValues(alpha: 0.09),
                                      width: 1,
                                    ),
                                    boxShadow: active
                                        ? [
                                            BoxShadow(
                                              color: cat.color.withValues(alpha: 
                                                0.15,
                                              ),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        cat.icon,
                                        color: active
                                            ? cat.color
                                            : Colors.white.withValues(alpha: 0.35),
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        cat.label,
                                        style: TextStyle(
                                          color: active
                                              ? cat.color
                                              : Colors.white.withValues(alpha: 0.45),
                                          fontSize: 12,
                                          fontWeight: active
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kPurple, _kPurpleViv],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kPurpleViv.withValues(alpha: 0.28),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Add Expense',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Transactions are recorded in real-time',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.22),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PayerBtn — UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════
class _PayerBtn extends StatelessWidget {
  const _PayerBtn({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: active
            ? Border.all(color: color.withValues(alpha: 0.35), width: 1)
            : null,
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 8)]
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: active ? color : Colors.white.withValues(alpha: 0.35),
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// _FilterPills — category + payer filter bar
// ══════════════════════════════════════════════════════════════════════════════
class _FilterPills extends StatelessWidget {
  const _FilterPills({
    required this.selected,
    required this.payer,
    required this.onCategory,
    required this.onPayer,
    required this.myName,
    required this.partnerName,
  });
  final _Category? selected;
  final String payer;
  final ValueChanged<_Category?> onCategory;
  final ValueChanged<String> onPayer;
  final String myName, partnerName;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _pill('All', selected == null && payer == 'all', null, null),
          const SizedBox(width: 8),
          _pill(myName, payer == 'me', null, 'me'),
          const SizedBox(width: 8),
          _pill(partnerName, payer == 'partner', null, 'partner'),
          const SizedBox(width: 8),
          ...List.generate(_Category.values.length, (i) {
            final cat = _Category.values[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _pill(cat.label, selected == cat, cat, null),
            );
          }),
        ],
      ),
    );
  }

  Widget _pill(String label, bool active, _Category? cat, String? payerVal) {
    Color color;
    if (cat != null) {
      color = cat.color;
    } else if (payerVal == 'partner') {
      color = _kRose;
    } else {
      color = _kPurple;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (cat != null) {
          onCategory(active ? null : cat);
        } else if (payerVal != null) {
          onPayer(active ? 'all' : payerVal);
        } else {
          onCategory(null);
          onPayer('all');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.50)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? color : Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _StatisticsCard — donut chart + legend
// ══════════════════════════════════════════════════════════════════════════════
class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.expenses,
    required this.myContribution,
    required this.partnerContribution,
    required this.myName,
    required this.partnerName,
    this.title = 'This Month',
  });
  final List<_Expense> expenses;
  final double myContribution, partnerContribution;
  final String myName, partnerName;
  final String title;

  @override
  Widget build(BuildContext context) {
    final total = myContribution + partnerContribution;
    // Category breakdown
    final Map<_Category, double> catMap = {};
    for (final e in expenses) {
      catMap[e.category] = (catMap[e.category] ?? 0) + e.amount;
    }
    final catEntries = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final catSegments = catEntries.map((e) => (e.value, e.key.color)).toList();
    final payerSegments = total > 0
        ? [(myContribution, _kPurple), (partnerContribution, _kRose)]
        : <(double, Color)>[];

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      tintColor: const Color(0xFF131318), // Home theme continuity
      shadowColor: Colors.black.withValues(alpha: 0.5), // Home theme continuity
      borderColor: Colors.white.withValues(alpha: 0.12), // Home theme continuity
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, color: _kPurple, size: 16),
              const SizedBox(width: 8),
              Text(
                'Statistics · $title',
                style: const TextStyle(
                  color: _kTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Who paid donut
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: payerSegments.isEmpty
                          ? Center(
                              child: Text(
                                'No data',
                                style: TextStyle(
                                  color: _kTextMuted,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          : CustomPaint(
                              painter: _DonutChartPainter(payerSegments),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'By Person',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _LegendItem(
                      color: _kPurple,
                      label: myName,
                      amount: myContribution,
                      total: total,
                    ),
                    _LegendItem(
                      color: _kRose,
                      label: partnerName,
                      amount: partnerContribution,
                      total: total,
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 130,
                color: Colors.white.withValues(alpha: 0.07),
              ),
              // By category donut
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: catSegments.isEmpty
                          ? Center(
                              child: Text(
                                'No data',
                                style: TextStyle(
                                  color: _kTextMuted,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          : CustomPaint(
                              painter: _DonutChartPainter(catSegments),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'By Category',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...catEntries
                        .take(3)
                        .map(
                          (e) => _LegendItem(
                            color: e.key.color,
                            label: e.key.label,
                            amount: e.value,
                            total: total,
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.amount,
    required this.total,
  });
  final Color color;
  final String label;
  final double amount, total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (amount / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$label $pct%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter(this.segments);
  final List<(double, Color)> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold(0.0, (s, e) => s + e.$1);
    if (total == 0) return;
    final cx = size.width / 2, cy = size.height / 2;
    final r = (size.width.clamp(0, size.height) / 2) - 4;
    final sw = r * 0.38;
    double start = -pi / 2;
    const gap = 0.04;
    for (final seg in segments) {
      final sweep = (seg.$1 / total) * (2 * pi) - gap;
      if (sweep <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r - sw / 2),
        start,
        sweep,
        false,
        Paint()
          ..color = seg.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter o) => o.segments != segments;
}

// ══════════════════════════════════════════════════════════════════════════════
// _ExpenseDetailSheet — view, edit, delete
// ══════════════════════════════════════════════════════════════════════════════
class _ExpenseDetailSheet extends StatefulWidget {
  const _ExpenseDetailSheet({
    required this.expense,
    required this.currentUserId,
    required this.partnerId,
    required this.onDelete,
    required this.onUpdate,
    required this.myName,
    required this.partnerName,
    this.onOpenMaps,
  });
  final _Expense expense;
  final String currentUserId, partnerId;
  final String myName, partnerName;
  final VoidCallback onDelete;
  final void Function(String, double, _Category, bool, DateTime) onUpdate;
  final VoidCallback? onOpenMaps;

  @override
  State<_ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends State<_ExpenseDetailSheet> {
  bool _editing = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late _Category _category;
  late bool _paidByMe;
  late DateTime _spentOn;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.expense.description);
    _amountCtrl = TextEditingController(
      text: widget.expense.amount.toStringAsFixed(0),
    );
    _category = widget.expense.category;
    _paidByMe = widget.expense.paidByMe;
    _spentOn = widget.expense.transactionDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _kPurple,
              onPrimary: Colors.black,
              surface: Color(0xFF17141E),
              onSurface: _kTextPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _kPurple),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF17141E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _spentOn) {
      setState(() {
        _spentOn = picked;
      });
      HapticFeedback.lightImpact();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final comparisonDate = DateTime(date.year, date.month, date.day);

    if (comparisonDate == today) {
      return 'Today';
    } else if (comparisonDate == yesterday) {
      return 'Yesterday';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  void _save() {
    final amt = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (amt == null || amt <= 0) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    widget.onUpdate(title, amt, _category, _paidByMe, _spentOn);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final botInset = MediaQuery.of(context).viewInsets.bottom;
    final e = widget.expense;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, botInset + 28),
          decoration: BoxDecoration(
            color: const Color(0xFF17141E).withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09), width: 1),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: e.category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: e.category.color.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        e.category.icon,
                        color: e.category.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editing ? 'Edit Expense' : 'Expense Detail',
                            style: const TextStyle(
                              color: _kTextPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            e.category.label,
                            style: TextStyle(
                              color: e.category.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_editing) ...[
                      GestureDetector(
                        onTap: () => setState(() => _editing = true),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _kPurple.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: _kPurple,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kRose.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kRose.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: _kRose,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                if (!_editing) ...[
                  _DetailRow(label: 'Amount', value: _fmtAmount(e.amount)),
                  _DetailRow(label: 'Description', value: e.description),
                  _DetailRow(
                    label: 'Paid by',
                    value: e.paidByMe ? widget.myName : widget.partnerName,
                  ),
                  _DetailRow(label: 'Category', value: e.category.label),
                  if (e.category == _Category.travel &&
                      widget.onOpenMaps != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 140),
                      child: GestureDetector(
                        onTap: widget.onOpenMaps,
                        child: Text(
                          'View on Map',
                          style: TextStyle(
                            color: _kPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  _DetailRow(
                    label: 'Date',
                    value:
                        '${e.transactionDate.day}/${e.transactionDate.month}/${e.transactionDate.year}',
                  ),
                  _DetailRow(label: 'Time', value: _timeAgo(e.transactionDate)),
                ] else ...[
                  // Edit fields
                  _label('Amount'),
                  const SizedBox(height: 8),
                  _field(
                    Row(
                      children: [
                        Text(
                          '₹',
                          style: TextStyle(
                            color: _kPurple,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              color: _kTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: _kPurple,
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _label('Description'),
                  const SizedBox(height: 8),
                  _field(
                    TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(
                        color: _kTextPrimary,
                        fontSize: 14,
                      ),
                      cursorColor: _kPurple,
                      decoration: InputDecoration(
                        hintText: 'What was it for?',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _label('Who paid?'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PayerBtn(
                            label: widget.myName.toUpperCase(),
                            active: _paidByMe,
                            color: _kPurple,
                            onTap: () => setState(() => _paidByMe = true),
                          ),
                        ),
                        Expanded(
                          child: _PayerBtn(
                            label: widget.partnerName.toUpperCase(),
                            active: !_paidByMe,
                            color: _kRose,
                            onTap: () => setState(() => _paidByMe = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _label('Spent On'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectDate,
                    behavior: HitTestBehavior.opaque,
                    child: _field(
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            color: _kPurple,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formatDate(_spentOn),
                              style: const TextStyle(
                                color: _kTextPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.25),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _label('Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _Category.values.map((cat) {
                      final active = _category == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _category = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? cat.color.withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: active
                                  ? cat.color.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.icon,
                                color: active ? cat.color : _kTextMuted,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                cat.label,
                                style: TextStyle(
                                  color: active ? cat.color : _kTextMuted,
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _editing = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: _kTextMuted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_kPurple, _kPurpleViv],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _kPurple.withValues(alpha: 0.30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
    t,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.35),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _field(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: child,
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(color: _kTextMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _kTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ExpenseSkeleton extends StatelessWidget {
  const _ExpenseSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _BudgetEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: _kPurple.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No expenses this month',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your shared spending here. Tap the + button to add your first expense!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
