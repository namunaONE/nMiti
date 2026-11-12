import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// HYA-450 (Wave 1) graha receipts: JPL Horizons DE441 apparent RA/DEC
/// converted to ecliptic of date. Bands calibrated to the post-fix
/// mirror measure - the first-CI class (mercury 6.259 / venus 16.251
/// arcsec) was the double EMB -> Earth moon correction on the
/// Earth-center vendored earth series, not theory age: lon hard 5 /
/// mean 1.5 arcsec, lat hard 5 arcsec, held in the fixture; see the
/// fixture header for the quantization floor and the crawl coverage.
void main() {
  // Dual-path: 'dart test packages' runs from the workspace root in CI
  // (festival-receipts pattern), while package-local runs sit in the
  // package dir.
  final fixturePath = File('test/fixtures/graha_receipts_2026_11.json')
          .existsSync()
      ? 'test/fixtures/graha_receipts_2026_11.json'
      : 'packages/nepali_panchang/test/fixtures/graha_receipts_2026_11.json';
  final fx = json.decode(File(fixturePath).readAsStringSync())
      as Map<String, dynamic>;
  final planets = fx['planets'] as Map<String, dynamic>;
  final bodyOf = <String, GrahaBody>{
    'mercury': GrahaBody.mercury,
    'venus': GrahaBody.venus,
    'mars': GrahaBody.mars,
    'jupiter': GrahaBody.jupiter,
    'saturn': GrahaBody.saturn,
  };
  final hardDeg = (fx['bands'] as Map<String, dynamic>)['apparent_lon_hard_deg'] as double;
  final meanDeg = (fx['bands'] as Map<String, dynamic>)['apparent_lon_mean_deg'] as double;
  final latHardDeg = (fx['bands'] as Map<String, dynamic>)['apparent_lat_hard_deg'] as double;
  final wrap180 = (double x) {
    final d = x % 360.0;
    return d > 180.0 ? d - 360.0 : (d < -180.0 ? d + 360.0 : d);
  };

  test('graha receipts: apparent longitude and latitude vs JPL Horizons',
      () {
    final lines = <String>[];
    final measured = <String, List<double>>{};
    for (final name in bodyOf.keys) {
      final body = bodyOf[name]!;
      final rows = <List<double>>[];
      final block = planets[name] as Map<String, dynamic>;
      for (final r in (block['dense'] as List).cast<List<dynamic>>()) {
        rows.add([r[0] as num, r[1] as num, r[2] as num]
            .map((e) => e.toDouble())
            .toList());
      }
      final station = block['station'] as List<dynamic>? ?? const [];
      for (final r in station.cast<List<dynamic>>()) {
        rows.add([r[0], r[1], r[2]].map((e) => (e as num).toDouble()).toList());
      }
      var sum = 0.0;
      var maxAbs = 0.0;
      var maxLat = 0.0;
      var worstJd = 0.0;
      for (final row in rows) {
        final jdUt = row[0];
        final jdTt = jdTtFromJdUt(jdUt);
        final pos = grahaPosition(body, jdTt);
        final dLon = wrap180(pos.apparentLongitudeDeg - row[1]).abs();
        final dLat = (pos.apparentLatitudeDeg - row[2]).abs();
        sum += dLon;
        if (dLon > maxAbs) {
          maxAbs = dLon;
          worstJd = jdUt;
        }
        if (dLat > maxLat) {
          maxLat = dLat;
        }
      }
      final mean = sum / rows.length;
      lines.add('$name n=${rows.length} mean=${(mean * 3600).toStringAsFixed(2)}"'
          's max=${(maxAbs * 3600).toStringAsFixed(2)}" @JD$worstJd'
          ' latMax=${(maxLat * 3600).toStringAsFixed(2)}"');
      measured[name] = [mean, maxAbs, maxLat];
    }
    // The scoreboard prints BEFORE the verdicts: a band failure must
    // still report every body's measured class (the first CI run hit
    // exactly this - the print sat behind a throwing expect).
    // ignore: avoid_print
    print('graha scoreboard (arcsec):\n${lines.join('\n')}');
    for (final name in bodyOf.keys) {
      final v = measured[name]!;
      final mean = v[0];
      final maxAbs = v[1];
      final maxLat = v[2];
      expect(mean, lessThan(meanDeg),
          reason: '$name mean ${(mean * 3600).toStringAsFixed(3)} arcsec '
          'exceeds the fixture mean band');
      expect(maxAbs, lessThan(hardDeg),
          reason: '$name max ${(maxAbs * 3600).toStringAsFixed(3)} arcsec '
          'exceeds the fixture hard band');
      expect(maxLat, lessThan(latHardDeg),
          reason: '$name lat max ${(maxLat * 3600).toStringAsFixed(3)} '
          'arcsec exceeds the fixture lat band');
    }
  });

  test('retrograde stations: solver lands on the receipt minima', () {
    // Mercury direct station: receipt lambda minimum at JD 2461358.16667.
    final m = grahaStationJdTt(GrahaBody.mercury,
        startJdTt: 2461354.0, endJdTt: 2461364.0);
    expect(m, isNotNull);
    expect(m!, inInclusiveRange(2461358.0, 2461358.4),
        reason: 'mercury direct station ${m.toStringAsFixed(5)}');
    // Venus direct station: receipt lambda minimum at JD 2461358.5.
    final v = grahaStationJdTt(GrahaBody.venus,
        startJdTt: 2461354.0, endJdTt: 2461364.0);
    expect(v, isNotNull);
    expect(v!, inInclusiveRange(2461358.35, 2461358.75),
        reason: 'venus direct station ${v.toStringAsFixed(5)}');
    // No station for Mars inside the window (all-direct 2026 receipts).
    final ma = grahaStationJdTt(GrahaBody.mars,
        startJdTt: 2461354.0, endJdTt: 2461364.0);
    expect(ma, isNull);
  });

  test('combustion and separation plumbing', () {
    // 2026-11-11 00:00 UT: Mercury/Venus deep in retro loop, far from the
    // Sun by construction of the receipts (elongations 12-25 deg).
    final jdTt = jdTtFromJdUt(2461355.5);
    for (final b in GrahaBody.values) {
      final sep = grahaSunSeparationDeg(b, jdTt);
      expect(sep, greaterThan(0.0));
      expect(sep, lessThan(180.0));
      grahaIsCombust(b, jdTt); // must not throw
    }
  });

  test('rise/set self-consistency (Kathmandu plumbing)', () {
    final rise = grahaRiseJdUt(
        body: GrahaBody.jupiter, year: 2026, month: 11, day: 11);
    final set = grahaSetJdUt(
        body: GrahaBody.jupiter, year: 2026, month: 11, day: 11);
    expect(rise, isNotNull);
    expect(set, isNotNull);
    final altRise = grahaAltitudeDeg(body: GrahaBody.jupiter, jdUt: rise!);
    expect((altRise - (-34.0 / 60.0)).abs(), lessThan(0.01));
    final altSet = grahaAltitudeDeg(body: GrahaBody.jupiter, jdUt: set!);
    expect((altSet - (-34.0 / 60.0)).abs(), lessThan(0.01));
  });
}

