import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Engine-vs-receipt calibration for the L4 muhurta layer (HYA-420 step 3)
/// against the BhaktiBharat Kathmandu corpus (18 days, 2026-11-05..22,
/// crawled 2026-11-05) and the hinducalculator 2026-11-05 spot receipt.
///
/// Window times inherit the publisher's sunrise/sunset display conventions
/// (BhaktiBharat sunrise ~4.25 min behind the engine, their sunset ~3.5 min
/// ahead), so the bands are a few minutes wide around zero. The RULE
/// identity is exact: engine choghadiya types must equal the fixture tables
/// cell-by-cell. Bands derive from the sandbox TS replica of the USNO
/// solvers against the corpus, with rounding margin on both sides.

const _fixtureName = 'muhurta_receipts_2026_11.json';

/// Dart DateTime.weekday: Monday = 1 .. Sunday = 7.
const _weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  'Sunday',
];

/// Rahu/Yamaganda/Gulika window boundaries vs BhaktiBharat, minutes.
const _rygBand = [-6, 6];

/// Abhijit (computed day/15) vs BhaktiBharat stepped tabulation, minutes.
const _abhijitBand = [-6, 5];

/// Brahma fixed convention (sunrise - 96/-48) vs BhaktiBharat, minutes.
const _brahmaFixedBand = [1, 6];

/// hinducalculator spot (their sunrise/sunset match the engine), minutes.
const _hinducalculatorBand = [-3, 2];

Map<String, dynamic> _loadFixture() {
  final file = File('test/fixtures/' + _fixtureName);
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  // CI runs from the package root; also try the repo-root variant.
  final alt = File('packages/nepali_panchang/test/fixtures/' + _fixtureName);
  return jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final data = _loadFixture();
  final days = (data['days'] as List).cast<Map<String, dynamic>>();

  int minutesOf(DateTime t) => t.hour * 60 + t.minute;

  void expectBand(int delta, List<int> band, String what) {
    expect(delta, greaterThanOrEqualTo(band[0]),
        reason: what + ' delta ' + delta.toString() + ' below ' +
            band[0].toString());
    expect(delta, lessThanOrEqualTo(band[1]),
        reason: what + ' delta ' + delta.toString() + ' above ' +
            band[1].toString());
  }

  test('engine sunrise/sunset vs BhaktiBharat receipts', () {
    for (final d in days) {
      final date = DateTime.parse(d['date'] as String);
      final m = muhurtaFor(year: date.year, month: date.month, day: date.day);
      final srPub =
          ((d['sunrise'] as Map<String, dynamic>)['minutes']) as int;
      final ssPub =
          ((d['sunset'] as Map<String, dynamic>)['minutes']) as int;
      expectBand(minutesOf(m.sunriseNpt) - srPub, const [2, 6],
          'sunrise on ' + (d['date'] as String));
      expectBand(minutesOf(m.sunsetNpt) - ssPub, const [-6, 0],
          'sunset on ' + (d['date'] as String));
    }
  });

  test('Rahu/Yamaganda/Gulika windows vs BhaktiBharat receipts', () {
    for (final d in days) {
      final date = DateTime.parse(d['date'] as String);
      final m = muhurtaFor(year: date.year, month: date.month, day: date.day);
      final windows = <String, MuhurtaWindow>{
        'rahu': m.rahuKalam,
        'yamaganda': m.yamaganda,
        'gulika': m.gulika,
      };
      for (final e in windows.entries) {
        final pub = d[e.key] as Map<String, dynamic>;
        expectBand(minutesOf(e.value.beginsAtNpt) - (pub['start'] as int),
            _rygBand, e.key + ' start on ' + (d['date'] as String));
        expectBand(minutesOf(e.value.endsAtNpt) - (pub['end'] as int),
            _rygBand, e.key + ' end on ' + (d['date'] as String));
      }
    }
  });

  test('Abhijit and Brahma fixed windows vs BhaktiBharat receipts', () {
    for (final d in days) {
      final date = DateTime.parse(d['date'] as String);
      final m = muhurtaFor(year: date.year, month: date.month, day: date.day);
      final abhijit = d['abhijit'] as Map<String, dynamic>;
      expectBand(minutesOf(m.abhijitMuhurta.beginsAtNpt) -
              (abhijit['start'] as int), _abhijitBand,
          'abhijit start on ' + (d['date'] as String));
      expectBand(minutesOf(m.abhijitMuhurta.endsAtNpt) -
              (abhijit['end'] as int), _abhijitBand,
          'abhijit end on ' + (d['date'] as String));
      final brahma = d['brahma_muhurta'] as Map<String, dynamic>;
      expectBand(minutesOf(m.brahmaMuhurtaFixed.beginsAtNpt) -
              (brahma['start'] as int), _brahmaFixedBand,
          'brahma fixed start on ' + (d['date'] as String));
      expectBand(minutesOf(m.brahmaMuhurtaFixed.endsAtNpt) -
              (brahma['end'] as int), _brahmaFixedBand,
          'brahma fixed end on ' + (d['date'] as String));
    }
  });

  test('choghadiya types equal the fixture tables cell-by-cell', () {
    final tables = data['rule_tables'] as Map<String, dynamic>;
    final ch = tables['choghadiya'] as Map<String, dynamic>;
    for (final d in days) {
      final date = DateTime.parse(d['date'] as String);
      final m = muhurtaFor(year: date.year, month: date.month, day: date.day);
      final wd = _weekdayNames[date.weekday - 1];
      final dayTypes =
          ((ch['day'] as Map<String, dynamic>)[wd] as List).cast<String>();
      final nightTypes =
          ((ch['night'] as Map<String, dynamic>)[wd] as List).cast<String>();
      for (var k = 0; k < 8; k++) {
        expect(m.choghadiyaDay[k].type, dayTypes[k],
            reason: wd + ' day part ' + (k + 1).toString());
        expect(m.choghadiyaNight[k].type, nightTypes[k],
            reason: wd + ' night part ' + (k + 1).toString());
      }
    }
  });

  test('hinducalculator 2026-11-05 spot receipt', () {
    final spots = data['spot_receipts'] as Map<String, dynamic>;
    final spot = spots['hinducalculator_2026-11-05'] as Map<String, dynamic>;
    final m = muhurtaFor(year: 2026, month: 11, day: 5);
    expectBand(
        minutesOf(m.sunriseNpt) - (spot['sunrise'] as int),
        _hinducalculatorBand, 'hinducalculator sunrise');
    expectBand(
        minutesOf(m.sunsetNpt) - (spot['sunset'] as int),
        _hinducalculatorBand, 'hinducalculator sunset');
    final windows = <String, MuhurtaWindow>{
      'rahu': m.rahuKalam,
      'yamaganda': m.yamaganda,
      'gulika': m.gulika,
    };
    for (final e in windows.entries) {
      final pub = spot[e.key] as Map<String, dynamic>;
      expectBand(minutesOf(e.value.beginsAtNpt) - (pub['start'] as int),
          _hinducalculatorBand, 'hinducalculator ' + e.key + ' start');
      expectBand(minutesOf(e.value.endsAtNpt) - (pub['end'] as int),
          _hinducalculatorBand, 'hinducalculator ' + e.key + ' end');
    }
  });
}
