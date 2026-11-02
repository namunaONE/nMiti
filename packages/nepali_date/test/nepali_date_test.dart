import 'package:nepali_date/nepali_date.dart';
import 'package:test/test.dart';

const _miniCsv = '''
# provenance comment
bs_year,baisakh1,weekday,baisakh,jestha,ashar,shrawan,bhadra,asoj,kartik,mangsir,poush,magh,falgun,chaitra,days,evidence
2081,2024-04-13,Sat,31,32,31,32,31,30,30,30,29,30,29,31,366,r12-verified
2082,2025-04-14,Mon,31,31,32,31,31,31,30,29,30,29,30,30,365,r12-verified
2083,2026-04-14,Tue,31,31,32,31,31,31,30,29,30,29,30,30,365,r12-verified
2084,2027-04-14,Wed,31,31,32,31,31,30,30,30,29,30,30,30,365,official-anchor
2085,2028-04-13,Thu,31,32,31,32,30,31,30,30,29,30,30,30,366,projection
''';

const _identicalRunCsv = '''
bs_year,baisakh1,weekday,baisakh,jestha,ashar,shrawan,bhadra,asoj,kartik,mangsir,poush,magh,falgun,chaitra,days,evidence
2081,2024-04-14,Sun,31,31,32,31,31,31,30,29,30,29,30,30,365,r12-verified
2082,2025-04-14,Mon,31,31,32,31,31,31,30,29,30,29,30,30,365,r12-verified
2083,2026-04-14,Tue,31,31,32,31,31,31,30,29,30,29,30,30,365,r12-verified
''';

BsYearRow withMonths(BsYearRow r, List<int> months) => BsYearRow(
      year: r.year,
      baisakh1: r.baisakh1,
      weekday: r.weekday,
      months: months,
      days: months.fold<int>(0, (a, b) => a + b),
      evidence: r.evidence,
    );

void main() {
  final cal = BsCalendar.fromCsv(_miniCsv);
  final allRows = parseBsCalendarCsv(_miniCsv);
  final core = BsCalendar(allRows.where((r) => r.year <= 2083));
  final tail = BsCalendar(allRows.where((r) => r.year >= 2084));

  test('parses rows and skips comments and header', () {
    expect(cal.years, [2081, 2082, 2083, 2084, 2085]);
    expect(cal.firstYear, 2081);
    expect(cal.lastYear, 2085);
  });

  test('parses multi-tag evidence columns (commas inside the last field)', () {
    const csv = 'bs_year,baisakh1,weekday,baisakh,jestha,ashar,shrawan,bhadra,asoj,kartik,mangsir,poush,magh,falgun,chaitra,days,evidence\n'
        '2083,2026-04-14,Tue,31,31,32,31,31,31,30,29,30,29,30,30,365,r12-verified,live-2026-11-02\n';
    final rows = parseBsCalendarCsv(csv);
    expect(rows, hasLength(1));
    expect(rows.first.evidence, 'r12-verified,live-2026-11-02');
    expect(rows.first.days, 365);
    expect(rows.first.months, hasLength(12));
  });

  test('rejects non-contiguous years', () {
    expect(() => BsCalendar(allRows.where((r) => r.year != 2083)), throwsArgumentError);
  });

  test('month and year lengths', () {
    expect(cal.monthLength(2081, 2), 32);
    expect(cal.yearLength(2082), 365);
    expect(() => cal.monthLength(2081, 13), throwsArgumentError);
  });

  test('BS -> AD: Kartik 16, 2083 is 2026-11-02', () {
    expect(cal.toGregorian(const BsDate(2083, 7, 16)), DateTime.utc(2026, 11, 2));
  });

  test('AD -> BS: 2026-11-02 is Kartik 16, 2083', () {
    expect(cal.fromGregorian(DateTime.utc(2026, 11, 2)), const BsDate(2083, 7, 16));
  });

  test('last day of a year converts back', () {
    expect(cal.fromGregorian(DateTime.utc(2026, 4, 13)), const BsDate(2082, 12, 30));
  });

  test('range errors are loud, not silent', () {
    expect(() => cal.fromGregorian(DateTime.utc(1900, 1, 1)), throwsArgumentError);
    expect(() => cal.fromGregorian(DateTime.utc(2100, 1, 1)), throwsArgumentError);
    expect(() => cal.toGregorian(const BsDate(2083, 7, 31)), throwsArgumentError);
  });

  test('invariants hold on the mini table', () {
    expect(validateCore(core), isEmpty);
    expect(validateTail(core, tail).where((v) => !v.knownDefect), isEmpty);
  });

  test('detects a broken month bound', () {
    final planted = core.rows
        .map((r) => r.year == 2082 ? withMonths(r, [28, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30]) : r)
        .toList();
    final codes = validateCore(BsCalendar(planted)).map((v) => v.code).toSet();
    expect(codes, contains('month-bounds'));
  });

  test('detects a 364-day year', () {
    final planted = core.rows
        .map((r) => r.year == 2082
            ? withMonths(r, [30, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30])
            : r)
        .toList();
    final codes = validateCore(BsCalendar(planted)).map((v) => v.code).toSet();
    expect(codes, contains('year-length'));
  });

  test('detects a broken anchor chain', () {
    final planted = core.rows.map((r) => r.year == 2083 ? _shifted(r) : r).toList();
    final codes = validateCore(BsCalendar(planted)).map((v) => v.code).toSet();
    expect(codes, contains('anchor-chain'));
  });

  test('detects three identical consecutive rows', () {
    final codes = validateCore(BsCalendar.fromCsv(_identicalRunCsv)).map((v) => v.code).toSet();
    expect(codes, contains('identical-run'));
  });

  test('flags a known tail defect without failing the build', () {
    final plantedTail = BsCalendar(tail.rows
        .map((r) => r.year == 2084
            ? withMonths(r, [30, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30])
            : r)
        .toList());
    final known = validateTail(core, plantedTail, knownDefectYears: {2084});
    expect(known.where((v) => v.knownDefect), hasLength(1));
    final unknown = validateTail(core, plantedTail, knownDefectYears: {});
    expect(unknown.where((v) => !v.knownDefect).map((v) => v.code), contains('year-length'));
  });

  test('tail must chain from the core boundary', () {
    final wrongStart = BsCalendar(parseBsCalendarCsv(_miniCsv).where((r) => r.year >= 2085));
    expect(
      validateTail(core, wrongStart).map((v) => v.code),
      contains('boundary'),
    );
  });

  test('Nepali digits and month names', () {
    expect(toNepaliDigits('2083'), '२०८३');
    expect(bsMonthNameEn(7), 'Kartik');
    expect(bsMonthNameNp(7), 'कात्तिक');
    expect(() => bsMonthNameEn(13), throwsArgumentError);
  });
}

BsYearRow _shifted(BsYearRow r) => BsYearRow(
      year: r.year,
      baisakh1: r.baisakh1.add(const Duration(days: 1)),
      weekday: r.weekday,
      months: r.months,
      days: r.days,
      evidence: r.evidence,
    );
