import 'ayanamsa.dart';
import 'julian.dart';

double _signedDiff(double a, double b) {
  var d = (a - b) % 360.0;
  if (d <= -180.0) d += 360.0;
  if (d > 180.0) d -= 360.0;
  return d;
}

/// Residual of the sidereal solar longitude against a target, wrapped
/// to the interval (-180, 180]: zero exactly at ingress.
double _residual(double jd, double targetDeg) =>
    _signedDiff(siderealSolarLongitude(jd), targetDeg);

/// Solves siderealSolarLongitude(jd) == targetDeg inside the bracket
/// jdLo..jdHi by secant iteration. The Sun moves about 0.9856 deg/day,
/// so the residual is monotone over a bracket of a few days and the
/// secant converges to well under a second.
double ingressJulianDay(double targetDeg, double jdLo, double jdHi) {
  var a = jdLo;
  var fa = _residual(a, targetDeg);
  var b = jdHi;
  var fb = _residual(b, targetDeg);
  if (fa * fb > 0.0) {
    throw ArgumentError('Ingress bracket does not straddle the target.');
  }
  for (var i = 0; i < 60; i++) {
    final denom = fb - fa;
    if (denom.abs() < 1e-12) break;
    final c = b - fb * (b - a) / denom;
    final fc = _residual(c, targetDeg);
    a = b;
    fa = fb;
    b = c;
    fb = fc;
    if ((b - a).abs() < 5.8e-6) break; // about half a second
  }
  return b;
}

/// The UTC instant of the rasiIndex ingress inside the bracket utcLo to
/// utcHi (a few days wide, e.g. two days either side of the expected
/// date). Rasi 1, Mesha at 0 deg, is the Baisakh sankranti; rasi 9,
/// Dhanu at 240 deg, is the Poush sankranti; rasi 12, Meena at 330 deg,
/// is the Chaitra sankranti.
DateTime ingressUtc({
  required int rasiIndex,
  required DateTime utcLo,
  required DateTime utcHi,
}) {
  if (rasiIndex < 1 || rasiIndex > 12) {
    throw ArgumentError(
        'Rasi index must be 1..12, got ' + rasiIndex.toString());
  }
  if (!utcLo.isBefore(utcHi)) {
    throw ArgumentError('Bracket start must be before bracket end.');
  }
  final jd = ingressJulianDay(
      30.0 * (rasiIndex - 1), julianDay(utcLo), julianDay(utcHi));
  return utcFromJulianDay(jd);
}
