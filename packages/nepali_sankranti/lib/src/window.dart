import 'package:nepali_date/nepali_date.dart';

import 'table.dart';

/// A violation of the sankranti window law (HYA-358) for one BS month.
class WindowViolation {
  final int bsYear;
  final int monthNo;

  /// The recomputed delta: month-start NPT date minus ingress NPT date.
  final int delta;
  final String message;

  const WindowViolation({
    required this.bsYear,
    required this.monthNo,
    required this.delta,
    required this.message,
  });

  String get key => bsYear.toString() + '-' + monthNo.toString();

  @override
  String toString() =>
      'BS ' + bsYear.toString() + ' month ' + monthNo.toString() +
      ': delta ' + delta.toString() + ' (' + message + ')';
}

/// Checks the sankranti window law over a whole calendar:
///
/// Every BS month must start on the NPT civil date of its sidereal
/// ingress or the day after - never before it. The single exception is
/// the 24-row pre-2036 consensus allowlist cataloged in the R5
/// experiment ([kBeforeSankrantiAllowlist]). The check recomputes every
/// delta from the calendar month starts and the table ingress instants;
/// it never trusts the CSV delta column.
List<WindowViolation> checkSankrantiWindows(
  BsCalendar calendar,
  List<SankrantiTableRow> rows,
) {
  final byKey = <String, SankrantiTableRow>{
    for (final r in rows) r.key: r,
  };
  final violations = <WindowViolation>[];
  for (final year in calendar.years) {
    final row = calendar.row(year);
    var start = calendar.baisakh1(year);
    for (var m = 1; m <= 12; m++) {
      if (m > 1) start = start.add(Duration(days: row.months[m - 2]));
      final key = year.toString() + '-' + m.toString();
      final tableRow = byKey[key];
      if (tableRow == null) {
        violations.add(WindowViolation(
          bsYear: year,
          monthNo: m,
          delta: 0,
          message: 'no published table row for ' + key,
        ));
        continue;
      }
      final nptDate = todayInNepalTime(nowUtc: tableRow.ingressUtc);
      final delta = start.difference(nptDate).inDays;
      final allowed = delta == 0 ||
          delta == 1 ||
          (delta == -1 &&
              year < 2036 &&
              kBeforeSankrantiAllowlist.contains(key));
      if (!allowed) {
        violations.add(WindowViolation(
          bsYear: year,
          monthNo: m,
          delta: delta,
          message: 'month starts before its sankranti',
        ));
      }
    }
  }
  return violations;
}
