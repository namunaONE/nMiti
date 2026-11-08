import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Chandra Darshan receipt gate (R10.1 ritual layer 3, HYA-441).
///
/// Loads test/fixtures/chandra_darshan_receipts_2026.json (crawled
/// 2026-11-08, re-crawled byte-identical the same day: nepaljyotish's
/// 13 Kathmandu saait windows for BS 2083, BhaktiBharat's 6
/// day-calls, drikpanchang's 25 New Delhi rows with two documented
/// divergences) and band-checks the engine against every receipt.
/// Bands:
///   nepaljyotish    2 min on both saait edges - their published
///                  sunset/moonset IS the saait (observed engine
///                  deltas +0.0..+1.3 min begin, +0.0..+0.9 min
///                  end), and every darshan evening must clear the
///                  served lag constant;
///   BhaktiBharat    day-calls exact (accepted => non-null, rejected
///                  => null); accepted rows' printed sunset/moonset
///                  within 5 min (their display runs ~+3/+4 min);
///   drikpanchang    day-calls exact on the 23 agreeing rows (Delhi
///                  coordinates); window edges within 3 min begin /
///                  8 min end (their moonset runs ~3-4 min early;
///                  IST printed, NPT = IST + 15 min exactly); the
///                  two disagreeing rows are asserted to disagree,
///                  with the engine's own dates verified.
/// The threshold band itself is re-derived from the binding rows via
/// the exported sunset/moonset solvers.

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

/// Parses a "yyyy-MM-ddTHH:mm" NPT wall-clock string (UTC fields).
DateTime _npt(String s) => parseWallClock(s);

double _deltaMin(DateTime engine, DateTime receipt) =>
    engine.difference(receipt).inMicroseconds / 60e6;

String _isoDate(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}';
}

/// Engine moonset-minus-sunset lag of one evening, minutes.
double _lagMin(int y, int m, int d,
    {double lat = 27.7172, double lng = 85.324}) {
  final ss = sunsetJdUt(year: y, month: m, day: d,
      latitudeDeg: lat, longitudeDeg: lng);
  final ms = moonsetJdUt(year: y, month: m, day: d,
      latitudeDeg: lat, longitudeDeg: lng);
  if (ms == null) {
    throw StateError('moonset unexpectedly null for $y-$m-$d');
  }
  return (ms - ss) * 1440.0;
}

const double _delLat = 28.6139;
const double _delLng = 77.2090;

void main() {
  final fx = _loadFixture('chandra_darshan_receipts_2026.json');
  final nj = (fx['nepaljyotish_ktm'] as List).cast<Map<String, dynamic>>();
  final bb =
      (fx['bhaktibharat_ktm_day_calls'] as List).cast<Map<String, dynamic>>();
  final drik = (fx['drikpanchang_del'] as List).cast<Map<String, dynamic>>();
  final caveats = (fx['caveats'] as List).cast<Map<String, dynamic>>();
  final windowsNj = chandraDarshanWindows(
      start: DateTime.utc(2026, 4, 1), end: DateTime.utc(2027, 5, 1));

  test('the BS 2083 nepaljyotish year: 13 windows, dates in order', () {
    expect(nj.length, 13);
    expect(windowsNj.length, 13,
        reason: 'the nepaljyotish table year must hold exactly 13 '
            'darshans');
    for (var i = 0; i < 13; i++) {
      expect(_isoDate(windowsNj[i].darshanDayNpt), nj[i]['date'],
          reason: 'window ${i + 1} darshan-date label');
    }
  });

  test('nepaljyotish saait windows agree within 2 min', () {
    for (var i = 0; i < 13; i++) {
      final w = windowsNj[i];
      final db = _deltaMin(w.saaitBeginsNpt, _npt(nj[i]['begins'] as String));
      final de = _deltaMin(w.saaitEndsNpt, _npt(nj[i]['ends'] as String));
      expect(db, inExclusiveRange(-0.25, 2.0),
          reason: 'NJ saait begin delta window ${i + 1}: '
          '${db.toStringAsFixed(2)} min');
      expect(de, inExclusiveRange(-0.25, 2.0),
          reason: 'NJ saait end delta window ${i + 1}: '
          '${de.toStringAsFixed(2)} min');
      expect(w.moonsetLagMinutes,
          greaterThanOrEqualTo(chandraDarshanMinMoonsetLagMinutes),
          reason: 'every darshan evening clears the lag constant');
      expect(w.dayIndexAfterNewMoon, lessThanOrEqualTo(2),
          reason: 'corpus day indices are k0/k1/k2');
    }
  });

  test('the threshold band straddles the served 39.0-minute constant',
      () {
    expect(chandraDarshanMinMoonsetLagMinutes, 39.0);
    // Binding rejected: New Delhi Jun 15 2026 - drikpanchang prints
    // Jun 16, so the engine must reject Jun 15 at Delhi (corpus lag
    // 37.80, the band's rejected maximum).
    final jun15del = _lagMin(2026, 6, 15, lat: _delLat, lng: _delLng);
    expect(jun15del, inExclusiveRange(36.0, 39.0),
        reason: 'Delhi Jun 15 2026 must fall below the constant '
            '(computed ${jun15del.toStringAsFixed(2)} min)');
    expect(
        chandraDarshanOn(
            year: 2026,
            month: 6,
            day: 15,
            latitudeDeg: _delLat,
            longitudeDeg: _delLng),
        isNull,
        reason: 'drikpanchang prints Jun 16, never Jun 15');
    // Kathmandu Jun 15 (corpus 35.78) is equally out.
    expect(_lagMin(2026, 6, 15), lessThan(39.0));
    // Binding accepted: Kathmandu Feb 7 2027 - nepaljyotish prints
    // it (corpus lag 40.33, the band's accepted minimum).
    final feb7ktm = _lagMin(2027, 2, 7);
    expect(feb7ktm, greaterThanOrEqualTo(39.0),
        reason: 'Kathmandu Feb 7 2027 must clear the constant '
            '(computed ${feb7ktm.toStringAsFixed(2)} min)');
    expect(chandraDarshanOn(year: 2027, month: 2, day: 7), isNotNull,
        reason: 'nepaljyotish prints Feb 7 2027 for Kathmandu');
  });

  test('BhaktiBharat day-calls: accepted exact, rejected null', () {
    expect(bb.length, 6);
    for (final row in bb) {
      final parts = (row['date'] as String).split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      final w = chandraDarshanOn(year: y, month: m, day: d);
      if (row['darshan'] == true) {
        expect(w, isNotNull,
            reason: 'BhaktiBharat prints a darshan on ${row['date']}');
        final db = _deltaMin(
            w!.saaitBeginsNpt, _npt(row['sunset'] as String));
        final de =
            _deltaMin(w.saaitEndsNpt, _npt(row['moonset'] as String));
        expect(db.abs(), lessThan(5.0),
            reason: 'BB printed sunset ${row['date']} '
            '(display runs ~+3/+4 min)');
        expect(de.abs(), lessThan(5.0),
            reason: 'BB printed moonset ${row['date']}');
      } else {
        expect(w, isNull,
            reason: 'BhaktiBharat prints no darshan on ${row['date']}');
      }
    }
    // The Dec 9 2026 row is the extreme: moonset 17:11 BEFORE
    // sunset 17:13 - no evening moon at all.
    final dec9 = bb.firstWhere((r) => r['date'] == '2026-12-09');
    expect(dec9['darshan'], false);
    expect(_lagMin(2026, 12, 9), lessThan(0.0),
        reason: 'moonset before sunset');
  });

  test('drikpanchang: 23 agreeing Delhi rows exact, window edges in '
      'band', () {
    for (final row in drik) {
      final parts = (row['date'] as String).split('-');
      final w = chandraDarshanOn(
          year: int.parse(parts[0]),
          month: int.parse(parts[1]),
          day: int.parse(parts[2]),
          latitudeDeg: _delLat,
          longitudeDeg: _delLng);
      if (row['agree'] == true) {
        expect(w, isNotNull,
            reason: 'drikpanchang prints ${row['date']} (Delhi)');
        final db = _deltaMin(
            w!.saaitBeginsNpt, _npt(row['begins_npt'] as String));
        final de =
            _deltaMin(w.saaitEndsNpt, _npt(row['ends_npt'] as String));
        expect(db.abs(), lessThan(3.0),
            reason: 'drik saait begin delta ${row['date']}');
        expect(de.abs(), lessThan(8.0),
            reason: 'drik saait end delta ${row['date']} '
            '(their moonset runs ~3-4 min early)');
      }
    }
  });

  test('the two drikpanchang divergences are recorded, never absorbed',
      () {
    final disagree =
        drik.where((r) => r['agree'] == false).toList();
    expect(disagree.map((r) => r['date']).toList(),
        ['2027-02-08', '2027-10-01']);
    final ids = caveats.map((c) => c['id']).toList();
    expect(ids, contains('drik-no-monotone-rule'));
    // The engine's own day-calls for those lunations.
    expect(
        chandraDarshanOn(
            year: 2027,
            month: 2,
            day: 8,
            latitudeDeg: _delLat,
            longitudeDeg: _delLng),
        isNull,
        reason: 'engine: Feb 7 2027, not drikpanchang\'s Feb 8');
    expect(
        chandraDarshanOn(
            year: 2027,
            month: 10,
            day: 1,
            latitudeDeg: _delLat,
            longitudeDeg: _delLng),
        isNull,
        reason: 'engine: Oct 2 2027, not drikpanchang\'s Oct 1');
    final feb = nextChandraDarshanAfter(
        afterNpt: _npt('2027-02-01T12:00'),
        latitudeDeg: _delLat, longitudeDeg: _delLng);
    expect(_isoDate(feb.darshanDayNpt), '2027-02-07');
    final oct = nextChandraDarshanAfter(
        afterNpt: _npt('2027-09-25T12:00'),
        latitudeDeg: _delLat, longitudeDeg: _delLng);
    expect(_isoDate(oct.darshanDayNpt), '2027-10-02');
  });

  test('the conj-day darshan is real; "Dwitiya at sunset" is refuted',
      () {
    // May 17 2026: conjunction-day darshan (k0), Moon 15-17 h old,
    // Shukla Pratipada, lag 54 min - printed by all three sources.
    final may = windowsNj[1];
    expect(_isoDate(may.darshanDayNpt), '2026-05-17');
    expect(may.dayIndexAfterNewMoon, 0,
        reason: 'the conjunction falls on the darshan day itself');
    expect(may.moonAgeHoursAtSaaitBegins, inExclusiveRange(15.0, 17.0));
    expect(may.tithiAtSaaitBegins, 'Shukla Pratipada');
    expect(may.moonsetLagMinutes, greaterThan(45.0));
    // Nov 10 2026: Shukla Dwitiya at sunset, yet rejected by every
    // source - the tithi is not the rule.
    final nov10SsJdTt = jdTtFromJdUt(sunsetJdUt(year: 2026, month: 11, day: 10));
    expect(limbIndex('tithi', nov10SsJdTt, 0.0), 1,
        reason: 'Nov 10 2026 is Shukla Dwitiya at sunset');
    expect(tithiName(limbIndex('tithi', nov10SsJdTt, 0.0)), 'Shukla Dwitiya');
    expect(chandraDarshanOn(year: 2026, month: 11, day: 10), isNull,
        reason: 'Dwitiya at sunset, yet rejected by every source '
            '(lag 26.5 min)');
    // Feb 7 2027: Pratipada at sunset AND accepted - the lag is the
    // rule, the tithi labels both sides of it.
    final feb7 = windowsNj[10];
    expect(_isoDate(feb7.darshanDayNpt), '2027-02-07');
    expect(feb7.tithiAtSaaitBegins, 'Shukla Pratipada');
    expect(feb7.moonsetLagMinutes,
        greaterThanOrEqualTo(chandraDarshanMinMoonsetLagMinutes));
  });

  test('covering and next queries; today is quiet, next is Nov 11',
      () {
    // Today Nov 8 2026 is a quiet day; Nov 10 is the refuted
    // Dwitiya evening; the next darshan is Nov 11.
    expect(chandraDarshanOn(year: 2026, month: 11, day: 8), isNull,
        reason: 'Nov 8 2026 is two days before the darshan');
    expect(chandraDarshanOn(year: 2026, month: 11, day: 10), isNull);
    final next = nextChandraDarshanAfter(
        afterNpt: _npt('2026-11-08T18:00'));
    expect(_isoDate(next.darshanDayNpt), '2026-11-11');
    final njNov11 = nj.firstWhere((r) => r['date'] == '2026-11-11');
    expect(
        _deltaMin(next.saaitBeginsNpt, _npt(njNov11['begins'] as String))
            .abs(),
        lessThan(2.0));
    expect(
        _deltaMin(next.saaitEndsNpt, _npt(njNov11['ends'] as String))
            .abs(),
        lessThan(2.0));
    // The darshan day itself answers non-null.
    expect(chandraDarshanOn(year: 2026, month: 11, day: 11), isNotNull);
    // And the day after the darshan is quiet again.
    expect(chandraDarshanOn(year: 2026, month: 11, day: 12), isNull);
  });

  test('physics: calendar 2026 holds 12 windows; spacing and saait '
      'durations', () {
    final cal2026 = chandraDarshanWindows(
        start: DateTime.utc(2026, 1, 1), end: DateTime.utc(2027, 1, 1));
    expect(cal2026.length, 12,
        reason: 'calendar 2026 must hold exactly 12 darshans');
    for (var i = 0; i < cal2026.length; i++) {
      final dur = cal2026[i].saaitDurationNpt.inMinutes;
      expect(dur, inExclusiveRange(35, 200),
          reason: 'saait duration window ${i + 1}');
      expect(cal2026[i].moonsetLagMinutes,
          greaterThanOrEqualTo(chandraDarshanMinMoonsetLagMinutes));
      if (i > 0) {
        final gap = cal2026[i]
            .darshanDayNpt
            .difference(cal2026[i - 1].darshanDayNpt)
            .inMinutes;
        expect(gap, inExclusiveRange(25 * 1440, 34 * 1440),
            reason: 'darshan-day spacing window ${i + 1}');
      }
    }
  });

  test('conventions, caveats and honesty fields are exposed', () {
    expect(
        chandraDarshanConventions.keys,
        containsAll([
          'identity',
          'saait_window',
          'day_rule',
          'linger_altitude_equivalence',
          'conj_day',
          'tithi_refuted',
          'drik_divergence',
          'young_moon_note',
          'hamro_patro_absence',
          'location',
        ]));
    expect(chandraDarshanAltitudeReferenceDeg, 8.0);
    final ids = caveats.map((c) => c['id']).toList();
    expect(ids, contains('threshold-band'));
    expect(ids, contains('drik-no-monotone-rule'));
    expect(ids, contains('bb-display-convention'));
    expect(ids, contains('hp-absence'));
    expect(ids, contains('ist-npt-shift'));
    // The altitude honesty field tracks the corpus band: every
    // accepted Kathmandu evening holds the Moon at >= 7.5 deg at
    // sunset (corpus accepted minimum 8.4 deg).
    for (final w in windowsNj) {
      expect(w.moonAltitudeDegAtSaaitBegins, inExclusiveRange(7.5, 25.0),
          reason: 'darshan ${_isoDate(w.darshanDayNpt)}');
    }
    // The provenance names the layer and the corpus date.
    expect(windowsNj[0].provenance, contains('chandra_darshan'));
    expect(windowsNj[0].evidenceTier, contains('2026-11-08'));
  });
}
