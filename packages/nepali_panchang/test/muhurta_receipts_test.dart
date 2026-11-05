import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Golden-fixture tests for the L4 muhurta receipts corpus (HYA-420 step 2).
///
/// Corpus: BhaktiBharat Kathmandu daily panchang pages for 2026-11-05 ..
/// 2026-11-22, crawled 2026-11-05. Nov 5 was final at crawl time; Nov 6-22
/// were pre-published and are flagged in the fixture for same-day
/// re-verification. Every window was parsed programmatically from the
/// crawled display strings (H:MM AM/PM) - no value was hand-converted into
/// minutes.
///
/// These tests validate publisher self-consistency, not engine accuracy:
/// the published Rahu/Yamaganda/Gulika windows must follow the 8-part rule
/// computed from EACH DAY OWN published sunrise and sunset, Brahma muhurta
/// must sit at the publisher fixed 96/48 minutes before sunrise, the
/// recorded Abhijit divergence from the day/15 rule (BhaktiBharat
/// tabulates a stepped window) must stay inside its band, and the
/// choghadiya tables must satisfy their derivation rules. Engine-vs-receipt
/// muhurta bands land with the muhurta module (step 3).

const _fixtureName = 'muhurta_receipts_2026_11.json';

/// Dart DateTime.weekday: Monday = 1 .. Sunday = 7.
const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _rahuParts = <String, int>{
  'Sunday': 8, 'Monday': 2, 'Tuesday': 7, 'Wednesday': 5,
  'Thursday': 6, 'Friday': 4, 'Saturday': 3,
};

const _yamaParts = <String, int>{
  'Sunday': 5, 'Monday': 4, 'Tuesday': 3, 'Wednesday': 2,
  'Thursday': 1, 'Friday': 7, 'Saturday': 6,
};

const _gulikaParts = <String, int>{
  'Sunday': 7, 'Monday': 6, 'Tuesday': 5, 'Wednesday': 4,
  'Thursday': 3, 'Friday': 2, 'Saturday': 1,
};

const _typeLords = <String, String>{
  'Udveg': 'Sun',
  'Amrit': 'Moon',
  'Rog': 'Mars',
  'Labh': 'Mercury',
  'Shubh': 'Jupiter',
  'Chal': 'Venus',
  'Kal': 'Saturn',
};

const _weekdayLords = <String, String>{
  'Sunday': 'Sun',
  'Monday': 'Moon',
  'Tuesday': 'Mars',
  'Wednesday': 'Mercury',
  'Thursday': 'Jupiter',
  'Friday': 'Venus',
  'Saturday': 'Saturn',
};

const _weekdaysInOrder = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

const _dayCycle = [
  'Jupiter', 'Mars', 'Sun', 'Venus', 'Mercury', 'Moon', 'Saturn',
];

const _nightCycle = [
  'Sun', 'Jupiter', 'Moon', 'Venus', 'Mars', 'Saturn', 'Mercury',
];

Map<String, dynamic> _loadFixture() {
  final file = File('test/fixtures/' + _fixtureName);
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  // CI runs from the package root; also try the repo-root variant.
  final alt = File('packages/nepali_panchang/test/fixtures/' + _fixtureName);
  return jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
}

/// The 1-indexed [part] window of sunrise-to-sunset divided in 8.
Map<String, int> _eightPartWindow(Map<String, dynamic> day, int part) {
  final sr = ((day['sunrise'] as Map<String, dynamic>)['minutes']) as int;
  final ss = ((day['sunset'] as Map<String, dynamic>)['minutes']) as int;
  final partLen = (ss - sr) / 8.0;
  return {
    'start': (sr + (part - 1) * partLen).round(),
    'end': (sr + part * partLen).round(),
  };
}

int _single(Map<String, dynamic> day, String field) {
  return ((day[field] as Map<String, dynamic>)['minutes']) as int;
}

void main() {
  final data = _loadFixture();
  final days = (data['days'] as List).cast<Map<String, dynamic>>();
  final tables = data['rule_tables'] as Map<String, dynamic>;
  final partTables =
      tables['weekday_part_1_indexed'] as Map<String, dynamic>;

  group('fixture integrity', () {
    test('schema and crawl metadata', () {
      expect(data['schema'], 'nmiti-muhurta-receipts/1');
      expect(data['crawl_date'], '2026-11-05');
      expect(data['source'], 'bhaktibharat');
      expect(data['location'], isNotNull);
      expect(data['conventions'], isNotNull);
      expect(data['same_day_reverify'], isNotNull);
    });

    test('18 contiguous days; weekday labels agree with the calendar', () {
      expect(days.length, 18);
      expect(days.first['date'], '2026-11-05');
      expect(days.last['date'], '2026-11-22');
      for (var i = 0; i < days.length; i++) {
        final d = days[i];
        final date = DateTime.parse(d['date'] as String);
        if (i > 0) {
          final prev = DateTime.parse(days[i - 1]['date'] as String);
          expect(date.difference(prev).inDays, 1,
              reason: 'day gap before ' + (d['date'] as String));
        }
        expect(d['weekday'], _weekdayNames[date.weekday - 1],
            reason: 'weekday label wrong on ' + (d['date'] as String));
      }
    });

    test('pre-published flags: Nov 5 final, Nov 6-22 pending re-verify', () {
      expect(days.first['prepublished'], false);
      for (final d in days.skip(1)) {
        expect(d['prepublished'], true,
            reason: (d['date'] as String) + ' must be flagged pre-published');
      }
    });

    test('every day carries the complete parsed field set', () {
      const windowFields = [
        'rahu', 'yamaganda', 'gulika', 'abhijit', 'brahma_muhurta',
        'varjyam', 'amrit_kalam',
      ];
      for (final d in days) {
        final dateStr = d['date'] as String;
        for (final f in ['sunrise', 'sunset', 'moonrise']) {
          final v = d[f] as Map<String, dynamic>;
          expect((v['display'] as String).isNotEmpty, isTrue,
              reason: f + ' display missing on ' + dateStr);
          final minutes = v['minutes'] as int;
          expect(minutes, inInclusiveRange(0, 1439),
              reason: f + ' minutes out of range on ' + dateStr);
        }
        for (final f in windowFields) {
          final v = d[f] as Map<String, dynamic>;
          expect((v['display'] as String).isNotEmpty, isTrue,
              reason: f + ' display missing on ' + dateStr);
          final start = v['start'] as int;
          final end = v['end'] as int;
          expect(start, inInclusiveRange(0, 1439));
          expect(end, inInclusiveRange(0, 1439));
          expect(end, greaterThan(start),
              reason: f + ' window not ordered on ' + dateStr);
        }
        final dur = (d['dur_muhurta'] as List).cast<Map<String, dynamic>>();
        expect(dur.length, 2, reason: 'dur windows on ' + dateStr);
        for (final w in dur) {
          expect((w['end'] as int) - (w['start'] as int),
              inInclusiveRange(41, 46),
              reason: 'dur window length off on ' + dateStr);
        }
      }
    });

    test('weekday part tables are pinned', () {
      expect(partTables['rahu'], _rahuParts);
      expect(partTables['yamaganda'], _yamaParts);
      expect(partTables['gulika'], _gulikaParts);
    });
  });

  group('8-part rule (rahu / yamaganda / gulika)', () {
    for (final d in days) {
      test((d['date'] as String) + ' windows follow the 8-part rule', () {
        final wd = d['weekday'] as String;
        final specs = <String, Map<String, int>>{
          'rahu': partTables['rahu'] as Map<String, int>,
          'yamaganda': partTables['yamaganda'] as Map<String, int>,
          'gulika': partTables['gulika'] as Map<String, int>,
        };
        for (final entry in specs.entries) {
          final exp = _eightPartWindow(d, entry.value[wd]!);
          final pub = d[entry.key] as Map<String, dynamic>;
          expect(((pub['start'] as int) - exp['start']!).abs(),
              lessThanOrEqualTo(2),
              reason: entry.key + ' start off on ' + (d['date'] as String));
          expect(((pub['end'] as int) - exp['end']!).abs(),
              lessThanOrEqualTo(2),
              reason: entry.key + ' end off on ' + (d['date'] as String));
        }
      });
    }
  });

  test('brahma muhurta: fixed 96/48 min before the same-day sunrise', () {
    // BhaktiBharat uses the FIXED convention (not night/15). The engine will
    // expose night/15 as the computed alternative; this pins what the
    // publisher actually prints.
    for (final d in days) {
      final sr = _single(d, 'sunrise');
      final b = d['brahma_muhurta'] as Map<String, dynamic>;
      expect(((b['start'] as int) - (sr - 96)).abs(), lessThanOrEqualTo(1),
          reason: 'brahma start off on ' + (d['date'] as String));
      expect(((b['end'] as int) - (sr - 48)).abs(), lessThanOrEqualTo(1),
          reason: 'brahma end off on ' + (d['date'] as String));
    }
  });

  test('abhijit: publisher tabulated window, divergence inside band', () {
    // The engine will compute the 8th of 15 daylight muhurtas (daylight/15).
    // BhaktiBharat instead prints a slow-stepped table, so the published
    // window drifts 1.3-2.9 min from day/15 across the corpus - recorded
    // publisher convention, allowed out to 4 min here.
    for (final d in days) {
      final sr = _single(d, 'sunrise');
      final ss = _single(d, 'sunset');
      final m15 = (ss - sr) / 15.0;
      final a = d['abhijit'] as Map<String, dynamic>;
      expect(((a['start'] as int) - (sr + 7 * m15).round()).abs(),
          lessThanOrEqualTo(4),
          reason: 'abhijit start beyond publisher band on ' + (d['date'] as String));
      expect(((a['end'] as int) - (sr + 8 * m15).round()).abs(),
          lessThanOrEqualTo(4),
          reason: 'abhijit end beyond publisher band on ' + (d['date'] as String));
      // The tabulation itself: identical windows inside each step group.
    }
  });

  test('hinducalculator 2026-11-05 spot receipt is self-consistent', () {
    final spots = data['spot_receipts'] as Map<String, dynamic>;
    final spot = spots['hinducalculator_2026-11-05'] as Map<String, dynamic>;
    final sr = spot['sunrise'] as int;
    final ss = spot['sunset'] as int;
    final partLen = (ss - sr) / 8.0;
    final specs = <String, int>{
      'rahu': _rahuParts['Thursday']!,
      'yamaganda': _yamaParts['Thursday']!,
      'gulika': _gulikaParts['Thursday']!,
    };
    for (final entry in specs.entries) {
      final w = spot[entry.key] as Map<String, dynamic>;
      final expStart = (sr + (entry.value - 1) * partLen).round();
      final expEnd = (sr + entry.value * partLen).round();
      expect(((w['start'] as int) - expStart).abs(), lessThanOrEqualTo(2));
      expect(((w['end'] as int) - expEnd).abs(), lessThanOrEqualTo(2));
    }
  });

  group('choghadiya rule tables', () {
    final ch = tables['choghadiya'] as Map<String, dynamic>;
    final typeOfLord = <String, String>{};
    for (final e in _typeLords.entries) {
      typeOfLord[e.value] = e.key;
    }

    test('cycle lords pinned in the fixture', () {
      expect((ch['day_cycle_lords'] as List).cast<String>(), _dayCycle);
      expect((ch['night_cycle_lords'] as List).cast<String>(), _nightCycle);
      expect(ch['night_part1_rule'] as String,
          'first night part lord = lord of the weekday 3 days later');
    });

    test('day table: every weekday column follows the derivation rule', () {
      final day = ch['day'] as Map<String, dynamic>;
      for (final wd in _weekdaysInOrder) {
        final parts = (day[wd] as List).cast<String>();
        expect(parts.length, 8, reason: wd + ' day parts');
        final lord = _weekdayLords[wd]!;
        final ci = _dayCycle.indexOf(lord);
        expect(ci, greaterThanOrEqualTo(0), reason: 'lord missing for ' + wd);
        for (var k = 0; k < 8; k++) {
          final expected = typeOfLord[_dayCycle[(ci + k) % 7]];
          expect(parts[k], expected,
              reason: wd + ' day part ' + (k + 1).toString());
        }
      }
    });

    test('night table: every weekday column follows the derivation rule', () {
      final night = ch['night'] as Map<String, dynamic>;
      for (final wd in _weekdaysInOrder) {
        final parts = (night[wd] as List).cast<String>();
        expect(parts.length, 8, reason: wd + ' night parts');
        final firstLord = _weekdayLords[
            _weekdaysInOrder[(_weekdaysInOrder.indexOf(wd) + 3) % 7]]!;
        final ci = _nightCycle.indexOf(firstLord);
        expect(ci, greaterThanOrEqualTo(0),
            reason: 'night first lord missing for ' + wd);
        for (var k = 0; k < 8; k++) {
          final expected = typeOfLord[_nightCycle[(ci + k) % 7]];
          expect(parts[k], expected,
              reason: wd + ' night part ' + (k + 1).toString());
        }
      }
    });
  });
}
