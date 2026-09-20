import 'package:flutter/material.dart';

/// A single tab in the bottom navigation bar.
///
/// This is the single source of truth for what a tab looks like. The shell
/// builds its pages and the bar builds its items from the same list, so the
/// ordering can never drift apart.
@immutable
class NavDestination {
  const NavDestination({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });

  /// Screen-reader label for this tab.
  final String label;

  /// Icon shown when the tab is selected.
  final IconData activeIcon;

  /// Icon shown when the tab is not selected.
  final IconData inactiveIcon;

  /// The five primary tabs of the app, in display order.
  ///
  /// Order must match the page list in [HomeShell].
  static const List<NavDestination> appTabs = [
    NavDestination(
      label: 'Home',
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
    ),
    NavDestination(
      label: 'Budget',
      activeIcon: Icons.wallet_rounded,
      inactiveIcon: Icons.wallet_outlined,
    ),
    NavDestination(
      label: 'Log',
      activeIcon: Icons.chat_bubble_rounded,
      inactiveIcon: Icons.chat_bubble_outline_rounded,
    ),
    NavDestination(
      label: 'Calendar',
      activeIcon: Icons.calendar_month_rounded,
      inactiveIcon: Icons.calendar_month_outlined,
    ),
    NavDestination(
      label: 'Maps',
      activeIcon: Icons.map_rounded,
      inactiveIcon: Icons.map_outlined,
    ),
  ];
}
