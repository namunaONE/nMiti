import 'dart:math' as math;

import 'vsop87d_earth.dart';

const double _radPerDeg = math.pi / 180;

/// True (geometric) ecliptic longitude of the Sun for [jd] in Terrestrial
/// Time, degrees, normalized to [0, 360).
///
/// VSOP87D Earth L series (Bretagnon & Francou 1988), dynamical ecliptic and
/// equinox of the date - see [vsop87dEarthSunGeometricLongitudeDeg] for the
/// truncation used. [jd] must already be a TT Julian Day - convert civil UTC
/// with [deltaTSeconds]. Replaces the Meeus chapter 25 low-accuracy theory
/// (HYA-406): chapter 25 carries a systematic error up to ~0.01 deg, while
/// the truncated VSOP87D series used here is good to well under one arcsec
/// for the supported 1600-2150 range.
double sunTrueLongitude(double jd) => vsop87dEarthSunGeometricLongitudeDeg(jd);

/// Apparent ecliptic longitude of the Sun for [jd] in Terrestrial Time,
/// degrees, normalized to [0, 360).
///
/// The true longitude corrected for nutation (Meeus chapter 22 low-accuracy
/// four-term formula) and for aberration (Meeus chapter 25: constant
/// 20.4898 arcsec scaled by the Earth-Sun distance in AU).
double sunApparentLongitude(double jd) {
  return _norm360(
      sunTrueLongitude(jd) + nutationInLongitudeDeg(jd) + sunAberrationDeg(jd));
}

/// Nutation in longitude (Meeus chapter 22 low-accuracy four-term
/// formula), degrees. Exposed by the R10.5 rung B frame audit (HYA-445):
/// an angular separation between two bodies needs no nutation (a common
/// frame rotation cancels between the bodies), but the publishers'
/// apparent-sidereal convention needs it on the moon as well as the sun.
/// Amplitude +-17.2 arcsec over the 18.6-year node cycle (+8.0 arcsec in
/// late 2026, ~16 s of tithi boundary time).
double nutationInLongitudeDeg(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final omega = 125.04452 - 1934.136261 * t;
  final ls = 280.4665 + 36000.7698 * t;
  final lm = 218.3165 + 481267.8813 * t;
  return (-17.20 * math.sin(omega * _radPerDeg) - 1.32 * math.sin(2 * ls * _radPerDeg) - 0.23 * math.sin(2 * lm * _radPerDeg) + 0.21 * math.sin(2 * omega * _radPerDeg)) / 3600.0;
}

/// Solar aberration (Meeus chapter 25), degrees: -20.4898 arcsec scaled
/// by the Earth-Sun distance in AU - the first-order light-time term of
/// the Sun's apparent position.
double sunAberrationDeg(double jd) =>
    -20.4898 / 3600.0 / sunEarthDistanceAu(jd);

/// Solar longitude in the SEPARATION frame (R10.5 rung B, HYA-445): the
/// true (VSOP87D) longitude plus the aberration term only, nutation
/// omitted - the frame the solar eclipse solver always used privately,
/// now public and shared with the tithi/karana elongation.
///
/// A common frame rotation cancels in an angular separation, so the
/// apparent separation carries nutation on NEITHER body - while each
/// body's own light-time correction is real and stays (for the Sun that
/// is the aberration). The tithi elongation formerly subtracted
/// [sunApparentLongitude] - nutation applied to the Sun ALONE - from the
/// geometric moon, rotating the Sun alone by the nutation and putting a
/// systematic -nutation into every tithi/karana angle (up to +-17.2
/// arcsec; +8.0 arcsec in late 2026 = ~16 s of boundary time).
///
/// The Moon's own light-time (~1.3 s of time, ~0.7 arcsec of longitude,
/// ~1.4 s of boundary time) is a NAMED, deliberately skipped
/// contributor: computing it would double the moon evaluations inside
/// every bisection for a term far below the publisher minute floor.
double sunLongitudeForSeparationDeg(double jd) {
  return _norm360(sunTrueLongitude(jd) + sunAberrationDeg(jd));
}

/// Earth-Sun distance for [jd] in Terrestrial Time, in astronomical units.
///
/// Meeus chapter 25 radius vector (accuracy ~1e-4 AU); used only to scale the
/// aberration constant.
double sunEarthDistanceAu(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
  final e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t;
  final v = m + _equationOfCenter(t, m);
  return 1.000001018 * (1 - e * e) / (1 + e * math.cos(v * _radPerDeg));
}

/// True (geometric) ecliptic longitude of the Sun via the low-accuracy
/// solar theory of Meeus, Astronomical Algorithms (2nd ed.), chapter 25.
///
/// Retained for provenance and regression tests; not used by the panchang
/// limbs since HYA-406.
double sunTrueLongitudeMeeus25(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
  final m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
  return _norm360(l0 + _equationOfCenter(t, m));
}

/// Apparent ecliptic longitude of the Sun via Meeus chapter 25:
/// lambda_apparent = lambda_true - 0.00569 - 0.00478 sin(Omega).
///
/// Retained for provenance and regression tests; not used by the panchang
/// limbs since HYA-406.
double sunApparentLongitudeMeeus25(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final omega = 125.04 - 1934.136 * t;
  return _norm360(
    sunTrueLongitudeMeeus25(jd) - 0.00569 - 0.00478 * math.sin(omega * _radPerDeg),
  );
}

/// Equation of center C of the Sun (Meeus chapter 25, eq. 25.4).
double _equationOfCenter(double t, double m) {
  return (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(m * _radPerDeg) +
      (0.019993 - 0.000101 * t) * math.sin(2 * m * _radPerDeg) +
      0.000289 * math.sin(3 * m * _radPerDeg);
}

double _norm360(double deg) => deg % 360.0;
