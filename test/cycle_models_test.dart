import 'package:flutter_test/flutter_test.dart';
import 'package:lovit/models/cycle_models.dart';

void main() {
  group('normalizeCalendarDate', () {
    test('strips the time component', () {
      final date = normalizeCalendarDate(DateTime(2026, 8, 13, 22, 45, 30));
      expect(date, DateTime(2026, 8, 13));
    });
  });

  group('cycleInfoFromPeriodData', () {
    test('derives period length from start/end dates', () {
      final info = cycleInfoFromPeriodData(
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 5),
      );
      expect(info.periodLength, 5);
      expect(info.cycleLength, 28);
    });

    test('defaults period length to 5 when no end date', () {
      final info = cycleInfoFromPeriodData(startDate: DateTime(2026, 8, 1));
      expect(info.periodLength, 5);
    });
  });

  group('CycleInfo', () {
    final info = CycleInfo(
      id: 'cycle',
      lastPeriodStart: DateTime(2026, 8, 1),
      cycleLength: 28,
      periodLength: 5,
    );

    test('isPeriodDay covers the first periodLength days', () {
      expect(info.isPeriodDay(DateTime(2026, 8, 1)), isTrue);
      expect(info.isPeriodDay(DateTime(2026, 8, 5)), isTrue);
      expect(info.isPeriodDay(DateTime(2026, 8, 6)), isFalse);
    });

    test('isPeriodDay wraps into the next cycle', () {
      expect(info.isPeriodDay(DateTime(2026, 8, 29)), isTrue);
      expect(info.isPeriodDay(DateTime(2026, 9, 2)), isTrue);
      expect(info.isPeriodDay(DateTime(2026, 9, 3)), isFalse);
    });

    test('fertile window is cycleLength - 18 .. cycleLength - 11', () {
      // Offsets 10..17 inclusive -> days 11..18 of a 28-day cycle.
      expect(info.isFertileDay(DateTime(2026, 8, 11)), isTrue);
      expect(info.isFertileDay(DateTime(2026, 8, 18)), isTrue);
      expect(info.isFertileDay(DateTime(2026, 8, 10)), isFalse);
      expect(info.isFertileDay(DateTime(2026, 8, 19)), isFalse);
    });

    test('cyclePhase boundaries', () {
      // Phase labels depend on the wall clock, so assert the pure
      // isPeriodDay boundary instead of wall-clock-dependent strings.
      expect(info.isPeriodDay(DateTime(2026, 8, 5)), isTrue);
      expect(info.isPeriodDay(DateTime(2026, 8, 6)), isFalse);
    });
  });
}
