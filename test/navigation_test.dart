import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovit/widgets/navigation/floating_nav_bar.dart';
import 'package:lovit/widgets/navigation/nav_destination.dart';

void main() {
  Widget harness({
    int currentIndex = 0,
    Map<int, int> badgeCounts = const {},
    void Function(int index)? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF09080E),
        body: Center(
          child: SizedBox(
            width: 400,
            height: 64,
            child: FloatingNavBar(
              destinations: NavDestination.appTabs,
              currentIndex: currentIndex,
              badgeCounts: badgeCounts,
              onDestinationSelected: onTap ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders one accessible tab per destination', (tester) async {
    await tester.pumpWidget(harness());

    for (final tab in NavDestination.appTabs) {
      expect(find.bySemanticsLabel(tab.label), findsOneWidget);
    }
  });

  testWidgets('tapping an inactive tab reports its index', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(harness(onTap: tapped.add));

    await tester.tap(find.byKey(const ValueKey<int>(2)));
    await tester.pump();

    expect(tapped, [2]);
  });

  testWidgets('tapping the active tab does NOT re-navigate', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(harness(currentIndex: 1, onTap: tapped.add));

    await tester.tap(find.byKey(const ValueKey<int>(1)));
    await tester.pump();

    expect(tapped, isEmpty);
  });

  testWidgets('full tab cell is tappable, not just the icon box', (
    tester,
  ) async {
    final tapped = <int>[];
    await tester.pumpWidget(harness(onTap: tapped.add));

    final rect = tester.getRect(find.byKey(const ValueKey<int>(3)));
    // Tap the very top edge of the tab's cell — above the icon — where the
    // tap target used to be dead space.
    await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
    await tester.pump();

    expect(tapped, [3]);
    // While we're here: let the whole selection spring run to completion to
    // surface any animation assertions (e.g. Opacity out of [0, 1]).
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
  });

  testWidgets('badges render for mapped indices and cap at 9+', (tester) async {
    await tester.pumpWidget(harness(badgeCounts: {2: 3, 4: 99}));

    expect(find.text('3'), findsOneWidget);
    expect(find.text('9+'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<int>(2)));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
  });

  testWidgets('out-of-range currentIndex is clamped safely', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      harness(currentIndex: 5, onTap: tapped.add),
    );

    // No exception: the out-of-range index falls back to the first tab, so
    // tab 0 is a no-op re-tap…
    await tester.tap(find.byKey(const ValueKey<int>(0)));
    await tester.pump();
    expect(tapped, isEmpty);

    // …while the other tabs still navigate normally.
    await tester.tap(find.byKey(const ValueKey<int>(3)));
    await tester.pump();
    expect(tapped, [3]);
  });
}
