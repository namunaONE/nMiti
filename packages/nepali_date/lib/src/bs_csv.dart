import 'dart:convert';

/// One parsed row of the canonical nMiti Bikram Sambat calendar CSV.
class BsYearRow {
  final int year;

  /// Gregorian (UTC) date of Baisakh 1.
  final DateTime baisakh1;

  /// Weekday of Baisakh 1 (Mon..Sun). Redundant with [baisakh1]; kept as a check.
  final String weekday;

  /// Days in each BS month, index 0 = Baisakh.
  final List<int> months;

  /// Total days in the BS year.
  final int days;

  /// Comma-separated evidence tags (see data/README.md).
  final String evidence;

  const BsYearRow({
    required this.year,
    required this.baisakh1,
    required this.weekday,
    required this.months,
    required this.days,
    required this.evidence,
  });

  int get yearLength => days;

  int monthLength(int month) => months[month - 1];
}

/// Parses the canonical nMiti CSV format:
///
///     bs_year,baisakh1,weekday,<12 month lengths>,days,evidence
///
/// Lines starting with '#' are provenance comments and are skipped.
/// The evidence column is last and may itself contain commas
/// (comma-separated tags, e.g. "r12-verified,live-2026-11-02").
/// All dates are parsed as UTC dates.
List<BsYearRow> parseBsCalendarCsv(String csv) {
  final rows = <BsYearRow>[];
  for (final line in const LineSplitter().convert(csv)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final cols = trimmed.split(',');
    if (cols[0] == 'bs_year') continue; // header row
    if (cols.length < 17) {
      throw FormatException('Expected at least 17 columns, got ${cols.length}: "$trimmed"');
    }
    final year = int.parse(cols[0]);
    final baisakh1 = _parseIsoDate(cols[1]);
    final months = <int>[for (var i = 3; i <= 14; i++) int.parse(cols[i])];
    rows.add(BsYearRow(
      year: year,
      baisakh1: baisakh1,
      weekday: cols[2],
      months: months,
      days: int.parse(cols[15]),
      // The evidence column is last; multi-tag rows (e.g. 1989, 2083 in
      // the core) legitimately carry more than 17 raw comma-separated fields.
      evidence: cols.sublist(16).join(','),
    ));
  }
  rows.sort((a, b) => a.year.compareTo(b.year));
  return rows;
}

DateTime _parseIsoDate(String text) {
  final parts = text.split('-');
  if (parts.length != 3) {
    throw FormatException('Expected an ISO date (yyyy-mm-dd), got "$text"');
  }
  return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}
