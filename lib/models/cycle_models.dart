import 'package:flutter/foundation.dart';

DateTime normalizeCalendarDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

final ValueNotifier<DateTime?> cycleTrackerSync = ValueNotifier<DateTime?>(
  null,
);

class CycleInfo {
  const CycleInfo({
    this.id,
    required this.lastPeriodStart,
    required this.cycleLength,
    required this.periodLength,
  });

  final String? id;
  final DateTime lastPeriodStart;
  final int cycleLength;
  final int periodLength;

  int _cycleOffsetFor(DateTime date) {
    final normalizedDate = normalizeCalendarDate(date);
    final normalizedStart = normalizeCalendarDate(lastPeriodStart);
    final diff = normalizedDate.difference(normalizedStart).inDays;
    return ((diff % cycleLength) + cycleLength) % cycleLength;
  }

  DateTime _cycleStartFor(DateTime date) {
    final normalizedDate = normalizeCalendarDate(date);
    return normalizedDate.subtract(
      Duration(days: _cycleOffsetFor(normalizedDate)),
    );
  }

  int get _fertileStartOffset {
    final value = cycleLength - 18;
    if (value < 0) {
      return 0;
    }
    if (value >= cycleLength) {
      return cycleLength - 1;
    }
    return value;
  }

  int get _fertileEndOffset {
    final value = cycleLength - 11;
    if (value < 0) {
      return 0;
    }
    if (value >= cycleLength) {
      return cycleLength - 1;
    }
    return value;
  }

  bool get isPeriodActive => isPeriodDay(DateTime.now());

  DateTime get nextPeriodStart {
    final today = normalizeCalendarDate(DateTime.now());
    final currentCycleStart = _cycleStartFor(today);
    if (isPeriodDay(today)) {
      return currentCycleStart;
    }
    return currentCycleStart.add(Duration(days: cycleLength));
  }

  DateTime get fertileStart {
    final today = normalizeCalendarDate(DateTime.now());
    final currentCycleStart = _cycleStartFor(today);
    final start = currentCycleStart.add(Duration(days: _fertileStartOffset));
    final end = currentCycleStart.add(Duration(days: _fertileEndOffset));
    if (today.isAfter(end)) {
      return start.add(Duration(days: cycleLength));
    }
    return start;
  }

  DateTime get fertileEnd {
    final today = normalizeCalendarDate(DateTime.now());
    final currentCycleStart = _cycleStartFor(today);
    final end = currentCycleStart.add(Duration(days: _fertileEndOffset));
    if (today.isAfter(end)) {
      return end.add(Duration(days: cycleLength));
    }
    return end;
  }

  int get daysUntilNext {
    final today = normalizeCalendarDate(DateTime.now());
    if (isPeriodDay(today)) {
      return 0;
    }
    final next = normalizeCalendarDate(nextPeriodStart);
    return next.difference(today).inDays;
  }

  int get currentCycleDay {
    final today = normalizeCalendarDate(DateTime.now());
    return _cycleOffsetFor(today) + 1;
  }

  double get progress => currentCycleDay / cycleLength;

  bool isPeriodDay(DateTime date) {
    return _cycleOffsetFor(date) < periodLength;
  }

  bool isFertileDay(DateTime date) {
    final cycleOffset = _cycleOffsetFor(date);
    return cycleOffset >= _fertileStartOffset &&
        cycleOffset <= _fertileEndOffset;
  }

  String get cyclePhase {
    final day = currentCycleDay;
    if (day <= periodLength) {
      return 'Menstrual Phase';
    }
    if (day <= 13) {
      return 'Follicular Phase';
    }
    if (day <= 16) {
      return 'Ovulation Phase';
    }
    return 'Luteal Phase';
  }
}

CycleInfo cycleInfoFromPeriodData({
  String? id,
  required DateTime startDate,
  DateTime? endDate,
  int cycleLength = 28,
}) {
  final normalizedStart = normalizeCalendarDate(startDate);
  final normalizedEnd = endDate != null ? normalizeCalendarDate(endDate) : null;
  final derivedPeriodLength = normalizedEnd != null
      ? normalizedEnd.difference(normalizedStart).inDays + 1
      : 5;

  return CycleInfo(
    id: id,
    lastPeriodStart: normalizedStart,
    cycleLength: cycleLength,
    periodLength: derivedPeriodLength.clamp(1, 10).toInt(),
  );
}
