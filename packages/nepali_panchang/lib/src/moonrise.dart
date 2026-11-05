import 'dart:math' as math;

import 'civil_time.dart';
import 'julian_day.dart';
import 'moon.dart';

/// Moonrise solver (HYA-417): the first rising of the Moon within an
/// NPT civil day, Kathmandu-anchored like the sunrise solver.
///
/// Rise condition - Meeus, Astronomical Algorithms (2nd ed.), eq. 15.1:
/// the geocentric altitude of the Moon's center reaches
/// h0 = 0.7276 * pi - 34', the standard upper-limb rise with the 34'
/// refraction folded into the target (pi = the equatorial horizontal
/// parallax, live per sample). The Moon is taken from the same 60-term
/// Meeus Ch.47 series the lunar engine uses, so moonrise and every
/// tithi boundary share one ephemeris.
///
/// Frame: mean equinox of date (the Ch.47 series is already in that
/// frame; nutation is omitted - a named seconds-level contributor),
/// obliquity Meeus eq. 22.2, sidereal time Meeus eq. 12.4,
/// ecliptic-to-equatorial Meeus eqs. 13.3/13.4.
///
/// Receipts: JPL Horizons topocentric samples (30-min step, airless
/// apparent elevation, upper limb + 34' refraction threshold,
/// Kathmandu geodetic site) pin the printed table in
/// test/moonrise_test.dart to a provisional +/-12 min band; the
/// Swiss-truth CI harness (tools/sweph/sweph_crosscheck.py) re-solves
/// every dumped moonrise under the identical target convention and
/// enforces the provisional 300/150 s band on every push.

const double _radPerDeg = math.pi / 180;
const double _degPerRad = 180 / math.pi;

/// Geocentric altitude of the Moon's center above the astronomical
/// horizon, degrees, at a UT Julian Day [jdUt].
double moonGeocentricAltitudeDeg({
  required double jdUt,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final jdTt = jdTtFromJdUt(jdUt);
  final pos = moonPosition(jdTt);
  final t = (jdUt - 2451545.0) / 36525.0;
  // Mean obliquity of the ecliptic, Meeus eq. 22.2 (degrees).
  final epsDeg = 23.439291111 -
      0.013004167 * t -
      0.000000164 * t * t +
      0.000000504 * t * t * t;
  final lam = pos.longitudeDeg * _radPerDeg;
  final bet = pos.latitudeDeg * _radPerDeg;
  final eps = epsDeg * _radPerDeg;
  // Equatorial coordinates, Meeus eqs. 13.3/13.4 (degrees).
  final raDeg = math.atan2(
          math.sin(lam) * math.cos(eps) - math.tan(bet) * math.sin(eps),
          math.cos(lam)) *
      _degPerRad;
  final decDeg = math.asin(math.sin(bet) * math.cos(eps) +
          math.cos(bet) * math.sin(eps) * math.sin(lam)) *
      _degPerRad;
  // Greenwich mean sidereal time, Meeus eq. 12.4 (degrees).
  final gmstDeg = 280.46061837 +
      360.98564736629 * (jdUt - 2451545.0) +
      0.000387933 * t * t -
      t * t * t / 38710000;
  final hourAngleDeg = gmstDeg + longitudeDeg - raDeg;
  final lat = latitudeDeg * _radPerDeg;
  final dec = decDeg * _radPerDeg;
  final h = hourAngleDeg * _radPerDeg;
  return math.asin(math.sin(lat) * math.sin(dec) +
          math.cos(lat) * math.cos(dec) * math.cos(h)) *
      _degPerRad;
}

/// Rise target at [jdUt] (Meeus eq. 15.1): the geocentric center
/// altitude at which the upper limb meets the refracted horizon. The
/// parallax is live from the Ch.47 distance, so the near Moon raises
/// the bar and the far Moon lowers it, exactly as in nature.
double moonRiseTargetAltitudeDeg(double jdUt) {
  final pos = moonPosition(jdTtFromJdUt(jdUt));
  return 0.7276 * pos.parallaxDeg - 34.0 / 60.0;
}

/// Moonrise of the NPT civil day [year]-[month]-[day] as a UT Julian
/// Day, or null when the Moon does not rise inside the civil day
/// (roughly once a lunar month the rise falls into a neighbouring
/// day).
///
/// The scan is 30-minute stepped over the civil day [00:00, 24:00) NPT
/// looking for the first upward crossing of the target, followed by
/// 40 bisection iterations. A rise already in progress at 00:00 is
/// not the day's moonrise - the next rise (after a mid-day setting,
/// typically in the evening) is, and the first-upward-crossing scan
/// picks that up naturally.
double? moonriseJdUt({
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final dayStartUt =
      julianDayFromCivil(year, month, day.toDouble()) - 18.25 / 24.0;
  const step = 1.0 / 48.0; // 30 minutes
  double margin(double jdUt) =>
      moonGeocentricAltitudeDeg(
              jdUt: jdUt,
              latitudeDeg: latitudeDeg,
              longitudeDeg: longitudeDeg) -
          moonRiseTargetAltitudeDeg(jdUt);
  var prevJd = dayStartUt;
  var prevMargin = margin(dayStartUt);
  for (var i = 1; i <= 48; i++) {
    final jd = dayStartUt + i * step;
    final m = margin(jd);
    if (prevMargin < 0.0 && m >= 0.0) {
      var lo = prevJd;
      var hi = jd;
      for (var k = 0; k < 40; k++) {
        final mid = (lo + hi) / 2;
        if (margin(mid) < 0.0) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return hi;
    }
    prevJd = jd;
    prevMargin = m;
  }
  return null;
}

/// Moonrise of the NPT civil day as a wall-clock [DateTime] holding
/// NPT fields (the engine's civil convention - see parseWallClock),
/// or null when the Moon does not rise that day.
DateTime? moonriseNpt({
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final jdUt = moonriseJdUt(
      year: year,
      month: month,
      day: day,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg);
  if (jdUt == null) {
    return null;
  }
  return dateTimeUtcFromJd(jdUt)
      .add(const Duration(milliseconds: nptOffsetMs));
}
