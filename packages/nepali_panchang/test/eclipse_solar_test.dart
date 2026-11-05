import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Structural tests and publisher receipt bands for the L6 local solar
/// eclipse circumstances solver (HYA-421 step 2).
///
/// The receipts were parsed programmatically on 2026-11-05 into
/// test/fixtures/solar_kathmandu_receipts.json - never hand-transcribed -
/// from timeanddate (canonical, including the 'Not Visible in
/// Kathmandu' evidence), time.now and heliora, for Kathmandu
/// (27.7172 N, 85.324 E), all in local NPT wall-clock time.
///
/// The pinned visible event is 2 Aug 2027, the first solar eclipse
/// visible from Kathmandu in the engine's live era (a shallow partial of
/// magnitude 0.075). Contact bands are provisional at 4 min; measured
/// deltas are within 48 s of timeanddate and 58 s of time.now, dominated
/// by the sources' own Delta-T choice - timeanddate's receipt records
/// Delta T = 69.8 s while the engine's Espenak-Meeus polynomial gives
/// about 75.7 s for mid-2027, a named seconds-level contributor.
/// Magnitude band 0.01 (measured -0.0014), obscuration band 0.01
/// absolute (measured -0.0009 vs time.now and -0.0001 vs heliora), Sun
/// altitude band 2 deg (measured within 0.13 deg).
///
/// The two below-horizon grazes (12 Aug 2026 and 6 Feb 2027) are real
/// penumbral hits that timeanddate lists as not visible: the penumbra
/// reaches past the terminator, so the engine keeps them with
/// visibility belowHorizon per the display policy, gated on the Sun's
/// altitude at the contacts - never on the separation alone.

Map<String, dynamic> _loadFixture() {
  final file = File('test/fixtures/solar_kathmandu_receipts.json');
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  // CI runs from the package root; also try the repo-root variant.
  final alt = File(
      'packages/nepali_panchang/test/fixtures/solar_kathmandu_receipts.json');
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

  test('fixture schema is the Kathmandu solar receipts corpus', () {
    expect(data['schema'], 'nmiti-solar-kathmandu-receipts/1');
    expect(data['crawl_date'], '2026-11-05');
    expect(data['location'] as Map, isNotEmpty);
    expect(eclipses.length, 3);
  });

  for (final e in eclipses) {
    final date = DateTime.parse(e['date'] as String);
    final dateStr = e['date'] as String;
    final receiptVisibility = e['visibility'] as String;
    final sources = e['sources'] as Map<String, dynamic>;
    final circumstances = solarEclipseNear(date.year, date.month, date.day);

    if (circumstances == null) {
      // Keep the receipt date visible in the failure.
      group('Kathmandu receipt ' + dateStr, () {
        test('graze is detected', () {
          fail('no solar eclipse graze found for ' + dateStr);
        });
      });
      continue;
    }
    final c = circumstances;

    group('Kathmandu receipt ' + dateStr, () {
      test('visibility matches the receipt', () {
        expect(c.visibility.name, receiptVisibility);
      });

      test('phase order, magnitude and obscuration are sane', () {
        expect(c.jdUtPartialStart, lessThan(c.jdUtGreatest));
        expect(c.jdUtGreatest, lessThan(c.jdUtPartialEnd));
        // A local partial never lasts longer than the penumbral crossing.
        expect((c.jdUtPartialEnd - c.jdUtPartialStart) * 1440.0,
            lessThan(360.0));
        expect(c.magnitude, greaterThan(0.0));
        expect(c.magnitude, lessThan(1.0));
        // Kathmandu never sees a central phase in this era: the receipts
        // pin grazes only.
        expect(c.centralAtGreatest, isFalse);
        expect(c.jdUtCentralStart, isNull);
        expect(c.jdUtCentralEnd, isNull);
        // Area overlap is always shallower than the diameter fraction.
        expect(c.obscuration, greaterThan(0.0));
        expect(c.obscuration, lessThan(c.magnitude));
      });

      test('contacts and greatest within 4 min of every clock receipt', () {
        final checks = <String, double>{
          'partial_start': c.jdUtPartialStart,
          'greatest': c.jdUtGreatest,
          'partial_end': c.jdUtPartialEnd,
        };
        for (final src in sources.entries) {
          final s = src.value as Map<String, dynamic>;
          for (final check in checks.entries) {
            final receipt = s[check.key] as String?;
            if (receipt == null) {
              continue; // not-visible receipts carry no clock times
            }
            final delta = _deltaMinutesNpt(check.value, date, receipt);
            expect(delta.abs(), lessThanOrEqualTo(4.0),
                reason: check.key +
                    ' off by ' +
                    delta.toStringAsFixed(2) +
                    ' min vs ' +
                    src.key +
                    ' on ' +
                    dateStr);
          }
        }
      });

      test('magnitude, obscuration and altitudes within the bands', () {
        final tad = sources['timeanddate'] as Map<String, dynamic>?;
        if (tad != null && tad['magnitude'] != null) {
          expect((c.magnitude - (tad['magnitude'] as num)).abs(),
              lessThanOrEqualTo(0.01));
          expect(
              (c.sunAltitudeDegAtStart - (tad['sun_alt_at_start_deg'] as num))
                  .abs(),
              lessThanOrEqualTo(2.0));
          expect((c.sunAltitudeDegAtGreatest -
                  (tad['sun_alt_at_greatest_deg'] as num))
              .abs(),
              lessThanOrEqualTo(2.0));
          expect(
              (c.sunAltitudeDegAtEnd - (tad['sun_alt_at_end_deg'] as num))
                  .abs(),
              lessThanOrEqualTo(2.0));
        }
        final tn = sources['time_now'] as Map<String, dynamic>?;
        if (tn != null && tn['obscuration'] != null) {
          expect((c.obscuration - (tn['obscuration'] as num)).abs(),
              lessThanOrEqualTo(0.01));
        }
        final hel = sources['heliora'] as Map<String, dynamic>?;
        if (hel != null && hel['obscuration'] != null) {
          expect((c.obscuration - (hel['obscuration'] as num)).abs(),
              lessThanOrEqualTo(0.01));
        }
      });

      test('the visibility gate is honest about the Sun altitude', () {
        if (c.visibility == SolarEclipseVisibility.belowHorizon) {
          expect(c.sunAltitudeDegAtStart, lessThan(0.0));
          expect(c.sunAltitudeDegAtGreatest, lessThan(0.0));
          expect(c.sunAltitudeDegAtEnd, lessThan(0.0));
        } else if (c.visibility == SolarEclipseVisibility.aboveHorizon) {
          expect(c.sunAltitudeDegAtStart, greaterThan(0.0));
          expect(c.sunAltitudeDegAtGreatest, greaterThan(0.0));
          expect(c.sunAltitudeDegAtEnd, greaterThan(0.0));
        }
      });
    });
  }

  for (final ne
      in (data['non_events'] as List).cast<Map<String, dynamic>>()) {
    final date = DateTime.parse(ne['date'] as String);
    test('non-event ' + (ne['date'] as String) + ' returns null', () {
      // The 17 Feb 2026 annular never brings the penumbra to Kathmandu:
      // 22.6 arcmin of margin, far above any ephemeris difference.
      expect(solarEclipseNear(date.year, date.month, date.day), isNull);
    });
  }

  test('a mid-lunation date with no graze returns null', () {
    expect(solarEclipseNear(2026, 12, 20), isNull);
  });

  test('2026 has exactly the one below-horizon graze, on 12 August', () {
    final year = solarEclipsesInYear(2026);
    expect(year.length, 1);
    final g = dateTimeUtcFromJd(year[0].jdUtGreatest);
    expect(g.year, 2026);
    expect(g.month, 8);
    expect(g.day, 12);
    expect(year[0].visibility, SolarEclipseVisibility.belowHorizon);
  });

  test('2027 has exactly the two grazes: 6 Feb below the horizon,'
      ' 2 Aug visible', () {
    final year = solarEclipsesInYear(2027);
    expect(year.length, 2);
    final first = dateTimeUtcFromJd(year[0].jdUtGreatest);
    expect(first.month, 2);
    expect(first.day, 6);
    expect(year[0].visibility, SolarEclipseVisibility.belowHorizon);
    final second = dateTimeUtcFromJd(year[1].jdUtGreatest);
    expect(second.month, 8);
    expect(second.day, 2);
    expect(year[1].visibility, SolarEclipseVisibility.aboveHorizon);
  });
}
