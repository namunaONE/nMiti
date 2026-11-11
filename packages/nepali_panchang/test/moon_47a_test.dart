import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

void main() {
  // Meeus, Astronomical Algorithms (2nd ed.), example 47.a:
  // 1992 April 12.0 TD = JD 2448724.5 - the permanent anchor epoch.
  //
  // Since the ELP2000-82B upgrade (HYA-369) the engine evaluates the
  // NASA-canonical truncated theory with the Chapront 2002 mean
  // arguments, so the value shifts from Meeus' printed Ch.47 result by
  // the known difference between the two theories (the spike measured
  // the longitude here at Swiss geometric minus 2.17 arcsec, i.e.
  // 133.162133 deg - Meeus' printed 133.162655 is itself ~0.3 arcsec
  // from Swiss). The tolerances stay orders of magnitude below what a
  // wrong table row or frame bug produces (the failure modes this
  // anchor exists for shift by arcseconds to degrees).
  //
  // The CI "elp2000 vendored table freshness gate" prints the current
  // anchor values as run notices on every run - keep this test in step
  // with them.
  final pos = moonPosition(2448724.5);

  test('example 47.a: geometric longitude is 133.162133 deg', () {
    expect(pos.longitudeDeg, closeTo(133.162133, 2e-3));
  });

  test('example 47.a: latitude is -3.229126 deg', () {
    expect(pos.latitudeDeg, closeTo(-3.229126, 6e-3));
  });

  test('example 47.a: distance is 368409.7 km', () {
    expect(pos.distanceKm, closeTo(368409.7, 10));
  });

  test('example 47.a: parallax is 0.99199 deg', () {
    expect(pos.parallaxDeg, closeTo(0.99199, 2e-4));
  });

  test('longitude is normalized to [0, 360)', () {
    expect(pos.longitudeDeg, greaterThanOrEqualTo(0));
    expect(pos.longitudeDeg, lessThan(360));
  });
}
