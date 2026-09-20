import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nav_destination.dart';

/// One animated tab in the [FloatingNavBar].
///
/// Owns a single [AnimationController] that drives scale + glow together, so
/// the selection feedback stays perfectly in sync. Animation only fires when
/// `isActive` actually changes (never on unrelated rebuilds), and haptics are
/// emitted only for a real selection change — not for re-taps on the active
/// tab and not for programmatic navigation (e.g. opening a tab from a
/// notification or swiping the page view).
class NavItem extends StatefulWidget {
  const NavItem({
    super.key,
    required this.destination,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  final NavDestination destination;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> with SingleTickerProviderStateMixin {
  static const _springOut = Curves.elasticOut;

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;
  late final Animation<double> _dotOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      reverseDuration: const Duration(milliseconds: 250),
    );

    // Forward springs (elasticOut) for a lively selection pop; reverse settles
    // cleanly (easeInOut) so deactivating a tab never squishes below rest size.
    final curve = CurvedAnimation(
      parent: _controller,
      curve: _springOut,
      reverseCurve: Curves.easeInOut,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.22).animate(curve);
    _glow = Tween<double>(begin: 0.0, end: 0.22).animate(curve);
    _dotOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

    // Start the selected tab in its active state without an opening animation.
    if (widget.isActive) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      _controller.forward(from: 0.0);
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isActive) {
      // Tapping the already-selected tab nudges the spring for tactile
      // feedback, but produces no haptic and no navigation.
      _controller.forward(from: 0.0);
      return;
    }
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: widget.isActive,
      label: widget.destination.label,
      button: true,
      child: InkWell(
        onTap: _handleTap,
        highlightColor: Colors.white.withValues(alpha: 0.08),
        splashColor: Colors.white.withValues(alpha: 0.05),
        borderRadius: _itemRadius,
        child: SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (_, child) {
                          return Transform.scale(
                            scale: _scale.value,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(
                                      alpha: _glow.value,
                                    ),
                                    blurRadius: 18,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: Center(child: child),
                            ),
                          );
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Icon(
                            widget.isActive
                                ? widget.destination.activeIcon
                                : widget.destination.inactiveIcon,
                            key: ValueKey<bool>(widget.isActive),
                            color: widget.isActive
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                            size: 22,
                          ),
                        ),
                      ),
                      if (widget.badgeCount > 0) _buildBadge()!,
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) {
                    final dotOpacity = _dotOpacity.value.clamp(0.0, 1.0);
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
                              color: Colors.white.withValues(
                                alpha: 0.65 * dotOpacity,
                              ),
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
        ),
      ),
    );
  }

  BorderRadius get _itemRadius => BorderRadius.circular(14);

  Widget? _buildBadge() {
    if (widget.badgeCount <= 0) return null;
    return Positioned(
      right: -2,
      top: -2,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
        child: Container(
          key: ValueKey<int>(widget.badgeCount),
          padding: const EdgeInsets.all(2),
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4B4B),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF131318), width: 1.5),
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
              widget.badgeCount > 9 ? '9+' : '${widget.badgeCount}',
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
    );
  }
}
