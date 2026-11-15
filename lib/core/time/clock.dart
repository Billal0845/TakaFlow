/// Injectable Clock abstraction for testable time calculations.
abstract class Clock {
  DateTime now();
  String todayLocalDate();
  String toLocalDate(DateTime dt);
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  String todayLocalDate() => toLocalDate(now());

  @override
  String toLocalDate(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class FixedClock implements Clock {
  final DateTime fixedDateTime;

  FixedClock(this.fixedDateTime);

  @override
  DateTime now() => fixedDateTime;

  @override
  String todayLocalDate() => toLocalDate(fixedDateTime);

  @override
  String toLocalDate(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
