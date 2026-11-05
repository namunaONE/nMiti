import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Structural tests and receipt bands for the L6 grahan shastra
/// module (HYA-421 step 4).
///
/// The shastra receipts (sutak 12 h solar / 9 h lunar from the local
/// visible contacts, visibility gating, upachhaya not kept, the
/// grastodit moonrise anchor, the Khagras/Khandagras/Upachhaya naming
/// and the C1-C6 collisions) were parsed programmatically on
/// 2026-11-05 into test/fixtures/grahan_shastra_receipts.json - never
/// hand-transcribed. The lunar Kathmandu local windows come from the
/// timeanddate stage tables crawled the same day, the solar bands
/// reuse the step-2/3 corpora (solar_kathmandu_receipts.json,
/// nasa_solar_2026_2030.json).
///
/// Bands: global contacts within 4 min of the timeanddate stage
/// tables (the same provisional band the step-2 gate uses, dominated
/// by the sources' own Delta-T choice); moonrise/moonset clamps
/// within 12 min (the moonrise solver's provisional band); magnitudes
/// within 0.01 of NASA for the 2026 events and 0.02 of timeanddate
/// for 2027-2028. The sutak window arithmetic itself is exact:
/// 12 h/9 h before the local first visible contact, ending at the
/// locally visible moksha.

Map<String, dynamic> _loadFixture() {
  final file =
      File('test/fixtures/grahan_shastra_receipts.json');
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  // CI runs from the package root; also try the repo-root variant.
  final alt = File(
      'packages/nepali_panchang/test/fixtures/grahan_shastra_receipts.json');
  return jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _loadSolarFixture() {
  final file = File('test/fixtures/solar_kathmandu_receipts.json');
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  final alt = File(
      'packages/nepali_panchang/test/fixtures/solar_kathmandu_receipts.json');
  return jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _loadNasaSolarFixture() {
  final file = File('test/fixtures/nasa_solar_2026_2030.json');
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  final alt = File(
      'packages/nepali_panchang/test/fixtures/nasa_solar_2026_2030.json');
  return jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
}

/// Engine instant minus an NPT wall-clock receipt on [date], in
/// minutes; the wall clock may carry seconds.
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

/// Engine instant minus an NPT wall-clock receipt given as a full ISO
/// datetime string (which may fall on the next civil day), in minutes.
double _deltaMinutesIso(double jdUt, String nptIso) {
  final date = DateTime.parse(nptIso.substring(0, 10));
  return _deltaMinutesNpt(jdUt, date, nptIso.substring(11));
}

void main() {
  final data = _loadFixture();
  final events = (data['events'] as List).cast<Map<String, dynamic>>();

  test('fixture schema is the grahan shastra corpus', () {
    expect(data['schema'], 'nmiti-grahan-shastra-receipts/1');
    expect(data['crawl_date'], '2026-11-05');
    final sutak = data['sutak_rules'] as Map<String, dynamic>;
    expect(sutak['solar_sutak_hours'], 12);
    expect(sutak['lunar_sutak_hours'], 9);
    expect(sutak['lunar_anchor'], 'umbral first contact');
    expect(sutak['visibility_gated'], true);
    expect(sutak['penumbral_not_kept'], true);
    expect((sutak['receipts'] as List).length, greaterThanOrEqualTo(8));
    final collisions = (data['collisions'] as List).cast<Map<String, dynamic>>();
    for (final id in ['C1', 'C2', 'C3', 'C4', 'C5', 'C6']) {
      expect(collisions.any((c) => c['id'] == id), isTrue,
          reason: 'collision ' + id + ' must be recorded');
    }
    final naming = data['naming'] as Map<String, dynamic>;
    expect((naming['receipts'] as List).length, greaterThanOrEqualTo(3));
  });

  test('sutak constants and the exemption note are pinned', () {
    expect(sutakSolarHours, 12.0);
    expect(sutakLunarHours, 9.0);
    final anyEvent = grahanInYear(2026);
    expect(anyEvent, isNotEmpty);
    expect(anyEvent.first.exemptionsNote.contains('prahar'), isTrue);
  });

  for (final e in events) {
    final dateStr = e['date'] as String;
    final date = DateTime.parse(dateStr);
    final expected = e['expected'] as Map<String, dynamic>;
    final kathmandu = e['kathmandu'] as Map<String, dynamic>;
    final tad = kathmandu['timeanddate'] as Map<String, dynamic>?;

    final found = grahanNear(date.year, date.month, date.day);
    if (found == null) {
      group('Kathmandu grahan receipt ' + dateStr, () {
        test('event is detected', () {
          fail('no grahan event found for ' + dateStr);
        });
      });
      continue;
    }
    final ev = found;

    group('Kathmandu grahan receipt ' + dateStr, () {
      test('class, naming, kept and visibility flags match the receipt', () {
        expect(ev.kind, GrahanKind.chandraGrahan);
        expect(ev.grahanClass.name, expected['grahan_class'] as String);
        expect(ev.nepaliName, expected['nepali_name'] as String);
        expect(ev.keptAsGrahan, expected['kept_as_grahan'] as bool);
        expect(ev.visibleAtLocation, expected['visible'] as bool);
        expect(ev.risesEclipsed, expected['rises_eclipsed'] as bool);
        expect(ev.setsEclipsed, expected['sets_eclipsed'] as bool);
        expect(ev.lunar, isNotNull);
        expect(ev.solar, isNull);
      });

      test('sutak window arithmetic is exact and correctly gated', () {
        if (ev.visibleAtLocation && ev.keptAsGrahan) {
          expect(ev.jdUtSutakStart, isNotNull);
          expect(ev.jdUtSutakEnd, isNotNull);
          expect(
              (ev.jdUtSutakStart! -
                      (ev.jdUtVisibleStart! - sutakLunarHours / 24.0))
                  .abs(),
              lessThan(1e-9));
          expect(ev.jdUtSutakEnd, ev.jdUtVisibleEnd);
          // The sutak starts on the anchor receipt, not hand-typed:
          // 9 h before the moonrise for the grastodit case, 9 h before
          // the umbral first contact otherwise.
          final anchorIso = ev.risesEclipsed
              ? tad?['moonrise'] as String?
              : tad?['partial_start'] as String?;
          if (anchorIso != null) {
            final delta =
                _deltaMinutesIso(ev.jdUtSutakStart!, anchorIso);
            expect(delta.abs(), lessThanOrEqualTo(12.0),
                reason: 'sutak start off by ' +
                    delta.toStringAsFixed(2) +
                    ' min vs ' +
                    anchorIso);
          }
        } else {
          expect(ev.jdUtSutakStart, isNull);
          expect(ev.jdUtSutakEnd, isNull);
        }
      });

      test('global contacts within 4 min of the stage table', () {
        if (tad == null) {
          return; // not-visible receipts carry no stage table
        }
        final lunar = ev.lunar!;
        final checks = <String, double>{
          'penumbral_start': lunar.jdUtPenumbralStart,
          'partial_start': lunar.jdUtPartialStart ?? -1,
          'total_start': lunar.jdUtTotalStart ?? -1,
          'greatest': ev.jdUtGreatest,
          'total_end': lunar.jdUtTotalEnd ?? -1,
          'partial_end': lunar.jdUtPartialEnd ?? -1,
          'penumbral_end': lunar.jdUtPenumbralEnd,
        };
        for (final check in checks.entries) {
          final receipt = tad[check.key] as String?;
          if (receipt == null || check.value < 0) {
            continue;
          }
          final delta = _deltaMinutesIso(check.value, receipt);
          expect(delta.abs(), lessThanOrEqualTo(4.0),
              reason: check.key +
                  ' off by ' +
                  delta.toStringAsFixed(2) +
                  ' min vs ' +
                  receipt +
                  ' on ' +
                  dateStr);
        }
      });

      test('the local window matches the observed receipt', () {
        if (!ev.visibleAtLocation) {
          expect(ev.jdUtVisibleStart, isNull);
          expect(ev.jdUtVisibleEnd, isNull);
          expect(kathmandu['not_visible_note'] != null ||
                  (tad?['verdict'] as String?) != null,
              isTrue,
              reason: 'not-visible expectations must carry their receipt');
          return;
        }
        if (ev.risesEclipsed) {
          // Grastodit: the first visible contact is the moonrise
          // (the moonrise solver's provisional 12 min band).
          final moonrise = tad?['moonrise'] as String?;
          expect(moonrise, isNotNull,
              reason: 'a grastodit receipt must record the moonrise');
          final delta = _deltaMinutesIso(ev.jdUtVisibleStart!, moonrise!);
          expect(delta.abs(), lessThanOrEqualTo(12.0),
              reason: 'visible start (moonrise) off by ' +
                  delta.toStringAsFixed(2) +
                  ' min');
        } else if (ev.grahanClass == GrahanClass.upachhaya) {
          final start = tad?['penumbral_start'] as String?;
          if (start != null) {
            final delta = _deltaMinutesIso(ev.jdUtVisibleStart!, start);
            expect(delta.abs(), lessThanOrEqualTo(4.0));
          }
        } else {
          final start = tad?['partial_start'] as String?;
          if (start != null) {
            final delta = _deltaMinutesIso(ev.jdUtVisibleStart!, start);
            expect(delta.abs(), lessThanOrEqualTo(4.0));
          }
        }
        if (ev.setsEclipsed) {
          final moonset = tad?['moonset'] as String?;
          expect(moonset, isNotNull,
              reason: 'a sets-before-moksha receipt must record the set');
          final delta = _deltaMinutesIso(ev.jdUtVisibleEnd!, moonset!);
          expect(delta.abs(), lessThanOrEqualTo(12.0));
        } else {
          final end = tad?['partial_end'] as String? ??
              tad?['penumbral_end'] as String?;
          if (end != null && ev.keptAsGrahan) {
            final delta = _deltaMinutesIso(ev.jdUtVisibleEnd!, end);
            expect(delta.abs(), lessThanOrEqualTo(4.0));
          }
        }
      });

      test('magnitude and moksha conventions hold', () {
        final nasaMag = expected['nasa_umbral_magnitude'] as num?;
        final tadMag = tad?['magnitude'] as num?;
        if (nasaMag != null) {
          expect((ev.magnitude - nasaMag).abs(), lessThanOrEqualTo(0.01));
        } else if (tadMag != null) {
          expect((ev.magnitude - tadMag).abs(), lessThanOrEqualTo(0.02));
        }
        final lunar = ev.lunar!;
        if (ev.keptAsGrahan) {
          expect(ev.jdUtMoksha, lunar.jdUtPartialEnd);
        } else {
          // Upachhaya: moksha carried for display is the penumbral end.
          expect(ev.jdUtMoksha, lunar.jdUtPenumbralEnd);
        }
      });
    });
  }

  group('solar grahan events (step-2/3 corpora)', () {
    final solarData = _loadSolarFixture();
    final solarEvents =
        (solarData['eclipses'] as List).cast<Map<String, dynamic>>();

    test('2 Aug 2027 Khandagras Surya Grahan carries a 12 h sutak', () {
      final ev = grahanNear(2027, 8, 2);
      expect(ev, isNotNull);
      expect(ev!.kind, GrahanKind.suryaGrahan);
      expect(ev.grahanClass, GrahanClass.khandagras);
      expect(ev.nepaliName, 'Khandagras Surya Grahan');
      expect(ev.visibleAtLocation, isTrue);
      expect(ev.risesEclipsed, isFalse);
      expect(ev.setsEclipsed, isFalse);
      expect(ev.jdUtSutakStart, isNotNull);
      expect(ev.jdUtSutakEnd, ev.jdUtVisibleEnd);
      expect(
          (ev.jdUtSutakStart! -
                  (ev.jdUtVisibleStart! - sutakSolarHours / 24.0))
              .abs(),
          lessThan(1e-9));
      // The sutak start is 12 h before the timeanddate first contact
      // receipt (16:27:20 NPT), so the same 4 min band applies.
      final tad = (solarEvents
              .firstWhere((x) => x['date'] == '2027-08-02')['sources']
          as Map<String, dynamic>)['timeanddate'] as Map<String, dynamic>;
      final delta = _deltaMinutesNpt(
          ev.jdUtSutakStart!, DateTime(2027, 8, 2), tad['partial_start'] as String);
      expect(delta.abs(), lessThanOrEqualTo(4.0),
          reason: 'sutak start off by ' + delta.toStringAsFixed(2) + ' min');
    });

    test('12 Aug 2026 below-horizon solar graze carries no sutak', () {
      final ev = grahanNear(2026, 8, 12);
      expect(ev, isNotNull);
      expect(ev!.kind, GrahanKind.suryaGrahan);
      expect(ev.grahanClass, GrahanClass.khandagras);
      expect(ev.keptAsGrahan, isTrue);
      expect(ev.visibleAtLocation, isFalse);
      expect(ev.jdUtSutakStart, isNull);
      expect(ev.jdUtSutakEnd, isNull);
      expect(ev.jdUtVisibleStart, isNull);
      expect(ev.jdUtVisibleEnd, isNull);
    });

    test('17 Feb 2026 never brings the penumbra: no grahan event', () {
      expect(grahanNear(2026, 2, 17), isNull);
    });

    test('1 Jun 2030 partial solar sutak starts the previous evening', () {
      final ev = grahanNear(2030, 6, 1);
      expect(ev, isNotNull);
      expect(ev!.kind, GrahanKind.suryaGrahan);
      expect(ev.grahanClass, GrahanClass.khandagras);
      expect(ev.visibleAtLocation, isTrue);
      expect(ev.sutakStartNpt, isNotNull);
      // Contacts 11:10-13:33 NPT: the 12 h sutak begins 23:10 NPT on
      // 31 May - the display layer must know sutak windows span civil
      // days.
      expect(ev.sutakStartNpt!.month, 5);
      expect(ev.sutakStartNpt!.day, 31);
      final nasaSolar = _loadNasaSolarFixture();
      final tad = ((nasaSolar['eclipses'] as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((x) => x['date'] == '2030-06-01')['timeanddate']
          as Map<String, dynamic>);
      final delta = _deltaMinutesNpt(
          ev.jdUtVisibleStart!, DateTime(2030, 6, 1), tad['partial_start'] as String);
      expect(delta.abs(), lessThanOrEqualTo(4.0));
      expect((ev.magnitude - (tad['magnitude'] as num)).abs(),
          lessThanOrEqualTo(0.02));
    });
  });

  test('2026 has exactly the three grahan events, in time order', () {
    final year = grahanInYear(2026);
    expect(year.length, 3);
    expect(year[0].kind, GrahanKind.chandraGrahan);
    expect(year[0].greatestNpt.month, 3);
    expect(year[0].greatestNpt.day, 3);
    expect(year[0].nepaliName, 'Khagras Chandra Grahan (grastodit)');
    expect(year[1].kind, GrahanKind.suryaGrahan);
    expect(year[1].greatestNpt.month, 8);
    expect(year[1].greatestNpt.day, 12);
    expect(year[1].visibleAtLocation, isFalse);
    expect(year[2].kind, GrahanKind.chandraGrahan);
    expect(year[2].greatestNpt.day, 28);
    expect(year[2].visibleAtLocation, isFalse);
    expect(year[2].jdUtSutakStart, isNull);
  });

  test('2027 contains the pinned events with their flags', () {
    final year = grahanInYear(2027);
    final byDay = <int, GrahanEvent>{};
    for (final e in year) {
      byDay[e.greatestNpt.month * 100 + e.greatestNpt.day] = e;
    }
    final feb6 = byDay[206];
    expect(feb6, isNotNull);
    expect(feb6!.kind, GrahanKind.suryaGrahan);
    expect(feb6.visibleAtLocation, isFalse);
    expect(feb6.jdUtSutakStart, isNull);
    final feb21 = byDay[221];
    expect(feb21, isNotNull);
    expect(feb21!.grahanClass, GrahanClass.upachhaya);
    expect(feb21.keptAsGrahan, isFalse);
    expect(feb21.jdUtSutakStart, isNull);
    expect(feb21.visibleAtLocation, isTrue);
    final aug2 = byDay[802];
    expect(aug2, isNotNull);
    expect(aug2!.kind, GrahanKind.suryaGrahan);
    expect(aug2.visibleAtLocation, isTrue);
    expect(aug2.jdUtSutakStart, isNotNull);
  });

  test('2028 contains the pinned events with their flags', () {
    final year = grahanInYear(2028);
    final byDay = <int, GrahanEvent>{};
    for (final e in year) {
      byDay[e.greatestNpt.month * 100 + e.greatestNpt.day] = e;
    }
    final jan12 = byDay[112];
    expect(jan12, isNotNull);
    expect(jan12!.kind, GrahanKind.chandraGrahan);
    expect(jan12.visibleAtLocation, isFalse);
    expect(jan12.jdUtSutakStart, isNull);
    final jan26 = byDay[126];
    expect(jan26, isNotNull);
    expect(jan26!.kind, GrahanKind.suryaGrahan);
    expect(jan26.visibleAtLocation, isFalse);
    final jul6 = byDay[706];
    expect(jul6, isNotNull);
    expect(jul6!.grahanClass, GrahanClass.khandagras);
    expect(jul6.visibleAtLocation, isTrue);
    expect(jul6.jdUtSutakStart, isNotNull);
    final dec31 = byDay[1231];
    expect(dec31, isNotNull);
    expect(dec31!.grahanClass, GrahanClass.khagras);
    expect(dec31.nepaliName, 'Khagras Chandra Grahan');
    expect(dec31.visibleAtLocation, isTrue);
    expect(dec31.jdUtSutakStart, isNotNull);
  });

  test('nextGrahanAfter returns the 6 Feb 2027 graze from Nov 2026', () {
    final next = nextGrahanAfter(2026, 11, 5);
    expect(next, isNotNull);
    expect(next!.kind, GrahanKind.suryaGrahan);
    expect(next.greatestNpt.year, 2027);
    expect(next.greatestNpt.month, 2);
    expect(next.greatestNpt.day, 6);
    expect(next.visibleAtLocation, isFalse);
    expect(next.jdUtSutakStart, isNull);
  });

  test('nextGrahanAfter from 4 Mar 2026 returns the 12 Aug 2026 graze', () {
    final next = nextGrahanAfter(2026, 3, 4);
    expect(next, isNotNull);
    expect(next!.greatestNpt.month, 8);
    expect(next.greatestNpt.day, 12);
    expect(next.visibleAtLocation, isFalse);
  });

  test('a mid-lunation date with no eclipse returns null', () {
    expect(grahanNear(2026, 12, 20), isNull);
  });

  test('the conventions map decodes every collision', () {
    final ev = grahanNear(2027, 8, 2)!;
    for (final key in [
      'shadowEnlargement',
      'sutakHours',
      'sutakAnchor',
      'sutakEnd',
      'grastodit',
      'upachhaya',
      'sutakExemptions',
      'naming',
      'belowHorizonSolar',
      'publisherDivergence',
      'sutakHoursReversedFaq',
    ]) {
      expect(ev.conventions.containsKey(key), isTrue,
          reason: 'conventions must decode ' + key);
    }
    expect(ev.conventions['shadowEnlargement']!.contains('Danjon'), isTrue);
    expect(ev.provenance.contains('shastra'), isTrue);
    expect(ev.evidenceTier.contains('receipt'), isTrue);
  });
}
