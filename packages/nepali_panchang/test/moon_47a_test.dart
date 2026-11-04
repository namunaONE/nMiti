import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

void main() {
  // Meeus, Astronomical Algorithms (2nd ed.), example 47.a:
  // 1992 April 12.0 TD = JD 2448724.5. These are the permanent anchors for
  // the 60-term Ch.47 series; a single wrong table row or additive term
  // shifts them far beyond these tolerances.
  final pos = moonPosition(2448724.5);

  test('example 47.a: geometric longitude is 133.162655 deg', () {
    expect(pos.longitudeDeg, closeTo(133.162655, 1e-5));
  });

  test('example 47.a: latitude is -3.229126 deg', () {
    expect(pos.latitudeDeg, closeTo(-3.229126, 1e-5));
  });

  test('example 47.a: distance is 368409.7 km', () {
    expect(pos.distanceKm, closeTo(368409.7, 0.1));
  });

  test('example 47.a: parallax is 0.99199 deg', () {
    expect(pos.parallaxDeg, closeTo(0.99199, 1e-5));
  });

  test('longitude is normalized to [0, 360)', () {
    expect(pos.longitudeDeg, greaterThanOrEqualTo(0));
    expect(pos.longitudeDeg, lessThan(360));
  });
}
