import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// 2026 festival receipt gate (HYA-417): Maha Shivaratri (Falgun 3,
/// 2082), Fagu Purnima (Falgun 18 hills / 19 Terai, 2082), Janai Purnima
/// (Bhadra 12, 2083) and Teej (Bhadra 29, 2083), crawled from Hamro
/// Patro and BhaktiBharat on 2026-11-05. Each receipt pins the day-label
/// the publisher printed, the udaya tithi they displayed and the
/// convention that decides it; the engine must reproduce the chosen day
/// under exactly that convention and expose the other conventions
/// rather than hide them.

DateTime _d(String s) {
  final p = s.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

void main() {
  final file = File('test/fixtures/festival_receipts_2026.json');
  final Map<String, dynamic> data;
  if (file.existsSync()) {
    data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } else {
    data = jsonDecode(File(
            'packages/nepali_panchang/test/fixtures/'
            'festival_receipts_2026.json')
        .readAsStringSync()) as Map<String, dynamic>;
  }
  final receipts = (data['receipts'] as List).cast<Map<String, dynamic>>();

  test('every 2026 fixture receipt maps to a battery rule', () {
    for (final r in receipts) {
      expect(festivalRuleById(r['id'] as String).id, r['id'] as String);
    }
  });

  test('the whole battery carries the shastra vocabulary (HYA-417)', () {
    for (final rule in festivalBattery) {
      expect(rule.shastraCategory, isNotNull,
          reason: '\${rule.id} lacks shastraCategory');
      expect(rule.shastraCitation, isNotNull,
          reason: '\${rule.id} lacks shastraCitation');
      expect(rule.shastraCitation, contains('Dharma Sindhu'),
          reason: '\${rule.id} citation must name its source');
    }
  });

  for (final r in receipts) {
    final id = r['id'] as String;
    final expected = _d(r['ad_date'] as String);
    test('HYA-417 \$id: engine reproduces the published day', () {
      final mine = scanFestivals(
          start: expected.subtract(const Duration(days: 5)),
          end: expected.add(const Duration(days: 5)),
          rules: [festivalRuleById(id)]);
      final matches =
          mine.where((o) => o.chosenDays.contains(expected)).toList();
      expect(matches, isNotEmpty,
          reason: 'no \$id observance chose \$expected; candidates: '
              '\${mine.map((o) => o.chosenDays.join('|')).join(' ; ')}');
    });
  }

  test('Maha Shivaratri 2082: nishita Feb 15, udaya exposes Feb 16', () {
    final obs = scanFestivals(
        start: DateTime.utc(2026, 2, 10),
        end: DateTime.utc(2026, 2, 20),
        rules: [festivalRuleById('mahaShivaratri')]);
    final o = obs.firstWhere((o) => o.chosenDays.contains(_d('2026-02-15')));
    expect(o.occasion.nishitaDays, [_d('2026-02-15')],
        reason: 'Chaturdashi spans the midnight ending Feb 15');
    expect(o.occasion.udayaDays, [_d('2026-02-16')],
        reason: 'the udaya convention gives Feb 16; publishers took '
            'the nishita day - the divergence must stay exposed');
    expect(o.conventionDivergence, isTrue);
  });

  test('Fagu Purnima 2082: hills firstDay Mar 2, Terai udaya Mar 3 '
      'exposed', () {
    final obs = scanFestivals(
        start: DateTime.utc(2026, 2, 25),
        end: DateTime.utc(2026, 3, 8),
        rules: [festivalRuleById('faguPurnima')]);
    final o = obs.firstWhere((o) => o.chosenDays.contains(_d('2026-03-02')));
    expect(o.occasion.overlapDays, contains(_d('2026-03-02')));
    expect(o.occasion.udayaDays, [_d('2026-03-03')],
        reason: 'Purnima began mid-day Mar 2 (udaya Chaturdashi); the '
            'Terai udaya day must be exposed');
    expect(o.conventionDivergence, isTrue);
  });

  test('Janai Purnima 2083: udaya Aug 28, first-overlap Aug 27 exposed',
      () {
    final obs = scanFestivals(
        start: DateTime.utc(2026, 8, 22),
        end: DateTime.utc(2026, 9, 3),
        rules: [festivalRuleById('janaiPurnima')]);
    final o = obs.firstWhere((o) => o.chosenDays.contains(_d('2026-08-28')));
    expect(o.occasion.overlapDays, contains(_d('2026-08-27')),
        reason: 'Purnima began Aug 27 09:24 NPT (BhaktiBharat); '
            'publishers took the udaya day Aug 28 instead');
  });

  test('Teej 2083: udaya Sep 14, both overlap days exposed', () {
    final obs = scanFestivals(
        start: DateTime.utc(2026, 9, 8),
        end: DateTime.utc(2026, 9, 20),
        rules: [festivalRuleById('teej')]);
    final o = obs.firstWhere((o) => o.chosenDays.contains(_d('2026-09-14')));
    expect(o.occasion.overlapDays, contains(_d('2026-09-13')),
        reason: 'Tritiya ran Sep 13 07:24 to Sep 14 07:23 NPT '
            '(BhaktiBharat); both days must be visible');
  });
}
