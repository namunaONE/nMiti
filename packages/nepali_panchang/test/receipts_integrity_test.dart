import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Golden-fixture integrity tests for the nMiti lunar calibration corpus.
///
/// Loads every test/fixtures/lunar_receipts_*.json corpus (live-crawled
/// publisher receipts: Nov 9-28, 2026 and Oct 18 - Nov 4, 2026, both crawled
/// 2026-11-04; Dec 1-31, 2026 advance-crawled 2026-11-07) and verifies that
/// each corpus is internally consistent:
/// every receipt is complete, every (limb, source) chain is strictly
/// monotone with physically plausible intervals and correct element
/// chaining, and the supporting karana / sunrise / flags sections are
/// intact.
///
/// This test deliberately validates data integrity only. Engine-vs-fixture
/// calibration (does the solver reproduce these published boundaries?)
/// lives in receipts_calibration_test.dart.

/// Golden boundary counts per (limb, source) chain, per corpus file.
const _expectedBoundaryCounts = <String, Map<String, int>>{
  'lunar_receipts_2026_11.json': {
    'tithi/bb': 20,
    'nakshatra/bb': 20,
    'yoga/bb': 20,
    'tithi/hp': 19,
    'nakshatra/hp': 19,
    'yoga/hp': 19,
  },
  'lunar_receipts_2026_10.json': {
    'tithi/bb': 20,
    'nakshatra/bb': 18,
    'yoga/bb': 17,
    'tithi/hp': 18,
    'nakshatra/hp': 18,
    'yoga/hp': 18,
  },
  'lunar_receipts_2026_12.json': {
    'tithi/bb': 30,
    'nakshatra/bb': 29,
    'yoga/bb': 31,
    'tithi/hp': 30,
    'nakshatra/hp': 30,
    'yoga/hp': 31,
  },
};

/// Golden per-source day counts (karana and sunrise receipts) per corpus.
const _expectedPerSourceDays = <String, int>{
  'lunar_receipts_2026_11.json': 20,
  'lunar_receipts_2026_10.json': 18,
  'lunar_receipts_2026_12.json': 31,
};

/// Golden flag receipts (flag + date) that must be present per corpus.
const _expectedFlags = <String, List<Map<String, String>>>{
  'lunar_receipts_2026_11.json': [
    {'flag': 'shukla-vriddhi/kshaya', 'date': '2026-11-19'},
  ],
  'lunar_receipts_2026_10.json': [
    {'flag': 'shukla-vriddhi/kshaya', 'date': '2026-10-18'},
    {'flag': 'shukla-vriddhi/kshaya', 'date': '2026-10-28'},
    {'flag': 'publisher-naming-bug', 'date': '2026-10-18'},
  ],
  'lunar_receipts_2026_12.json': [
    {'flag': 'shukla-vriddhi/kshaya', 'date': '2026-12-10'},
    {'flag': 'publisher-naming-bug', 'date': '2026-12-14'},
    {'flag': 'udaya-display-gap', 'date': '2026-12-25'},
  ],
};

/// Golden crawl dates per corpus.
const _expectedCrawlDate = <String, String>{
  'lunar_receipts_2026_11.json': '2026-11-04',
  'lunar_receipts_2026_10.json': '2026-11-04',
  'lunar_receipts_2026_12.json': '2026-11-07',
};

void main() {
  for (final fileName in _expectedBoundaryCounts.keys) {
    group('corpus $fileName', () {
      final file = File('test/fixtures/$fileName');
      final Map<String, dynamic> data;
      if (file.existsSync()) {
        data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } else {
        // CI runs from the package root; also try the repo-root variant.
        final alt =
            File('packages/nepali_panchang/test/fixtures/$fileName');
        data = jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
      }

      final expectedCounts = _expectedBoundaryCounts[fileName]!;
      final expectedTotal =
          expectedCounts.values.fold<int>(0, (a, c) => a + c);
      final expectedDays = _expectedPerSourceDays[fileName]!;
      final boundaries =
          (data['boundaries'] as List).cast<Map<String, dynamic>>();

      test('fixture file exists and declares the expected schema', () {
        expect(data['schema'], 'nmiti-lunar-receipts/1');
        expect(data['crawl_date'], _expectedCrawlDate[fileName]);
        expect(data['page_window'], isNotNull);
      });

      test('boundary counts per limb and source', () {
        final counts = <String, int>{};
        for (final b in boundaries) {
          final key = '${b['limb']}/${b['source']}';
          counts[key] = (counts[key] ?? 0) + 1;
        }
        for (final entry in expectedCounts.entries) {
          expect(counts[entry.key], entry.value,
              reason: 'unexpected count for ${entry.key}');
        }
        expect(boundaries.length, expectedTotal);
      });

      test('every boundary receipt is complete and well-formed', () {
        for (final b in boundaries) {
          final limb = b['limb'] as String?;
          expect(limb, anyOf('tithi', 'nakshatra', 'yoga'),
              reason: 'unknown limb in receipt $b');
          expect(b['source'], anyOf('bb', 'hp'),
              reason: 'unknown source in $b');
          expect((b['ends'] as String?)?.isNotEmpty, isTrue,
              reason: 'missing ends in $b');
          expect((b['begins'] as String?)?.isNotEmpty, isTrue,
              reason: 'missing begins in $b');
          expect(b['published_npt'], isA<String>(),
              reason: 'missing published_npt in $b');
          // Must parse as an ISO local NPT instant.
          DateTime.parse(b['published_npt'] as String);
          DateTime.parse(b['page_date'] as String);
          expect(b['crawl_date'], _expectedCrawlDate[fileName],
              reason: 'unexpected crawl_date in $b');
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
            var prevTime =
                DateTime.parse(chain.first['published_npt'] as String);
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

      test('karana section: one receipt per source per day, unique', () {
        final karanas = (data['karana'] as List).cast<Map<String, dynamic>>();
        expect(karanas.length, expectedDays * 2);
        final seen = <String>{};
        for (final k in karanas) {
          expect(k['source'], anyOf('bb', 'hp'));
          expect(k['reference'], anyOf('noon', 'udaya'));
          expect((k['class'] as String?)?.isNotEmpty, isTrue);
          final key = '${k['date']}/${k['source']}';
          expect(seen.contains(key), isFalse,
              reason: 'duplicate karana receipt $key');
          seen.add(key);
          DateTime.parse(k['date'] as String);
        }
        expect(karanas.where((k) => k['source'] == 'bb').length, expectedDays);
        expect(karanas.where((k) => k['source'] == 'hp').length, expectedDays);
      });

      test('sunrise section: one receipt per source per day, plausible times', () {
        final sunrises = (data['sunrise'] as List).cast<Map<String, dynamic>>();
        expect(sunrises.length, expectedDays * 2);
        final seen = <String>{};
        for (final s in sunrises) {
          expect(s['source'], anyOf('bb', 'hp'));
          final key = '${s['date']}/${s['source']}';
          expect(seen.contains(key), isFalse,
              reason: 'duplicate sunrise receipt $key');
          seen.add(key);
          final npt = s['npt'] as String;
          final parts = npt.split(':');
          expect(parts.length, 2, reason: 'bad sunrise time $npt');
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          expect(hour, inInclusiveRange(4, 8),
              reason: 'sunrise hour out of band: $npt');
          expect(minute, inInclusiveRange(0, 59),
              reason: 'sunrise minute out of band: $npt');
          DateTime.parse(s['date'] as String);
        }
        expect(sunrises.where((s) => s['source'] == 'bb').length, expectedDays);
        expect(sunrises.where((s) => s['source'] == 'hp').length, expectedDays);
      });

      test('flags section records the corpus vriddhi/kshaya days', () {
        final flags = (data['flags'] as List).cast<Map<String, dynamic>>();
        expect(flags, isNotEmpty);
        for (final expected in _expectedFlags[fileName]!) {
          final found = flags.any((f) =>
              f['flag'] == expected['flag'] &&
              f['date'] == expected['date']);
          expect(found, isTrue,
              reason:
                  'flag receipt missing: ${expected['flag']} on ${expected['date']}');
        }
      });
    });
  }
}
