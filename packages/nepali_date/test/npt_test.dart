import 'package:nepali_date/nepali_date.dart';
import 'package:test/test.dart';

/// The timezone matrix: the same instant can read as three different
/// calendar dates in Kathmandu, UTC, and New York. Nepal Time is a fixed
/// +05:45 with no DST, so its date boundary (18:15:00 UTC) is identical
/// every day of every year - unlike UTC's 00:00 or New York's moving
/// boundary. US Eastern is the classic DST counterexample, used with its
/// fixed seasonal offsets (EST -5 in January, EDT -4 in July).
void main() {
  test('Nepal Time offset is exactly UTC+05:45 (matches the widget constant)', () {
    expect(nepalTimeOffset, const Duration(hours: 5, minutes: 45));
    expect(nepalTimeOffset.inMilliseconds, 20700000); // NPT_MS in widget.js
  });

  test('Nepal midnight is 18:15:00 UTC, to the second', () {
    expect(todayInNepalTime(nowUtc: DateTime.utc(2026, 11, 2, 18, 14, 59)),
        DateTime.utc(2026, 11, 2));
    expect(todayInNepalTime(nowUtc: DateTime.utc(2026, 11, 2, 18, 15, 0)),
        DateTime.utc(2026, 11, 3));
  });

  test('the 18:15:00 UTC boundary holds on every seasonal date (no DST in NPT)', () {
    for (final day in [
      DateTime.utc(2026, 3, 20), // spring equinox
      DateTime.utc(2026, 6, 21), // summer solstice
      DateTime.utc(2026, 9, 23), // autumn equinox
      DateTime.utc(2026, 12, 21), // winter solstice
    ]) {
      final before = todayInNepalTime(
          nowUtc: DateTime.utc(day.year, day.month, day.day, 18, 14, 59));
      final after = todayInNepalTime(
          nowUtc: DateTime.utc(day.year, day.month, day.day, 18, 15, 0));
      expect(before, DateTime.utc(day.year, day.month, day.day),
          reason: 'one second before Nepal midnight the date has not rolled');
      expect(after, day.add(const Duration(days: 1)),
          reason: 'at Nepal midnight the date rolls over');
    }
  });

  test('exhaustive minute sweep of a full UTC day: exactly 345 minutes differ from UTC', () {
    var differ = 0;
    var flips = 0;
    var prev = DateTime.utc(2026, 11, 2);
    for (var minute = 0; minute < 1440; minute++) {
      final t = DateTime.utc(2026, 11, 2, 0, minute); // Dart normalizes minute > 59
      final nptToday = todayInNepalTime(nowUtc: t);
      final utcToday = DateTime.utc(t.year, t.month, t.day);
      if (nptToday != utcToday) differ++;
      if (nptToday != prev) flips++;
      prev = nptToday;
    }
    expect(differ, 345, reason: '18:15-23:59 UTC (345 minutes) is already the next day in Nepal');
    expect(flips, 1, reason: 'exactly one date rollover per UTC day, at 18:15:00');
  });

  test('timezone matrix: the same instant, three different todays', () {
    // 2026-01-01 04:59:59 UTC: Nepal and UTC say Jan 1; New York (EST, -5)
    // still says Dec 31, 2025.
    final a = DateTime.utc(2026, 1, 1, 4, 59, 59);
    expect(todayInNepalTime(nowUtc: a), DateTime.utc(2026, 1, 1));
    expect(DateTime.utc(a.year, a.month, a.day), DateTime.utc(2026, 1, 1));
    final nyA = a.subtract(const Duration(hours: 5));
    expect(DateTime.utc(nyA.year, nyA.month, nyA.day), DateTime.utc(2025, 12, 31));

    // 2026-01-01 18:15:00 UTC: Nepal has already rolled to Jan 2; UTC and
    // New York still say Jan 1.
    final b = DateTime.utc(2026, 1, 1, 18, 15);
    expect(todayInNepalTime(nowUtc: b), DateTime.utc(2026, 1, 2));
    expect(DateTime.utc(b.year, b.month, b.day), DateTime.utc(2026, 1, 1));
    final nyB = b.subtract(const Duration(hours: 5));
    expect(DateTime.utc(nyB.year, nyB.month, nyB.day), DateTime.utc(2026, 1, 1));

    // 2026-07-01 03:30:00 UTC: Nepal and UTC say Jul 1; New York (EDT, -4)
    // still says Jun 30.
    final c = DateTime.utc(2026, 7, 1, 3, 30);
    expect(todayInNepalTime(nowUtc: c), DateTime.utc(2026, 7, 1));
    expect(DateTime.utc(c.year, c.month, c.day), DateTime.utc(2026, 7, 1));
    final nyC = c.subtract(const Duration(hours: 4));
    expect(DateTime.utc(nyC.year, nyC.month, nyC.day), DateTime.utc(2026, 6, 30));
  });

  test('todayInNepalTime() with no argument returns a date-only UTC value', () {
    final t = todayInNepalTime();
    expect(t.isUtc, isTrue);
    expect(t.hour, 0);
    expect(t.minute, 0);
    expect(t.second, 0);
    expect(t.millisecond, 0);
    expect(t.microsecond, 0);
  });
}
