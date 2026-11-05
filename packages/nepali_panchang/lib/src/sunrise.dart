import 'dart:math' as math;

import 'julian_day.dart';

const double _radPerDeg = math.pi / 180;

/// Sunrise for a civil date, USNO 'Almanac for Computers' low-accuracy solar
/// equations (R6a-1 step 3, HYA-403).
///
/// Rising sun at geometric center altitude -0.8333 deg (standard refraction
/// plus solar semidiameter), defaulting to the nMiti Kathmandu anchor
/// 27.7172 N / 85.324 E. Against the Nov 2026 corpus this tracks BhaktiBharat
/// at a constant +4.2 +/- 0.5 min (their convention) and Hamro Patro at
/// +0.5 +/- 0.5 min.

/// Sunrise in UTC hours (0..24) for [year]-[month]-[day] at the location.
double sunriseUtcHours({
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
  final t = dayOfYear + (6.0 - lngHour) / 24.0;
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
    throw ArgumentError('sun does not rise on $year-$month-$day');
  }
  final h = _norm360(360.0 - math.acos(cosH) / _radPerDeg);
  var ut = h / 15.0 + ra / 15.0 - 0.06571 * t - 6.622 - lngHour;
  ut = ut % 24.0;
  if (ut < 0.0) {
    ut += 24.0;
  }
  return ut;
}

/// Sunrise as a UT Julian Day for [year]-[month]-[day].
double sunriseJdUt({
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final hours = sunriseUtcHours(
      year: year,
      month: month,
      day: day,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg);
  final jd = julianDayFromCivil(year, month, day.toDouble());
  // The USNO algorithm expresses the sunrise in UT hours of the
  // civil date and [sunriseUtcHours] wraps negatives into [23, 24).
  // From late April to early September the NPT civil day dawns
  // BEFORE 00:00 UT of its civil date (the Kathmandu sunrise lands
  // before 05:45 NPT), and the wrap placed such udayas one NPT day
  // late - the Janai Purnima 2083 receipts caught it: the Aug 28
  // udaya was being evaluated at Aug 29's dawn. East-longitude
  // anchors can never see a genuine afternoon-UT sunrise, so a
  // wrapped hour is always the previous UT day.
  if (hours > 12.0 && longitudeDeg > 0.0) {
    return jd - 1.0 + hours / 24.0;
  }
  return jd + hours / 24.0;
}

double _norm360(double deg) => deg % 360.0;
