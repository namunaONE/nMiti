import 'bs_csv.dart';
import 'bs_date.dart';
import 'evidence.dart';

/// An immutable table of contiguous BS years with month lengths and anchors.
class BsCalendar {
  final List<BsYearRow> _rows;
  final Map<int, BsYearRow> _byYear;
  final List<int> _years;
  final List<DateTime> _starts;

  BsCalendar._(this._rows, this._byYear, this._years, this._starts);

  factory BsCalendar(Iterable<BsYearRow> rows) {
    final sorted = [...rows]..sort((a, b) => a.year.compareTo(b.year));
    if (sorted.isEmpty) {
      throw ArgumentError('A calendar needs at least one year.');
    }
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].year - sorted[i - 1].year;
      if (gap == 0) {
        throw ArgumentError('Duplicate BS year ${sorted[i].year}.');
      }
      if (gap != 1) {
        throw ArgumentError(
            'BS years must be contiguous; gap between ${sorted[i - 1].year} and ${sorted[i].year}.');
      }
    }
    final byYear = <int, BsYearRow>{for (final r in sorted) r.year: r};
    final years = <int>[for (final r in sorted) r.year];
    final starts = <DateTime>[for (final r in sorted) _utcDateOnly(r.baisakh1)];
    return BsCalendar._(sorted, byYear, years, starts);
  }

  factory BsCalendar.fromCsv(String csv) => BsCalendar(parseBsCalendarCsv(csv));

  /// All rows, sorted by year.
  List<BsYearRow> get rows => List.unmodifiable(_rows);

  /// All BS years, sorted.
  List<int> get years => List.unmodifiable(_years);

  int get firstYear => _years.first;

  int get lastYear => _years.last;

  bool containsYear(int year) => _byYear.containsKey(year);

  /// The evidence tier and raw tags of BS [year], taken from its row so
  /// surfaces never re-derive tiers from year numbers. Throws
  /// [ArgumentError] outside the table, exactly like [row].
  BsEvidence evidenceOfYear(int year) => BsEvidence.fromTags(row(year).evidence);

  /// The evidence tier and raw tags for the BS [date]. The date is validated
  /// exactly like [toGregorian], so evidence is never reported for a date the
  /// calendar cannot convert.
  BsEvidence evidenceOf(BsDate date) {
    final r = row(date.year);
    if (date.month < 1 || date.month > 12) {
      throw ArgumentError('BS month must be 1..12, got ${date.month}.');
    }
    final length = r.months[date.month - 1];
    if (date.day < 1 || date.day > length) {
      throw ArgumentError(
          'BS ${date.year} month ${date.month} has $length days, got day ${date.day}.');
    }
    return BsEvidence.fromTags(r.evidence);
  }

  /// The row for BS [year]. Throws [ArgumentError] if outside the table.
  BsYearRow row(int year) {
    final r = _byYear[year];
    if (r == null) {
      throw ArgumentError(
          'BS year $year is outside the declared range $firstYear..$lastYear. '
          'Rows are evidence-tagged (verified or projection, see data/README.md); '
          'beyond the table nMiti fails loudly instead of guessing.');
    }
    return r;
  }

  /// Days in [month] (1-12) of BS [year].
  int monthLength(int year, int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError('BS month must be 1..12, got $month.');
    }
    return row(year).months[month - 1];
  }

  /// Total days in BS [year].
  int yearLength(int year) => row(year).days;

  /// Gregorian (UTC) date of Baisakh 1 of BS [year].
  DateTime baisakh1(int year) => _utcDateOnly(row(year).baisakh1);

  /// Converts a BS date to its Gregorian (UTC) equivalent.
  DateTime toGregorian(BsDate date) {
    final r = row(date.year);
    if (date.month < 1 || date.month > 12) {
      throw ArgumentError('BS month must be 1..12, got ${date.month}.');
    }
    final length = r.months[date.month - 1];
    if (date.day < 1 || date.day > length) {
      throw ArgumentError(
          'BS ${date.year} month ${date.month} has $length days, got day ${date.day}.');
    }
    var offset = date.day - 1;
    for (var m = 0; m < date.month - 1; m++) {
      offset += r.months[m];
    }
    return baisakh1(date.year).add(Duration(days: offset));
  }

  /// Converts a Gregorian date to the BS calendar. Uses the calendar day as
  /// written (UTC fields if [g] is UTC, local fields otherwise).
  BsDate fromGregorian(DateTime g) {
    final t = _utcDateOnly(g);
    if (t.isBefore(_starts.first)) {
      throw ArgumentError(
          'Gregorian date ${_iso(t)} is before the first day of the table '
          '(Baisakh 1, BS $firstYear = ${_iso(_starts.first)}). '
          'nMiti never converts outside the declared range.');
    }
    final limit = _starts.last.add(Duration(days: _rows.last.days));
    if (!t.isBefore(limit)) {
      final lastDay = _starts.last.add(Duration(days: _rows.last.days - 1));
      throw ArgumentError(
          'Gregorian date ${_iso(t)} is after the last day of the table '
          '(Chaitra end, BS $lastYear = ${_iso(lastDay)}). '
          'nMiti never converts outside the declared range.');
    }
    var lo = 0;
    var hi = _starts.length - 1;
    var idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (!_starts[mid].isAfter(t)) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    final row = _rows[idx];
    var dayOfYear = t.difference(_starts[idx]).inDays + 1;
    var month = 1;
    var day = dayOfYear;
    for (final length in row.months) {
      if (day <= length) break;
      day -= length;
      month++;
    }
    return BsDate(row.year, month, day);
  }
}

DateTime _utcDateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

String _iso(DateTime d) => '${_pad4(d.year)}-${_pad2(d.month)}-${_pad2(d.day)}';

String _pad2(int value) => value < 10 ? '0$value' : '$value';

String _pad4(int value) => value.toString().padLeft(4, '0');
