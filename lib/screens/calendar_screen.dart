import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shimmer/shimmer.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';
import '../models/cycle_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Palette — matches requested light theme
// ══════════════════════════════════════════════════════════════════════════════
const Color _kCard = Color(0x7A16161E);
const Color _kCardBorder = Color(0x1AFFFFFF);
const Color _kTextPrimary = Color(0xFFF2EFF9);
const Color _kTextSub = Color(0xFFAEABB8);
const Color _kTextMuted = Color(0xFF5A5768);
const Color _kPurple = Color(0xFF7357FB);
const Color _kPurpleViv = Color(0xFF9B6FFF);
const Color _kRose = Color(0xFFFF7B93);
const Color _kGold = Color(0xFFFFB74D);
const Color _kGreen = Color(0xFF4CAF50);
const Color _kBlue = Color(0xFF42A5F5);

// ══════════════════════════════════════════════════════════════════════════════
// Models & Enums (preserved logic)
// ══════════════════════════════════════════════════════════════════════════════
enum _EventColor {
  purple(_kPurple),
  rose(_kRose),
  gold(_kGold),
  green(_kGreen),
  blue(_kBlue);

  const _EventColor(this.value);
  final Color value;
}

class _CalEvent {
  const _CalEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.color,
    this.note,
  });
  final String id;
  final String title;
  final DateTime date;
  final _EventColor color;
  final String? note;
}

class _Reminder {
  const _Reminder({
    required this.id,
    required this.title,
    required this.date,
    this.note,
  });
  final String id;
  final String title;
  final DateTime date;
  final String? note;
}

// ══════════════════════════════════════════════════════════════════════════════
// CalendarScreen
// ══════════════════════════════════════════════════════════════════════════════
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.onOpenTasks});
  final VoidCallback? onOpenTasks;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  // Sync state
  List<_CalEvent> _sharedEvents = [];
  List<_Reminder> _sharedReminders = [];
  List<Task> _sharedTasks = [];
  CycleInfo? _cycle;

  StreamSubscription? _calendarSub;
  StreamSubscription? _taskSub;
  StreamSubscription<List<PeriodLog>>? _periodSub;
  StreamSubscription? _reconnectSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusedDay = DateTime.now();
    _selectedDay = _normalizeDate(DateTime.now());

    cycleTrackerSync.addListener(_handleCycleSync);
    unawaited(_initializeSharedCalendar());
    unawaited(_loadCycleData());

    _reconnectSub = _sb.onReconnect.listen((_) {
      debugPrint('[Calendar] Connectivity restored, auto-refreshing...');
      unawaited(_initializeSharedCalendar(refresh: true));
      unawaited(_loadCycleData());
    });
  }

  void _handleCycleSync() {
    if (cycleTrackerSync.value != null && mounted) {
      _loadCycleData();
    }
  }

  final SupabaseService _sb = SupabaseService();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_initializeSharedCalendar(refresh: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calendarSub?.cancel();
    _taskSub?.cancel();
    _periodSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }

  // ── Sync logic (preserved) ────────────────────────────────────────────────
  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _initializeSharedCalendar({bool refresh = false}) async {
    final supabase = _sb;
    String? effectivePairingId;

    // Instant Cache Resolution
    final prefs = supabase.prefsSync;
    if (prefs != null) {
      final cachedPairingStr = prefs.getString('cache_active_pairing');
      if (cachedPairingStr != null) {
        try {
          final cachedPairing = Pairing.fromJson(jsonDecode(cachedPairingStr));
          effectivePairingId = cachedPairing.id;
        } catch (_) {}
      }
    }

    if (effectivePairingId == null) {
      final pairing = await supabase.getActivePairing();
      effectivePairingId = pairing?.id ?? supabase.currentUserId;
    }

    if (!refresh && effectivePairingId != null) {
      _calendarSub = supabase
          .watchCalendarEvents(effectivePairingId)
          .listen(
            (events) {
              if (mounted) {
                setState(() {
                  _sharedEvents = events.map((e) {
                    return _CalEvent(
                      id: e.id,
                      title: e.title,
                      date: e.startTime,
                      color: _EventColor.values.firstWhere(
                        (c) =>
                            c.value.toARGB32() ==
                            int.parse(e.color.replaceFirst('#', '0xFF')),
                        orElse: () => _EventColor.purple,
                      ),
                      note: e.description,
                    );
                  }).toList();
                });
              }
            },
            onError: (e) {
              debugPrint('[Calendar] Event stream error: $e');
            },
          );

      _taskSub = supabase
          .watchTasks(effectivePairingId)
          .listen(
            (tasks) {
              if (mounted) {
                setState(() => _sharedTasks = tasks);
              }
            },
            onError: (e) {
              debugPrint('[Calendar] Task stream error: $e');
            },
          );
    }
  }

  Future<void> _loadCycleData() async {
    final supabase = _sb;
    String? effectivePairingId;

    // Instant Cache Resolution
    final prefs = supabase.prefsSync;
    if (prefs != null) {
      final cachedPairingStr = prefs.getString('cache_active_pairing');
      if (cachedPairingStr != null) {
        try {
          final cachedPairing = Pairing.fromJson(jsonDecode(cachedPairingStr));
          effectivePairingId = cachedPairing.id;
        } catch (_) {}
      }
    }

    if (effectivePairingId == null) {
      final pairing = await supabase.getActivePairing();
      effectivePairingId = pairing?.id ?? supabase.currentUserId;
    }

    if (effectivePairingId == null) return;

    _periodSub?.cancel();
    _periodSub = supabase.watchPeriodLogs(effectivePairingId).listen((logs) {
      if (logs.isNotEmpty && mounted) {
        setState(() {
          final latest = logs.first;
          _cycle = cycleInfoFromPeriodData(
            id: latest.id,
            startDate: latest.startDate,
            endDate: latest.endDate,
            cycleLength: latest.cycleLength,
          );
        });
      }
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    HapticFeedback.selectionClick();
  }

  void _jumpToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = _normalizeDate(DateTime.now());
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _logPeriod() async {
    if (_selectedDay == null) return;
    try {
      final supabase = _sb;
      final pairing = await supabase.getActivePairing();
      await supabase.createPeriodLog(
        pairingId: pairing?.id,
        cycleStartDate: _selectedDay!,
      );
      if (pairing != null) {
        final partnerId = pairing.user1Id == supabase.currentUserId
            ? pairing.user2Id
            : pairing.user1Id;
        if (partnerId != null && partnerId.isNotEmpty) {
          final myProfile = await supabase.getMyProfile();
          final partnerProfile = await supabase.getPartnerProfile(pairing.id);
          final senderName =
              partnerProfile?.preferences['partner_nickname'] ??
              myProfile?.displayName ??
              'Your partner';
          unawaited(supabase.sendPushNotification(
            toUserId: partnerId,
            type: 'period',
            title: 'Period status update',
            body:
                '$senderName logged a new period starting on ${_selectedDay!.day}/${_selectedDay!.month}',
          ));
        }
      }
      _showToast(
        'Period logged for ${_selectedDay!.day}/${_selectedDay!.month}',
      );
      await _loadCycleData();
    } catch (e) {
      _showToast('Failed to log period');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _deleteSharedEvent(String id) async {
    final deletedEvent = _sharedEvents.firstWhere((e) => e.id == id);
    final originalEvents = List<_CalEvent>.from(_sharedEvents);

    setState(() {
      _sharedEvents.removeWhere((e) => e.id == id);
    });

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text('Event "${deletedEvent.title}" deleted'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                setState(() {
                  _sharedEvents = originalEvents;
                });
              },
            ),
          ),
        )
        .closed
        .then((reason) async {
          if (reason != SnackBarClosedReason.action) {
            try {
              await _sb.deleteCalendarEvent(id);
              final pairing = await _sb.getActivePairing();
              if (pairing != null) {
                final partnerId = pairing.user1Id == _sb.currentUserId
                    ? pairing.user2Id
                    : pairing.user1Id;
                if (partnerId != null && partnerId.isNotEmpty) {
                  final myProfile = await _sb.getMyProfile();
                  final partnerProfile = await _sb.getPartnerProfile(pairing.id);
                  final senderName =
                      partnerProfile?.preferences['partner_nickname'] ??
                      myProfile?.displayName ??
                      'Your partner';
                  unawaited(_sb.sendPushNotification(
                    toUserId: partnerId,
                    type: 'calendar',
                    title: 'Calendar updated',
                    body: '$senderName deleted the event: ${deletedEvent.title}',
                  ));
                }
              }
            } catch (e) {
              if (mounted) {
                setState(() => _sharedEvents = originalEvents);
                _showToast('Failed to delete event');
              }
            }
          }
        });
  }

  Future<void> _deleteSharedReminder(String id) async {
    final deletedRem = _sharedReminders.firstWhere((r) => r.id == id);
    final originalReminders = List<_Reminder>.from(_sharedReminders);

    setState(() {
      _sharedReminders.removeWhere((r) => r.id == id);
    });

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text('Reminder "${deletedRem.title}" deleted'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                setState(() {
                  _sharedReminders = originalReminders;
                });
              },
            ),
          ),
        )
        .closed
        .then((reason) async {
          if (reason != SnackBarClosedReason.action) {
            try {
              await _sb.deleteCalendarEvent(id);
              final pairing = await _sb.getActivePairing();
              if (pairing != null) {
                final partnerId = pairing.user1Id == _sb.currentUserId
                    ? pairing.user2Id
                    : pairing.user1Id;
                if (partnerId != null && partnerId.isNotEmpty) {
                  final myProfile = await _sb.getMyProfile();
                  final partnerProfile = await _sb.getPartnerProfile(pairing.id);
                  final senderName =
                      partnerProfile?.preferences['partner_nickname'] ??
                      myProfile?.displayName ??
                      'Your partner';
                  unawaited(_sb.sendPushNotification(
                    toUserId: partnerId,
                    type: 'calendar',
                    title: 'Calendar updated',
                    body:
                        '$senderName deleted the reminder: ${deletedRem.title}',
                  ));
                }
              }
            } catch (e) {
              if (mounted) {
                setState(() => _sharedReminders = originalReminders);
                _showToast('Failed to delete reminder');
              }
            }
          }
        });
  }

  Future<void> _toggleSharedTask(String id) async {
    final index = _sharedTasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final task = _sharedTasks[index];
    final originalTasks = List<Task>.from(_sharedTasks);
    final nextValue = !task.isCompleted;

    setState(() {
      _sharedTasks[index] = task.copyWith(isCompleted: nextValue);
    });

    HapticFeedback.lightImpact();

    try {
      await _sb.updateTask(id, {'is_completed': nextValue});

      if (nextValue) {
        final pairing = await _sb.getActivePairing();
        if (pairing != null) {
          final partnerId = pairing.user1Id == _sb.currentUserId ? pairing.user2Id : pairing.user1Id;
          if (partnerId != null && partnerId.isNotEmpty) {
            final myProfile = await _sb.getMyProfile();
            final partnerProfile = await _sb.getPartnerProfile(pairing.id);
            final senderName = partnerProfile?.preferences['partner_nickname'] ??
                myProfile?.displayName ??
                'Your partner';
            unawaited(_sb.sendPushNotification(
              toUserId: partnerId,
              type: 'task',
              title: '✅ Task Completed',
              body: '$senderName completed: ${task.title}',
            ));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sharedTasks = originalTasks);
        _showToast('Failed to update task');
      }
    }
  }

  Future<void> _deleteSharedTask(String id) async {
    final deletedTask = _sharedTasks.firstWhere((t) => t.id == id);
    final originalTasks = List<Task>.from(_sharedTasks);

    setState(() {
      _sharedTasks.removeWhere((t) => t.id == id);
    });

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text('Task "${deletedTask.title}" deleted'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                setState(() {
                  _sharedTasks = originalTasks;
                });
              },
            ),
          ),
        )
        .closed
        .then((reason) async {
          if (reason != SnackBarClosedReason.action) {
            try {
              await _sb.deleteTask(id);
              final pairing = await _sb.getActivePairing();
              if (pairing != null) {
                final partnerId = pairing.user1Id == _sb.currentUserId
                    ? pairing.user2Id
                    : pairing.user1Id;
                if (partnerId != null && partnerId.isNotEmpty) {
                  final myProfile = await _sb.getMyProfile();
                  final partnerProfile = await _sb.getPartnerProfile(pairing.id);
                  final senderName =
                      partnerProfile?.preferences['partner_nickname'] ??
                      myProfile?.displayName ??
                      'Your partner';
                  unawaited(_sb.sendPushNotification(
                    toUserId: partnerId,
                    type: 'task',
                    title: 'Task removed',
                    body: '$senderName deleted: ${deletedTask.title}',
                  ));
                }
              }
            } catch (e) {
              if (mounted) {
                setState(() => _sharedTasks = originalTasks);
                _showToast('Failed to delete task');
              }
            }
          }
        });
  }

  void _openCycleSettings() {
    if (_cycle == null) {
      _logPeriod(); // If no cycle, just log current selected day
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditCycleSheet(
        initialDate: _cycle!.lastPeriodStart,
        initialCycleLength: _cycle!.cycleLength,
        initialPeriodLength: _cycle!.periodLength,
        onSave: (date, cycleLen, periodLen) async {
          try {
            final supabase = _sb;
            if (_cycle!.id != null) {
              try {
                await supabase.updatePeriodLog(
                  _cycle!.id!,
                  cycleStartDate: date,
                  cycleLength: cycleLen,
                  periodLength: periodLen,
                );
              } catch (e) {
                if (e.toString().contains('PGRST116')) {
                  // Fallback: If RLS blocks the update, we just create a new log.
                  // Since the stream sorts by updatedAt DESC, the new log will take precedence!
                  final pairingId = (await supabase.getActivePairing())?.id;
                  await supabase.createPeriodLog(
                    cycleStartDate: date,
                    cycleLength: cycleLen,
                    periodLength: periodLen,
                    pairingId: pairingId,
                  );
                } else {
                  rethrow;
                }
              }
            } else {
              final pairingId = (await supabase.getActivePairing())?.id;
              await supabase.createPeriodLog(
                cycleStartDate: date,
                cycleLength: cycleLen,
                periodLength: periodLen,
                pairingId: pairingId,
              );
            }
            _showToast('Cycle updated successfully');
            await _loadCycleData();
            final pairing = await supabase.getActivePairing();
            if (pairing != null) {
              final partnerId = pairing.user1Id == supabase.currentUserId
                  ? pairing.user2Id
                  : pairing.user1Id;
              if (partnerId != null && partnerId.isNotEmpty) {
                final myProfile = await supabase.getMyProfile();
                final partnerProfile = await supabase.getPartnerProfile(pairing.id);
                final senderName =
                    partnerProfile?.preferences['partner_nickname'] ??
                    myProfile?.displayName ??
                    'Your partner';
                unawaited(supabase.sendPushNotification(
                  toUserId: partnerId,
                  type: 'period',
                  title: 'Period status update',
                  body: '$senderName updated cycle details',
                ));
              }
            }
          } catch (e) {
            debugPrint('[CalendarScreen] Update cycle error: $e');
            _showToast('Failed to update cycle. Try restarting the app.');
          }
        },
      ),
    );
  }

  void _openAddSheet({
    _CalEvent? editEvent,
    _EntryType? initialType,
    DateTime? initialDate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEventSheet(
        initialDate:
            editEvent?.date ?? initialDate ?? _selectedDay ?? DateTime.now(),
        editEvent: editEvent,
        initialType: initialType,
        onAddEvent: (ev) async {
          final supabase = _sb;
          final pairing = await supabase.getActivePairing();
          final effectivePairingId = pairing?.id ?? supabase.currentUserId;
          if (effectivePairingId == null) return;

          if (editEvent != null) {
            await supabase.updateCalendarEvent(editEvent.id, {
              'title': ev.title,
              'description': ev.note,
              'start_time': ev.date.toUtc().toIso8601String(),
              'end_time': ev.date
                  .add(const Duration(hours: 1))
                  .toUtc()
                  .toIso8601String(),
              'color':
                  '#${ev.color.value.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
            });
          } else {
            await supabase.createCalendarEvent(
              pairingId: effectivePairingId,
              title: ev.title,
              description: ev.note,
              startTime: ev.date,
              endTime: ev.date.add(const Duration(hours: 1)),
              color:
                  '#${ev.color.value.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
            );
          }

          if (pairing != null) {
            final partnerId = pairing.user1Id == supabase.currentUserId
                ? pairing.user2Id
                : pairing.user1Id;
            if (partnerId != null && partnerId.isNotEmpty) {
              final myProfile = await supabase.getMyProfile();
              final partnerProfile = await supabase.getPartnerProfile(pairing.id);
              final senderName = partnerProfile?.preferences['partner_nickname'] ??
                  myProfile?.displayName ??
                  'Your partner';
              unawaited(supabase.sendPushNotification(
                toUserId: partnerId,
                type: 'calendar',
                title: '📅 Calendar event reminder',
                body: editEvent != null
                    ? '$senderName updated the event: ${ev.title}'
                    : '$senderName added: ${ev.title}',
              ));
            }
          }
        },
        onAddReminder: (rem) async {
          final supabase = _sb;
          final pairing = await supabase.getActivePairing();
          final effectivePairingId = pairing?.id ?? supabase.currentUserId;
          if (effectivePairingId == null) return;

          await supabase.createCalendarEvent(
            pairingId: effectivePairingId,
            title: rem.title,
            description: rem.note,
            startTime: rem.date,
            endTime: rem.date.add(const Duration(minutes: 30)),
            color:
                '#${_kPurple.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
          );

          if (pairing != null) {
            final partnerId = pairing.user1Id == supabase.currentUserId
                ? pairing.user2Id
                : pairing.user1Id;
            if (partnerId != null && partnerId.isNotEmpty) {
              final myProfile = await supabase.getMyProfile();
              final partnerProfile = await supabase.getPartnerProfile(pairing.id);
              final senderName = partnerProfile?.preferences['partner_nickname'] ??
                  myProfile?.displayName ??
                  'Your partner';
              unawaited(supabase.sendPushNotification(
                toUserId: partnerId,
                type: 'calendar',
                title: '📅 Calendar event reminder',
                body: '$senderName set a reminder: ${rem.title}',
              ));
            }
          }
        },
      ),
    );
  }

  // ── Data filters ──────────────────────────────────────────────────────────
  List<_CalEvent> _eventsForDay(DateTime day) =>
      _sharedEvents.where((e) => isSameDay(e.date, day)).toList();

  List<_Reminder> _sharedRemindersForDay(DateTime day) =>
      _sharedReminders.where((r) => isSameDay(r.date, day)).toList();

  List<Task> _tasksForDay(DateTime day) => _sharedTasks
      .where((t) => t.dueDate != null && isSameDay(t.dueDate!, day))
      .toList();


  bool _isPeriodDay(DateTime d) => _cycle?.isPeriodDay(d) ?? false;
  bool _isFertileDay(DateTime d) => _cycle?.isFertileDay(d) ?? false;

  bool get _isNotToday {
    final now = DateTime.now();
    final isDifferentMonth =
        _focusedDay.year != now.year || _focusedDay.month != now.month;
    final isDifferentDay =
        _selectedDay == null || !isSameDay(_selectedDay, now);
    return isDifferentMonth || isDifferentDay;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final topInset = MediaQuery.of(context).padding.top;
    final botInset = MediaQuery.of(context).padding.bottom;
    final today = _normalizeDate(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Unified Floating Glass Header & Calendar ───────────────────
              SliverToBoxAdapter(
                child: GlassPanel(
                  padding: EdgeInsets.zero,
                  borderRadius: 44,
                  blurSigma: 50,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(44),
                    ),
                    child: Column(
                      children: [
                        // Header Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _NavBtn(
                                icon: Icons.chevron_left_rounded,
                                onTap: () {
                                  final newDate = DateTime(
                                    _focusedDay.year,
                                    _focusedDay.month - 1,
                                    1,
                                  );
                                  if (newDate.year >= 1900) {
                                    setState(() => _focusedDay = newDate);
                                  }
                                },
                              ),
                              GestureDetector(
                                onTap: _showMonthYearPicker,
                                child: Column(
                                  children: [
                                    Text(
                                      _monthName(
                                        _focusedDay.month,
                                      ).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_focusedDay.year}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _NavBtn(
                                icon: Icons.chevron_right_rounded,
                                onTap: () {
                                  final newDate = DateTime(
                                    _focusedDay.year,
                                    _focusedDay.month + 1,
                                    1,
                                  );
                                  if (newDate.year <= 2100) {
                                    setState(() => _focusedDay = newDate);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildCalendarGrid(today),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Selected day agenda ─────────────────────────────────────────
              if (_selectedDay != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _CycleStatusCard(
                          date: _selectedDay!,
                          cycle: _cycle,
                          isPeriod: _isPeriodDay(_selectedDay!),
                          isFertile: _isFertileDay(_selectedDay!),
                          onLogPeriod: _logPeriod,
                          onEdit: _openCycleSettings,
                        ),
                        const SizedBox(height: 24),
                        _SelectedDayAgenda(
                          date: _selectedDay!,
                          events: _eventsForDay(_selectedDay!),
                          reminders: _sharedRemindersForDay(_selectedDay!),
                          tasks: _tasksForDay(_selectedDay!),
                          holidays: _getHolidaysForDay(_selectedDay!),
                          isPeriod: _isPeriodDay(_selectedDay!),
                          isFertile: _isFertileDay(_selectedDay!),
                          onDeleteEvent: _deleteSharedEvent,
                          onDeleteReminder: _deleteSharedReminder,
                          onDeleteTask: _deleteSharedTask,
                          onEditEvent: (ev) => _openAddSheet(editEvent: ev),
                          onToggleTask: (id) {
                            unawaited(_toggleSharedTask(id));
                          },
                          onOpenTasks: widget.onOpenTasks,
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // Jump to Today Pill - Refined Placement
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.fastOutSlowIn,
            bottom: _isNotToday ? (botInset + 100) : -80,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _isNotToday ? 1.0 : 0.0,
              child: AnimatedScale(
                scale: _isNotToday ? 1.0 : 0.8,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                child: GestureDetector(
                  onTap: _jumpToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kPurple, _kPurpleViv],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: _kPurpleViv.withValues(alpha: 0.35),
                          blurRadius: 15,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.today_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'TODAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
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

  Widget _buildCalendarGrid(DateTime today) {
    return TableCalendar(
      firstDay: DateTime(1900),
      lastDay: DateTime(2100),
      focusedDay: _focusedDay,
      selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
      onDaySelected: _onDaySelected,
      onPageChanged: (d) => setState(() => _focusedDay = d),
      calendarFormat: CalendarFormat.month,
      availableGestures: AvailableGestures.horizontalSwipe,
      headerVisible: false,
      daysOfWeekHeight: 30,
      rowHeight: 52,
      eventLoader: (day) {
        final List<Object> markers = [];
        markers.addAll(_eventsForDay(day));
        markers.addAll(_sharedRemindersForDay(day));
        markers.addAll(_tasksForDay(day));
        if (_getHolidaysForDay(day).isNotEmpty) markers.add('holiday');
        return markers;
      },
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: true,
        outsideTextStyle: TextStyle(
          color: Color(0xFF32323A),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        weekendTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        defaultTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        disabledTextStyle: TextStyle(color: Color(0xFF32323A), fontSize: 16),
        todayDecoration: BoxDecoration(color: Colors.transparent),
        todayTextStyle: TextStyle(
          color: Color(0xFF9B6FFF),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        selectedDecoration: BoxDecoration(color: Colors.transparent),
        selectedTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        markerDecoration: BoxDecoration(color: Colors.transparent),
        markersMaxCount: 0,
        cellMargin: EdgeInsets.all(2),
        cellPadding: EdgeInsets.zero,
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
        weekendStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focused) =>
            _buildDayCell(day, focused, false, false),
        todayBuilder: (context, day, focused) =>
            _buildDayCell(day, focused, true, false),
        selectedBuilder: (context, day, focused) =>
            _buildDayCell(day, focused, false, true),
        outsideBuilder: (context, day, focused) =>
            _buildDayCell(day, focused, false, false, outside: true),
        disabledBuilder: (context, day, focused) =>
            _buildDayCell(day, focused, false, false, outside: true),
      ),
    );
  }

  void _showMonthYearPicker() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MonthYearPickerSheet(
        initialDate: _focusedDay,
        onChanged: (newDate) {
          setState(() => _focusedDay = newDate);
        },
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day,
    DateTime focused,
    bool isToday,
    bool isSelected, {
    bool outside = false,
  }) {
    final dayEvents = _eventsForDay(day);
    final dayReminders = _sharedRemindersForDay(day);
    final dayTasks = _tasksForDay(day);
    final dayHolidays = _getHolidaysForDay(day);

    Color textColor = outside ? Colors.white.withValues(alpha: 0.25) : Colors.white;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isToday) {
      textColor = _kPurpleViv;
    }

    final isPeriod = _isPeriodDay(day);
    final isFertile = _isFertileDay(day);

    Color? bgColor;
    if (isSelected) {
      bgColor = _kPurple;
    } else if (isToday) {
      bgColor = Colors.white.withValues(alpha: 0.08);
    } else if (isPeriod) {
      bgColor = _kRose.withValues(alpha: 0.15);
    } else if (isFertile) {
      bgColor = _kBlue.withValues(alpha: 0.1);
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: () {
        HapticFeedback.heavyImpact();
        _openAddSheet(initialDate: day, initialType: _EntryType.task);
      },
      child: Center(
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (bgColor != null)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          )
                        : (isToday
                              ? Border.all(color: _kPurpleViv, width: 1.5)
                              : (isPeriod
                                    ? Border.all(
                                        color: _kRose.withValues(alpha: 0.3),
                                        width: 1,
                                      )
                                    : null)),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _kPurple.withValues(alpha: 0.6),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ]
                        : (isToday
                              ? [
                                  BoxShadow(
                                    color: _kPurpleViv.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null),
                  ),
                ),
              Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: dayHolidays.isNotEmpty && !isSelected
                        ? _kGold
                        : (isPeriod && !isSelected ? _kRose : textColor),
                    fontSize: 15,
                    fontWeight: isSelected || dayHolidays.isNotEmpty || isToday
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...dayEvents.take(3).map((e) => _Dot(e.color.value)),
                    if (dayReminders.isNotEmpty && dayEvents.length < 3)
                      _Dot(_kPurple),
                    if (dayTasks.isNotEmpty &&
                        dayEvents.length + (dayReminders.isNotEmpty ? 1 : 0) <
                            3)
                      _Dot(_kGreen),
                    if (dayHolidays.isNotEmpty &&
                        dayEvents.length +
                                (dayReminders.isNotEmpty ? 1 : 0) +
                                (dayTasks.isNotEmpty ? 1 : 0) <
                            3)
                      _Dot(_kGold),
                  ],
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
// Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
    ),
  );
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      onTap();
      HapticFeedback.lightImpact();
    },
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _CycleStatusCard extends StatelessWidget {
  const _CycleStatusCard({
    required this.date,
    this.cycle,
    required this.isPeriod,
    required this.isFertile,
    required this.onLogPeriod,
    required this.onEdit,
  });
  final DateTime date;
  final CycleInfo? cycle;
  final bool isPeriod;
  final bool isFertile;
  final VoidCallback onLogPeriod;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPeriod ? _kRose.withValues(alpha: 0.1) : _kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPeriod ? _kRose.withValues(alpha: 0.3) : _kCardBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isPeriod ? _kRose : (isFertile ? _kBlue : _kPurple))
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPeriod
                    ? Icons.water_drop_rounded
                    : (isFertile
                          ? Icons.favorite_rounded
                          : Icons.calendar_month_rounded),
                color: isPeriod ? _kRose : (isFertile ? _kBlue : _kPurple),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPeriod
                        ? 'Period Day'
                        : (isFertile ? 'Fertile Window' : 'Cycle Status'),
                    style: TextStyle(
                      color: isPeriod ? _kRose : _kTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isPeriod) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _getPeriodProgress(),
                        backgroundColor: _kRose.withValues(alpha: 0.1),
                        color: _kRose,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Day ${_getPeriodDay()} of ${_getPeriodDuration()}',
                      style: TextStyle(
                        color: _kRose.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else
                    Text(
                      isFertile
                          ? 'High chance of conception'
                          : 'Tap to edit cycle settings',
                      style: const TextStyle(color: _kTextSub, fontSize: 13),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.edit_note_rounded,
              color: isPeriod ? _kRose : _kTextMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  int _getPeriodDay() {
    if (cycle == null) return 0;
    final diff = date.difference(cycle!.lastPeriodStart).inDays;
    return (diff % cycle!.cycleLength) + 1;
  }

  int _getPeriodDuration() {
    return cycle?.periodLength ?? 5;
  }

  double _getPeriodProgress() {
    final duration = _getPeriodDuration();
    if (duration == 0) return 0;
    final day = _getPeriodDay();
    return (day / duration).clamp(0.0, 1.0);
  }
}

class _SelectedDayAgenda extends StatelessWidget {
  const _SelectedDayAgenda({
    required this.date,
    required this.events,
    required this.reminders,
    required this.tasks,
    required this.holidays,
    required this.isPeriod,
    required this.isFertile,
    required this.onDeleteEvent,
    required this.onDeleteReminder,
    required this.onDeleteTask,
    required this.onEditEvent,
    required this.onToggleTask,
    this.onOpenTasks,
  });

  final DateTime date;
  final List<_CalEvent> events;
  final List<_Reminder> reminders;
  final List<Task> tasks;
  final List<String> holidays;
  final bool isPeriod;
  final bool isFertile;
  final ValueChanged<String> onDeleteEvent;
  final ValueChanged<String> onDeleteReminder;
  final ValueChanged<String> onDeleteTask;
  final ValueChanged<_CalEvent> onEditEvent;
  final ValueChanged<String> onToggleTask;
  final VoidCallback? onOpenTasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (holidays.isNotEmpty) ...[
          ...holidays.map((h) => _HolidayCard(name: h)),
          const SizedBox(height: 8),
        ],
        if (events.isEmpty &&
            reminders.isEmpty &&
            tasks.isEmpty &&
            holidays.isEmpty)
          const _CalendarEmptyState(),
        ...events.map(
          (e) => _EventCard(
            title: e.title,
            time: '${e.date.hour}:${e.date.minute.toString().padLeft(2, '0')}',
            subtitle: e.note ?? '',
            color: e.color.value,
            onDelete: () => onDeleteEvent(e.id),
            onEdit: () => onEditEvent(e),
            onOpenTasks: onOpenTasks,
          ),
        ),
        ...reminders.map(
          (r) => _EventCard(
            title: r.title,
            time: 'Reminder',
            subtitle: r.note ?? '',
            color: _kPurple,
            onDelete: () => onDeleteReminder(r.id),
            onOpenTasks: onOpenTasks,
          ),
        ),
        ...tasks.map(
          (t) => _EventCard(
            title: t.title,
            time: t.isCompleted ? 'Completed' : 'Task',
            subtitle: t.description ?? '',
            color: _kGreen,
            onDelete: () => onDeleteTask(t.id),
            onToggle: () => onToggleTask(t.id),
            onOpenTasks: onOpenTasks,
            isTask: true,
            isCompleted: t.isCompleted,
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.title,
    required this.time,
    required this.subtitle,
    required this.color,
    required this.onDelete,
    this.onEdit,
    this.onToggle,
    this.onOpenTasks,
    this.isTask = false,
    this.isCompleted = false,
  });

  final String title;
  final String time;
  final String subtitle;
  final Color color;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;
  final VoidCallback? onOpenTasks;
  final bool isTask;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isTask ? onToggle : onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kCardBorder, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isTask)
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? _kGreen.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? _kGreen
                          : Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, color: _kGreen, size: 14)
                      : null,
                ),
              )
            else
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 6, left: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: isCompleted ? _kGreen : _kTextMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: isCompleted ? _kTextMuted : _kTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _kTextMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, color: _kTextMuted),
              onSelected: (val) {
                if (val == 'delete') onDelete();
                if (val == 'edit' && onEdit != null) onEdit!();
                if (val == 'toggle' && onToggle != null) onToggle!();
                if (val == 'view' && onOpenTasks != null) {
                  onOpenTasks!();
                }
              },
              itemBuilder: (ctx) => [
                if (isTask) ...[
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      isCompleted ? 'Mark Incomplete' : 'Mark Complete',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'view',
                    child: const Text('View in Home'),
                  ),
                ],
                if (!isTask && onEdit != null)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HolidayCard extends StatelessWidget {
  const _HolidayCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: _kGold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: _kGold,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const Text(
            'Holiday',
            style: TextStyle(
              color: _kGold,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

enum _EntryType { event, task, reminder }

class _AddEventSheet extends StatefulWidget {
  const _AddEventSheet({
    required this.initialDate,
    this.editEvent,
    this.initialType,
    required this.onAddEvent,
    required this.onAddReminder,
  });
  final DateTime initialDate;
  final _CalEvent? editEvent;
  final _EntryType? initialType;
  final ValueChanged<_CalEvent> onAddEvent;
  final ValueChanged<_Reminder> onAddReminder;

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late DateTime _date;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 13, minute: 0);
  _EntryType _type = _EntryType.event;
  _EventColor _color = _EventColor.purple;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    if (widget.initialType != null) {
      _type = widget.initialType!;
    }
    if (widget.editEvent != null) {
      _titleCtrl.text = widget.editEvent!.title;
      _noteCtrl.text = widget.editEvent!.note ?? '';
      _color = widget.editEvent!.color;
      _startTime = TimeOfDay.fromDateTime(widget.editEvent!.date);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => _darkDatePickerTheme(ctx, child),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final note = _noteCtrl.text.trim();

    if (_type == _EntryType.task) {
      _submitTask(title, note);
    } else if (_type == _EntryType.reminder) {
      _submitReminder(title, note);
    } else {
      _submitEvent(title, note);
    }
  }

  Future<void> _submitEvent(String title, String note) async {
    widget.onAddEvent(
      _CalEvent(
        id:
            widget.editEvent?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        date: DateTime(
          _date.year,
          _date.month,
          _date.day,
          _startTime.hour,
          _startTime.minute,
        ),
        color: _color,
        note: note.isEmpty ? null : note,
      ),
    );
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  Future<void> _submitTask(String title, String note) async {
    try {
      final supabase = SupabaseService();
      final pairing = await supabase.getActivePairing();
      if (pairing == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active pairing')),
          );
        }
        return;
      }
      await supabase.createTask(
        pairingId: pairing.id,
        title: title,
        description: note.isEmpty ? null : note,
        dueDate: DateTime(
          _date.year,
          _date.month,
          _date.day,
          _startTime.hour,
          _startTime.minute,
        ),
      );

      final partnerId = pairing.user1Id == supabase.currentUserId
          ? pairing.user2Id
          : pairing.user1Id;
      if (partnerId != null && partnerId.isNotEmpty) {
        final myProfile = await supabase.getMyProfile();
        final partnerProfile = await supabase.getPartnerProfile(pairing.id);
        final senderName = partnerProfile?.preferences['partner_nickname'] ??
            myProfile?.displayName ??
            'Your partner';
        unawaited(supabase.sendPushNotification(
          toUserId: partnerId,
          type: 'task',
          title: '📝 New Task Added',
          body: '$senderName added: $title',
        ));
      }

      HapticFeedback.lightImpact();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error creating task: $e');
    }
  }

  Future<void> _submitReminder(String title, String note) async {
    widget.onAddReminder(
      _Reminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        date: DateTime(
          _date.year,
          _date.month,
          _date.day,
          _startTime.hour,
          _startTime.minute,
        ),
        note: note.isEmpty ? null : note,
      ),
    );
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final botInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, botInset + 32),
      decoration: const BoxDecoration(
        color: Color(0xFF131318),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                widget.editEvent != null ? 'Edit Event' : 'Add New Event',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TypeTab(
                      label: 'Event',
                      isSelected: _type == _EntryType.event,
                      onTap: () => setState(() => _type = _EntryType.event),
                    ),
                    _TypeTab(
                      label: 'Task',
                      isSelected: _type == _EntryType.task,
                      onTap: () => setState(() => _type = _EntryType.task),
                    ),
                    _TypeTab(
                      label: 'Reminder',
                      isSelected: _type == _EntryType.reminder,
                      onTap: () => setState(() => _type = _EntryType.reminder),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField(controller: _titleCtrl, hint: 'Event name*'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _noteCtrl,
              hint: 'Type the note here...',
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _buildPickerRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: '${_date.day} ${_monthName(_date.month)} ${_date.year}',
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPickerRow(
                    icon: Icons.access_time,
                    label: 'Start time',
                    value: _startTime.format(context),
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPickerRow(
                    icon: Icons.access_time,
                    label: 'End time',
                    value: _endTime.format(context),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPurple, _kPurpleViv],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _kPurple.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.editEvent != null
                        ? 'Update Changes'
                        : 'Create Entry',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: _kTextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kTextMuted),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.all(20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kPurple, width: 2),
        ),
      ),
    );
  }

  Widget _buildPickerRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: _kTextPrimary, fontSize: 16),
              ),
            ),
            Icon(icon, color: _kTextMuted, size: 24),
          ],
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _kTextMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : _kTextSub,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──
String _monthName(int month) {
  const names = [
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
  return names[month - 1];
}

Widget _darkDatePickerTheme(BuildContext context, Widget? child) {
  return Theme(
    data: ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: _kPurple,
        onPrimary: Colors.white,
        surface: Color(0xFF1A1B24),
        onSurface: Colors.white,
      ),
      dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1A1B24)),
    ),
    child: child!,
  );
}

// ── Global Holidays & Observances ──
class _Holiday {
  const _Holiday(
    this.day,
    this.month,
    this.name, {
    this.isInternational = true,
  });
  final int day;
  final int month;
  final String name;
  final bool isInternational;
}

const List<_Holiday> _kGlobalHolidays = [
  // Fixed Dates
  _Holiday(1, 1, "New Year's Day"),
  _Holiday(1, 1, "Global Family Day"),
  _Holiday(26, 1, "Republic Day (India)", isInternational: false),
  _Holiday(14, 2, "Valentine's Day"),
  _Holiday(8, 3, "International Women's Day"),
  _Holiday(17, 3, "St. Patrick's Day"),
  _Holiday(21, 3, "World Poetry Day"),
  _Holiday(1, 4, "April Fool's Day"),
  _Holiday(22, 4, "Earth Day"),
  _Holiday(1, 5, "Labor Day / May Day"),
  _Holiday(8, 5, "World Red Cross Day"),
  _Holiday(1, 6, "Global Day of Parents"),
  _Holiday(5, 6, "World Environment Day"),
  _Holiday(21, 6, "International Day of Yoga"),
  _Holiday(4, 7, "Independence Day (USA)"),
  _Holiday(30, 7, "International Day of Friendship"),
  _Holiday(15, 8, "Independence Day (India)", isInternational: false),
  _Holiday(5, 9, "Teachers' Day (India)", isInternational: false),
  _Holiday(21, 9, "International Day of Peace"),
  _Holiday(2, 10, "Gandhi Jayanti (India)", isInternational: false),
  _Holiday(31, 10, "Halloween"),
  _Holiday(14, 11, "Children's Day (India)", isInternational: false),
  _Holiday(19, 11, "International Men's Day"),
  _Holiday(1, 12, "World AIDS Day"),
  _Holiday(10, 12, "Human Rights Day"),
  _Holiday(25, 12, "Christmas Day"),
  _Holiday(31, 12, "New Year's Eve"),
];

List<String> _getHolidaysForDay(DateTime day) {
  final List<String> results = [];

  // Check Fixed Holidays
  for (final h in _kGlobalHolidays) {
    if (h.day == day.day && h.month == day.month) {
      results.add(h.name);
    }
  }

  // Check Floating Holidays (Logic based)
  // Mother's Day: 2nd Sunday of May
  if (day.month == 5 && day.weekday == DateTime.sunday) {
    if (day.day > 7 && day.day <= 14) results.add("Mother's Day");
  }

  // Father's Day: 3rd Sunday of June
  if (day.month == 6 && day.weekday == DateTime.sunday) {
    if (day.day > 14 && day.day <= 21) results.add("Father's Day");
  }

  // Thanksgiving (USA): 4th Thursday of November
  if (day.month == 11 && day.weekday == DateTime.thursday) {
    if (day.day > 21 && day.day <= 28) results.add("Thanksgiving Day (USA)");
  }

  return results;
}

class _EditCycleSheet extends StatefulWidget {
  const _EditCycleSheet({
    required this.initialDate,
    required this.initialCycleLength,
    required this.initialPeriodLength,
    required this.onSave,
  });
  final DateTime initialDate;
  final int initialCycleLength;
  final int initialPeriodLength;
  final Function(DateTime, int, int) onSave;

  @override
  State<_EditCycleSheet> createState() => _EditCycleSheetState();
}

class _EditCycleSheetState extends State<_EditCycleSheet> {
  late DateTime _startDate;
  late int _cycleLen;
  late int _periodLen;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate;
    _cycleLen = widget.initialCycleLength;
    _periodLen = widget.initialPeriodLength;
  }

  @override
  Widget build(BuildContext context) {
    final botInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, botInset + 32),
      decoration: const BoxDecoration(
        color: Color(0xFF131318),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _kCardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cycle Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          _buildOption(
            icon: Icons.calendar_today_rounded,
            label: 'Last Period Started',
            value: '${_startDate.day} ${_monthName(_startDate.month)}',
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) => _darkDatePickerTheme(ctx, child),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
          ),
          const SizedBox(height: 16),
          _buildOption(
            icon: Icons.repeat_rounded,
            label: 'Cycle Length',
            value: '$_cycleLen Days',
            onTap: () => _showNumberPicker(
              'Cycle Length',
              _cycleLen,
              21,
              45,
              (v) => setState(() => _cycleLen = v),
            ),
          ),
          const SizedBox(height: 16),
          _buildOption(
            icon: Icons.water_drop_rounded,
            label: 'Period Duration',
            value: '$_periodLen Days',
            onTap: () => _showNumberPicker(
              'Period Duration',
              _periodLen,
              3,
              10,
              (v) => setState(() => _periodLen = v),
            ),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () {
              widget.onSave(_startDate, _cycleLen, _periodLen);
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kPurple, _kPurpleViv]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _kPurple.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Update Cycle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: _kTextSub, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: _kTextSub, fontSize: 15),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: _kTextMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showNumberPicker(
    String title,
    int current,
    int min,
    int max,
    ValueChanged<int> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Stack(
              alignment: Alignment.center,
              children: [
                // Glassy highlight for selection
                Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 50,
                    diameterRatio: 1.2,
                    perspective: 0.003,
                    magnification: 1.3,
                    useMagnifier: true,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (i) {
                      HapticFeedback.selectionClick();
                      onSelected(min + i);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: max - min + 1,
                      builder: (ctx, i) => Center(
                        child: Text(
                          '${min + i} Days',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthYearPickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;

  const _MonthYearPickerSheet({
    required this.initialDate,
    required this.onChanged,
  });

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Year Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navBtn(Icons.chevron_left_rounded, () {
                  setState(() => _selectedYear--);
                }),
                Text(
                  '$_selectedYear',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                _navBtn(Icons.chevron_right_rounded, () {
                  setState(() => _selectedYear++);
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Months Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(12, (index) {
                final month = index + 1;
                final isSelected = month == _selectedMonth;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedMonth = month);
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: (MediaQuery.of(context).size.width - 64) / 3,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7357FB)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7357FB)
                            : Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _monthNameLocal(month),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              onPressed: () {
                widget.onChanged(DateTime(_selectedYear, _selectedMonth, 1));
                Navigator.pop(context);
                HapticFeedback.heavyImpact();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7357FB),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Confirm Selection',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(height: bottomInset + 24),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  String _monthNameLocal(int m) {
    const names = [
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
    return names[m - 1];
  }
}

class _CalendarEmptyState extends StatelessWidget {
  const _CalendarEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'A Quiet Day',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing scheduled for today. Take some time to relax or plan something fun with your partner!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: Column(
        children: List.generate(
          3,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }
}
