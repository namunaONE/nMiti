import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_date_data/nepali_date_data.dart';
import 'package:test/test.dart';

/// The trust machine. The domain is finite - every day from Baisakh 1 of
/// BS 1975 to the end of Chaitra of BS 2100 - so every property can be
/// checked exhaustively instead of sampled. On every CI run this suite
/// round-trip converts every one of the ~46,000 days in BOTH directions
/// and cross-checks every day's weekday by an independent path. Random
/// property-based testing cannot be stronger than testing everything.
void main() {
  final core = coreCalendar;
  final tail = tailCalendar;
  final full = fullCalendar;

  final totalDays = full.rows.fold<int>(0, (sum, row) => sum + row.days);

  test('coverage receipt: verified core BS 1975-2083, projection tail BS 2084-2100', () {
    expect(core.firstYear, 1975);
    expect(core.lastYear, 2083);
    expect(core.years, hasLength(109));
    expect(tail.firstYear, 2084);
    expect(tail.lastYear, 2100);
    expect(tail.years, hasLength(17));
    expect(full.firstYear, 1975);
    expect(full.lastYear, 2100);
  });

  test('structural invariants hold on the real tables; the only flagged year is the labeled BS 2096 defect', () {
    expect(validateCore(core), isEmpty);
    final tailViolations = validateTail(core, tail);
    expect(tailViolations.where((v) => !v.knownDefect), isEmpty);
    final known = tailViolations.where((v) => v.knownDefect).toList();
    expect(known, hasLength(1));
    expect(known.single.year, 2096);
    expect(known.single.code, 'year-length');
    expect(tail.yearLength(2096), 364);
  });

  test('exhaustive BS->AD->BS round-trip: every day of BS 1975-2100', () {
    final failures = <String>[];
    final seenAd = <DateTime>{};
    var swept = 0;
    DateTime? prev;
    for (final y in full.years) {
      final row = full.row(y);
      for (var m = 1; m <= 12; m++) {
        for (var d = 1; d <= row.months[m - 1]; d++) {
          final bs = BsDate(y, m, d);
          final g = full.toGregorian(bs);
          final back = full.fromGregorian(g);
          if (back != bs && failures.length < 10) {
            failures.add('BS ' + bs.toString() + ' -> AD ' + g.toIso8601String() + ' -> BS ' + back.toString());
          }
          if (prev != null && g.difference(prev).inDays != 1 && failures.length < 10) {
            failures.add('non-consecutive AD mapping around BS ' + bs.toString());
          }
          if (!seenAd.add(g) && failures.length < 10) {
            failures.add('AD day mapped twice: ' + g.toIso8601String());
          }
          prev = g;
          swept++;
        }
      }
    }
    expect(failures, isEmpty);
    expect(swept, totalDays);
    expect(seenAd, hasLength(totalDays)); // bijection: distinct BS dates -> distinct AD days
    expect(swept, greaterThan(45000), reason: 'the whole domain is swept, not sampled');
  });

  test('exhaustive AD->BS->AD round-trip: every Gregorian day of the table', () {
    final failures = <String>[];
    final seenBs = <BsDate>{};
    var swept = 0;
    var g = full.toGregorian(BsDate(full.firstYear, 1, 1));
    final lastBsDay = BsDate(full.lastYear, 12, full.row(full.lastYear).months[11]);
    final last = full.toGregorian(lastBsDay);
    while (!g.isAfter(last)) {
      final bs = full.fromGregorian(g);
      final back = full.toGregorian(bs);
      if ((back.year != g.year || back.month != g.month || back.day != g.day) && failures.length < 10) {
        failures.add('AD ' + g.toIso8601String() + ' -> BS ' + bs.toString() + ' -> AD ' + back.toIso8601String());
      }
      if (!seenBs.add(bs) && failures.length < 10) {
        failures.add('BS date visited twice: ' + bs.toString());
      }
      g = g.add(const Duration(days: 1));
      swept++;
    }
    expect(failures, isEmpty);
    expect(swept, totalDays);
    expect(seenBs, hasLength(totalDays)); // bijection, the other direction
  });

  test('weekday cross-check: every day, by an independent path', () {
    // The weekday column says which weekday Baisakh 1 is. Advance with pure
    // day-of-year arithmetic from the table, and compare against the
    // DateTime weekday of the engine's Gregorian mapping - two independent
    // paths to the same fact, for every single day.
    const wdNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final failures = <String>[];
    var checked = 0;
    for (final y in full.years) {
      final row = full.row(y);
      final base = wdNames.indexOf(row.weekday);
      expect(base, greaterThanOrEqualTo(0), reason: 'weekday column must be Mon..Sun, got: ' + row.weekday);
      var doy = 0;
      for (var m = 1; m <= 12; m++) {
        for (var d = 1; d <= row.months[m - 1]; d++) {
          final expected = (base + doy) % 7;
          final g = full.toGregorian(BsDate(y, m, d));
          if (g.weekday - 1 != expected && failures.length < 10) {
            failures.add('BS ' + y.toString() + '-' + m.toString() + '-' + d.toString() + ': table path says ' + wdNames[expected] + ', engine says ' + wdNames[g.weekday - 1]);
          }
          doy++;
          checked++;
        }
      }
    }
    expect(failures, isEmpty);
    expect(checked, greaterThan(45000));
  });

  test('the table edges are exact and beyond them errors are loud, not silent', () {
    final first = full.toGregorian(const BsDate(1975, 1, 1));
    expect(full.fromGregorian(first), const BsDate(1975, 1, 1));
    final chaitra2100 = full.row(2100).months[11];
    final last = full.toGregorian(BsDate(2100, 12, chaitra2100));
    expect(full.fromGregorian(last), BsDate(2100, 12, chaitra2100));
    expect(() => full.fromGregorian(first.subtract(const Duration(days: 1))), throwsArgumentError);
    expect(() => full.fromGregorian(last.add(const Duration(days: 1))), throwsArgumentError);
  });
}
