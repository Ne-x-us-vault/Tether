// ══════════════════════════════════════════════════════════════════════════════
// notification_screen.dart — Lovit App
// A dedicated notification center for shared activities and alerts.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Palette
// ══════════════════════════════════════════════════════════════════════════════
const Color _kBg = Color(0xFF0C0C10);
const Color _kTextPrimary = Color(0xFFEDEAF4);
const Color _kTextSub = Color(0xFFABA7B8);
const Color _kTextMuted = Color(0xFF7A7788);
const Color _kPurple = Color(0xFFB39DFF);
const Color _kPink = Color(0xFFFF6EC7);
const Color _kRose = Color(0xFFFF9BAB);
const Color _kGold = Color(0xFFFFD88A);
const Color _kGreen = Color(0xFF4ADE80);
const Color _kCyan = Color(0xFF67E8F9);

enum NotificationType {
  expense,
  task,
  calendar,
  battery,
  period,
  memory,
  mood,
  chat,
  call,
  location,
}

class LovitNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final bool isRead;
  final dynamic metadata;

  LovitNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });
}

class NotificationScreen extends StatefulWidget {
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenBudget;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenMaps;

  const NotificationScreen({
    super.key,
    this.onOpenChat,
    this.onOpenBudget,
    this.onOpenCalendar,
    this.onOpenTasks,
    this.onOpenMaps,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final SupabaseService _sb = SupabaseService();
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSub;
  List<Map<String, dynamic>> _rawNotifications = [];
  List<LovitNotification> _notifications = [];
  bool _loading = true;

  UserProfile? _myProfile;
  UserProfile? _partnerProfile;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _subscribeToNotifications();
  }

  Future<void> _loadProfiles() async {
    try {
      final me = await _sb.getMyProfile();
      UserProfile? partner;
      final pairing = await _sb.getActivePairing();
      if (pairing != null) {
        final partnerId = pairing.user1Id == me?.id ? pairing.user2Id : pairing.user1Id;
        if (partnerId != null) {
          partner = await _sb.getPartnerProfile(pairing.id);
        }
      }
      if (mounted) {
        setState(() {
          _myProfile = me;
          _partnerProfile = partner;
          _notifications = _parseRawNotifications(_rawNotifications);
        });
      }
    } catch (e) {
      debugPrint('[Notifications] Error loading profiles: $e');
    }
  }

  String get _partnerName {
    return _myProfile?.preferences['partner_nickname'] ?? 
           _partnerProfile?.displayName ?? 
           'Partner';
  }

  String _formatNotificationText(String text) {
    if (text.isEmpty) return text;
    final pName = _partnerName;
    String result = text
        .replaceAll('Your partner', pName)
        .replaceAll('Your Partner', pName)
        .replaceAll('partner', pName.toLowerCase())
        .replaceAll('Partner', pName);
        
    final partnerDisplayName = _partnerProfile?.displayName;
    if (partnerDisplayName != null && partnerDisplayName.isNotEmpty && partnerDisplayName.toLowerCase() != 'partner') {
      result = result
          .replaceAll(partnerDisplayName, pName)
          .replaceAll("$partnerDisplayName's", "$pName's");
    }
    return result;
  }

  List<LovitNotification> _parseRawNotifications(List<Map<String, dynamic>> rawList) {
    return rawList.map((map) {
      final typeStr = map['notification_type'] as String? ?? 'mood';
      NotificationType type;
      switch (typeStr) {
        case 'expense':
        case 'budget':
          type = NotificationType.expense;
          break;
        case 'task':
          type = NotificationType.task;
          break;
        case 'calendar':
          type = NotificationType.calendar;
          break;
        case 'battery':
          type = NotificationType.battery;
          break;
        case 'period':
          type = NotificationType.period;
          break;
        case 'memory':
          type = NotificationType.memory;
          break;
        case 'message':
        case 'reaction':
        case 'pin':
          type = NotificationType.chat;
          break;
        case 'voice_call':
        case 'video_call':
          type = NotificationType.call;
          break;
        case 'location':
          type = NotificationType.location;
          break;
        case 'mood':
        default:
          type = NotificationType.mood;
          break;
      }

      final rawTitle = map['title'] as String? ?? 'Notification';
      final rawBody = map['body'] as String? ?? '';

      return LovitNotification(
        id: map['id'] as String,
        type: type,
        title: _formatNotificationText(rawTitle),
        subtitle: _formatNotificationText(rawBody),
        timestamp: map['created_at'] != null 
            ? DateTime.parse(map['created_at'] as String).toLocal()
            : DateTime.now(),
        isRead: map['is_read'] as bool? ?? false,
        metadata: map,
      );
    }).toList();
  }

  void _subscribeToNotifications() {
    _notificationSub = _sb.watchNotifications().listen((rawList) {
      if (mounted) {
        setState(() {
          _rawNotifications = rawList;
          _notifications = _parseRawNotifications(rawList);
          _loading = false;
        });
      }
    });
  }

  int? _targetTabForNotification(NotificationType type) {
    switch (type) {
      case NotificationType.expense:
        return 1;
      case NotificationType.task:
        return 0;
      case NotificationType.calendar:
      case NotificationType.period:
        return 3;
      case NotificationType.chat:
      case NotificationType.call:
        return 2;
      case NotificationType.location:
        return 4;
      case NotificationType.battery:
      case NotificationType.memory:
      case NotificationType.mood:
        return null;
    }
  }

  Future<void> _openNotificationTarget(LovitNotification notification) async {
    final targetTab = _targetTabForNotification(notification.type);
    final openedFromHomeFlow =
        widget.onOpenChat != null ||
        widget.onOpenBudget != null ||
        widget.onOpenCalendar != null ||
        widget.onOpenTasks != null ||
        widget.onOpenMaps != null;

    if (openedFromHomeFlow && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    switch (notification.type) {
      case NotificationType.expense:
        if (widget.onOpenBudget != null) {
          widget.onOpenBudget!.call();
        } else if (targetTab != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('notification_tab', targetTab);
          if (mounted) context.go('/home');
        }
        break;
      case NotificationType.task:
        if (widget.onOpenTasks != null) {
          widget.onOpenTasks!.call();
        } else if (targetTab != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('notification_tab', targetTab);
          NotificationService.pendingHomeAction.value =
              NotificationService.homeTasksAction;
          if (mounted) context.go('/home');
        }
        break;
      case NotificationType.calendar:
      case NotificationType.period:
        if (widget.onOpenCalendar != null) {
          widget.onOpenCalendar!.call();
        } else if (targetTab != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('notification_tab', targetTab);
          if (mounted) context.go('/home');
        }
        break;
      case NotificationType.chat:
      case NotificationType.call:
        if (widget.onOpenChat != null) {
          widget.onOpenChat!.call();
        } else if (targetTab != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('notification_tab', targetTab);
          if (mounted) context.go('/home');
        }
        break;
      case NotificationType.location:
        if (widget.onOpenMaps != null) {
          widget.onOpenMaps!.call();
        } else if (targetTab != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('notification_tab', targetTab);
          if (mounted) context.go('/home');
        }
        break;
      case NotificationType.battery:
      case NotificationType.memory:
      case NotificationType.mood:
        break;
    }
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Ambient backgrounds
          Positioned(
            top: -100,
            right: -50,
            child: _GlowBlob(300, _kPurple.withValues(alpha: 0.05)),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _GlowBlob(400, _kPink.withValues(alpha: 0.04)),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _loading
                      ? ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                          itemCount: 5,
                          itemBuilder: (context, index) =>
                              const _NotificationSkeleton(),
                        )
                      : _notifications.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            return Dismissible(
                              key: Key(notification.id),
                              direction: DismissDirection.startToEnd,
                              onDismissed: (direction) {
                                // Delete from Supabase - the realtime stream will automatically sync
                                unawaited(
                                  _sb.deleteNotification(notification.id),
                                );
                                HapticFeedback.mediumImpact();
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: _kRose.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: _kRose,
                                  size: 24,
                                ),
                              ),
                              child: _NotificationTile(
                                notification: notification,
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  await _openNotificationTarget(notification);
                                  unawaited(_sb.deleteNotification(notification.id));
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _kTextPrimary,
              size: 20,
            ),
          ),
          const Text(
            'Notifications',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const Spacer(),
          if (_notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  unawaited(_sb.clearAllNotifications());
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'CLEAR ALL',
                  style: TextStyle(
                    color: _kRose.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPurple.withValues(alpha: 0.2)),
            ),
            child: Text(
              '${_notifications.length} NEW',
              style: const TextStyle(
                color: _kPurple,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: _kTextMuted.withValues(alpha: 0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: _kTextSub.withValues(alpha: 0.5),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you about shared activities here.',
            style: TextStyle(color: _kTextMuted.withValues(alpha: 0.4), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final LovitNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        tintColor: const Color(0xFF16161E),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          notification.title,
                          style: const TextStyle(
                            color: _kTextPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _formatTime(notification.timestamp),
                          style: TextStyle(
                            color: _kTextMuted.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.subtitle,
                      style: TextStyle(
                        color: _kTextSub.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color color;
    switch (notification.type) {
      case NotificationType.expense:
        iconData = Icons.account_balance_wallet_rounded;
        color = _kGreen;
        break;
      case NotificationType.task:
        iconData = Icons.sticky_note_2_rounded;
        color = _kGold;
        break;
      case NotificationType.calendar:
        iconData = Icons.calendar_today_rounded;
        color = _kCyan;
        break;
      case NotificationType.chat:
        iconData = Icons.chat_bubble_rounded;
        color = _kPurple;
        break;
      case NotificationType.call:
        iconData = Icons.phone_in_talk_rounded;
        color = _kGreen;
        break;
      case NotificationType.location:
        iconData = Icons.location_on_rounded;
        color = _kCyan;
        break;
      case NotificationType.battery:
        iconData = Icons.battery_alert_rounded;
        color = _kRose;
        break;
      case NotificationType.period:
        iconData = Icons.nightlight_round;
        color = _kPink;
        break;
      case NotificationType.memory:
        iconData = Icons.photo_library_rounded;
        color = _kPurple;
        break;
      case NotificationType.mood:
        iconData = Icons.face_rounded;
        color = _kPurple;
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

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

// ignore: unused_element
class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
