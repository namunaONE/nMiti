import 'dart:io';

import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_sankranti/nepali_sankranti.dart';
import 'package:test/test.dart';

File _find(String rel) {
  for (final path in [rel, '../../' + rel]) {
    final f = File(path);
    if (f.existsSync()) return f;
  }
  throw StateError('Required data file not found: ' + rel);
}

void main() {
  final core = _find('data/calendar_bs_core_1975_2083.csv').readAsStringSync();
  final tail = _find('data/calendar_bs_tail_2084_2100.csv').readAsStringSync();
  final table = parseSankrantiTableCsv(
      _find('data/sankranti_moments_1975_2100.csv').readAsStringSync());
  final calendar = BsCalendar([
    ...parseBsCalendarCsv(core),
    ...parseBsCalendarCsv(tail),
  ]);

  test('WINDOW LAW (HYA-358): zero violations across the verified core', () {
    final violations =
        checkSankrantiWindows(calendar, table).where((v) => v.bsYear <= 2083);
    expect(violations, isEmpty);
  });

  test('tail projection: exactly the six pinned window defects', () {
    final violations =
        checkSankrantiWindows(calendar, table).map((v) => v.key).toSet();
    expect(violations, kProjectionWindowDefects);
  });

  test('BS 2096 (364-day projection defect) keeps every sankranti window', () {
    final y2096 = table.where((r) => r.bsYear == 2096).toList();
    expect(y2096, hasLength(12));
    for (final r in y2096) {
      expect(r.startsOnDelta, inInclusiveRange(0, 1));
    }
  });

  test('planted-defect demo: Baisakh 1 2084 shifted a day earlier must fail', () {
    final modified = calendar.rows.map((r) {
      if (r.year != 2084) return r;
      return BsYearRow(
        year: 2084,
        baisakh1: r.baisakh1.subtract(const Duration(days: 1)),
        weekday: r.weekday,
        months: r.months,
        days: r.days,
        evidence: r.evidence,
      );
    }).toList();
    final violations =
        checkSankrantiWindows(BsCalendar(modified), table).map((v) => v.key);
    expect(violations, contains('2084-3'));
  });
}
