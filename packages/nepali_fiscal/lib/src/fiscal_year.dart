import 'package:nepali_date/nepali_date.dart';

/// One Nepali fiscal year: Shrawan 1 of [startYear] through the last day of
/// Ashadh of [startYear] + 1. Every boundary is derived from the canonical
/// month-length table; no date here is hardcoded.
class BsFiscalYear {
  /// The BS year in which the fiscal year opens (its Shrawan 1).
  final int startYear;

  /// First day: Shrawan 1 of [startYear].
  final BsDate startBs;

  /// Last day: the final day of Ashadh of the closing year.
  final BsDate endBs;

  /// [startBs] in Gregorian (UTC).
  final DateTime startAd;

  /// [endBs] in Gregorian (UTC).
  final DateTime endAd;

  /// Total days in the fiscal year (365 or 366), summed from month lengths.
  final int days;

  /// The two spanned years' evidence combined, derived by the same
  /// deterministic rule as [BsEvidence.fromTags] - never guessed upward.
  final BsEvidence evidence;

  /// Evidence of the opening year (the Shrawan row).
  final BsEvidence startEvidence;

  /// Evidence of the closing year (the Ashadh row).
  final BsEvidence endEvidence;

  const BsFiscalYear._({
    required this.startYear,
    required this.startBs,
    required this.endBs,
    required this.startAd,
    required this.endAd,
    required this.days,
    required this.evidence,
    required this.startEvidence,
    required this.endEvidence,
  });

  /// The BS year the fiscal year closes in (its Ashadh is the last month).
  int get endYear => startYear + 1;

  /// '2083/84' style label (two-digit tail, the Nepali convention).
  String get labelBs => '${startYear}/${_pad2(endYear % 100)}';

  /// '2026/27' style Gregorian label of the covered AD years.
  String get labelAd => '${startAd.year}/${_pad2(endAd.year % 100)}';

  @override
  String toString() =>
      'BsFiscalYear(${labelBs}: ${_iso(startAd)}..${_iso(endAd)}, '
      '$days days, ${evidence.tier.name})';
}

/// Fiscal-year surfaces over a loaded [BsCalendar]. Pure derivation, no IO,
/// no hardcoded dates: Shrawan 1 opens the year, the last day of Ashadh
/// closes it, and any fiscal span not fully inside the table fails loudly.
class BsFiscalCalendar {
  final BsCalendar _calendar;

  const BsFiscalCalendar(this._calendar);

  /// The fiscal year opening in Shrawan of [startYear]. Requires both
  /// [startYear] and its successor in the table; throws the same
  /// tier-aware range [ArgumentError] as [BsCalendar.row] otherwise.
  BsFiscalYear byStartYear(int startYear) {
    final startRow = _calendar.row(startYear);
    final endRow = _calendar.row(startYear + 1);
    final startBs = BsDate(startYear, 4, 1);
    final endBs = BsDate(startYear + 1, 3, endRow.months[2]);
    var days = 0;
    for (var m = 3; m < 12; m++) {
      days += startRow.months[m]; // Shrawan..Chaitra of the opening year.
    }
    for (var m = 0; m < 3; m++) {
      days += endRow.months[m]; // Baisakh..Ashadh of the closing year.
    }
    return BsFiscalYear._(
      startYear: startYear,
      startBs: startBs,
      endBs: endBs,
      startAd: _calendar.toGregorian(startBs),
      endAd: _calendar.toGregorian(endBs),
      days: days,
      evidence: BsEvidence.fromTags('${startRow.evidence},${endRow.evidence}'),
      startEvidence: BsEvidence.fromTags(startRow.evidence),
      endEvidence: BsEvidence.fromTags(endRow.evidence),
    );
  }

  /// The fiscal year a BS date belongs to. The date itself is validated with
  /// exactly the same rules as [BsCalendar.toGregorian]; dates whose fiscal
  /// span is not fully covered by the table fail loudly instead of guessing.
  BsFiscalYear fiscalYearOf(BsDate date) {
    // Validation only: the fiscal tier is about the span years, so the
    // date's own evidence result is intentionally unused.
    _calendar.evidenceOf(date);
    return byStartYear(date.month >= 4 ? date.year : date.year - 1);
  }
}

String _pad2(int value) => value < 10 ? '0$value' : '$value';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}';
