import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

void main() {
  // Meeus, Astronomical Algorithms (2nd ed.), example 25.a:
  // 1992 October 13.0 TD = JD 2448908.5.
  test('example 25.a: apparent longitude is 199.90895 deg', () {
    expect(sunApparentLongitude(2448908.5), closeTo(199.90895, 1e-4));
  });

  test('example 25.a: Earth-Sun distance is 0.99766 AU', () {
    expect(sunEarthDistanceAu(2448908.5), closeTo(0.99766, 1e-4));
  });

  // The book prints the true longitude 199.90988 deg as the sum of its own
  // rounded intermediates; the full-precision chain gives 199.90987.
  test('example 25.a: true longitude is 199.90988 deg', () {
    expect(sunTrueLongitude(2448908.5), closeTo(199.90988, 1e-4));
  });

  test('longitudes are normalized to [0, 360)', () {
    final apparent = sunApparentLongitude(2448908.5);
    expect(apparent, greaterThanOrEqualTo(0));
    expect(apparent, lessThan(360));
  });
}
