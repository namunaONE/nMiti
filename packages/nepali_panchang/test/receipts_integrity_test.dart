import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Golden-fixture integrity test for the nMiti lunar calibration corpus.
///
/// Loads test/fixtures/lunar_receipts_2026_11.json (live-crawled publisher
/// receipts for Nov 9-28, 2026, crawled 2026-11-04) and verifies that the
/// corpus is internally consistent: every receipt is complete, every
/// (limb, source) chain is strictly monotone with physically plausible
/// intervals and correct element chaining, and the supporting karana /
/// sunrise / flags sections are intact.
///
/// This test deliberately validates data integrity only. Engine-vs-fixture
/// calibration (does the solver reproduce these published boundaries?)
/// lands with the lunar limb solver.
void main() {
  final file = File('test/fixtures/lunar_receipts_2026_11.json');
  final Map<String, dynamic> data;
  if (file.existsSync()) {
    data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } else {
    // CI runs from the package root; also try the repo-root variant.
    final alt = File('packages/nepali_panchang/test/fixtures/lunar_receipts_2026_11.json');
    data = jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
  }

  test('fixture file exists and declares the expected schema', () {
    expect(data['schema'], 'nmiti-lunar-receipts/1');
    expect(data['crawl_date'], '2026-11-04');
    expect(data['page_window'], isNotNull);
  });

  final boundaries = (data['boundaries'] as List).cast<Map<String, dynamic>>();

  test('boundary counts per limb and source', () {
    final counts = <String, int>{};
    for (final b in boundaries) {
      final key = '${b['limb']}/${b['source']}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    expect(counts['tithi/bb'], 20);
    expect(counts['nakshatra/bb'], 20);
    expect(counts['yoga/bb'], 20);
    expect(counts['tithi/hp'], 19);
    expect(counts['nakshatra/hp'], 19);
    expect(counts['yoga/hp'], 19);
    expect(boundaries.length, 117);
  });

  test('every boundary receipt is complete and well-formed', () {
    for (final b in boundaries) {
      final limb = b['limb'] as String?;
      expect(limb, anyOf('tithi', 'nakshatra', 'yoga'),
          reason: 'unknown limb in receipt $b');
      expect(b['source'], anyOf('bb', 'hp'), reason: 'unknown source in $b');
      expect((b['ends'] as String?)?.isNotEmpty, isTrue, reason: 'missing ends in $b');
      expect((b['begins'] as String?)?.isNotEmpty, isTrue, reason: 'missing begins in $b');
      expect(b['published_npt'], isA<String>(), reason: 'missing published_npt in $b');
      // Must parse as an ISO local NPT instant.
      DateTime.parse(b['published_npt'] as String);
      DateTime.parse(b['page_date'] as String);
      expect(b['crawl_date'], '2026-11-04', reason: 'unexpected crawl_date in $b');
    }
  });

  test('chains are monotone, intervals plausible, elements chain correctly', () {
    const limbSpanDeg = <String, double>{
      'tithi': 12.0,
      'nakshatra': 360.0 / 27.0,
      'yoga': 360.0 / 27.0,
    };
    for (final limb in ['tithi', 'nakshatra', 'yoga']) {
      for (final source in ['bb', 'hp']) {
        final chain = boundaries
            .where((b) => b['limb'] == limb && b['source'] == source)
            .toList();
        expect(chain, isNotEmpty, reason: 'empty chain $limb/$source');
        var prevTime = DateTime.parse(chain.first['published_npt'] as String);
        for (var i = 1; i < chain.length; i++) {
          final row = chain[i];
          final t = DateTime.parse(row['published_npt'] as String);
          final gap = row['prev_gap'] == true;
          final minutes = t.difference(prevTime).inMinutes;
          expect(minutes > 0, isTrue,
              reason: '$limb/$source not strictly increasing at ${row['published_npt']}');
          final hours = minutes / 60.0;
          if (gap) {
            // One boundary was not displayed: interval spans two limb steps.
            expect(hours, greaterThanOrEqualTo(38),
                reason: '$limb/$source gap interval too short at ${row['published_npt']}');
            expect(hours, lessThanOrEqualTo(58),
                reason: '$limb/$source gap interval too long at ${row['published_npt']}');
          } else {
            expect(hours, greaterThanOrEqualTo(18),
                reason: '$limb/$source interval too short at ${row['published_npt']}');
            expect(hours, lessThanOrEqualTo(30),
                reason: '$limb/$source interval too long at ${row['published_npt']}');
            // Consecutive receipts must chain: begins of the previous row
            // equals ends of this row.
            expect(chain[i - 1]['begins'], row['ends'],
                reason: '$limb/$source element chain broken before ${row['published_npt']}');
            // Implied mean speed across the interval must be physical.
            final spanDeg = limbSpanDeg[limb]!;
            final degPerDay = spanDeg / (hours / 24.0);
            expect(degPerDay, greaterThan(9.0),
                reason: '$limb/$source implied speed too low at ${row['published_npt']}');
            expect(degPerDay, lessThan(18.5),
                reason: '$limb/$source implied speed too high at ${row['published_npt']}');
          }
          prevTime = t;
        }
      }
    }
  });

  test('karana section: 40 receipts, 20 per source, unique per date', () {
    final karanas = (data['karana'] as List).cast<Map<String, dynamic>>();
    expect(karanas.length, 40);
    final seen = <String>{};
    for (final k in karanas) {
      expect(k['source'], anyOf('bb', 'hp'));
      expect(k['reference'], anyOf('noon', 'udaya'));
      expect((k['class'] as String?)?.isNotEmpty, isTrue);
      final key = '${k['date']}/${k['source']}';
      expect(seen.contains(key), isFalse, reason: 'duplicate karana receipt $key');
      seen.add(key);
      DateTime.parse(k['date'] as String);
    }
    expect(karanas.where((k) => k['source'] == 'bb').length, 20);
    expect(karanas.where((k) => k['source'] == 'hp').length, 20);
  });

  test('sunrise section: 40 receipts, 20 per source, plausible times', () {
    final sunrises = (data['sunrise'] as List).cast<Map<String, dynamic>>();
    expect(sunrises.length, 40);
    final seen = <String>{};
    for (final s in sunrises) {
      expect(s['source'], anyOf('bb', 'hp'));
      final key = '${s['date']}/${s['source']}';
      expect(seen.contains(key), isFalse, reason: 'duplicate sunrise receipt $key');
      seen.add(key);
      final npt = s['npt'] as String;
      final parts = npt.split(':');
      expect(parts.length, 2, reason: 'bad sunrise time $npt');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      expect(hour, inInclusiveRange(4, 8), reason: 'sunrise hour out of band: $npt');
      expect(minute, inInclusiveRange(0, 59), reason: 'sunrise minute out of band: $npt');
      DateTime.parse(s['date'] as String);
    }
    expect(sunrises.where((s) => s['source'] == 'bb').length, 20);
    expect(sunrises.where((s) => s['source'] == 'hp').length, 20);
  });

  test('flags section records the Nov 18-19 Navami vriddhi', () {
    final flags = (data['flags'] as List).cast<Map<String, dynamic>>();
    expect(flags, isNotEmpty);
    final navami = flags.any(
        (f) => f['flag'] == 'shukla-vriddhi/kshaya' && f['date'] == '2026-11-19');
    expect(navami, isTrue, reason: 'Navami vriddhi flag receipt missing');
  });
}
