import 'dart:math' as math;

import 'ayanamsa.dart';
import 'civil_time.dart';
import 'graha/graha_table.dart';
import 'julian_day.dart';
import 'moon.dart';
import 'sun.dart';

/// Graha engine (HYA-450, Wave 1): geocentric apparent positions of the five
/// classical grahas - Mercury through Saturn - from the vendored VSOP87D
/// planetary theory (Bretagnon & Francou 1988; see graha/graha_table.dart for
/// the truncation recipe and the provenance of the GENERATED coefficient
/// table).
///
/// Pipeline, deliberately mirroring the solar channel's conventions so all
/// bodies share one frame discipline:
/// - VSOP87D heliocentric spherical series of date -> rectangular AU;
/// - the "Earth" series describe the Earth-Moon barycenter: the engine adds
///   the EMB -> Earth correction from its own ELP2000-82B moon (mu =
///   1/82.3006 of the geocentric moon vector, ~6.5 arcsec at worst);
/// - light-time by iteration (tau = |geo| / c, three passes, c in AU/day);
/// - first-order aberration as the observer-velocity term s' = unit(s + v/c)
///   (reproduces the Meeus ch.25 solar constant -20.4898 arcsec exactly);
/// - nutation via the SAME exported 4-term formula the sun uses
///   ([nutationInLongitudeDeg]): apparent = light-time+aberration longitude
///   + dPsi. Ecliptic latitude is untouched by nutation in longitude;
/// - sidereal longitude against the receipts-measured Swiss-Lahiri
///   reference line ([ayanamsaSwissLahiriReference]) - the frame the graha
///   publisher corpus (Swarnsiddhi) actually prints; the engine's own base
///   ayanamsa profiles remain lunar-limb territory.
///
/// Receipts (test/graha_test.dart): JPL Horizons DE441 apparent RA/DEC
/// converted to ecliptic of date, dense 2026-10-16..12-03 plus 2h station
/// refinement windows - hard 15 arcsec / mean 5 arcsec PROVISIONAL bands,
/// expected class ~1 arcsec, tightened after the first CI scoreboard.
///
/// The mean lunar node (Rahu) rides along on the Meeus ch. 47.7
/// polynomial - the classical convention (every panchang prints the MEAN
/// node; the true node's +/- 1.7 deg wobble is the named skip) - sidereal
/// on the BASE profile for the Swiss crosscheck harness.
///
/// Named skips (stated, never absorbed): gravitational light deflection
/// (<=0.01 arcsec at these solar elongations), aberration beyond first
/// order (<=0.001 arcsec), topocentric parallax for positions (rise/set
/// below), planetary semidiameters, the true node.

const double _radPerDeg = math.pi / 180;
const double _degPerRad = 180 / math.pi;

/// Speed of light, AU/day (499.004784 light-seconds, IAU 2012).
const double _cAuPerDay = 173.1446327;

/// Moon-to-(Earth+Moon) mass ratio for the EMB -> Earth correction
/// (Meeus ch. 25 note on the VSOP87 Earth series).
const double _moonMassRatio = 1.0 / 82.3006;

/// 1 AU in km (IAU 2012).
const double _auKm = 149597870.7;

/// The five classical grahas the W1 engine serves.
enum GrahaBody { mercury, venus, mars, jupiter, saturn }

/// Table body index of each graha (the vendored table also carries Earth
/// at index 2 for the geocentric subtraction).
const List<int> _tableIndex = [0, 1, 3, 4, 5];

/// Classical combustion limits, degrees of apparent separation from the
/// Sun. PROVISIONAL (HYA-450): the commonly printed set; the shastra
/// citation (BPHS Ch. 9 and its commentaries) is an open receipt and the
/// retro variants (Mercury 12, Venus 8) are deliberately NOT used until
/// the source is pinned.
const Map<GrahaBody, double> _combustionLimitDeg = {
  GrahaBody.mercury: 14.0,
  GrahaBody.venus: 10.0,
  GrahaBody.mars: 17.0,
  GrahaBody.jupiter: 11.0,
  GrahaBody.saturn: 15.0,
};

class _Vec {
  final double x, y, z;
  const _Vec(this.x, this.y, this.z);
}

_Vec _sub(_Vec a, _Vec b) => _Vec(a.x - b.x, a.y - b.y, a.z - b.z);
double _len(_Vec a) => math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
_Vec _unit(_Vec a) {
  final l = _len(a);
  return _Vec(a.x / l, a.y / l, a.z / l);
}

double _norm360(double deg) => deg % 360.0;

double _wrap180(double deg) {
  final d = deg % 360.0;
  return d > 180.0 ? d - 360.0 : (d < -180.0 ? d + 360.0 : d);
}

/// One heliocentric variable (0 = L rad, 1 = B rad, 2 = R AU) of one table
/// body at [jdTt] (Terrestrial Time Julian Day).
double _series(int tableBody, int varIdx, double jdTt) {
  final tau = (jdTt - 2451545.0) / 365250.0;
  final counts = kGrahaSectionCounts;
  final terms = kGrahaTerms;
  final sec0 = tableBody * 18 + varIdx * 6;
  var off = 0;
  for (var i = 0; i < sec0; i++) {
    off += counts[i];
  }
  var acc = 0.0;
  var tp = 1.0;
  for (var p = 0; p < 6; p++) {
    final n = counts[sec0 + p];
    for (var k = 0; k < n; k++) {
      acc += tp * terms[off] * math.cos(terms[off + 1] + terms[off + 2] * tau);
      off += 3;
    }
    tp *= tau;
  }
  return acc;
}

/// Heliocentric rectangular position of a table body, AU.
_Vec _helio(int tableBody, double jdTt) {
  final l = _series(tableBody, 0, jdTt);
  final b = _series(tableBody, 1, jdTt);
  final r = _series(tableBody, 2, jdTt);
  final cb = math.cos(b);
  return _Vec(r * cb * math.cos(l), r * cb * math.sin(l), r * math.sin(b));
}

/// Heliocentric position of the EARTH: VSOP87D gives the Earth-Moon
/// barycenter; Earth = EMB - mu * (geocentric moon vector in AU).
_Vec _earthHelio(double jdTt) {
  final emb = _helio(2, jdTt);
  final m = moonPosition(jdTt);
  final r = m.distanceKm / _auKm;
  final lam = m.longitudeDeg * _radPerDeg;
  final bet = m.latitudeDeg * _radPerDeg;
  final cb = math.cos(bet);
  return _Vec(
    emb.x - _moonMassRatio * r * cb * math.cos(lam),
    emb.y - _moonMassRatio * r * cb * math.sin(lam),
    emb.z - _moonMassRatio * r * math.sin(bet),
  );
}

/// Apparent geocentric position of a graha at [jdTt] (Terrestrial Time).
class GrahaPosition {
  /// Light-time + aberration longitude, MEAN equinox of date, degrees
  /// [0, 360). The separation frame: nutation omitted on BOTH bodies of a
  /// separation (the R10.5 rung B discipline).
  final double longitudeDeg;

  /// Ecliptic latitude, degrees (nutation in longitude does not touch it).
  final double latitudeDeg;

  /// Apparent longitude, TRUE equinox of date (adds nutation, mirroring
  /// [sunApparentLongitude]).
  final double apparentLongitudeDeg;

  /// Apparent latitude (same value as [latitudeDeg]; kept for symmetry).
  final double apparentLatitudeDeg;

  /// Geocentric light-time distance, AU.
  final double distanceAu;

  /// Apparent sidereal longitude against the Swiss-Lahiri reference line
  /// (the frame the graha publisher corpus prints).
  final double siderealLongitudeDeg;

  /// Apparent sidereal longitude on the BASE ayanamsa profile - the
  /// crosscheck channel: the Swiss harness measures the ayanamsa gap
  /// itself (the dump_limb_instants convention).
  final double siderealLongitudeBaseDeg;

  const GrahaPosition({
    required this.longitudeDeg,
    required this.latitudeDeg,
    required this.apparentLongitudeDeg,
    required this.apparentLatitudeDeg,
    required this.distanceAu,
    required this.siderealLongitudeDeg,
    required this.siderealLongitudeBaseDeg,
  });
}

/// Apparent geocentric ecliptic position of [body] at [jdTt] (TT).
GrahaPosition grahaPosition(GrahaBody body, double jdTt) {
  final tb = _tableIndex[body.index];
  final earth = _earthHelio(jdTt);
  var tau = 0.0;
  var geo = _sub(_helio(tb, jdTt), earth);
  for (var i = 0; i < 3; i++) {
    geo = _sub(_helio(tb, jdTt - tau), earth);
    tau = _len(geo) / _cAuPerDay;
  }
  // First-order aberration: the observer's heliocentric velocity tilts the
  // apparent direction toward the apex of motion, s' = unit(s + v/c).
  const dt = 0.02;
  final e1 = _earthHelio(jdTt + dt);
  final e2 = _earthHelio(jdTt - dt);
  final v = _Vec(
    (e1.x - e2.x) / (2 * dt),
    (e1.y - e2.y) / (2 * dt),
    (e1.z - e2.z) / (2 * dt),
  );
  final s = _unit(geo);
  final sa = _unit(_Vec(
    s.x + v.x / _cAuPerDay,
    s.y + v.y / _cAuPerDay,
    s.z + v.z / _cAuPerDay,
  ));
  final lon = math.atan2(sa.y, sa.x) * _degPerRad;
  final lonDeg = lon < 0 ? lon + 360.0 : lon;
  final latDeg = math.asin(sa.z.clamp(-1.0, 1.0)) * _degPerRad;
  final app = _norm360(lonDeg + nutationInLongitudeDeg(jdTt));
  return GrahaPosition(
    longitudeDeg: _norm360(lonDeg),
    latitudeDeg: latDeg,
    apparentLongitudeDeg: app,
    apparentLatitudeDeg: latDeg,
    distanceAu: _len(geo),
    siderealLongitudeDeg: _norm360(
        app - ayanamsaSwissLahiriReference(jdTt)),
    siderealLongitudeBaseDeg: _norm360(app - ayanamsaBase(jdTt)),
  );
}

/// Rate of change of the apparent longitude, degrees/day, wrap-safe.
double grahaLongitudeRateDegPerDay(GrahaBody body, double jdTt) {
  const h = 0.05;
  final a = grahaPosition(body, jdTt + h).apparentLongitudeDeg;
  final b = grahaPosition(body, jdTt - h).apparentLongitudeDeg;
  return _wrap180(a - b) / (2 * h);
}

/// The first retrograde station (direct or retro) of [body] strictly inside
/// (startJdTt, endJdTt), or null. A 0.5-day scan for a sign change of the
/// longitude rate, then 60 bisections.
double? grahaStationJdTt(
  GrahaBody body, {
  required double startJdTt,
  required double endJdTt,
}) {
  final step = 0.5;
  var prevT = startJdTt;
  var prevRate = grahaLongitudeRateDegPerDay(body, startJdTt);
  for (var t = startJdTt + step; t <= endJdTt + 1e-9; t += step) {
    final rate = grahaLongitudeRateDegPerDay(body, t);
    if (prevRate != 0.0 && rate != 0.0 && (prevRate < 0) != (rate < 0)) {
      var lo = prevT;
      var hi = t;
      for (var k = 0; k < 60; k++) {
        final mid = (lo + hi) / 2;
        final r = grahaLongitudeRateDegPerDay(body, mid);
        if ((r < 0) == (prevRate < 0)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return hi;
    }
    prevT = t;
    prevRate = rate;
  }
  return null;
}

/// Apparent separation of [body] from the Sun, degrees [0, 180]: the
/// SEPARATION frame (nutation cancels between the two bodies, the R10.5
/// rung B discipline), each body keeping its own light-time.
double grahaSunSeparationDeg(GrahaBody body, double jdTt) {
  final g = grahaPosition(body, jdTt);
  final sun = sunLongitudeForSeparationDeg(jdTt);
  return _wrap180(g.longitudeDeg - sun).abs();
}

/// Whether [body] is combust at [jdTt]: separation under the classical
/// limit (see [_combustionLimitDeg] for the provisional citation status).
bool grahaIsCombust(GrahaBody body, double jdTt) {
  return grahaSunSeparationDeg(body, jdTt) < _combustionLimitDeg[body]!;
}

/// Mean lunar ascending node (Rahu), tropical longitude of the mean
/// equinox of date, degrees [0, 360): the Meeus ch. 47.7 polynomial -
/// the same mean node the ELP2000-82B series carry, retrograde at
/// ~-0.053 deg/day. The classical Rahu IS the mean node; the true node
/// is the named skip (see the library doc).
double rahuMeanLongitudeDeg(double jdTt) {
  final t = (jdTt - 2451545.0) / 36525.0;
  final omega = 125.0445479 -
      1934.1362891 * t +
      0.0020754 * t * t +
      t * t * t / 467441.0 -
      t * t * t * t / 60616000.0;
  return _norm360(omega);
}

/// Sidereal mean node (Rahu) on the BASE ayanamsa profile - the
/// dump/crosscheck channel: the Swiss harness measures the ayanamsa
/// convention gap itself.
double rahuMeanSiderealLongitudeDeg(double jdTt) {
  return _norm360(rahuMeanLongitudeDeg(jdTt) - ayanamsaBase(jdTt));
}

/// Nutation in obliquity (Meeus ch. 22 four-term), degrees - the companion
/// of [nutationInLongitudeDeg], used by the rise/set equatorial conversion.
double _nutationInObliquityDeg(double jdTt) {
  final t = (jdTt - 2451545.0) / 36525.0;
  final omega = 125.04452 - 1934.136261 * t;
  final ls = 280.4665 + 36000.7698 * t;
  final lm = 218.3165 + 481267.8813 * t;
  return (9.20 * math.cos(omega * _radPerDeg) +
          0.57 * math.cos(2 * ls * _radPerDeg) +
          0.10 * math.cos(2 * lm * _radPerDeg) -
          0.09 * math.cos(2 * omega * _radPerDeg)) /
      3600.0;
}

/// Rise/set target altitude for a graha: the center reaches -34 arcmin
/// (standard refraction at the horizon; no semidiameter, no parallax -
/// named skips, planets are pointlike at this class).
const double _grahaHorizonDeg = -34.0 / 60.0;

/// Geocentric altitude of [body]'s center at [jdUt] (UT Julian Day),
/// degrees, Kathmandu-anchored by default (same site convention as the
/// moonrise solver).
double grahaAltitudeDeg({
  required GrahaBody body,
  required double jdUt,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final jdTt = jdTtFromJdUt(jdUt);
  final pos = grahaPosition(body, jdTt);
  final t = (jdUt - 2451545.0) / 36525.0;
  final epsDeg = 23.439291111 -
      0.013004167 * t -
      0.000000164 * t * t +
      0.000000504 * t * t * t +
      _nutationInObliquityDeg(jdTt);
  final lam = pos.apparentLongitudeDeg * _radPerDeg;
  final bet = pos.apparentLatitudeDeg * _radPerDeg;
  final eps = epsDeg * _radPerDeg;
  final raDeg = math.atan2(
          math.sin(lam) * math.cos(eps) - math.tan(bet) * math.sin(eps),
          math.cos(lam)) *
      _degPerRad;
  final decDeg = math.asin(math.sin(bet) * math.cos(eps) +
          math.cos(bet) * math.sin(eps) * math.sin(lam)) *
      _degPerRad;
  final gmstDeg = 280.46061837 +
      360.98564736629 * (jdUt - 2451545.0) +
      0.000387933 * t * t -
      t * t * t / 38710000;
  final h = (gmstDeg + longitudeDeg - raDeg) * _radPerDeg;
  final lat = latitudeDeg * _radPerDeg;
  final dec = decDeg * _radPerDeg;
  return math.asin(math.sin(lat) * math.sin(dec) +
          math.cos(lat) * math.cos(dec) * math.cos(h)) *
      _degPerRad;
}

double? _solveCrossing({
  required GrahaBody body,
  required double dayStartUt,
  required bool rising,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  const step = 1.0 / 48.0; // 30 minutes
  double margin(double jdUt) =>
      grahaAltitudeDeg(
          body: body,
          jdUt: jdUt,
          latitudeDeg: latitudeDeg,
          longitudeDeg: longitudeDeg) -
      _grahaHorizonDeg;
  var prevJd = dayStartUt;
  var prevMargin = margin(dayStartUt);
  for (var i = 1; i <= 48; i++) {
    final jd = dayStartUt + i * step;
    final m = margin(jd);
    final crossed = rising
        ? (prevMargin < 0.0 && m >= 0.0)
        : (prevMargin >= 0.0 && m < 0.0);
    if (crossed) {
      var lo = prevJd;
      var hi = jd;
      for (var k = 0; k < 40; k++) {
        final mid = (lo + hi) / 2;
        final mm = margin(mid);
        final below = rising ? mm < 0.0 : mm >= 0.0;
        if (below) {
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

/// Rise of [body] within the NPT civil day as a UT Julian Day, or null.
double? grahaRiseJdUt({
  required GrahaBody body,
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final dayStartUt =
      julianDayFromCivil(year, month, day.toDouble()) - 5.75 / 24.0;
  return _solveCrossing(
      body: body,
      dayStartUt: dayStartUt,
      rising: true,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg);
}

/// Set of [body] within the NPT civil day as a UT Julian Day, or null.
double? grahaSetJdUt({
  required GrahaBody body,
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final dayStartUt =
      julianDayFromCivil(year, month, day.toDouble()) - 5.75 / 24.0;
  return _solveCrossing(
      body: body,
      dayStartUt: dayStartUt,
      rising: false,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg);
}
