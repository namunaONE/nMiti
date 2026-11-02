import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_date_data/nepali_date_data.dart';
import 'package:test/test.dart';

void main() {
  test('core spans BS 1975-2083 with 109 verified rows', () {
    expect(coreCalendar.firstYear, 1975);
    expect(coreCalendar.lastYear, 2083);
    expect(coreCalendar.years.length, 109);
  });

  test('tail spans BS 2084-2100 with 17 rows', () {
    expect(tailCalendar.firstYear, 2084);
    expect(tailCalendar.lastYear, 2100);
    expect(tailCalendar.years.length, 17);
  });

  test('full calendar spans 1975-2100 contiguously', () {
    expect(fullCalendar.firstYear, 1975);
    expect(fullCalendar.lastYear, 2100);
    expect(fullCalendar.years.length, 126);
  });

  test('today: 2026-11-02 is Kartik 16, 2083', () {
    expect(fullCalendar.fromGregorian(DateTime.utc(2026, 11, 2)), const BsDate(2083, 7, 16));
  });

  test('official anchor: Baisakh 1 2084 = Wednesday 2027-04-14', () {
    final g = fullCalendar.toGregorian(const BsDate(2084, 1, 1));
    expect(g, DateTime.utc(2027, 4, 14));
    expect(g.weekday, DateTime.wednesday);
  });

  test('known real-world anchors match the chain', () {
    expect(fullCalendar.baisakh1(2081), DateTime.utc(2024, 4, 13));
    expect(fullCalendar.baisakh1(2082), DateTime.utc(2025, 4, 14));
    expect(fullCalendar.baisakh1(2083), DateTime.utc(2026, 4, 14));
  });

  test('all core invariants hold', () {
    expect(validateCore(coreCalendar), isEmpty);
  });

  test('tail has exactly one known defect (BS 2096 = 364 days)', () {
    final violations = validateTail(coreCalendar, tailCalendar);
    expect(violations.where((v) => !v.knownDefect), isEmpty);
    expect(violations.where((v) => v.knownDefect), hasLength(1));
    expect(violations.first.year, 2096);
    expect(violations.first.knownDefect, isTrue);
  });

  test('evidence tags are intact', () {
    expect(coreCalendar.row(2083).evidence, contains('live-2026-11-02'));
    expect(tailCalendar.row(2084).evidence, 'official-anchor');
    expect(tailCalendar.row(2096).evidence, 'projection-defect');
    for (final y in coreCalendar.years) {
      expect(coreCalendar.row(y).evidence, contains('r12-verified'));
    }
  });

  test('every year round-trips through Baisakh 1 and its last day', () {
    for (final cal in [coreCalendar, tailCalendar]) {
      for (final y in cal.years) {
        final b1 = cal.baisakh1(y);
        expect(cal.fromGregorian(b1), BsDate(y, 1, 1));
        final lastLen = cal.monthLength(y, 12);
        final last = cal.toGregorian(BsDate(y, 12, lastLen));
        expect(cal.fromGregorian(last), BsDate(y, 12, lastLen));
      }
    }
  });
}
