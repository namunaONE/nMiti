import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Structural tests and provisional receipt bands for the L4 sunset solver
/// (HYA-420 step 1).
///
/// The receipts corpus (BhaktiBharat Kathmandu daily pages, 2026-11-05 ..
/// 2026-11-22, crawled 2026-11-05) pins the published sunsets. The engine
/// tracks BhaktiBharat at a constant -3 min (their display convention, the
/// mirror of their +4 min sunrise convention) and matched the
/// hinducalculator 2026-11-05 spot receipt exactly. Bands are provisional
/// until the Swiss cross-check (HYA-369) records its sunrise/sunset deltas.

Map<String, dynamic> _loadFixture() {
  final file = File('test/fixtures/muhurta_receipts_2026_11.json');
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  // CI runs from the package root; also try the repo-root variant.
  final alt =
      File('packages/nepali_panchang/test/fixtures/muhurta_receipts_2026_11.json');
  return jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
}

/// NPT wall-clock minutes of the engine event for a civil date.
int _nptMinutes(double jdUt) {
  final utc = dateTimeUtcFromJd(jdUt);
  final npt = utc.add(const Duration(milliseconds: nptOffsetMs));
  return npt.hour * 60 + npt.minute;
}

int _sunsetNptMinutes(DateTime date) => _nptMinutes(sunsetJdUt(
    year: date.year, month: date.month, day: date.day));

int _sunriseNptMinutes(DateTime date) => _nptMinutes(sunriseJdUt(
    year: date.year, month: date.month, day: date.day));

void main() {
  final data = _loadFixture();
  final days = (data['days'] as List).cast<Map<String, dynamic>>();

  test('fixture schema is the muhurta receipts corpus', () {
    expect(data['schema'], 'nmiti-muhurta-receipts/1');
    expect(data['crawl_date'], '2026-11-05');
    expect(data['source'], 'bhaktibharat');
    expect(days.length, 18);
  });

  test('sunset lands in the evening, after sunrise, near-symmetric day', () {
    for (final d in days) {
      final date = DateTime.parse(d['date'] as String);
      final ss = _sunsetNptMinutes(date);
      final sr = _sunriseNptMinutes(date);
      final dateStr = d['date'] as String;
      expect(ss, greaterThan(12 * 60),
          reason: 'sunset before noon on ' + dateStr);
      expect(ss, greaterThan(sr),
          reason: 'sunset not after sunrise on ' + dateStr);
      // Early-November Kathmandu day length: about 10.6-11.1 hours.
      expect(ss - sr, greaterThanOrEqualTo(630),
          reason: 'day too short on ' + dateStr);
      expect(ss - sr, lessThanOrEqualTo(675),
          reason: 'day too long on ' + dateStr);
      // Midpoint must sit near solar noon (about 11:45-12:00 NPT).
      final mid = (sr + ss) / 2.0;
      expect(mid, greaterThanOrEqualTo(11 * 60 + 30),
          reason: 'day midpoint too early on ' + dateStr);
      expect(mid, lessThanOrEqualTo(12 * 60 + 15),
          reason: 'day midpoint too late on ' + dateStr);
    }
  });

  test('sunsetUtcHours stays in forenoon UT at the Kathmandu anchor', () {
    for (final d in days) {
      final date = DateTime.parse(d['date'] as String);
      final ut = sunsetUtcHours(
          year: date.year, month: date.month, day: date.day);
      expect(ut, greaterThan(0.0));
      expect(ut, lessThan(12.0),
          reason: 'Kathmandu sunset must land in forenoon UT');
    }
  });

  test('engine sunset vs BhaktiBharat receipts: constant offset band', () {
    // Recorded offset: -4..-3 min (engine behind their display clock).
    // Provisional band [-6, 0] until the Swiss cross-check tightens it.
    for (final d in days) {
      final date = DateTime.parse(d['date'] as String);
      final ss = _sunsetNptMinutes(date);
      final pub = ((d['sunset'] as Map<String, dynamic>)['minutes']) as int;
      final delta = ss - pub;
      expect(delta, greaterThanOrEqualTo(-6),
          reason: 'sunset too early vs BB on ' + (d['date'] as String));
      expect(delta, lessThanOrEqualTo(0),
          reason: 'sunset too late vs BB on ' + (d['date'] as String));
    }
  });

  test('engine matches the hinducalculator 2026-11-05 spot receipt', () {
    final spots = data['spot_receipts'] as Map<String, dynamic>;
    final spot = spots['hinducalculator_2026-11-05'] as Map<String, dynamic>;
    final date = DateTime.utc(2026, 11, 5);
    final ss = _sunsetNptMinutes(date);
    final sr = _sunriseNptMinutes(date);
    expect((ss - (spot['sunset'] as int)).abs(), lessThanOrEqualTo(3));
    expect((sr - (spot['sunrise'] as int)).abs(), lessThanOrEqualTo(3));
  });
}
