import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

void main() {
  // Anchors from the Espenak-Meeus fits themselves (values produced by the
  // validated TS reference); they also agree with the observed Morrison &
  // Stephenson curve to well under a second in the satellite era.
  test('observed anchors: 1975, 1990, 2000, 2010', () {
    expect(deltaTSeconds(1975, 1), closeTo(45.49, 0.05));
    expect(deltaTSeconds(1990, 1), closeTo(56.92, 0.05));
    expect(deltaTSeconds(2000, 1), closeTo(63.87, 0.05));
    expect(deltaTSeconds(2010, 1), closeTo(66.72, 0.05));
  });

  test('nMiti corpus era: November 2026 is about 75.6 s', () {
    expect(deltaTSeconds(2026, 11), closeTo(75.62, 0.05));
  });

  test('BS 2100 (AD 2043) stays inside the 2005-2050 branch', () {
    expect(deltaTSeconds(2043, 6), closeTo(87.48, 0.05));
  });

  test('2050-01 hands over to the 2050-2150 branch at 93.08 s', () {
    expect(deltaTSeconds(2050, 1), closeTo(93.08, 0.05));
  });

  test('years outside AD 1600-2150 throw ArgumentError', () {
    expect(() => deltaTSeconds(1500, 1), throwsArgumentError);
    expect(() => deltaTSeconds(2200, 1), throwsArgumentError);
  });
}
