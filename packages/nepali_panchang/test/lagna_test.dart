import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Lagna (rising sign) receipt gate (R10.2, HYA-441).
///
/// Loads test/fixtures/lagna_receipts_2026_11.json (crawled 2026-11-09
/// 00:43-01:05 UTC: Swarnsiddhi second-precision twelve-boundary day
/// tables plus frame closes plus live Rising-now degrees for six
/// cities, nepaljyotish's minute-precision 13-row Kathmandu table,
/// nine PanchangBodh dated day-calls) and band-checks the engine
/// against every receipt. Bands:
///   Swarnsiddhi    78 boundary receipts (six cities x 12 boundaries +
///                  frame close) within 2 min (observed 0.05 min); the
///                  frame start is SOLVED by walking back from the
///                  printed sunrise - never scanned from a fixed hour
///                  (Mumbai's previous window began 03:06 local; see
///                  the scan_alignment convention);
///   nepaljyotish   12 interior boundaries within 3 min (minute-
///                  rounded print, observed 2.28 min) with row 1
///                  re-anchored at their printed sunrise; the engine's
///                  own USNO sunrises anchor the frame ends within
///                  1.5 min;
///   PanchangBodh  nine day-calls exact on the sunrise lagna sign
///                  (their times are IST-labeled: +15 min gives NPT);
///   Rising-now    six live degree receipts within 0.5 deg (observed
///                  0.19 deg).
/// Zero divergences across the corpus.

Map<String, dynamic> _loadFixture(String fileName) {
  final file = File('test/fixtures/${fileName}');
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  // CI runs from the package root; also try the repo-root variant.
  final alt =
      File('packages/nepali_panchang/test/fixtures/${fileName}');
  return jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
}

const double _ktmLat = 27.7172;
const double _ktmLng = 85.324;

/// JD (UT) of a local wall-clock "HH:MM[:SS]" (optionally "+1" = next
/// day) on [date], at a city [tzOffsetMin] minutes east of UTC: the
/// wall fields are treated as UTC, then shifted by the zone offset.
double _jdWall(String date, String time, int tzOffsetMin) {
  final dayJump = time.endsWith('+1') ? 1 : 0;
  final hms = time.replaceAll('+1', '').split(':');
  final d = date.split('-');
  final wall = DateTime.utc(
      int.parse(d[0]),
      int.parse(d[1]),
      int.parse(d[2]) + dayJump,
      int.parse(hms[0]),
      int.parse(hms[1]),
      hms.length > 2 ? int.parse(hms[2]) : 0);
  return jdFromDateTimeUtc(wall) - tzOffsetMin / 1440.0;
}

/// NPT wall clock (UTC fields) of a UT Julian Day.
DateTime _nptWall(double jdUt) =>
    dateTimeUtcFromJd(jdUt).add(const Duration(milliseconds: nptOffsetMs));

/// Engine-minus-receipt delta, minutes.
double _deltaMin(double engineJdUt, double receiptJdUt) =>
    (engineJdUt - receiptJdUt) * 1440.0;

double _wallDeltaMin(DateTime a, DateTime b) =>
    a.difference(b).inMicroseconds / 60e6;

/// The Swarnsiddhi frame for one city: the TRUE begin of the window
/// containing the printed sunrise (solved by walking back from the
/// sunrise instant), then twelve chained boundaries - the thirteenth is
/// the frame close, which returns the frame sign.
List<LagnaBoundary> _cityFrame(Map<String, dynamic> city) {
  final lat = (city['lat'] as num).toDouble();
  final lon = (city['lon'] as num).toDouble();
  final anchor = _jdWall(city['page_date'] as String,
      city['sunrise_printed'] as String, city['tz_offset_min'] as int);
  final out = <LagnaBoundary>[
    previousLagnaBoundaryBefore(
        jdUt: anchor, latitudeDeg: lat, longitudeDeg: lon)
  ];
  for (var i = 0; i < 12; i++) {
    out.add(nextLagnaBoundaryAfter(
        jdUt: out.last.jdUt, latitudeDeg: lat, longitudeDeg: lon));
  }
  return out;
}

void main() {
  final fx = _loadFixture('lagna_receipts_2026_11.json');
  final ss = (fx['swarnsiddhi_2026_11'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();
  final nj = fx['nj_kathmandu_2026_11_09'] as Map<String, dynamic>;
  final njWindows = (nj['windows'] as List).cast<Map<String, dynamic>>();
  final pb = (fx['panchangbodh_ktm_day_calls'] as List)
      .cast<Map<String, dynamic>>();
  final caveats = (fx['caveats'] as List).cast<Map<String, dynamic>>();

  test('Swarnsiddhi six-city frames: 13 boundaries each, Libra order, '
      'receipt band', () {
    expect(ss.length, 6);
    for (final e in ss.entries) {
      final city = e.value;
      final frame = _cityFrame(city);
      final receipts = (city['boundaries'] as List).cast<String>();
      expect(receipts.length, 13, reason: '${e.key} frame rows');
      for (var i = 0; i < 13; i++) {
        expect(frame[i].rashiIndex, (6 + i) % 12,
            reason: '${e.key} boundary ${i + 1} rashi order');
        final rec = _jdWall(city['page_date'] as String, receipts[i],
            city['tz_offset_min'] as int);
        final d = _deltaMin(frame[i].jdUt, rec);
        expect(d.abs(), lessThan(2.0),
            reason: '${e.key} boundary ${i + 1} delta '
            '${d.toStringAsFixed(3)} min');
      }
    }
  });

  test('every frame closes one sidereal day later (1436.07 min)', () {
    for (final e in ss.entries) {
      final frame = _cityFrame(e.value);
      final cycle = (frame[12].jdUt - frame[0].jdUt) * 1440.0;
      expect(cycle, closeTo(lagnaSiderealDayMinutes, 0.5),
          reason: '${e.key} frame cycle ${cycle.toStringAsFixed(2)} min');
      expect(frame[12].rashiIndex, frame[0].rashiIndex,
          reason: '${e.key} frame close returns the frame sign');
    }
  });

  test('Swarnsiddhi live Rising-now degrees: six cities, 0.5 deg band',
      () {
    // The live receipts all ran on 2026-11-09 in the city zone (the
    // page-date label lags the live clock for DEL/MUM/BLR/LDN - the
    // ss-page-date-cache caveat).
    for (final e in ss.entries) {
      final city = e.value;
      final rn = city['rising_now'] as Map<String, dynamic>;
      final at = _jdWall('2026-11-09', rn['at'] as String,
          city['tz_offset_min'] as int);
      final asc = siderealAscendantDeg(
          jdUt: at,
          latitudeDeg: (city['lat'] as num).toDouble(),
          longitudeDeg: (city['lon'] as num).toDouble());
      final idx = lagnaRashiIndexOf(asc);
      expect(lagnaRashiNames[idx], rn['rashi'] as String,
          reason: '${e.key} rising-now sign');
      final parts = (rn['deg'] as String).split(':');
      final printed =
          double.parse(parts[0]) + double.parse(parts[1]) / 60.0;
      expect(asc - idx * 30.0, closeTo(printed, 0.5),
          reason: '${e.key} rising-now degree in rashi');
    }
  });

  test('nepaljyotish Kathmandu table: interior boundaries in band, '
      'sunrise-anchored frame', () {
    expect(njWindows.length, 13);
    // Row 1 is the Tula window re-anchored at their printed sunrise
    // 06:20 NPT; rows 2-13 chain from there.
    final anchor = jdFromDateTimeUtc(DateTime.utc(2026, 11, 9, 6, 20)) -
        nptOffsetMs / 86400000.0;
    var b = nextLagnaBoundaryAfter(
        jdUt: anchor, latitudeDeg: _ktmLat, longitudeDeg: _ktmLng);
    for (var i = 1; i <= 12; i++) {
      final row = njWindows[i];
      expect(b.rashiNameNepali, row['rashi'] as String,
          reason: 'NJ row ${i + 1} rashi');
      final rec = _jdWall('2026-11-09', row['begins'] as String, 345);
      final d = _deltaMin(b.jdUt, rec);
      expect(d.abs(), lessThan(3.0),
          reason: 'NJ row ${i + 1} boundary delta '
          '${d.toStringAsFixed(2)} min');
      b = nextLagnaBoundaryAfter(
          jdUt: b.jdUt, latitudeDeg: _ktmLat, longitudeDeg: _ktmLng);
    }
    // The engine's own USNO sunrises anchor the frame ends (their row
    // 13 closes at the next day's printed 06:20).
    final sr9 = _nptWall(sunriseJdUt(year: 2026, month: 11, day: 9));
    final sr10 = _nptWall(sunriseJdUt(year: 2026, month: 11, day: 10));
    expect(_wallDeltaMin(sr9, DateTime.utc(2026, 11, 9, 6, 20)).abs(),
        lessThan(1.5),
        reason: 'engine sunrise Nov 9 vs NJ 06:20 '
        '(${_wallDeltaMin(sr9, DateTime.utc(2026, 11, 9, 6, 20)).toStringAsFixed(2)} min)');
    expect(_wallDeltaMin(sr10, DateTime.utc(2026, 11, 10, 6, 20)).abs(),
        lessThan(1.5),
        reason: 'engine sunrise Nov 10 vs NJ 06:20 (+1) '
        '(${_wallDeltaMin(sr10, DateTime.utc(2026, 11, 10, 6, 20)).toStringAsFixed(2)} min)');
  });

  test('PanchangBodh day-calls: nine sunrise-lagna signs exact, '
      'Jun-16 suspect resolved', () {
    expect(pb.length, 9);
    for (final row in pb) {
      // Their times are IST-labeled instants (the pb-ist-seam
      // caveat): tz 330 converts the print to UT.
      final jdUt = _jdWall(
          row['date'] as String, row['sunrise_printed'] as String, 330);
      final asc = siderealAscendantDeg(
          jdUt: jdUt, latitudeDeg: _ktmLat, longitudeDeg: _ktmLng);
      expect(lagnaRashiNames[lagnaRashiIndexOf(asc)],
          row['lagna_sunrise'] as String,
          reason: 'PB ${row['date']} sunrise lagna');
    }
    final jun16 = pb.firstWhere((r) => r['date'] == '2026-06-16');
    expect(jun16['note'] as String, contains('RESOLVED'),
        reason: 'the Jun-16 suspect row must carry its resolution');
  });

  test('channel anchors: GMST Meeus 12.4, mean obliquity Meeus 22.2',
      () {
    expect(greenwichMeanSiderealTimeDeg(2451545.0),
        closeTo(280.46061837, 1e-5));
    expect(meanObliquityOfEclipticDeg(2451545.0),
        closeTo(23.439291111, 1e-6));
  });

  test('sunrise ascendant hugs the sun (the PanchangBodh sign rule)',
      () {
    for (final d in [
      DateTime.utc(2026, 11, 9),
      DateTime.utc(2026, 6, 15),
      DateTime.utc(2026, 6, 16),
    ]) {
      final sr = sunriseJdUt(year: d.year, month: d.month, day: d.day);
      final jdTt = jdTtFromJdUt(sr);
      final asc = siderealAscendantDeg(
          jdUt: sr, latitudeDeg: _ktmLat, longitudeDeg: _ktmLng);
      final sun = sunTrueLongitude(jdTt) - ayanamsaTotal(jdTt, 0.0);
      final diff = (asc - sun) % 360.0;
      final wrapped = diff > 180.0 ? diff - 360.0 : diff;
      expect(wrapped, inExclusiveRange(-2.0, 0.5),
          reason: 'asc-vs-sun ${d.year}-${d.month}-${d.day}: '
          '${wrapped.toStringAsFixed(3)} deg (the sunrise ascendant '
          'lags the sun, never leads it by more than 0.5 deg)');
    }
  });

  test('running lagna at 06:24 NPT Nov 9: the rising-now receipt', () {
    final now = lagnaAtNpt(DateTime.utc(2026, 11, 9, 6, 24));
    expect(now.rashiName, 'Libra');
    expect(now.rashiNameNepali, 'Tula');
    expect(now.degreeInRashi, closeTo(22.57, 0.5),
        reason: 'Swarnsiddhi prints Libra 22:34');
    expect(
        _wallDeltaMin(now.beginsAtNpt, DateTime.utc(2026, 11, 9, 4, 40, 51))
            .abs(),
        lessThan(2.0),
        reason: 'the running Tula window began 04:40:51 NPT');
    expect(
        _wallDeltaMin(
                now.nextBoundaryAtNpt, DateTime.utc(2026, 11, 9, 6, 59, 30))
            .abs(),
        lessThan(2.0),
        reason: 'Vrishchik begins 06:59:30 NPT');
    // The Kathmandu day holds twelve windows of 55-245 min each.
    final windows = lagnaWindowsBetween(
        jdUtStart:
            jdFromDateTimeUtc(DateTime.utc(2026, 11, 9, 4, 0)) -
                nptOffsetMs / 86400000.0,
        jdUtEnd: jdFromDateTimeUtc(DateTime.utc(2026, 11, 10, 4, 0)) -
            nptOffsetMs / 86400000.0,
        latitudeDeg: _ktmLat,
        longitudeDeg: _ktmLng);
    expect(windows.length, 12);
    for (final w in windows) {
      expect(w.duration.inMinutes, inExclusiveRange(55, 245),
          reason: 'window ${w.rashiName} duration');
    }
  });

  test('the solver refuses polar latitudes rather than serving a bogus '
      'boundary', () {
    expect(
        () => lagnaAtNpt(DateTime.utc(2026, 11, 9, 12), latitudeDeg: 70.0),
        throwsArgumentError,
        reason: '|lat| >= 66.5 deg has no monotone ascendant');
    expect(
        () => siderealAscendantDeg(
            jdUt: 2461000.5, latitudeDeg: -70.0, longitudeDeg: 85.324),
        throwsArgumentError);
  });

  test('conventions and caveats are exposed for the display layer', () {
    expect(lagnaConventions.length, 11);
    expect(
        lagnaConventions.keys,
        containsAll([
          'identity',
          'frame',
          'day_rule',
          'ayanamsa',
          'nj_anchor',
          'rising_now',
          'pb_ist_seam',
          'pb_jun16_resolved',
          'scan_alignment',
          'unreconciled_source',
          'location',
        ]));
    expect(lagnaConventions['scan_alignment'], contains('128 min'));
    final ids = caveats.map((c) => c['id']).toList();
    expect(caveats.length, 6);
    expect(ids, contains('frame-solve'));
    expect(ids, contains('ss-page-date-cache'));
    expect(ids, contains('pb-ist-seam'));
    // The honesty fields name the layer and the corpus.
    final now = lagnaAtNpt(DateTime.utc(2026, 11, 9, 6, 24));
    expect(now.provenance, contains('nMiti nepali_panchang engine'));
    expect(now.evidenceTier, contains('lagna_receipts_2026_11'));
  });

  test('rashi name tables: English and Nepali, Tula at index 6', () {
    expect(lagnaRashiNames.length, 12);
    expect(lagnaRashiNamesNepali.length, 12);
    expect(lagnaRashiNames[6], 'Libra');
    expect(lagnaRashiNamesNepali[6], 'Tula');
    // The nepaljyotish frame starts and closes on Tula.
    expect(njWindows.first['rashi'], 'Tula');
    expect(njWindows.last['rashi'], 'Tula');
    expect(njWindows.first['begins_anchor'], 'sunrise');
    expect(njWindows.last['ends_anchor'], 'next sunrise');
  });
}
