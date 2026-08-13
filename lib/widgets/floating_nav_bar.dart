// ══════════════════════════════════════════════════════════════════════════════
// floating_nav_bar.dart — Lovit App
// Floating pill navigation bar — stateless shell, animated items.
// Parent (HomeShell) positions this inside a Stack at the bottom.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Icon pairs ─────────────────────────────────────────────────────────────────
const List<IconData> _kActiveIcons = [
  Icons.home_rounded,
  Icons.wallet_rounded, // Budget
  Icons.chat_bubble_rounded, // Chat
  Icons.calendar_month_rounded, // Calendar
  Icons.map_rounded, // Maps
];

const List<IconData> _kInactiveIcons = [
  Icons.home_outlined,
  Icons.wallet_outlined, // Budget
  Icons.chat_bubble_outline_rounded, // Chat
  Icons.calendar_month_outlined, // Calendar
  Icons.map_outlined, // Maps
];

// ══════════════════════════════════════════════════════════════════════════════
// FloatingNavBar — stateless, just the pill
// ══════════════════════════════════════════════════════════════════════════════
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    this.unreadCount = 0,
    required this.onTap,
  });

  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 52),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 25,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0x4C1A1A22),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
              child: Stack(
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (i) => Expanded(
                        child: _NavItem(
                          activeIcon: _kActiveIcons[i],
                          inactiveIcon: _kInactiveIcons[i],
                          isActive: currentIndex == i,
                          notificationCount: i == 2 ? unreadCount : 0,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onTap(i);
                          },
                        ),
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
// _NavItem — animated icon + dot with soft white glow
// ══════════════════════════════════════════════════════════════════════════════
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isActive,
    this.notificationCount = 0,
    required this.onTap,
  });

  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isActive;
  final int notificationCount;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _scale = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _NavItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.forward(from: 0.0);
    } else if (!widget.isActive && old.isActive) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, _) {
                    final glowOpacity = 0.22 * _ctrl.value;
                    return Transform.scale(
                      scale: _scale.value,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: glowOpacity),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: Icon(
                              widget.isActive
                                  ? widget.activeIcon
                                  : widget.inactiveIcon,
                              key: ValueKey<bool>(widget.isActive),
                              color: widget.isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (widget.notificationCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4B4B),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF131318),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.notificationCount > 9 ? '9+' : '${widget.notificationCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                final dotOpacity = _ctrl.value.clamp(0.0, 1.0);
                return Opacity(
                  opacity: dotOpacity,
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.65 * dotOpacity),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
