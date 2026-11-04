import 'dart:math' as math;

const double _radPerDeg = math.pi / 180;

/// True (geometric) ecliptic longitude of the Sun for [jd] in Terrestrial
/// Time, degrees, normalized to [0, 360).
///
/// Low-accuracy solar theory of Meeus, Astronomical Algorithms (2nd ed.),
/// chapter 25. [jd] must already be a TT Julian Day - convert civil UTC with
/// [deltaTSeconds].
double sunTrueLongitude(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
  final m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
  return _norm360(l0 + _equationOfCenter(t, m));
}

/// Apparent ecliptic longitude of the Sun for [jd] in Terrestrial Time,
/// degrees, normalized to [0, 360).
///
/// The true longitude corrected for nutation and aberration via Meeus
/// chapter 25: lambda_apparent = lambda_true - 0.00569 - 0.00478 sin(Omega).
double sunApparentLongitude(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final omega = 125.04 - 1934.136 * t;
  return _norm360(
    sunTrueLongitude(jd) - 0.00569 - 0.00478 * math.sin(omega * _radPerDeg),
  );
}

/// Earth-Sun distance for [jd] in Terrestrial Time, in astronomical units.
double sunEarthDistanceAu(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
  final e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t;
  final v = m + _equationOfCenter(t, m);
  return 1.000001018 * (1 - e * e) / (1 + e * math.cos(v * _radPerDeg));
}

/// Equation of center C of the Sun (Meeus chapter 25, eq. 25.4).
double _equationOfCenter(double t, double m) {
  return (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(m * _radPerDeg) +
      (0.019993 - 0.000101 * t) * math.sin(2 * m * _radPerDeg) +
      0.000289 * math.sin(3 * m * _radPerDeg);
}

double _norm360(double deg) => deg % 360.0;
