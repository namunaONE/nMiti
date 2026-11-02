/// A single invariant violation found in calendar data.
class InvariantViolation {
  final String code;
  final int year;
  final String message;

  /// True for preserved, labeled upstream defects in the projection tail
  /// (for example BS 2096 = 364 days). Known defects are reported but do not
  /// fail the build; unknown ones do.
  final bool knownDefect;

  const InvariantViolation({
    required this.code,
    required this.year,
    required this.message,
    this.knownDefect = false,
  });

  @override
  String toString() =>
      '${knownDefect ? 'KNOWN DEFECT' : 'VIOLATION'} [$code] BS $year: $message';
}

/// BS years in the projection tail with a known, preserved upstream defect.
const Set<int> knownTailDefectYears = {2096};

const List<String> _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _weekdayOf(DateTime d) => _weekdayNames[d.weekday - 1];

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameMonths(List<int> a, List<int> b) {
  for (var i = 0; i < 12; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void _checkRow(BsCalendar cal, int y, List<InvariantViolation> out) {
  final row = cal.row(y);
  for (var m = 0; m < 12; m++) {
    final length = row.months[m];
    if (length < 29 || length > 32) {
      out.add(InvariantViolation(
        code: 'month-bounds',
        year: y,
        message: 'month ${m + 1} has $length days (expected 29..32).',
      ));
    }
  }
  final sum = row.months.fold<int>(0, (a, b) => a + b);
  if (sum != row.days) {
    out.add(InvariantViolation(
      code: 'days-mismatch',
      year: y,
      message: 'days column says ${row.days} but months sum to $sum.',
    ));
  }
  final b1 = cal.baisakh1(y);
  if (b1.month != 4 || b1.day < 11 || b1.day > 15) {
    out.add(InvariantViolation(
      code: 'baisakh1-window',
      year: y,
      message: 'Baisakh 1 falls on ${b1.year}-${b1.month}-${b1.day} (expected Apr 11..15).',
    ));
  }
  final weekday = _weekdayOf(b1);
  if (weekday != row.weekday) {
    out.add(InvariantViolation(
      code: 'weekday-mismatch',
      year: y,
      message: 'weekday column says ${row.weekday} but Baisakh 1 is a $weekday.',
    ));
  }
}

void _checkChain(BsCalendar cal, List<InvariantViolation> out) {
  for (var i = 1; i < cal.years.length; i++) {
    final prev = cal.row(cal.years[i - 1]);
    final cur = cal.row(cal.years[i]);
    final expected = cal.baisakh1(prev.year).add(Duration(days: prev.days));
    if (!_sameDate(expected, cal.baisakh1(cur.year))) {
      out.add(InvariantViolation(
        code: 'anchor-chain',
        year: cur.year,
        message: 'Baisakh 1 should be ${expected.year}-${expected.month}-${expected.day} '
            '(previous year ${prev.year} has ${prev.days} days).',
      ));
    }
  }
}

void _checkYearLength(BsCalendar cal, int y, List<InvariantViolation> out,
    {Set<int> knownDefectYears = const {}}) {
  final row = cal.row(y);
  if (row.days != 365 && row.days != 366) {
    out.add(InvariantViolation(
      code: 'year-length',
      year: y,
      message: 'year has ${row.days} days (expected 365/366).',
      knownDefect: knownDefectYears.contains(y) && row.days == 364,
    ));
  }
}

/// Validates a core-tier table: month bounds, year lengths, anchor chain,
/// Baisakh 1 window, weekday consistency, evidence tags, and the
/// no-three-identical-consecutive-rows rule.
List<InvariantViolation> validateCore(BsCalendar core) {
  final out = <InvariantViolation>[];
  for (final y in core.years) {
    _checkRow(core, y, out);
    _checkYearLength(core, y, out);
    if (!core.row(y).evidence.contains('r12-verified')) {
      out.add(InvariantViolation(
        code: 'evidence',
        year: y,
        message: 'core row is missing the r12-verified evidence tag.',
      ));
    }
  }
  _checkChain(core, out);
  for (var i = 2; i < core.years.length; i++) {
    final a = core.row(core.years[i - 2]);
    final b = core.row(core.years[i - 1]);
    final c = core.row(core.years[i]);
    if (_sameMonths(a.months, b.months) && _sameMonths(b.months, c.months)) {
      out.add(InvariantViolation(
        code: 'identical-run',
        year: c.year,
        message: 'BS ${a.year}, ${b.year} and ${c.year} have three identical consecutive rows.',
      ));
    }
  }
  return out;
}

/// Validates the projection tail: continuity with the core, the official
/// 2084 anchor, month bounds, chain, and year lengths (known defects flagged).
List<InvariantViolation> validateTail(
  BsCalendar core,
  BsCalendar tail, {
  Set<int> knownDefectYears = knownTailDefectYears,
}) {
  final out = <InvariantViolation>[];
  if (tail.firstYear != core.lastYear + 1) {
    out.add(InvariantViolation(
      code: 'boundary',
      year: tail.firstYear,
      message: 'tail must start at BS ${core.lastYear + 1}.',
    ));
  } else {
    final lastCore = core.row(core.lastYear);
    final expected = core.baisakh1(core.lastYear).add(Duration(days: lastCore.days));
    if (!_sameDate(expected, tail.baisakh1(tail.firstYear))) {
      out.add(InvariantViolation(
        code: 'boundary-anchor',
        year: tail.firstYear,
        message: 'tail must chain from core Baisakh 1 ${core.lastYear} '
            'plus ${lastCore.days} days.',
      ));
    }
  }
  for (final y in tail.years) {
    _checkRow(tail, y, out);
    _checkYearLength(tail, y, out, knownDefectYears: knownDefectYears);
  }
  _checkChain(tail, out);
  return out;
}
