import 'package:flutter/material.dart';

/// Shared app-wide layout metrics.
///
/// Kept in one place so every screen that draws content behind the floating
/// navigation bar reserves exactly the same vertical space.
class AppLayout {
  AppLayout._();

  /// Height of the floating pill navigation bar.
  static const double navBarHeight = 64;

  /// Gap between the pill and the bottom edge of the screen.
  static const double navBarBottomGap = 12;

  /// Extra visual clearance screens add when drawing behind the bar.
  static const double navBarClearance = 20;

  /// Total vertical space reserved for the floating nav bar.
  ///
  /// Screens that scroll content behind the bar apply this as their bottom
  /// padding so nothing is hidden under the pill.
  static const double kNavBarPad =
      navBarHeight + navBarBottomGap + navBarClearance;

  /// Horizontal margin of the pill on each side.
  static const EdgeInsets navBarMargin = EdgeInsets.symmetric(horizontal: 52);
}
