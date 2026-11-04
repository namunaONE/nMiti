import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Golden-fixture calibration test (R6a-1 step 3 + R6a-2 joint, HYA-403/404).
///
/// Runs the full engine - 60-term Meeus moon, Ch.25 apparent sun, Delta T,
/// per-source ayanamsa profiles, wrap-free boundary solver - against every
/// receipt of both golden corpora crawled live from BhaktiBharat and Hamro
/// Patro (Nov 9-28, 2026 and Oct 18 - Nov 4, 2026; both crawled 2026-11-04).
/// This is the permanent minute-level accuracy gate for the lunar limb layer.
///
/// Bands were derived from pre-push sandbox calibrations of these exact
/// formulas; the wide HP bands absorb the publishers' mutual divergence
/// (documented per-receipt in the fixtures), not engine error. The Oct
/// corpus (109 boundaries) lands inside the same bands as the Nov corpus
/// (117 boundaries) - one shared band map covers both.

/// Golden per-source day counts (karana and sunrise receipts) per corpus.
const _expectedPerSourceDays = <String, int>{
  'lunar_receipts_2026_11.json': 20,
  'lunar_receipts_2026_10.json': 18,
};

/// Shared minute-level |engine - published| bands per (limb, source).
const _maxAbsDeltaMin = <String, double>{
  'tithi/bb': 1.5,
  'nakshatra/bb': 1.5,
  'yoga/bb': 2.0,
  'tithi/hp': 12.0,
  'nakshatra/hp': 10.0,
  'yoga/hp': 10.0,
};

void main() {
  final ayDelta = <String, double>{
    'bb': ayanamsaDeltaBhaktiBharat,
    'hp': ayanamsaDeltaHamroPatro,
  };

  for (final fileName in _expectedPerSourceDays.keys) {
    group('calibration corpus $fileName', () {
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
      final boundaries =
          (data['boundaries'] as List).cast<Map<String, dynamic>>();
      final expectedDays = _expectedPerSourceDays[fileName]!;

      test('engine reproduces all published boundary moments', () {
        for (final b in boundaries) {
          final limb = b['limb'] as String;
          final source = b['source'] as String;
          final ends = b['ends'] as String;
          final publishedNpt = b['published_npt'] as String;
          final delta = ayDelta[source]!;

          // Element identity from the receipt name.
          var expectedIndex = -1;
          if (limb == 'tithi') {
            expectedIndex = tithiIndexFromName(ends);
          } else if (limb == 'nakshatra') {
            expectedIndex = nakshatraNames.indexOf(ends);
          } else if (limb == 'yoga') {
            expectedIndex = yogaNames.indexOf(ends);
          } else {
            fail('unexpected limb in fixture: $limb');
          }
          expect(expectedIndex, greaterThanOrEqualTo(0),
              reason: 'unknown $limb name in fixture: $ends');

          // Probe six hours before the published end: always inside the element
          // (min limb duration in the corpus window is 18 h).
          final publishedWall = parseWallClock(publishedNpt);
          final probeJdTt =
              jdTtFromJdUt(jdFromDateTimeUtc(publishedWall) - 0.25);
          final probeIndex = limbIndex(limb, probeJdTt, delta);
          expect(probeIndex, expectedIndex,
              reason: '$limb/$source $ends element identity mismatch at '
                  '$publishedNpt: engine index $probeIndex');

          final boundaryJdTt = nextLimbBoundaryJdTt(limb, probeJdTt, delta);
          final engineWall =
              dateTimeUtcFromJd(jdUtFromJdTt(boundaryJdTt))
                  .add(const Duration(milliseconds: nptOffsetMs));
          final deltaMin =
              engineWall.difference(publishedWall).inSeconds / 60.0;

          final band = _maxAbsDeltaMin['$limb/$source']!;
          expect(deltaMin.abs(), lessThan(band),
              reason: '$limb/$source $ends ($publishedNpt): engine minus '
                  'published = ${deltaMin.toStringAsFixed(2)} min, band $band');
        }
      });

      test('karana rule table matches all published karana receipts', () {
        final karanas = (data['karana'] as List).cast<Map<String, dynamic>>();
        expect(karanas.length, expectedDays * 2);
        for (final k in karanas) {
          final date = k['date'] as String;
          final source = k['source'] as String;
          final published = k['class'] as String;
          final parts = date.split('-');
          final y = int.parse(parts[0]);
          final mo = int.parse(parts[1]);
          final d = int.parse(parts[2]);

          final DateTime refWall;
          if (k['reference'] == 'noon') {
            // BhaktiBharat convention: karana running at local noon NPT.
            refWall = DateTime.utc(y, mo, d, 12, 0);
          } else {
            // Hamro Patro convention: karana running at sunrise (udaya). Uses
            // the engine sunrise of that day.
            final rise = sunriseJdUt(year: y, month: mo, day: d);
            refWall = dateTimeUtcFromJd(rise).add(
                const Duration(milliseconds: nptOffsetMs));
          }
          final jdTt = jdTtFromJdUt(
              jdFromDateTimeUtc(refWall.subtract(
                  const Duration(milliseconds: nptOffsetMs))));
          final engine = karanaName(karanaNumber(jdTt));
          expect(_normalizeKarana(engine), _normalizeKarana(published),
              reason: '$date/$source: engine $engine vs published $published');
        }
      });

      test('sunrise solver matches the published sunrises (convention bands)',
          () {
        final sunrises = (data['sunrise'] as List).cast<Map<String, dynamic>>();
        expect(sunrises.length, expectedDays * 2);
        for (final s in sunrises) {
          final date = s['date'] as String;
          final source = s['source'] as String;
          final parts = date.split('-');
          final y = int.parse(parts[0]);
          final mo = int.parse(parts[1]);
          final d = int.parse(parts[2]);
          final publishedParts = (s['npt'] as String).split(':');
          final publishedWall = DateTime.utc(y, mo, d,
              int.parse(publishedParts[0]), int.parse(publishedParts[1]));

          final rise = sunriseJdUt(year: y, month: mo, day: d);
          final engineWall = dateTimeUtcFromJd(rise)
              .add(const Duration(milliseconds: nptOffsetMs));
          final deltaMin =
              engineWall.difference(publishedWall).inSeconds / 60.0;

          // Constant per-source convention offsets (sandbox-calibrated):
          // BhaktiBharat ~ +4.2 min, Hamro Patro ~ +0.5 min.
          double lo;
          double hi;
          if (source == 'bb') {
            lo = 2.0;
            hi = 6.0;
          } else {
            lo = -1.0;
            hi = 2.5;
          }
          expect(deltaMin, greaterThan(lo),
              reason: '$date/$source sunrise delta $deltaMin min below band');
          expect(deltaMin, lessThan(hi),
              reason: '$date/$source sunrise delta $deltaMin min above band');
        }
      });
    });
  }
}

/// Canonicalizes karana spellings across the two publishers:
/// 'Vishti (Bhadra)' -> 'vishti', BhaktiBharat 'Garija' -> Hamro 'garaja'.
String _normalizeKarana(String s) {
  var x = s.toLowerCase().replaceAll('(bhadra)', '').trim();
  if (x == 'garija') {
    x = 'garaja';
  }
  return x;
}
