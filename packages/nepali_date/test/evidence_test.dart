import 'package:nepali_date/nepali_date.dart';
import 'package:test/test.dart';

/// Real rows from the canonical CSVs: the live-tagged core boundary (2083),
/// the officially anchored tail start (2084), and a plain projection row (2085).
const _boundaryCsv = '''
bs_year,baisakh1,weekday,baisakh,jestha,ashar,shrawan,bhadra,asoj,kartik,mangsir,poush,magh,falgun,chaitra,days,evidence
2083,2026-04-14,Tue,31,31,32,31,31,31,30,29,30,29,30,30,365,r12-verified,live-2026-11-02
2084,2027-04-14,Wed,31,31,32,31,31,30,30,30,29,30,30,30,365,official-anchor
2085,2028-04-13,Thu,31,32,31,32,30,31,30,30,29,30,30,30,366,projection
''';

/// The labeled upstream defect row (BS 2096, 364 days) with its neighbors.
const _defectCsv = '''
bs_year,baisakh1,weekday,baisakh,jestha,ashar,shrawan,bhadra,asoj,kartik,mangsir,poush,magh,falgun,chaitra,days,evidence
2094,2037-04-14,Tue,31,31,32,31,31,31,30,29,30,30,30,365,projection
2095,2038-04-14,Wed,31,31,32,31,31,31,30,29,30,30,30,30,366,projection
2096,2039-04-15,Fri,30,31,32,32,31,30,30,29,30,29,30,30,364,projection-defect
''';

void main() {
  final cal = BsCalendar.fromCsv(_boundaryCsv);
  final defect = BsCalendar.fromCsv(_defectCsv);

  test('tier derivation follows the tag vocabulary, never guesses upward', () {
    expect(BsEvidence.fromTags('r12-verified').tier, BsEvidenceTier.verified);
    expect(BsEvidence.fromTags('r12-verified,live-2026-11-02').tier, BsEvidenceTier.verified);
    expect(BsEvidence.fromTags('r12-verified,disputed-resolved').tier, BsEvidenceTier.verified);
    expect(BsEvidence.fromTags('official-anchor').tier, BsEvidenceTier.verified);
    expect(BsEvidence.fromTags('projection').tier, BsEvidenceTier.projection);
    expect(BsEvidence.fromTags('projection-defect').tier, BsEvidenceTier.projectionDefect);
    expect(BsEvidence.fromTags('some-future-tag').tier, BsEvidenceTier.unknown);
    expect(BsEvidence.fromTags('').tier, BsEvidenceTier.unknown);
  });

  test('evidence keeps raw tags verbatim and supports tag lookup', () {
    final e = BsEvidence.fromTags('r12-verified,disputed-resolved');
    expect(e.tags, 'r12-verified,disputed-resolved');
    expect(e.hasTag('Disputed-Resolved'), isTrue);
    expect(e.hasTag('live-2026-11-02'), isFalse);
  });

  test('calendar evidence per year: verified core, official anchor, projection tail', () {
    expect(cal.evidenceOfYear(2083).tier, BsEvidenceTier.verified);
    expect(cal.evidenceOfYear(2083).hasTag('live-2026-11-02'), isTrue);
    expect(cal.evidenceOfYear(2084).tier, BsEvidenceTier.verified);
    expect(cal.evidenceOfYear(2085).tier, BsEvidenceTier.projection);
    expect(defect.evidenceOfYear(2096).tier, BsEvidenceTier.projectionDefect);
    expect(() => cal.evidenceOfYear(2101), throwsArgumentError);
  });

  test('evidence per date validates exactly like toGregorian (all 4 rejection classes)', () {
    expect(cal.evidenceOf(const BsDate(2083, 7, 18)).tier, BsEvidenceTier.verified);
    expect(cal.evidenceOf(const BsDate(2085, 1, 1)).tier, BsEvidenceTier.projection);
    expect(() => cal.evidenceOf(const BsDate(2083, 0, 1)), throwsArgumentError);
    expect(() => cal.evidenceOf(const BsDate(2083, 13, 1)), throwsArgumentError);
    expect(() => cal.evidenceOf(const BsDate(2083, 7, 0)), throwsArgumentError);
    // Kartik 2083 has 30 days.
    expect(() => cal.evidenceOf(const BsDate(2083, 7, 31)), throwsArgumentError);
  });

  test('range errors are tier-aware and name the declared range', () {
    expect(
      () => cal.toGregorian(const BsDate(2101, 1, 1)),
      throwsA(isA<ArgumentError>().having((e) => e.message.toString(), 'message',
          allOf(contains('2083..2085'), contains('instead of guessing')))),
    );
    expect(
      () => cal.fromGregorian(DateTime.utc(1918, 4, 12)),
      throwsA(isA<ArgumentError>().having((e) => e.message.toString(), 'message',
          allOf(contains('2026-04-14'), contains('never converts outside')))),
    );
    expect(
      () => cal.fromGregorian(DateTime.utc(2029, 4, 14)),
      throwsA(isA<ArgumentError>().having((e) => e.message.toString(), 'message',
          allOf(contains('2029-04-12'), contains('never converts outside')))),
    );
  });

  test('conversion behavior is unchanged (regression pins)', () {
    // Ship-day pin: Kartik 18, 2083 = 2026-11-04 (matches the live today.json).
    expect(cal.toGregorian(const BsDate(2083, 7, 18)), DateTime.utc(2026, 11, 4));
    expect(cal.fromGregorian(DateTime.utc(2026, 11, 4)), const BsDate(2083, 7, 18));
    // Fiscal opening pin: Shrawan 1, 2083 = 2026-07-17 (FY 2083/84 starts).
    expect(cal.toGregorian(const BsDate(2083, 4, 1)), DateTime.utc(2026, 7, 17));
    expect(cal.fromGregorian(DateTime.utc(2026, 7, 17)), const BsDate(2083, 4, 1));
    // Projection tail still converts: Baisakh 1, 2085 = 2028-04-13.
    expect(cal.toGregorian(const BsDate(2085, 1, 1)), DateTime.utc(2028, 4, 13));
  });

  test('projection-defect year keeps its label and still converts', () {
    expect(defect.yearLength(2096), 364);
    expect(defect.evidenceOf(const BsDate(2096, 12, 30)).tier, BsEvidenceTier.projectionDefect);
    expect(defect.toGregorian(const BsDate(2096, 12, 30)), DateTime.utc(2040, 4, 12));
  });
}
