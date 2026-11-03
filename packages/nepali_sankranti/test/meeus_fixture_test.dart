import 'package:nepali_sankranti/nepali_sankranti.dart';
import 'package:test/test.dart';

void main() {
  // Meeus, Astronomical Algorithms (2nd ed.), Example 25.a/25.b:
  // 1992 October 13.0 TD. Mean longitude 201.80720 deg, mean anomaly
  // 278.99397 deg, true longitude 199.90988 deg, apparent longitude
  // 199.90895 deg.
  test('Meeus Example 25.b: apparent solar longitude 1992-10-13', () {
    final t = julianCenturies(2448908.5);
    expect(meanSolarLongitude(t), closeTo(201.80720, 0.0005));
    expect(meanSolarAnomaly(t), closeTo(278.99397, 0.0005));
    expect(apparentSolarLongitude(t), closeTo(199.90895, 0.0005));
  });

  test('ayanamsa at J2000.0 is exactly the R5 calibration constant', () {
    expect(ayanamsa(2451545.0), closeTo(23.87508, 1e-9));
  });

  test('sidereal longitude is tropical minus ayanamsa, wrapped to 0..360', () {
    final jd = 2448908.5;
    final t = julianCenturies(jd);
    final expected = (apparentSolarLongitude(t) - ayanamsa(jd)) % 360.0;
    expect(siderealSolarLongitude(jd), closeTo(expected, 1e-9));
  });

  test('a bracket that does not straddle the ingress is a loud error', () {
    // Dhanu sankranti 2026 is Dec 16; a Dec 14-only bracket must throw.
    expect(
      () => ingressUtc(
          rasiIndex: 9,
          utcLo: DateTime.utc(2026, 12, 14),
          utcHi: DateTime.utc(2026, 12, 14, 12)),
      throwsArgumentError,
    );
  });

  test('rasi index bounds are loud, not silent', () {
    expect(
      () => ingressUtc(
          rasiIndex: 13,
          utcLo: DateTime.utc(2026, 12, 14),
          utcHi: DateTime.utc(2026, 12, 19)),
      throwsArgumentError,
    );
  });
}
