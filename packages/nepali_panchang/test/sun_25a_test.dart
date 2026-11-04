import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

void main() {
  // --- VSOP87D primary solar theory (HYA-406) ---
  // Values from the full-precision VSOP87D evaluation; see
  // lib/src/vsop87d_earth.dart for the truncation statement.
  test('VSOP87D: geometric longitude at J2000.0 is 280.377844 deg', () {
    expect(sunTrueLongitude(2451545.0), closeTo(280.377844, 1e-5));
  });

  test('VSOP87D: example 25.a geometric longitude is 199.907295 deg', () {
    expect(sunTrueLongitude(2448908.5), closeTo(199.907295, 1e-5));
  });

  test('VSOP87D: example 25.a apparent longitude is 199.906043 deg', () {
    expect(sunApparentLongitude(2448908.5), closeTo(199.906043, 1e-5));
  });

  // VSOP87D must stay inside Meeus chapter 25's own stated accuracy.
  test('VSOP87D apparent longitude agrees with Meeus 25 within 0.01 deg', () {
    final diff = (sunApparentLongitude(2448908.5) -
            sunApparentLongitudeMeeus25(2448908.5))
        .abs();
    expect(diff, lessThan(0.01));
  });

  // --- Meeus chapter 25 (retained functions, provenance/regression) ---
  // Meeus, Astronomical Algorithms (2nd ed.), example 25.a:
  // 1992 October 13.0 TD = JD 2448908.5.
  test('Meeus 25.a: apparent longitude is 199.90895 deg', () {
    expect(sunApparentLongitudeMeeus25(2448908.5), closeTo(199.90895, 1e-4));
  });

  test('Meeus 25.a: Earth-Sun distance is 0.99766 AU', () {
    expect(sunEarthDistanceAu(2448908.5), closeTo(0.99766, 1e-4));
  });

  // The book prints the true longitude 199.90988 deg as the sum of its own
  // rounded intermediates; the full-precision chain gives 199.90987.
  test('Meeus 25.a: true longitude is 199.90988 deg', () {
    expect(sunTrueLongitudeMeeus25(2448908.5), closeTo(199.90988, 1e-4));
  });

  test('longitudes are normalized to [0, 360)', () {
    final apparent = sunApparentLongitude(2448908.5);
    expect(apparent, greaterThanOrEqualTo(0));
    expect(apparent, lessThan(360));
  });
}
