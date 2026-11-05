import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// NASA solar catalog 2026-2030 reconciliation gate (HYA-421 step 3).
///
/// The corpus is the five NASA/GSFC 'Eclipses During YYYY' bulletins
/// (OH2026..OH2030), parsed programmatically on 2026-11-05 into
/// test/fixtures/nasa_solar_2026_2030.json - never hand-transcribed:
/// all twelve solar eclipses of 2026-2030 with their catalog data
/// (greatest eclipse TD/UT, Delta T, magnitude, gamma, saros), plus
/// the timeanddate Kathmandu verdict for every event and clock
/// receipts for the two visible partials.
///
/// The reconciliation, decoded during the crawl and never assumed:
/// - every event whose penumbra reaches Kathmandu with the Sun up is
///   aboveHorizon and timeanddate says visible (2 Aug 2027, 1 Jun
///   2030);
/// - every event that grazes Kathmandu at night is belowHorizon
///   while timeanddate says not visible (12 Aug 2026, 6 Feb 2027,
///   26 Jan 2028) - the penumbra reaches past the terminator;
/// - every polar/southern event returns null (7 events).
///
/// Contact bands for the visible partials are provisional at 4 min
/// (measured deltas within 48 s for 2027-08-02 with timeanddate's own
/// Delta T = 69.8 s receipt as a named contributor, within 68 s for
/// 2030-06-01 with timeanddate's stated Delta T = 0 s vs the
/// engine's Espenak-Meeus 77.8 s). Magnitude band 0.01 (measured
/// -0.0014 and +0.0014).

Map<String, dynamic> _loadFixture() {
  final file = File('test/fixtures/nasa_solar_2026_2030.json');
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  // CI runs from the package root; also try the repo-root variant.
  final alt = File(
      'packages/nepali_panchang/test/fixtures/nasa_solar_2026_2030.json');
  return jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
}

/// Engine instant minus an NPT wall-clock receipt on [date], in minutes.
double _deltaMinutesNpt(double jdUt, DateTime date, String wallClock) {
  final parts = wallClock.split(':');
  final minutes = int.parse(parts[0]) * 60.0 +
      int.parse(parts[1]) +
      (parts.length > 2 ? double.parse(parts[2]) / 60.0 : 0.0);
  // NPT = UT + 5:45, so NPT midnight is 18:15 UT of the previous UT day.
  final receiptJdUt =
      julianDayFromCivil(date.year, date.month, date.day.toDouble()) +
          minutes / 1440.0 -
          5.75 / 24.0;
  return (jdUt - receiptJdUt) * 1440.0;
}

void main() {
  final data = _loadFixture();
  final eclipses = (data['eclipses'] as List).cast<Map<String, dynamic>>();

  test('fixture schema is the NASA 2026-2030 solar catalog', () {
    expect(data['schema'], 'nmiti-nasa-solar-catalog/1');
    expect(data['crawl_date'], '2026-11-05');
    expect(eclipses.length, 12);
    final byYear = <int, int>{};
    for (final e in eclipses) {
      final y = DateTime.parse(e['date'] as String).year;
      byYear[y] = (byYear[y] ?? 0) + 1;
    }
    // 2 solar eclipses every year except 2029 (4, all partial).
    expect(byYear, {2026: 2, 2027: 2, 2028: 2, 2029: 4, 2030: 2});
  });

  test('catalog graze classes reconcile with the year scans', () {
    List<String> classesOf(int year) =>
        solarEclipsesInYear(year).map((c) => c.visibility.name).toList();
    expect(classesOf(2026), ['belowHorizon']);
    expect(classesOf(2027), ['belowHorizon', 'aboveHorizon']);
    expect(classesOf(2028), ['belowHorizon']);
    expect(classesOf(2029), isEmpty);
    expect(classesOf(2030), ['aboveHorizon']);
  });

  for (final e in eclipses) {
    final date = DateTime.parse(e['date'] as String);
    final dateStr = e['date'] as String;
    final expected = e['expected_engine_class'] as String;
    final tad = e['timeanddate'] as Map<String, dynamic>;
    final c = solarEclipseNear(date.year, date.month, date.day);

    group('NASA ' + dateStr, () {
      test('engine class matches the reconciled catalog: ' + expected, () {
        if (expected == 'null') {
          expect(c, isNull,
              reason: dateStr + ' must not graze Kathmandu at all');
        } else {
          expect(c, isNotNull,
              reason: dateStr + ' graze missing at Kathmandu');
          expect(c!.visibility.name, expected);
        }
      });

      test('NASA catalog fields are coherent', () {
        expect(e['type'] as String, anyOf('total', 'annular', 'partial'));
        expect((e['nasa_gamma'] as num).abs(), lessThan(2.0));
        final deltaT = e['nasa_delta_t_seconds'] as num;
        expect(deltaT, greaterThan(70.0));
        expect(deltaT, lessThan(80.0));
        final mag = e['nasa_magnitude'] as num;
        if (e['type'] == 'partial') {
          expect(mag, greaterThan(0.0));
          expect(mag, lessThan(1.0));
        } else {
          expect(mag, greaterThan(0.9));
        }
      });

      test('timeanddate verdict is consistent with the engine class', () {
        if (tad['verdict'] == 'visible') {
          expect(expected, 'aboveHorizon',
              reason: dateStr + ' is visible but classed ' + expected);
        } else {
          expect(expected == 'null' || expected == 'belowHorizon', isTrue,
              reason: dateStr +
                  ' is not visible but engine class is ' +
                  expected);
        }
      });

      if (expected != 'null' && c == null) {
        test('graze is detected', () {
          fail('no solar eclipse graze found for ' + dateStr);
        });
      } else if (expected != 'null') {
        final cc = c!;

        test('local greatest falls on the NASA greatest UT date', () {
          final g = dateTimeUtcFromJd(cc.jdUtGreatest);
          expect(g.year, date.year);
          expect(g.month, date.month);
          expect(g.day, date.day);
        });

        test('below-horizon grazes keep the Sun below every contact', () {
          if (expected == 'belowHorizon') {
            expect(cc.sunAltitudeDegAtStart, lessThan(0.0));
            expect(cc.sunAltitudeDegAtGreatest, lessThan(0.0));
            expect(cc.sunAltitudeDegAtEnd, lessThan(0.0));
          }
          // Kathmandu never sees a central phase in this catalog.
          expect(cc.centralAtGreatest, isFalse);
        });

        test('contacts and greatest within 4 min of the clock receipt',
            () {
          final checks = <String, double>{
            'partial_start': cc.jdUtPartialStart,
            'greatest': cc.jdUtGreatest,
            'partial_end': cc.jdUtPartialEnd,
          };
          for (final check in checks.entries) {
            final receipt = tad[check.key] as String?;
            if (receipt == null) {
              continue;
            }
            final delta = _deltaMinutesNpt(check.value, date, receipt);
            expect(delta.abs(), lessThanOrEqualTo(4.0),
                reason: check.key +
                    ' off by ' +
                    delta.toStringAsFixed(2) +
                    ' min vs timeanddate on ' +
                    dateStr);
          }
        });

        test('magnitude within 0.01 of the timeanddate receipt', () {
          final receiptMag = tad['magnitude'] as num?;
          if (receiptMag != null) {
            expect((cc.magnitude - receiptMag).abs(),
                lessThanOrEqualTo(0.01));
          }
          // Visible partials are shallow grazes by the display policy.
          expect(cc.magnitude, lessThan(0.5));
          expect(cc.obscuration, lessThan(cc.magnitude));
        });
      }
    });
  }
}
