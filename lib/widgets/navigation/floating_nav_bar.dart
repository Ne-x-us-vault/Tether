import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import 'nav_destination.dart';
import 'nav_item.dart';

/// Floating glassmorphic pill navigation bar.
///
/// A stateless shell: the parent owns the selected index, the destinations
/// list and any badge counts, and this widget only renders + animates them.
///
/// Every item exposes proper [Semantics] so screen readers can navigate it,
/// and haptics are emitted by the items only when the selection actually
/// changes.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.badgeCounts = const {},
  }) : assert(destinations.length >= 2, 'Nav bar needs at least 2 tabs');

  /// Tabs to render, in display order. Must match shell page order.
  final List<NavDestination> destinations;

  /// Index of the currently selected tab (range-checked against
  /// [destinations]).
  final int currentIndex;

  /// Called with the tapped index. Fire-and-forget from the bar's
  /// perspective; the parent decides how to switch pages.
  final ValueChanged<int> onDestinationSelected;

  /// Per-index badge counts. Only indices with a value > 0 render a badge.
  final Map<int, int> badgeCounts;

  double get _radius => AppLayout.navBarHeight / 2;

  @override
  Widget build(BuildContext context) {
    final safeIndex = (currentIndex < 0 || currentIndex >= destinations.length)
        ? 0
        : currentIndex;

    return Container(
      height: AppLayout.navBarHeight,
      margin: AppLayout.navBarMargin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
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
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0x4C1A1A22),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: NavItem(
                        key: ValueKey<int>(i),
                        destination: destinations[i],
                        isActive: safeIndex == i,
                        badgeCount: badgeCounts[i] ?? 0,
                        onTap: () => onDestinationSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
