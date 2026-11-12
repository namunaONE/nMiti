import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// HYA-450 (Wave 1 graha engine, PR-A): the permanent JPL Horizons
/// accuracy gate for the vendored VSOP87D graha channels.
///
/// Receipts-first: the fixture (test/fixtures/graha_horizons_2026.json,
/// schema nmiti-graha-horizons/1) was fetched fresh from the Horizons
/// batch CGI at authoring time (2026-11-11: 49 daily 12:00 UT instants
/// per planet, 2026-10-16 through 2026-12-03, plus 1-hour Mercury and
/// Venus station refinements over Nov 13-15) and is never retyped -
/// CENTER=500 geocentric, QUANTITIES=31 (ObsEcLon/ObsEcLat), CSV, UTC.
///
/// Bands: tropical longitude/latitude 15 arcsec against the apparent
/// observer ecliptic place (the band carries the light-time and
/// aberration convention matches, the VSOP87D truncation tails and
/// the nutation-frame class); the Mercury and Venus retrograde
/// stations from the engine's rate bisection must land within 90
/// minutes of the fixture's hourly-grid minimum; Mars, Jupiter and
/// Saturn must stay direct across the whole window.
void main() {
  // 'dart test packages' (CI) runs from the workspace root while a
  // local 'dart test' runs from the package dir - resolve the fixture
  // the same dual-path way as festival_receipts_2026_test.dart.
  final file = File('test/fixtures/graha_horizons_2026.json');
  final Map<String, dynamic> doc;
  if (file.existsSync()) {
    doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } else {
    doc = jsonDecode(File(
            'packages/nepali_panchang/test/fixtures/'
            'graha_horizons_2026.json')
        .readAsStringSync()) as Map<String, dynamic>;
  }
  final daily = doc['daily']! as Map<String, dynamic>;
  final stationHourly = doc['station_hourly']! as Map<String, dynamic>;

  const bodies = <String, int>{
    'mercury': kGrahaMercury,
    'venus': kGrahaVenus,
    'mars': kGrahaMars,
    'jupiter': kGrahaJupiter,
    'saturn': kGrahaSaturn,
  };

  double wrapDelta(double a, double b) {
    double d = (a - b) % 360.0;
    if (d > 180.0) d -= 360.0;
    if (d < -180.0) d += 360.0;
    return d.abs();
  }

  test('fixture integrity: row counts and contiguous instants', () {
    for (final name in bodies.keys) {
      final rows = (daily[name]! as List).cast<List<dynamic>>();
      expect(rows.length, 49, reason: name);
      for (int i = 1; i < rows.length; i++) {
        final gap = (rows[i][0] as num).toDouble() -
            (rows[i - 1][0] as num).toDouble();
        expect(gap, closeTo(1.0, 1e-6), reason: name + ' row ' + i.toString());
      }
    }
    for (final name in ['mercury', 'venus']) {
      final rows = (stationHourly[name]! as List).cast<List<dynamic>>();
      expect(rows.length, 72, reason: name);
      for (int i = 1; i < rows.length; i++) {
        final gap = (rows[i][0] as num).toDouble() -
            (rows[i - 1][0] as num).toDouble();
        expect(gap, closeTo(1.0 / 24.0, 1e-4),
            reason: name + ' hour ' + i.toString());
      }
    }
  });

  for (final entry in bodies.entries) {
    test('Horizons apparent place: ' + entry.key, () {
      final rows = (daily[entry.key]! as List).cast<List<dynamic>>();
      for (final row in rows) {
        final jd = (row[0] as num).toDouble();
        final lon = (row[1] as num).toDouble();
        final lat = (row[2] as num).toDouble();
        final pos = grahaPosition(entry.value, jd);
        final dLon = wrapDelta(pos.tropicalLongitudeDeg, lon) * 3600.0;
        final dLat = (pos.tropicalLatitudeDeg - lat).abs() * 3600.0;
        expect(dLon, lessThan(15.0),
            reason: entry.key +
                ' JD ' +
                jd.toString() +
                ': engine ' +
                pos.tropicalLongitudeDeg.toStringAsFixed(6) +
                ' vs Horizons ' +
                lon.toString());
        expect(dLat, lessThan(15.0),
            reason: entry.key +
                ' JD ' +
                jd.toString() +
                ': engine lat ' +
                pos.tropicalLatitudeDeg.toStringAsFixed(6) +
                ' vs Horizons ' +
                lat.toString());
      }
    });
  }

  double fixtureStationJd(String planet) {
    final rows = (stationHourly[planet]! as List).cast<List<dynamic>>();
    var best = rows[0];
    for (final row in rows) {
      if ((row[1] as num).toDouble() < (best[1] as num).toDouble()) {
        best = row;
      }
    }
    return (best[0] as num).toDouble();
  }

  test('Mercury retrograde station within 90 min of the Horizons grid',
      () {
    final ref = fixtureStationJd('mercury');
    final station = grahaStationJdUt(kGrahaMercury, ref);
    expect(station, isNotNull);
    expect((station! - ref).abs(), lessThan(90.0 / 1440.0));
  });

  test('Venus retrograde station within 90 min of the Horizons grid', () {
    final ref = fixtureStationJd('venus');
    final station = grahaStationJdUt(kGrahaVenus, ref);
    expect(station, isNotNull);
    expect((station! - ref).abs(), lessThan(90.0 / 1440.0));
  });

  test('retrograde before and direct after the stations', () {
    final mer = fixtureStationJd('mercury');
    final ven = fixtureStationJd('venus');
    expect(grahaIsRetrograde(kGrahaMercury, mer - 1.0), isTrue);
    expect(grahaIsRetrograde(kGrahaMercury, mer + 1.0), isFalse);
    expect(grahaIsRetrograde(kGrahaVenus, ven - 1.0), isTrue);
    expect(grahaIsRetrograde(kGrahaVenus, ven + 1.0), isFalse);
  });

  test('Mars, Jupiter and Saturn stay direct across the window', () {
    const direct = <String, int>{
      'mars': kGrahaMars,
      'jupiter': kGrahaJupiter,
      'saturn': kGrahaSaturn,
    };
    for (final e in direct.entries) {
      final rows = (daily[e.key]! as List).cast<List<dynamic>>();
      for (final row in rows) {
        final jd = (row[0] as num).toDouble();
        expect(grahaIsRetrograde(e.value, jd), isFalse,
            reason: e.key + ' JD ' + jd.toString());
      }
    }
  });

  test('frame coherence: sidereal + base ayanamsa = tropical, ranges', () {
    final jd = 2461344.0;
    final jdTt = jdTtFromJdUt(jd);
    const five = <int>[
      kGrahaMercury,
      kGrahaVenus,
      kGrahaMars,
      kGrahaJupiter,
      kGrahaSaturn
    ];
    for (final b in five) {
      final pos = grahaPosition(b, jd);
      expect(pos.tropicalLongitudeDeg, inInclusiveRange(0.0, 360.0));
      expect(
          wrapDelta(
              pos.siderealLongitudeDeg + ayanamsaBase(jdTt),
              pos.tropicalLongitudeDeg),
          lessThan(1e-9));
    }
  });

  test('rise/set solver smoke: Jupiter crosses the horizon on 2026-11-11',
      () {
    final jdMid =
        julianDayFromCivil(2026, 11, 11) - nptOffsetHours / 24.0;
    final rise =
        grahaRiseJdUt(year: 2026, month: 11, day: 11, body: kGrahaJupiter);
    final set =
        grahaSetJdUt(year: 2026, month: 11, day: 11, body: kGrahaJupiter);
    expect(rise, isNotNull);
    expect(set, isNotNull);
    expect(rise!, inInclusiveRange(jdMid, jdMid + 1.0));
    expect(set!, inInclusiveRange(jdMid, jdMid + 1.0));
  });
}
