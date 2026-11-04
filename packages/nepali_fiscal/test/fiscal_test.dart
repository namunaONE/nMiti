import 'dart:io';

import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_fiscal/nepali_fiscal.dart';
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
  final calendar = BsCalendar([
    ...parseBsCalendarCsv(core),
    ...parseBsCalendarCsv(tail),
  ]);
  final fiscal = BsFiscalCalendar(calendar);

  test('FY 2083/84: Shrawan 1 2083 -> Ashadh end 2084, all boundaries derived', () {
    final f = fiscal.byStartYear(2083);
    expect(f.startYear, 2083);
    expect(f.endYear, 2084);
    expect(f.startBs, const BsDate(2083, 4, 1));
    expect(f.startAd, DateTime.utc(2026, 7, 17));
    expect(f.endBs, const BsDate(2084, 3, 32)); // Ashadh 2084 has 32 days.
    expect(f.endAd, DateTime.utc(2027, 7, 16));
    expect(f.days, 365);
    expect(f.labelBs, '2083/84');
    expect(f.labelAd, '2026/27');
    expect(f.evidence.tier, BsEvidenceTier.verified);
  });

  test('tier asymmetry: FY 2084/85 starts verified but never claims more than projection', () {
    final f = fiscal.byStartYear(2084);
    expect(f.startEvidence.tier, BsEvidenceTier.verified); // official-anchor
    expect(f.endEvidence.tier, BsEvidenceTier.projection); // 2085 projection
    expect(f.evidence.tier, BsEvidenceTier.projection); // never guessed upward
    // The opening boundary itself is still officially anchored; only the
    // year-long span drops to projection honesty.
    expect(
        calendar.evidenceOf(const BsDate(2084, 4, 1)).tier, BsEvidenceTier.verified);
    expect(f.startAd, DateTime.utc(2027, 7, 17));
    expect(f.endAd, DateTime.utc(2028, 7, 15));
    expect(f.days, 365);
  });

  test('FY 2095/96 carries the projection-defect label of its end year', () {
    final f = fiscal.byStartYear(2095);
    expect(f.endBs, const BsDate(2096, 3, 32)); // Ashadh 2096 has 32 days.
    expect(f.evidence.tier, BsEvidenceTier.projectionDefect);
    expect(f.days, 365); // the defect day lies outside the fiscal span
  });

  test('stress wall: every FY in the loaded table derives consistently', () {
    for (var fy = 1975; fy <= 2099; fy++) {
      final f = fiscal.byStartYear(fy);
      final adSpan = f.endAd.difference(f.startAd).inDays + 1;
      expect(f.days, adSpan, reason: 'FY $fy: month-sum != AD-span');
      expect(f.days, anyOf(365, 366), reason: 'FY $fy: length');
      expect(f.startBs, BsDate(fy, 4, 1), reason: 'FY $fy: start');
      expect(f.endBs, BsDate(fy + 1, 3, calendar.monthLength(fy + 1, 3)),
          reason: 'FY $fy: end');
      // Membership: opening day, mid-year, and the closing Ashadh day all
      // map back to this fiscal year.
      expect(fiscal.fiscalYearOf(BsDate(fy, 4, 1)).startYear, fy,
          reason: 'FY $fy: Shrawan 1 membership');
      expect(fiscal.fiscalYearOf(BsDate(fy, 10, 15)).startYear, fy,
          reason: 'FY $fy: mid-year membership');
      expect(fiscal.fiscalYearOf(f.endBs).startYear, fy,
          reason: 'FY $fy: closing-day membership');
      // The label spans exactly the two BS years.
      expect(f.labelBs, '$fy/${((fy + 1) % 100).toString().padLeft(2, '0')}',
          reason: 'FY $fy: label');
    }
  });

  test('Baisakh-Jestha-Ashadh belong to the previous fiscal year', () {
    expect(fiscal.fiscalYearOf(const BsDate(2083, 1, 1)).labelBs, '2082/83');
    expect(fiscal.fiscalYearOf(const BsDate(2083, 3, 32)).labelBs, '2082/83');
    expect(fiscal.fiscalYearOf(const BsDate(2083, 3, 32)).startAd,
        DateTime.utc(2025, 7, 17));
    expect(fiscal.fiscalYearOf(const BsDate(2083, 4, 1)).labelBs, '2083/84');
    // Ship-day pin: today, Kartik 18 2083, sits inside FY 2083/84.
    final f = fiscal.fiscalYearOf(const BsDate(2083, 7, 18));
    expect(f.labelBs, '2083/84');
    expect(f.startAd, DateTime.utc(2026, 7, 17));
  });

  test('labels roll over correctly at the BS century edge', () {
    final f = fiscal.byStartYear(2099);
    expect(f.labelBs, '2099/00');
    expect(f.labelAd, '2042/43');
    expect(f.endBs, const BsDate(2100, 3, 31)); // Ashadh 2100 has 31 days.
    expect(f.endAd, DateTime.utc(2043, 7, 16));
    expect(f.days, 365);
  });

  test('fiscal spans beyond the table fail loudly, naming year and range', () {
    expect(
      () => fiscal.byStartYear(2100), // needs BS 2101
      throwsA(isA<ArgumentError>().having((e) => e.message.toString(),
          'message',
          allOf(contains('2101'), contains('outside the declared range'),
              contains('instead of guessing')))),
    );
    expect(() => fiscal.byStartYear(1974), throwsArgumentError); // BS 1974
    expect(() => fiscal.fiscalYearOf(const BsDate(2100, 4, 1)),
        throwsArgumentError); // its FY would need 2101
    expect(() => fiscal.fiscalYearOf(const BsDate(1975, 1, 1)),
        throwsArgumentError); // its FY would need 1974
    // Invalid dates are rejected by the same rules as toGregorian.
    expect(() => fiscal.fiscalYearOf(const BsDate(2083, 7, 31)),
        throwsArgumentError); // Kartik 2083 has 30 days
  });
}
