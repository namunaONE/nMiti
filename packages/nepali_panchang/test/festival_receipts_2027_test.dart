import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// 2027-season festival receipt gate (R6b-2): Maha Shivaratri (Falgun
/// 22, 2083) and Fagu Purnima (Chaitra 7 hills / Chaitra 8 Terai,
/// 2083), crawled from Hamro Patro's fully-published BS 2083 season
/// pages on 2026-11-06, plus two convention-stress observations from
/// the same crawl: the Magha Purnima kshaya (Purnima entirely between
/// sunrises, Feb 20-21; the festival stays on the first overlap day)
/// and the Krishna Ekadashi vriddhi (udaya Ekadashi on both Mar 3 and
/// Mar 4). BhaktiBharat 2027 pages are empty templates and the HP BS
/// 2084 pages are unpopulated, so Janai Purnima and Teej 2084 are
/// pending, not gated. Samapti instants are band-checked at +/-10 min
/// (the HP divergence band the calibration corpus uses); measured
/// engine-vs-HP deltas on these receipts are 0-4 min.

DateTime _d(String s) {
  final p = s.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// NPT wall-clock instant as UTC fields (calibration-test convention).
DateTime _npt(int y, int m, int d, int hh, int mm) =>
    DateTime.utc(y, m, d, hh, mm);

const _band = Duration(minutes: 10);

void _expectWithin(DateTime engine, DateTime receipt, String why) {
  expect(engine.difference(receipt).abs() <= _band, isTrue,
      reason: why +
          ': engine ' +
          engine.toIso8601String() +
          ' vs receipt ' +
          receipt.toIso8601String() +
          ' (band 10 min)');
}

void main() {
  final file = File('test/fixtures/festival_receipts_2027.json');
  final Map<String, dynamic> data;
  if (file.existsSync()) {
    data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } else {
    data = jsonDecode(File(
            'packages/nepali_panchang/test/fixtures/'
            'festival_receipts_2027.json')
        .readAsStringSync()) as Map<String, dynamic>;
  }
  final receipts = (data['receipts'] as List).cast<Map<String, dynamic>>();
  final observations =
      (data['observations'] as List).cast<Map<String, dynamic>>();

  test('every 2027 gated receipt maps to a battery rule', () {
    for (final r in receipts) {
      expect(festivalRuleById(r['id'] as String).id, r['id'] as String);
    }
  });

  test('2027 observations are deliberately outside the battery', () {
    // The kshaya and vriddhi observations gate the tithi scanner, not a
    // festival rule: they must NOT resolve through festivalRuleById.
    for (final o in observations) {
      expect(() => festivalRuleById(o['id'] as String),
          throwsArgumentError,
          reason: 'observations are tithi-scanner receipts, not battery '
              'rules');
    }
  });

  for (final r in receipts) {
    final id = r['id'] as String;
    final expected = _d(r['ad_date'] as String);
    test('R6b-2 ' + id + ': engine reproduces the published day', () {
      final mine = scanFestivals(
          start: expected.subtract(const Duration(days: 5)),
          end: expected.add(const Duration(days: 5)),
          rules: [festivalRuleById(id)]);
      final matches =
          mine.where((o) => o.chosenDays.contains(expected)).toList();
      expect(matches, isNotEmpty,
          reason: 'no ' +
              id +
              ' observance chose ' +
              expected.toIso8601String() +
              '; candidates: ' +
              mine.map((o) => o.chosenDays.join('|')).join(' ; '));
    });
  }

  test('Maha Shivaratri 2083: nishita Mar 6, udaya exposes Mar 7', () {
    final obs = scanFestivals(
        start: DateTime.utc(2027, 3, 1),
        end: DateTime.utc(2027, 3, 25),
        rules: [festivalRuleById('mahaShivaratri')]);
    final o = obs.firstWhere((o) => o.chosenDays.contains(_d('2027-03-06')));
    expect(o.occasion.nishitaDays, [_d('2027-03-06')],
        reason: 'Chaturdashi runs Mar 6 12:20 to Mar 7 14:04 NPT and '
            'spans the midnight ending Mar 6 (HP Falgun 22/23 samapti)');
    expect(o.occasion.udayaDays, [_d('2027-03-07')],
        reason: 'the udaya convention gives Mar 7; HP took the nishita '
            'day Mar 6 - the divergence must stay exposed');
    expect(o.conventionDivergence, isTrue);
    _expectWithin(o.occasion.beginsAtNpt, _npt(2027, 3, 6, 12, 20),
        'Chaturdashi begins (HP Falgun 22 samapti: udaya Trayodashi '
        'ends 12:20)');
    _expectWithin(o.occasion.endsAtNpt, _npt(2027, 3, 7, 14, 4),
        'Chaturdashi ends (HP Falgun 23 samapti 14:04)');
  });

  test('Fagu Purnima 2083: hills firstDay Mar 21, Terai udaya Mar 22 '
      'exposed', () {
    final obs = scanFestivals(
        start: DateTime.utc(2027, 3, 16),
        end: DateTime.utc(2027, 3, 26),
        rules: [festivalRuleById('faguPurnima')]);
    final o = obs.firstWhere((o) => o.chosenDays.contains(_d('2027-03-21')));
    expect(o.occasion.overlapDays, contains(_d('2027-03-21')));
    expect(o.occasion.udayaDays, [_d('2027-03-22')],
        reason: 'Purnima began 18:35 Mar 21 (udaya Chaturdashi); the '
            'Terai udaya day Mar 22 must be exposed');
    expect(o.conventionDivergence, isTrue);
    _expectWithin(o.occasion.beginsAtNpt, _npt(2027, 3, 21, 18, 35),
        'Purnima begins (HP Chaitra 7 samapti: udaya Chaturdashi ends '
        '18:35)');
    _expectWithin(o.occasion.endsAtNpt, _npt(2027, 3, 22, 16, 25),
        'Purnima ends (HP Chaitra 8 samapti 16:25)');
  });

  test('Magha Purnima kshaya: no udaya day, festival on the first '
      'overlap day Feb 20', () {
    final occ = tithiOccasions(
        tithiIndex: 14,
        start: DateTime.utc(2027, 2, 15),
        end: DateTime.utc(2027, 2, 25));
    final o =
        occ.firstWhere((o) => o.overlapDays.contains(_d('2027-02-20')));
    expect(o.udayaDays, isEmpty,
        reason: 'Purnima began 08:12 Feb 20 and ended before the Feb 21 '
            'sunrise - entirely between udayas (HP shows Chaturdashi Feb '
            '20, Pratipada Feb 21)');
    expect(o.skippedInUdayaChain, isTrue);
    expect(o.overlapDays, [_d('2027-02-20'), _d('2027-02-21')]);
    expect(o.overlapDays.first, _d('2027-02-20'),
        reason: 'HP keeps the Magh Snan / Swasthani Samapti / Chhaya '
            'Darshan labels on Falgun 8 = Feb 20, the day Purnima began '
            '- the kshaya-day resolution is the first overlap day');
    _expectWithin(o.beginsAtNpt, _npt(2027, 2, 20, 8, 12),
        'Purnima begins (HP Falgun 8 samapti: udaya Chaturdashi ends '
        '08:12)');
  });

  test('Krishna Ekadashi vriddhi: udaya Ekadashi on both Mar 3 and '
      'Mar 4', () {
    final occ = tithiOccasions(
        tithiIndex: 25,
        start: DateTime.utc(2027, 3, 1),
        end: DateTime.utc(2027, 3, 8));
    expect(occ, hasLength(1));
    final o = occ.first;
    expect(o.udayaDays, [_d('2027-03-03'), _d('2027-03-04')],
        reason: 'Ekadashi ended Mar 4 07:37 NPT after ~26.7 h; HP prints '
            'udaya Ekadashi with the same samapti 07:37 on both Falgun 19 '
            'and Falgun 20 - the merged-window vriddhi mark');
    expect(o.spansMultipleDays, isTrue);
    expect(o.udayaDays, contains(_d('2027-03-04')),
        reason: 'HP puts the Vijaya Ekadashi Vrat label on Falgun 20 = '
            'Mar 4, the second of the two udaya days');
    _expectWithin(o.endsAtNpt, _npt(2027, 3, 4, 7, 37),
        'Ekadashi ends (HP merged-window samapti 07:37)');
  });

  test('chain instants: Trayodashi Feb 19 11:27, Pratipada Feb 22 '
      '02:17, Dwadashi Mar 5 10:09', () {
    final tray = tithiOccasions(
        tithiIndex: 13,
        start: DateTime.utc(2027, 2, 15),
        end: DateTime.utc(2027, 2, 22));
    expect(tray, hasLength(1));
    _expectWithin(tray.first.endsAtNpt, _npt(2027, 2, 19, 11, 27),
        'Shukla Trayodashi ends (HP Falgun 7 samapti 11:27)');

    final pratipada = tithiOccasions(
        tithiIndex: 15,
        start: DateTime.utc(2027, 2, 19),
        end: DateTime.utc(2027, 2, 25));
    expect(pratipada, hasLength(1));
    _expectWithin(pratipada.first.endsAtNpt, _npt(2027, 2, 22, 2, 17),
        'Krishna Pratipada ends (HP Falgun 9 samapti "ratiko 2:17" - the '
        'night of Sunday Feb 21, i.e. Feb 22 02:17)');

    final dwadashi = tithiOccasions(
        tithiIndex: 26,
        start: DateTime.utc(2027, 3, 4),
        end: DateTime.utc(2027, 3, 8));
    expect(dwadashi, hasLength(1));
    _expectWithin(dwadashi.first.endsAtNpt, _npt(2027, 3, 5, 10, 9),
        'Krishna Dwadashi ends (HP Falgun 21 samapti 10:09)');
  });
}
