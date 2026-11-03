import 'dart:math' as math;

double _rev360(double deg) {
  final x = deg % 360.0;
  return x < 0.0 ? x + 360.0 : x;
}

/// Geometric mean longitude of the Sun in degrees, wrapped to [0, 360).
/// Meeus Ch.25.
double meanSolarLongitude(double t) =>
    _rev360(280.46646 + 36000.76983 * t + 0.0003032 * t * t);

/// Mean anomaly of the Sun in degrees, wrapped to [0, 360).
/// Meeus Ch.25.
double meanSolarAnomaly(double t) =>
    _rev360(357.52911 + 35999.05029 * t - 0.0001537 * t * t);

double _equationOfCenter(double t) {
  final m = meanSolarAnomaly(t) * math.pi / 180.0;
  return (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(m) +
      (0.019993 - 0.000101 * t) * math.sin(2.0 * m) +
      0.000289 * math.sin(3.0 * m);
}

/// Apparent ecliptic longitude of the Sun in degrees, wrapped to
/// [0, 360). Meeus Ch.25: true longitude (mean plus equation of center)
/// corrected for aberration and nutation in longitude via the ascending
/// node Omega of the Moon's mean orbit. Accuracy about 0.01 deg, which
/// is roughly 15 minutes of sun-motion time - the declared tolerance of
/// the Commons Layer 1 artifact.
double apparentSolarLongitude(double t) {
  final trueLongitude = meanSolarLongitude(t) + _equationOfCenter(t);
  final omega = (125.04 - 1934.136 * t) * math.pi / 180.0;
  return _rev360(trueLongitude - 0.00569 - 0.00478 * math.sin(omega));
}
