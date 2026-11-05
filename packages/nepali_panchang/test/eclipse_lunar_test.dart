import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Structural tests and NASA receipt bands for the L6 geocentric lunar
/// eclipse solver (HYA-421 step 1).
///
/// The receipts are the two lunar eclipses of 2026 from the NASA/GSFC
/// 'Eclipses During 2026' bulletin, parsed programmatically on 2026-11-05
/// into test/fixtures/nasa_lunar_2026.json - never hand-transcribed. The
/// engine defaults to the same Danjon 1/85 shadow enlargement NASA
/// tabulates with (collision C1; the Chauvenet 1/50 rule is decoded and
/// exposed in eclipse_lunar.dart, never silently substituted). Contact
/// bands are provisional at 3 min; measured deltas are within 1.2 min and
/// can be tightened once the Swiss cross-check records them.

Map<String, dynamic> _loadFixture() {
  final file = File('test/fixtures/nasa_lunar_2026.json');
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  // CI runs from the package root; also try the repo-root variant.
  final alt =
      File('packages/nepali_panchang/test/fixtures/nasa_lunar_2026.json');
  return jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
}

/// Engine instant minus the NASA receipt instant, in minutes.
double _deltaMinutes(double jdUt, DateTime date, int nasaMinutes) {
  final nasaJd =
      julianDayFromCivil(date.year, date.month, date.day.toDouble()) +
          nasaMinutes / 1440.0;
  return (jdUt - nasaJd) * 1440.0;
}

void main() {
  final data = _loadFixture();
  final eclipses = (data['eclipses'] as List).cast<Map<String, dynamic>>();

  test('fixture schema is the NASA 2026 lunar receipts corpus', () {
    expect(data['schema'], 'nmiti-nasa-lunar-2026/1');
    expect(data['crawl_date'], '2026-11-05');
    expect(data['source'], 'https://eclipse.gsfc.nasa.gov/OH/OH2026.html');
    expect(eclipses.length, 2);
  });

  for (final e in eclipses) {
    final date = DateTime.parse(e['date'] as String);
    final dateStr = e['date'] as String;
    final phases = e['phases'] as Map<String, dynamic>;
    final receiptType = e['type'] as String;
    final circumstances = lunarEclipseNear(date.year, date.month, date.day);

    if (circumstances == null) {
      // Keep the receipt date visible in the failure.
      group('NASA receipt ' + dateStr, () {
        test('eclipse is detected with the NASA type', () {
          fail('no lunar eclipse found for ' + dateStr);
        });
      });
      continue;
    }
    final c = circumstances;

    group('NASA receipt ' + dateStr, () {
      test('eclipse is detected with the NASA type', () {
        expect(c.type.name, receiptType);
      });

      test('all contacts within 3 min of NASA (provisional band)', () {
        final checks = <String, double?>{
          'penumbral_start': c.jdUtPenumbralStart,
          'partial_start': c.jdUtPartialStart,
          'total_start': c.jdUtTotalStart,
          'greatest': c.jdUtGreatest,
          'total_end': c.jdUtTotalEnd,
          'partial_end': c.jdUtPartialEnd,
          'penumbral_end': c.jdUtPenumbralEnd,
        };
        for (final check in checks.entries) {
          final receipt = phases[check.key] as Map<String, dynamic>?;
          if (receipt == null) {
            expect(check.value, isNull,
                reason: check.key + ' must not exist for ' + dateStr);
            continue;
          }
          expect(check.value, isNotNull,
              reason: check.key + ' missing for ' + dateStr);
          final delta =
              _deltaMinutes(check.value!, date, receipt['minutes'] as int);
          expect(delta.abs(), lessThanOrEqualTo(3.0),
              reason: check.key +
                  ' off by ' +
                  delta.toStringAsFixed(2) +
                  ' min vs NASA on ' +
                  dateStr);
        }
      });

      test('magnitudes within the NASA bands', () {
        expect(
            (c.umbralMagnitude - (e['umbral_magnitude'] as num)).abs(),
            lessThanOrEqualTo(0.01));
        expect(
            (c.penumbralMagnitude - (e['penumbral_magnitude'] as num)).abs(),
            lessThanOrEqualTo(0.03));
      });

      test('phase order, durations and type thresholds are sane', () {
        expect(c.jdUtGreatest, greaterThan(c.jdUtPenumbralStart));
        expect(c.jdUtGreatest, lessThan(c.jdUtPenumbralEnd));
        // The whole penumbral event lasts at most about six hours.
        expect(
            (c.jdUtPenumbralEnd - c.jdUtPenumbralStart) * 1440.0,
            lessThan(360.0));
        if (c.jdUtPartialStart != null) {
          expect(c.jdUtPartialStart!, greaterThan(c.jdUtPenumbralStart));
          expect(c.jdUtPartialEnd!, lessThan(c.jdUtPenumbralEnd));
        }
        if (c.jdUtTotalStart != null) {
          expect(c.jdUtTotalStart!, greaterThan(c.jdUtPartialStart!));
          expect(c.jdUtTotalEnd!, lessThan(c.jdUtPartialEnd!));
          expect(c.jdUtGreatest, greaterThan(c.jdUtTotalStart!));
          expect(c.jdUtGreatest, lessThan(c.jdUtTotalEnd!));
          // Totality of a total lunar eclipse lasts tens of minutes to
          // hours (Mar 3 2026: about 59 min).
          expect((c.jdUtTotalEnd! - c.jdUtTotalStart!) * 1440.0,
              greaterThan(20.0));
        }
        if (c.type == LunarEclipseType.penumbral) {
          expect(c.umbralMagnitude, lessThan(0.0));
        } else if (c.type == LunarEclipseType.partial) {
          expect(c.umbralMagnitude, greaterThan(0.0));
          expect(c.umbralMagnitude, lessThan(1.0));
        } else {
          expect(c.umbralMagnitude, greaterThan(1.0));
        }
      });

      test('greatest sits near the midpoint of the contacts', () {
        final mid = c.jdUtPenumbralStart +
            (c.jdUtPenumbralEnd - c.jdUtPenumbralStart) / 2.0;
        expect((c.jdUtGreatest - mid).abs() * 1440.0, lessThan(3.0));
      });
    });
  }

  test('non-eclipse dates return null', () {
    // 2026-04-01 has no nearby full moon at all; 2026-04-02 has a full
    // moon with no eclipse; 2026-05-10 is mid-lunation.
    expect(lunarEclipseNear(2026, 4, 1), isNull);
    expect(lunarEclipseNear(2026, 4, 2), isNull);
    expect(lunarEclipseNear(2026, 5, 10), isNull);
  });

  test('2026 has exactly the two NASA lunar eclipses, on the right dates', () {
    final year = lunarEclipsesInYear(2026);
    expect(year.length, 2);
    // Greatest eclipses 2026-03-03 11:34 UT and 2026-08-28 04:13 UT.
    final first = dateTimeUtcFromJd(year[0].jdUtGreatest);
    expect(first.year, 2026);
    expect(first.month, 3);
    expect(first.day, 3);
    expect(year[0].type, LunarEclipseType.total);
    final second = dateTimeUtcFromJd(year[1].jdUtGreatest);
    expect(second.month, 8);
    expect(second.day, 28);
    expect(year[1].type, LunarEclipseType.partial);
  });

  test('Chauvenet 1/50 rule is decoded and exposed (collision C1)', () {
    final danjon = lunarEclipseNear(2026, 8, 28)!;
    final chauvenet = lunarEclipseNear(2026, 8, 28,
        shadowEnlargement: chauvenetShadowEnlargement)!;
    // Chauvenet's larger enlargement widens both cones: contacts move
    // outward and the magnitude grows. It must not change the type.
    expect(
        chauvenet.jdUtPenumbralStart, lessThan(danjon.jdUtPenumbralStart));
    expect(chauvenet.jdUtPenumbralEnd, greaterThan(danjon.jdUtPenumbralEnd));
    expect(chauvenet.umbralMagnitude, greaterThan(danjon.umbralMagnitude));
    expect(chauvenet.type, LunarEclipseType.partial);
  });
}
