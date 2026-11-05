import 'dart:math' as math;

import 'julian_day.dart';

const double _radPerDeg = math.pi / 180;

/// Sunset for a civil date, USNO 'Almanac for Computers' low-accuracy solar
/// equations (L4 muhurta layer, HYA-420 step 1).
///
/// Setting sun at geometric center altitude -0.8333 deg (standard refraction
/// plus solar semidiameter): the same equations as sunrise.dart with the
/// setting-branch hour angle (plain acos, without the 360 - acos complement)
/// and the 18h local-mean-time seed. Defaults to the nMiti Kathmandu anchor
/// 27.7172 N / 85.324 E. Against the Nov 2026 BhaktiBharat receipts this
/// tracks their published sunset at a constant -3 min (the mirror of their
/// +4 min sunrise display convention); the hinducalculator 2026-11-05 spot
/// receipt (17:17 NPT) matches the engine exactly. The receipts corpus lives
/// in test/fixtures/muhurta_receipts_2026_11.json and the bands in
/// test/sunset_test.dart.

/// Sunset in UTC hours (0..24) for [year]-[month]-[day] at the location.
double sunsetUtcHours({
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final firstOfYear = julianDayFromCivil(year, 1, 1.0);
  final jd0 = julianDayFromCivil(year, month, day.toDouble());
  final dayOfYear = jd0 - firstOfYear + 1.0;
  final lngHour = longitudeDeg / 15.0;
  final t = dayOfYear + (18.0 - lngHour) / 24.0;
  final m = 0.9856 * t - 3.289;
  final l = _norm360(
      m + 1.916 * math.sin(m * _radPerDeg) + 0.020 * math.sin(2 * m * _radPerDeg) + 282.634);
  final ra = _norm360(
      math.atan2(0.91764 * math.sin(l * _radPerDeg), math.cos(l * _radPerDeg)) /
          _radPerDeg);
  final sinDec = 0.39782 * math.sin(l * _radPerDeg);
  final cosDec = math.cos(math.asin(sinDec));
  const zenith = 90.8333;
  final cosH = (math.cos(zenith * _radPerDeg) -
          sinDec * math.sin(latitudeDeg * _radPerDeg)) /
      (cosDec * math.cos(latitudeDeg * _radPerDeg));
  if (cosH < -1.0 || cosH > 1.0) {
    throw ArgumentError('sun does not set on this date at this latitude');
  }
  // Setting branch: plain acos hour angle (the rising branch in
  // sunriseUtcHours uses 360 - acos).
  final h = math.acos(cosH) / _radPerDeg;
  var ut = h / 15.0 + ra / 15.0 - 0.06571 * t - 6.622 - lngHour;
  ut = ut % 24.0;
  if (ut < 0.0) {
    ut += 24.0;
  }
  return ut;
}

/// Sunset as a UT Julian Day for [year]-[month]-[day].
double sunsetJdUt({
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final hours = sunsetUtcHours(
      year: year,
      month: month,
      day: day,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg);
  final jd = julianDayFromCivil(year, month, day.toDouble());
  // Unlike sunrise, an east-longitude anchor can never see the wrap hide
  // a day change: Kathmandu sunsets always land in forenoon UT (roughly
  // 11:15-12:30 UT) of the same civil date, so the summer day-wrap guard
  // that sunriseJdUt needs does not apply here. Western longitudes wrap
  // the other way: the computed hour is then the small hours of the NEXT
  // UT date.
  if (hours < 12.0 && longitudeDeg < 0.0) {
    return jd + 1.0 + hours / 24.0;
  }
  return jd + hours / 24.0;
}

double _norm360(double deg) => deg % 360.0;
