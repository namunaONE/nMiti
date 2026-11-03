import 'dart:convert';

/// One published Commons Layer 1 moment: a row of the R5 artifact.
class SankrantiMoment {
  final int bsYear;

  /// 1..12. Month 1 is Baisakh, the Mesha sankranti.
  final int monthNo;
  final String month;
  final String rashi;

  /// The ingress instant (UTC), parsed from the NPT timestamp.
  final DateTime utc;
  final String weekday;

  /// 0 = the BS month starts on the ingress date, 1 = the next day,
  /// -1 = before the ingress date: the 24 cataloged pre-1980 rows.
  final int delta;
  final String evidence;

  const SankrantiMoment({
    required this.bsYear,
    required this.monthNo,
    required this.month,
    required this.rashi,
    required this.utc,
    required this.weekday,
    required this.delta,
    required this.evidence,
  });
}

/// Parses the Commons Layer 1 artifact CSV whose columns are
/// bs_year, month_no, month, rashi, sankranti_npt, weekday,
/// starts_on_delta, evidence. Lines starting with a hash are provenance
/// comments and are skipped; the bs_year line is the header. The
/// sankranti_npt timestamps carry the explicit +05:45 Nepal Time offset.
List<SankrantiMoment> parseSankrantiMomentsCsv(String csv) {
  final rows = <SankrantiMoment>[];
  for (final rawLine in const LineSplitter().convert(csv)) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final cols = line.split(',');
    if (cols[0] == 'bs_year') continue;
    if (cols.length < 8) {
      throw FormatException('Expected 8 columns, got ' +
          cols.length.toString() +
          ': "' +
          line +
          '"');
    }
    rows.add(SankrantiMoment(
      bsYear: int.parse(cols[0]),
      monthNo: int.parse(cols[1]),
      month: cols[2],
      rashi: cols[3],
      utc: DateTime.parse(cols[4]).toUtc(),
      weekday: cols[5],
      delta: int.parse(cols[6]),
      evidence: cols.sublist(7).join(','),
    ));
  }
  return rows;
}
