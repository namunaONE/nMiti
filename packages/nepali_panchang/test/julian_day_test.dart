import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

void main() {
  test('J2000.0 epoch: 2000-01-01 12:00 TT is JD 2451545.0', () {
    expect(julianDayFromCivil(2000, 1, 1.5), closeTo(2451545.0, 1e-9));
  });

  test('Meeus Ch.7 example 7.a: 1987-01-27.0 is JD 2446822.5', () {
    expect(julianDayFromCivil(1987, 1, 27.0), closeTo(2446822.5, 1e-9));
  });

  test('Meeus Ch.7 fractional day: 1957-10-04.81 is JD 2436116.31', () {
    expect(julianDayFromCivil(1957, 10, 4.81), closeTo(2436116.31, 1e-6));
  });
}
