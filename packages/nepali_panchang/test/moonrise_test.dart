import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Moonrise solver test (HYA-417).
///
/// Golden table: provisional receipts derived from JPL Horizons -
/// airless topocentric apparent elevation, 30-min samples, Kathmandu
/// geodetic site (27.7172 N / 85.324 E / 1400 m). The rise estimate per
/// date is the linear interpolation of the crossing of
/// -(34' + 0.2724 * pi) with nominal parallax pi = 0.95 deg - the
/// upper-limb-plus-standard-refraction rise, the same convention the
/// solver targets (Meeus eq. 15.1). The +/-12 min band absorbs the
/// 30-min sampling curvature and the nominal-parallax threshold slack;
/// the tight gate is the Swiss-truth harness
/// (tools/sweph/sweph_crosscheck.py), which mirrors the solver's exact
/// convention on Swiss Ephemeris in CI with provisional 300/150 s bands.
///
/// The golden dates are the 2026 festival days: Falgun 3 (Shivaratri),
/// Falgun 18/19 (Fagu Purnima hills / Terai Holi), Bhadra 29 (Teej).
const List<List<String>> _golden = [
  ['2026-02-15', '05:17'], // Falgun 3, 2082 - Maha Shivaratri day
  ['2026-02-16', '05:57'],
  ['2026-03-02', '17:04'], // Falgun 18, 2082 - Fagu Purnima (hills)
  ['2026-03-03', '18:05'], // Falgun 19, 2082 - Terai Holi (sunset rise)
  ['2026-09-14', '08:42'], // Bhadra 29, 2083 - Teej
  ['2026-09-15', '09:41'],
];

DateTime _npt(String date, String hm) {
  return DateTime.utc(
      int.parse(date.substring(0, 4)),
      int.parse(date.substring(5, 7)),
      int.parse(date.substring(8, 10)),
      int.parse(hm.substring(0, 2)),
      int.parse(hm.substring(3, 5)));
}

void main() {
  for (final row in _golden) {
    final date = row[0];
    final expected = _npt(date, row[1]);
    final y = int.parse(date.substring(0, 4));
    final mo = int.parse(date.substring(5, 7));
    final d = int.parse(date.substring(8, 10));
    test('$date: moonrise inside the Horizons band (+-12 min of '
        '${row[1]} NPT)', () {
      final rise = moonriseNpt(year: y, month: mo, day: d);
      expect(rise, isNotNull, reason: 'no moonrise found on $date');
      final diffMin = rise!.difference(expected).inMinutes.abs();
      expect(diffMin, lessThan(12),
          reason: 'moonrise $rise vs Horizons estimate $expected');
      expect([rise.year, rise.month, rise.day], [y, mo, d],
          reason: 'the rise must land on its own NPT civil day');
    });
    test('$date: the rise instant sits on the target altitude', () {
      final jdUt = moonriseJdUt(year: y, month: mo, day: d);
      expect(jdUt, isNotNull);
      final h = moonGeocentricAltitudeDeg(jdUt: jdUt!);
      final target = moonRiseTargetAltitudeDeg(jdUt);
      expect((h - target).abs(), lessThan(0.02),
          reason: 'h=$h vs h0=$target - the solver must stop at '
              'the Meeus 15.1 target');
      double margin(double jd) =>
          moonGeocentricAltitudeDeg(jdUt: jd) -
              moonRiseTargetAltitudeDeg(jd);
      expect(margin(jdUt - 20.0 / 1440.0), lessThan(0.0),
          reason: 'below target 20 min before the rise');
      expect(margin(jdUt + 20.0 / 1440.0), greaterThan(0.0),
          reason: 'above target 20 min after the rise');
    });
  }

  test('successive-day moonrise drift is lunar (20-100 min per day)', () {
    int minutes(DateTime t) => t.hour * 60 + t.minute;
    final f15 = moonriseNpt(year: 2026, month: 2, day: 15)!;
    final f16 = moonriseNpt(year: 2026, month: 2, day: 16)!;
    final m02 = moonriseNpt(year: 2026, month: 3, day: 2)!;
    final m03 = moonriseNpt(year: 2026, month: 3, day: 3)!;
    final s14 = moonriseNpt(year: 2026, month: 9, day: 14)!;
    final s15 = moonriseNpt(year: 2026, month: 9, day: 15)!;
    final drifts = [
      minutes(f16) - minutes(f15),
      minutes(m03) - minutes(m02),
      minutes(s15) - minutes(s14),
    ];
    for (final drift in drifts) {
      expect(drift, allOf(greaterThan(20), lessThan(100)),
          reason: 'moonrise advances ~24.8h/24h = ~50 min/day; a drift '
              'outside 20-100 min signals a solver defect');
    }
  });
}
