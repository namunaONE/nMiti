import 'delta_t.dart';

/// Civil-time helpers: UTC DateTime <-> Julian Day and the Nepal conventions.
///
/// NPT (Kathmandu) is UTC+05:45. Wall-clock times from the calibration corpus
/// are converted by treating the wall fields as UTC and shifting by the NPT
/// offset; the inverse shift renders engine output as NPT wall clock.

/// NPT offset from UTC in hours (Kathmandu, +05:45).
const double nptOffsetHours = 5.75;

/// NPT offset from UTC in milliseconds.
const int nptOffsetMs = 20700000;

/// Julian Day (UT) of a UTC [dateTime]. Continuous, fractional.
double jdFromDateTimeUtc(DateTime dateTime) {
  return 2440587.5 + dateTime.millisecondsSinceEpoch / 86400000.0;
}

/// UTC instant for a Julian Day in UT.
DateTime dateTimeUtcFromJd(double jd) {
  final ms = ((jd - 2440587.5) * 86400000.0).round();
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

/// TT Julian Day for a UT Julian Day (adds Delta T at its civil month).
double jdTtFromJdUt(double jdUt) {
  final utc = dateTimeUtcFromJd(jdUt);
  return jdUt + deltaTSeconds(utc.year, utc.month) / 86400.0;
}

/// UT Julian Day for a TT Julian Day (subtracts Delta T). Delta T depends
/// only on the civil year and month, so a single evaluation suffices.
double jdUtFromJdTt(double jdTt) {
  final utc = dateTimeUtcFromJd(jdTt - 0.001);
  return jdTt - deltaTSeconds(utc.year, utc.month) / 86400.0;
}

/// Parses "yyyy-MM-ddTHH:mm" as a wall-clock DateTime with UTC fields
/// (no offset applied - callers shift by [nptOffsetMs] as needed).
DateTime parseWallClock(String s) {
  return DateTime.utc(
    int.parse(s.substring(0, 4)),
    int.parse(s.substring(5, 7)),
    int.parse(s.substring(8, 10)),
    int.parse(s.substring(11, 13)),
    int.parse(s.substring(14, 16)),
  );
}
