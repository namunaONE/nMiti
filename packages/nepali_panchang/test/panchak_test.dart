import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Panchak receipt gate (R10.1 ritual layer 2, HYA-441).
///
/// Loads test/fixtures/panchak_receipts_2026.json (crawled 2026-11-08:
/// 13 Swarnsiddhi windows, 13 PanchangBodh windows, the BhaktiBharat
/// current window and date lists, golden-corpus Revati-end pins) and
/// band-checks the engine against every receipt. Bands:
///   Swarnsiddhi    15 min, plus the constant-offset signature - every
///                  delta negative (the engine runs a constant ~7 min
///                  earlier; their ephemeris convention, the same
///                  class as the documented sunrise convention
///                  offsets);
///   PanchangBodh  150 min (independent computation; observed spread
///                  up to 111 min);
///   corpus pins     3 min (the panchak end IS the Revati/Ashwini
///                  boundary the locked corpora gate; the internal
///                  segment transitions are the corpus nakshatra
///                  receipts of the same months).
/// The fabricated bhaktivoice table is asserted present as a caveat
/// and absent from every gate.

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

void main() {
  final fx = _loadFixture('panchak_receipts_2026.json');
  final receipts =
      (fx['windows'] as List).cast<Map<String, dynamic>>();
  final caveats = (fx['caveats'] as List).cast<Map<String, dynamic>>();
  final engine2026 = panchakWindows(
      start: DateTime.utc(2026, 1, 1), end: DateTime.utc(2027, 1, 1));

  test('the 2026 receipt year has exactly 13 windows, dates in order',
      () {
    expect(receipts.length, 13);
    expect(engine2026.length, 13,
        reason:
            'calendar 2026 must hold exactly 13 Panchak windows');
    for (var i = 0; i < 13; i++) {
      expect(_isoDate(engine2026[i].beginsDayNpt), receipts[i]['date'],
          reason: 'window ${i + 1} begins-date label');
    }
  });

  test('Swarnsiddhi windows agree within the constant-offset band', () {
    var sumBegin = 0.0;
    for (var i = 0; i < 13; i++) {
      final db = _deltaMin(engine2026[i].beginsAtNpt,
          _npt(receipts[i]['ss_npt_begin'] as String));
      final de = _deltaMin(engine2026[i].endsAtNpt,
          _npt(receipts[i]['ss_npt_end'] as String));
      sumBegin += db.abs();
      expect(db, inExclusiveRange(-15.0, -2.0),
          reason: 'SS begin delta window ${i + 1}: '
          '${db.toStringAsFixed(1)} min (constant-offset signature)');
      expect(de, inExclusiveRange(-15.0, -2.0),
          reason: 'SS end delta window ${i + 1}: '
          '${de.toStringAsFixed(1)} min');
    }
    expect(sumBegin / 13, lessThan(10.0),
        reason: 'mean SS begin delta must stay a small constant');
  });

  test('PanchangBodh windows agree within the publisher band', () {
    for (var i = 0; i < 13; i++) {
      final db = _deltaMin(engine2026[i].beginsAtNpt,
          _npt(receipts[i]['pb_npt_begin'] as String));
      final de = _deltaMin(engine2026[i].endsAtNpt,
          _npt(receipts[i]['pb_npt_end'] as String));
      expect(db.abs(), lessThan(150.0),
          reason: 'PB begin delta window ${i + 1}');
      expect(de.abs(), lessThan(150.0),
          reason: 'PB end delta window ${i + 1}');
    }
  });

  test('the BhaktiBharat current window matches the engine', () {
    final bb = fx['bb_today_window'] as Map<String, dynamic>;
    final w = engine2026[11]; // the Nov 17 window
    expect(w.beginsDayNpt, DateTime.utc(2026, 11, 17));
    expect(
        _deltaMin(w.beginsAtNpt, _npt(bb['npt_begin'] as String)).abs(),
        lessThan(15.0));
    expect(
        _deltaMin(w.endsAtNpt, _npt(bb['npt_end'] as String)).abs(),
        lessThan(15.0));
  });

  test('the BhaktiBharat date lists are engine begins-dates (subset)', () {
    final lists = fx['bb_date_lists'] as Map<String, dynamic>;
    final dates = [
      ...(lists['past_2026'] as List),
      ...(lists['next'] as List),
    ].cast<String>();
    expect(dates.length, 12);
    for (final d in dates) {
      final parts = d.split('-');
      final w = panchakNear(
          year: int.parse(parts[0]),
          month: int.parse(parts[1]),
          day: int.parse(parts[2]));
      expect(w, isNotNull,
          reason: 'BhaktiBharat lists ${d} as a begins-date');
    }
    // Their past list skips Jul 31; the window is real (fixture
    // caveat bb-list-quirks) - Swarnsiddhi and PanchangBodh both
    // print it.
    expect(panchakNear(year: 2026, month: 7, day: 31), isNotNull);
  });

  test('window types follow the weekday-of-begin rule and match both '
      'publishers', () {
    for (var i = 0; i < 13; i++) {
      final w = engine2026[i];
      expect(w.type, panchakTypeForWeekday(w.beginsWeekdayNpt),
          reason: 'type must derive from the begin weekday');
      final ssType = receipts[i]['ss_type'] as String?;
      if (ssType != null) {
        expect(w.type.name, ssType,
            reason: 'SS typed row window ${i + 1}');
      }
      final pbType = receipts[i]['pb_type'] as String?;
      if (pbType != null && receipts[i]['date'] != '2026-12-14') {
        expect(w.type.name, pbType,
            reason: 'PB typed row window ${i + 1}');
      }
    }
    // The decoded Dec collision: the engine places the begin at Dec 14
    // ~22:4x NPT (Monday -> Rajya; Swarnsiddhi and BhaktiBharat agree);
    // PanchangBodh's ephemeris lands past NPT midnight -> their Agni.
    final dec = engine2026[12];
    expect(dec.type, PanchakType.rajya);
    expect(receipts[12]['pb_type'], 'agni');
    expect(_isoDate(dec.beginsDayNpt), '2026-12-14');
  });

  test('golden-corpus pins: the end is the gated Revati boundary, the '
      'segments are the corpus nakshatra receipts', () {
    var pinned = 0;
    for (var i = 0; i < 13; i++) {
      final pin = receipts[i]['corpus_pin'] as Map<String, dynamic>?;
      if (pin == null) continue;
      pinned++;
      final w = engine2026[i];
      final endDelta = _deltaMin(
              w.endsAtNpt, _npt(pin['published_npt'] as String))
          .abs();
      expect(endDelta, lessThan(3.0),
          reason: 'corpus end pin window ${i + 1}');
      final segReceipts =
          (pin['segment_receipts'] as List).cast<Map<String, dynamic>>();
      expect(segReceipts.length, 4);
      expect(w.nakshatraSegments.length, 5,
          reason: 'a window holds exactly the five Panchak nakshatras');
      expect(w.nakshatraSegments.map((s) => s.name).toList(),
          panchakNakshatraNames,
          reason: 'segment chain window ${i + 1}');
      for (var s = 0; s < 4; s++) {
        final d = _deltaMin(w.nakshatraSegments[s + 1].beginsAtNpt,
                _npt(segReceipts[s]['published_npt'] as String))
            .abs();
        expect(d, lessThan(3.0),
            reason: 'segment ${s + 2} transition window ${i + 1}');
      }
    }
    expect(pinned, 3, reason: 'the Oct/Nov/Dec windows must be pinned');
  });

  test('physics: durations, spacing and the calendar-year count', () {
    for (var i = 0; i < 13; i++) {
      final dur = engine2026[i].durationNpt.inMinutes;
      expect(dur, inExclusiveRange(4 * 1440, 5 * 1440),
          reason: 'duration window ${i + 1}');
      if (i > 0) {
        final gap = engine2026[i]
            .beginsAtNpt
            .difference(engine2026[i - 1].beginsAtNpt)
            .inMinutes;
        expect(gap, inExclusiveRange(26.5 * 1440, 28.5 * 1440),
            reason: 'begin spacing window ${i + 1}');
      }
    }
    final into2027 = panchakWindows(
        start: DateTime.utc(2026, 1, 1), end: DateTime.utc(2027, 2, 1));
    expect(into2027.length, 14);
    expect(_isoDate(into2027[13].beginsDayNpt).startsWith('2027-01'),
        isTrue,
        reason: 'the 14th window begins the next sidereal month');
  });

  test('covering and next queries; half-open window semantics', () {
    final quiet = _npt('2026-11-08T18:00');
    expect(panchakOn(quiet), isNull,
        reason: 'Nov 8 2026 falls between the Oct and Nov windows');
    final next = nextPanchakAfter(quiet);
    expect(_isoDate(next.beginsDayNpt), '2026-11-17');
    expect(next.type, PanchakType.agni, reason: 'Tuesday begin');
    final midNov = _npt('2026-11-18T12:00');
    final running = panchakOn(midNov);
    expect(running, isNotNull);
    expect(running!.type, PanchakType.agni);
    // Half-open: the begin instant is inside, the end instant outside.
    final w = engine2026[11];
    expect(panchakOn(w.beginsAtNpt), isNotNull);
    expect(panchakOn(w.endsAtNpt), isNull);
    // A running window is skipped: next is the following one.
    final afterMid = nextPanchakAfter(midNov);
    expect(_isoDate(afterMid.beginsDayNpt), '2026-12-14');
  });

  test('the fabricated bhaktivoice table is recorded and never gated',
      () {
    final ids = caveats.map((c) => c['id']).toList();
    expect(ids, contains('bhaktivoice-fabricated-panchak'));
    for (final w in receipts) {
      expect(w.containsKey('bhaktivoice_npt_begin'), isFalse,
          reason: 'fabricated window times must never enter the gate');
    }
  });
}
