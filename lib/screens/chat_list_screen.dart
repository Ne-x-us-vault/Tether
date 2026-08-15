import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../widgets/glass.dart';
import '../widgets/secure_media_image.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final VoidCallback? onOpenBudget;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenMaps;

  const ChatListScreen({
    super.key,
    this.onOpenBudget,
    this.onOpenCalendar,
    this.onOpenTasks,
    this.onOpenMaps,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  final _sb = SupabaseService();
  bool _loading = true;
  Pairing? _pairing;
  UserProfile? _myProfile;
  UserProfile? _partner;
  Message? _lastMessage;
  int _unreadCount = 0;
  StreamSubscription? _msgSub;
  StreamSubscription? _profileSub;
  StreamSubscription? _typingStreamSub;
  String? _typingPairingId;
  bool _isPartnerOnline = false;
  Timer? _presenceTimer;
  bool _isPartnerTyping = false;
  Timer? _typingTimer;
  StreamSubscription? _reconnectSub;

  @override
  void initState() {
    super.initState();
    _loadData();

    _reconnectSub = _sb.onReconnect.listen((_) {
      debugPrint('[ChatList] Connectivity restored, auto-refreshing...');
      _loadData();
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _profileSub?.cancel();
    _typingTimer?.cancel();
    _typingStreamSub?.cancel();
    if (_typingPairingId != null) {
      _sb.releaseTypingChannel(_typingPairingId!);
    }
    _reconnectSub?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    String? effectivePairingId;

    // Instant Cache Resolution
    final prefs = _sb.prefsSync;
    if (prefs != null) {
      final cachedPairingStr = prefs.getString('cache_active_pairing');
      if (cachedPairingStr != null) {
        try {
          final cachedPairing = Pairing.fromJson(jsonDecode(cachedPairingStr));
          effectivePairingId = cachedPairing.id;
          if (mounted) {
            setState(() {
              _pairing = cachedPairing;
            });
          }
        } catch (_) {}
      }
    }

    if (effectivePairingId != null) {
      _startListeners(effectivePairingId);
    }

    try {
      final pairing = await _sb.getActivePairing();
      if (pairing != null) {
        if (effectivePairingId != pairing.id) {
          _startListeners(pairing.id);
        }

        final me = await _sb.getMyProfile();
        final partner = await _sb.getPartnerProfile(pairing.id);
        if (mounted) {
          setState(() {
            _pairing = pairing;
            _myProfile = me;
            _partner = partner;
            _loading = false;
          });
          // Restart profile listener with resolved partner ID
          _startProfileListener(partner?.id);
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('[ChatList/Init] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startProfileListener(String? partnerId) {
    _presenceTimer?.cancel();
    _profileSub?.cancel();
    if (partnerId == null) return;

    // Realtime presence via Postgres Changes
    _profileSub = _sb.watchPartnerPresence(partnerId).listen((profile) {
      if (!mounted) return;
      setState(() {
        _partner = profile;
        _isPartnerOnline = profile.isOnline;
      });
    });
  }


  void _startListeners(String pairingId) {
    _msgSub?.cancel();
    _msgSub = _sb.watchMessages(pairingId).listen((msgs) {
      if (mounted) {
        setState(() {
          if (msgs.isNotEmpty) {
            _lastMessage = msgs.first;
          }
          _unreadCount = msgs
              .where((m) => !m.isRead && m.senderId != _sb.currentUserId)
              .length;
          _loading = false;
        });
      }
    });

    _startProfileListener(_partner?.id);

    _startTypingListener(pairingId);
  }

  void _startTypingListener(String pairingId) {
    // Bind exactly one typing channel per pairing: rebind on pairing change,
    // release the old channel, and never leak ref-counted channels on refresh.
    if (_typingStreamSub != null && _typingPairingId == pairingId) return;
    _typingStreamSub?.cancel();
    if (_typingPairingId != null) {
      _sb.releaseTypingChannel(_typingPairingId!);
    }
    _typingPairingId = pairingId;
    _typingStreamSub = _sb.watchTyping(pairingId).listen((payload) {
      if (!mounted) return;
      final userId = payload['user_id'] as String?;
      final isTyping = payload['is_typing'] as bool? ?? false;
      if (userId != _sb.currentUserId) {
        setState(() => _isPartnerTyping = isTyping);
        _typingTimer?.cancel();
        if (isTyping) {
          _typingTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isPartnerTyping = false);
          });
        }
      }
    });
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await _loadData();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // --- Main Content ---
          RefreshIndicator(
            color: const Color(0xFFB39DFF),
            backgroundColor: const Color(0xFF131318),
            displacement: 40,
            edgeOffset: topInset + 90,
            onRefresh: _handleRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Extra space for the floating header
                SliverToBoxAdapter(child: SizedBox(height: topInset + 120)),

                // --- Chat List ---
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: _loading
                        ? const _ChatListShimmer()
                        : (_pairing == null
                              ? _buildNoPairingState()
                              : _buildChatItem()),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // --- The Obsidian Top Bar (Matching App Theme) ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildObsidianHeader(topInset),
          ),
        ],
      ),
    );
  }

  Widget _buildObsidianHeader(double topInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 20),
      child: GlassPanel(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // Matching the Calendar Obsidian Glass look
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.black.withValues(alpha: 0.55),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LOVIT',
                        style: TextStyle(
                          color: Color(0xFFB39DFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        'Message',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _NavIcon(
                icon: Icons.sports_esports_rounded,
                onTap: _showGamesComingSoon,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGamesComingSoon() {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Games',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002) // Perspective
                    ..rotateX(-0.1 * (1 - value))
                    ..rotateY(0.1 * (1 - value))
                    // ignore: deprecated_member_use
                    ..scale(0.8 + (0.2 * value)),
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFB39DFF),
                      Color(0xFFFF6EC7),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 3D Parallax Icon
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform(
                            transform: Matrix4.identity()
                              ..setTranslationRaw(
                                0.0,
                                -10.0 * (1 - value),
                                40.0 * value,
                              ),
                            alignment: Alignment.center,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB39DFF).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB39DFF).withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: -10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.videogame_asset_rounded,
                            color: Color(0xFFB39DFF),
                            size: 64,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'NEW FEATURE',
                        style: TextStyle(
                          color: Color(0xFFFF6EC7),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'GAME CENTER\nIS COMING',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 0.9),
                                duration: const Duration(seconds: 4),
                                curve: Curves.easeInOutQuart,
                                builder: (context, value, _) =>
                                    FractionallySizedBox(
                                      widthFactor: value,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFFB39DFF),
                                              Color(0xFFFF6EC7),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                              ),
                              const Center(
                                child: Text(
                                  'PREPARING...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'NOTIFY ME',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: 15 * anim1.value,
            sigmaY: 15 * anim1.value,
          ),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  // ignore: unused_element
  void _showQuickMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassPanel(
        borderRadius: 40,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick Access',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            _QuickMenuButton(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Shared Budget',
              color: const Color(0xFF4ADE80),
              onTap: () {
                Navigator.pop(context);
                widget.onOpenBudget?.call();
              },
            ),
            const SizedBox(height: 12),
            _QuickMenuButton(
              icon: Icons.calendar_month_rounded,
              label: 'Shared Calendar',
              color: const Color(0xFF9B6FFF),
              onTap: () {
                Navigator.pop(context);
                widget.onOpenCalendar?.call();
              },
            ),
            const SizedBox(height: 12),
            _QuickMenuButton(
              icon: Icons.map_rounded,
              label: 'Live Maps',
              color: const Color(0xFFFFD88A),
              onTap: () {
                Navigator.pop(context);
                widget.onOpenMaps?.call();
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _openChat() {
    if (_pairing == null) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          pairingId: _pairing!.id,
          threadId: null, // Default thread
        ),
      ),
    );
  }

  Widget _buildChatItem() {
    final partnerName =
        _myProfile?.preferences['partner_nickname'] ??
        _partner?.displayName ??
        'Partner';
    final lastMsgText =
        _lastMessage?.content ?? 'Start your private conversation';
    final timeStr = _lastMessage != null
        ? DateFormat('hh:mm a').format(_lastMessage!.createdAt)
        : '';
    final isUnread =
        _lastMessage != null &&
        !_lastMessage!.isRead &&
        _lastMessage!.senderId != _sb.currentUserId;

    return GestureDetector(
      onTap: _openChat,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: GlassPanel(
          borderRadius: 24,
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.black.withValues(alpha: 0.1),
            ),
            child: Row(
              children: [
                _AvatarWithStatus(
                  avatarUrl: _partner?.avatarUrl,
                  initial: partnerName.isEmpty ? '?' : partnerName[0],
                  isOnline: _isPartnerOnline,
                  gradient: const [Color(0xFFB39DFF), Color(0xFF9B6FFF)],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            partnerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: isUnread
                                  ? const Color(0xFFB39DFF)
                                  : Colors.white.withValues(alpha: 0.25),
                              fontSize: 11,
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isPartnerTyping ? 'Typing...' : lastMsgText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _isPartnerTyping
                                    ? const Color(0xFF4ADE80)
                                    : (isUnread
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.4)),
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                fontStyle: _isPartnerTyping
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          if (_unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFB39DFF),
                                    Color(0xFF7C5CFF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFB39DFF,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                _unreadCount > 99 ? '99+' : '$_unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoPairingState() {
    return GlassPanel(
      borderRadius: 32,
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFFF9BAB),
            size: 54,
          ),
          const SizedBox(height: 20),
          const Text(
            'The Private Space',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Connect with your partner to unlock your private chat log.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showComingSoon() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassPanel(
        borderRadius: 40,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFFB39DFF),
              size: 48,
            ),
            const SizedBox(height: 20),
            const Text(
              'Chat Screen Coming Soon',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We are building a beautiful messaging interface just for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB39DFF), Color(0xFF9B6FFF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'OKAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
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
}

class _AvatarWithStatus extends StatelessWidget {
  const _AvatarWithStatus({
    required this.initial,
    required this.isOnline,
    required this.gradient,
    this.avatarUrl,
  });
  final String initial;
  final bool isOnline;
  final List<Color> gradient;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipOval(
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? SecureMediaImage(
                    value: avatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: Center(
                      child: Text(
                        initial.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    errorWidget: Center(
                      child: Text(
                        initial.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF131318), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ChatListShimmer extends StatelessWidget {
  const _ChatListShimmer();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(5),
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

class _QuickMenuButton extends StatelessWidget {
  const _QuickMenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size * 0.6,
            spreadRadius: size * 0.2,
          ),
        ],
      ),
    );
  }
}
