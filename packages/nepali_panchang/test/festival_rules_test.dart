import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Festival rules test (R6b, HYA-367).
///
/// Permanent CI gate against the 2083 festival receipt corpus: the 14
/// Dashain-Tihar festivals crawled from Hamro Patro date pages (festival
/// labels + displayed tithi) plus the Nepal Panchang Nirnayak Samiti
/// adjudications reported in the press (two-day Maha Ashtami, Fulpati on
/// Asoj 30, tika on Kartik 4, Kojagrat on Kartik 8). Each receipt pins the
/// convention the publisher/samiti used; the engine must reproduce the
/// chosen day(s) under exactly that convention, and the hard cases assert
/// that the other conventions are exposed rather than hidden.

DateTime _d(String s) {
  final p = s.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

bool _sameDays(List<DateTime> a, List<DateTime> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

void main() {
  final file = File('test/fixtures/festival_receipts_2083.json');
  final Map<String, dynamic> data;
  if (file.existsSync()) {
    data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } else {
    // CI runs from the package root; also try the repo-root variant.
    data = jsonDecode(File(
            'packages/nepali_panchang/test/fixtures/'
            'festival_receipts_2083.json')
        .readAsStringSync()) as Map<String, dynamic>;
  }
  final receipts = (data['receipts'] as List).cast<Map<String, dynamic>>();

  // One shared scan over the full Dashain-Tihar stretch.
  final observances = scanFestivals(
      start: DateTime.utc(2026, 10, 1), end: DateTime.utc(2026, 11, 20));

  test('every fixture receipt maps to a battery rule', () {
    for (final r in receipts) {
      expect(festivalRuleById(r['id'] as String).id, r['id'] as String);
    }
  });

  test('scan covers the whole battery in the window', () {
    final ids = observances.map((o) => o.rule.id).toSet();
    for (final rule in festivalBattery) {
      expect(ids.contains(rule.id), isTrue,
          reason: 'no occasion for ${rule.id} in the window');
    }
  });

  for (final r in receipts) {
    final id = r['id'] as String;
    final expected = ((r['ad_dates'] as List?) ?? [r['ad_date'] as String])
        .cast<String>()
        .map(_d)
        .toList();
    test('$id: engine reproduces the published day(s)', () {
      final mine = observances.where((o) => o.rule.id == id).toList();
      expect(mine, isNotEmpty, reason: 'no $id observance scanned');
      final matches =
          mine.where((o) => _sameDays(o.chosenDays, expected)).toList();
      expect(matches, isNotEmpty,
          reason: 'no $id observance chose ${expected.join(', ')}; '
              'candidates: '
              '${mine.map((o) => o.chosenDays.join('|')).join(' ; ')}');
    });
  }

  test('Fulpati 2083 (Asoj 30) is the borderline first-day case', () {
    final o = observances.firstWhere((o) =>
        o.rule.id == 'fulpati' && o.chosenDays.contains(_d('2026-10-17')));
    expect(o.occasion.borderline, isTrue,
        reason: 'Saptami begins minutes after the Asoj 30 sunrise; the '
            'occasion must carry the borderline flag');
    expect(o.conventionDivergence, isTrue,
        reason: 'the udaya convention gives Kartik 1 (Oct 18)');
  });

  test('Maha Ashtami 2083 spans two civil days (samiti listed both)', () {
    final o = observances.firstWhere((o) =>
        o.rule.id == 'mahaAshtami' &&
        o.chosenDays.contains(_d('2026-10-18')));
    expect(o.chosenDays.length, 2);
    expect(o.chosenDays, [_d('2026-10-18'), _d('2026-10-19')]);
    expect(o.occasion.spansMultipleDays, isTrue);
    expect(o.conventionDivergence, isTrue,
        reason: 'the udaya convention gives only Kartik 2 (Oct 19)');
  });

  test('Kojagrat Purnima exposes both conventions: evening Oct 25, udaya '
      'Oct 26', () {
    final o = observances.firstWhere((o) =>
        o.rule.id == 'kojagratPurnima' &&
        o.chosenDays.contains(_d('2026-10-25')));
    expect(o.occasion.udayaDays, [_d('2026-10-26')],
        reason: 'Purnima runs Oct 25 ~12:12 to Oct 26 09:57; the udaya '
            'day is Oct 26 and must be exposed');
    expect(o.conventionDivergence, isTrue);
  });

  test('Laxmi Puja (evening Nov 8) and Gai Puja (udaya Nov 9) share one '
      'Amavasya', () {
    final laxmi = observances.firstWhere((o) =>
        o.rule.id == 'laxmiPuja' &&
        o.chosenDays.contains(_d('2026-11-08')));
    final gai = observances.firstWhere(
        (o) => o.rule.id == 'gaiPuja' && o.chosenDays.contains(_d('2026-11-09')));
    expect(laxmi.occasion.beginsAtNpt, gai.occasion.beginsAtNpt,
        reason: 'both festivals ride the same Amavasya run');
    expect(laxmi.conventionDivergence, isTrue);
  });

  test('Dhanteras (evening Nov 6) and Kag Tihar (udaya Nov 7) share one '
      'Trayodashi', () {
    final dhan = observances.firstWhere((o) =>
        o.rule.id == 'dhanteras' &&
        o.chosenDays.contains(_d('2026-11-06')));
    final kag = observances.firstWhere(
        (o) => o.rule.id == 'kagTihar' && o.chosenDays.contains(_d('2026-11-07')));
    expect(dhan.occasion.beginsAtNpt, kag.occasion.beginsAtNpt,
        reason: 'both festivals ride the same Trayodashi run');
  });
}
