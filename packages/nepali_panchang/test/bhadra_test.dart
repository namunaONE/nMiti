import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Bhadra (Vishti karana) receipt gate - R10.1 ritual layer 1, HYA-441.
///
/// Gates the Bhadra module against the 2026 receipt corpus
/// (test/fixtures/bhadra_receipts_2026.json, crawled 2026-11-07):
///  - 12 Swarnsiddhi window receipts (IST display, NPT = IST + 15 min),
///    every window edge that coincides with a tithi boundary cross-pinned
///    against the locked lunar corpora at the tight corpus band (3 min;
///    10 min on the one HP-pinned edge whose publisher pair disagrees
///    by 9 min), all other edges at the 10 min display band;
///  - the BhaktiBharat festival-page receipts: the Nov 7 today window,
///    the past and next date lists (the begins-date convention), the
///    ghati mukha/puchha rule and the tithi-half map;
///  - the corpus karana receipts: every Vishti day the Oct/Nov/Dec
///    corpora print (BB noon, HP udaya) must fall inside an engine
///    Bhadra window;
///  - the two corpus-derived December windows beyond the Swarnsiddhi
///    table (Purnima Dec 23, Krishna Tritiya Dec 26), pinned to the
///    corpus tithi edges they inherit.
///
/// Two documented knife-edges are allowed and nothing else: a loka
/// segment differing at a window edge by a rashi transition within
/// 20 min of that edge (first case: Nov 30 02:02, the Karka->Simha
/// crossing), and a begins-date differing by one day only when the
/// window begins within 3 min of NPT midnight (first potential case:
/// Nov 23 23:58). The bhaktivoice window times are not gated at all -
/// see the fixture caveat.

DateTime _d(String s) {
  final p = s.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String _ymd(DateTime d) =>
    d.year.toString().padLeft(4, '0') +
    '-' +
    d.month.toString().padLeft(2, '0') +
    '-' +
    d.day.toString().padLeft(2, '0');

/// Rashi 1..12 of the sidereal moon at an NPT wall instant (BB profile).
int _rasiAt(DateTime nptWall) {
  final jdTt = jdTtFromJdUt(jdFromDateTimeUtc(
      nptWall.subtract(const Duration(milliseconds: nptOffsetMs))));
  return (moonSiderealDeg(jdTt, ayanamsaDeltaBhaktiBharat) / 30.0).floor() +
      1;
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void _expectWithin(DateTime engine, DateTime receipt, double bandMin,
    String why) {
  final deltaMin =
      engine.difference(receipt).inSeconds.abs() / 60.0;
  expect(deltaMin, lessThan(bandMin),
      reason: '$why: engine ${engine.toIso8601String()} vs receipt '
          '${receipt.toIso8601String()} = ${deltaMin.toStringAsFixed(2)} '
          'min, band $bandMin min');
}

/// Begins-date list comparison with the midnight knife-edge allowance.
void _expectBeginsDates(
    List<BhadraWindow> wins, List<String> receipt, String why) {
  expect(wins.length, receipt.length,
      reason: '$why: engine ${wins.length} windows vs receipt '
          '${receipt.length} dates');
  for (var i = 0; i < receipt.length; i++) {
    final got = _ymd(wins[i].beginsAtNpt);
    if (got == receipt[i]) continue;
    final b = wins[i].beginsAtNpt;
    final midnightBefore = DateTime.utc(b.year, b.month, b.day);
    final midnightAfter = midnightBefore.add(const Duration(days: 1));
    final nearMidnight =
        b.difference(midnightBefore).abs() <= const Duration(minutes: 3) ||
            b.difference(midnightAfter).abs() <= const Duration(minutes: 3);
    final adjacent =
        DateTime.utc(b.year, b.month, b.day).difference(_d(receipt[i])).abs() <=
            const Duration(days: 1);
    expect(nearMidnight && adjacent, isTrue,
        reason: '$why: begins-date $got vs receipt ${receipt[i]} is not a '
            'midnight knife-edge');
  }
}

/// Loka path comparison with the window-edge knife-edge allowance: the
/// engine and the receipt may differ by one edge segment only when the
/// corresponding rashi transition sits within 20 min of the window
/// edge (fixture caveat row7-leading-edge-knife-edge).
bool _lokaAllowed(List<int> engine, List<int> receipt, BhadraWindow w) {
  if (_sameList(engine, receipt)) return true;
  const edge = Duration(minutes: 20);
  // Receipt saw a leading segment the engine did not: the transition
  // into the engine's first rashi happened just before the window.
  if (engine.length == receipt.length - 1 &&
      _sameList(engine, receipt.sublist(1))) {
    return _rasiAt(w.beginsAtNpt.subtract(edge)) == receipt.first;
  }
  // Receipt saw a trailing segment the engine did not.
  if (engine.length == receipt.length - 1 &&
      _sameList(engine, receipt.sublist(0, receipt.length - 1))) {
    return _rasiAt(w.endsAtNpt.add(edge)) == receipt.last;
  }
  // Engine saw a leading segment the receipt did not: the engine's own
  // transition instant is available on the segment list.
  if (receipt.length == engine.length - 1 &&
      _sameList(receipt, engine.sublist(1))) {
    return w.lokaSegments[1].beginsAtNpt
            .difference(w.beginsAtNpt)
            .abs() <=
        edge;
  }
  // Engine saw a trailing segment the receipt did not.
  if (receipt.length == engine.length - 1 &&
      _sameList(receipt, engine.sublist(0, engine.length - 1))) {
    return w.lokaSegments.last.beginsAtNpt.difference(w.endsAtNpt).abs() <=
        edge;
  }
  return false;
}

void main() {
  final file = File('test/fixtures/bhadra_receipts_2026.json');
  final Map<String, dynamic> data;
  if (file.existsSync()) {
    data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } else {
    data = jsonDecode(File(
            'packages/nepali_panchang/test/fixtures/'
            'bhadra_receipts_2026.json')
        .readAsStringSync()) as Map<String, dynamic>;
  }
  final windows = (data['windows'] as List).cast<Map<String, dynamic>>();
  final dateLists = data['bb_date_lists'] as Map<String, dynamic>;

  group('fixture integrity', () {
    test('schema and the 12 Swarnsiddhi window receipts', () {
      expect(data['schema'], 'nmiti-bhadra-receipts/1');
      expect(windows.length, 12);
      final halves =
          data['rules']['tithi_half_map'] as Map<String, dynamic>;
      expect((halves['shukla'] as Map).length, 4);
      expect((halves['krishna'] as Map).length, 4);
      expect(
          (data['karana_vishti_cross_check'] as List).length, 16);
    });

    test('window fields: durations 9-16 h, karana numbers, rashi 1-12, '
        'ascending', () {
      DateTime? prevBegin;
      for (final w in windows) {
        final begin = parseWallClock(w['npt_begin'] as String);
        final end = parseWallClock(w['npt_end'] as String);
        final minutes = end.difference(begin).inMinutes;
        expect(minutes, greaterThan(9 * 60),
            reason: '${w['date']}: window shorter than 9 h');
        expect(minutes, lessThan(16 * 60),
            reason: '${w['date']}: window longer than 16 h');
        expect(bhadraVishtiKaranaNumbers.contains(w['karana_number']),
            isTrue,
            reason: '${w['date']}: karana ${w['karana_number']} is not '
                'a Vishti number');
        for (final r in (w['loka_rasi'] as List).cast<int>()) {
          expect(r, greaterThanOrEqualTo(1));
          expect(r, lessThanOrEqualTo(12));
        }
        if (prevBegin != null) {
          expect(begin.isAfter(prevBegin), isTrue,
              reason: '${w['date']}: begins before the previous window');
        }
        prevBegin = begin;
      }
    });
  });

  group('structural windows', () {
    test('Nov 1 - Dec 31: 16 windows, first Nov 3, last Dec 29', () {
      // 16, not 15: the Nov 1 scan floor also contains the Krishna
      // Dashami window beginning Nov 3 23:43 NPT - pinned by the
      // fixture's own BB past list (Oct 8 ... Nov 3, Nov 7) and the
      // bhaktivoice caveat row. The first draft of this expectation
      // forgot it: the pre-fix wall-clock round-trip hang meant the
      // scan had never completed when the list was written.
      final wins = bhadraWindows(
          start: DateTime.utc(2026, 11, 1),
          end: DateTime.utc(2026, 12, 31));
      final expected = <String>[
        '2026-11-03', '2026-11-07', '2026-11-13', '2026-11-17',
        '2026-11-20', '2026-11-23', '2026-11-26', '2026-11-30',
        '2026-12-03', '2026-12-07', '2026-12-13', '2026-12-16',
        '2026-12-20', '2026-12-23', '2026-12-26', '2026-12-29',
      ];
      _expectBeginsDates(wins, expected, 'Nov-Dec scan');
    });

    test('lunar month Nov 9 - Dec 9: exactly 8 windows with ascending '
        'karana numbers and the pinned tithi halves', () {
      final wins = bhadraWindows(
          start: DateTime.utc(2026, 11, 9),
          end: DateTime.utc(2026, 12, 9));
      expect(wins.length, 8);
      expect(wins.map((w) => w.karanaNumber).toList(),
          bhadraVishtiKaranaNumbers);
      expect(wins.map((w) => w.tithiIndex).toList(),
          [3, 7, 10, 14, 17, 21, 24, 28]);
      expect(wins.map((w) => w.firstHalfOfTithi).toList(),
          [false, true, false, true, false, true, false, true]);
      for (final w in wins) {
        final minutes = w.durationNpt.inMinutes;
        expect(minutes, greaterThan(9 * 60));
        expect(minutes, lessThan(16 * 60));
      }
    });

    test('bhadraNear: null on Nov 8, present on the gated Bhadra days',
        () {
      expect(bhadraNear(year: 2026, month: 11, day: 8), isNull);
      expect(bhadraNear(year: 2026, month: 11, day: 7), isNotNull);
      expect(bhadraNear(year: 2026, month: 12, day: 3), isNotNull);
      expect(bhadraNear(year: 2026, month: 12, day: 16), isNotNull);
    });

    test('nextBhadraAfter skips a window already running', () {
      final fromOutside =
          nextBhadraAfter(DateTime.utc(2026, 11, 8, 6));
      _expectWithin(fromOutside.beginsAtNpt,
          DateTime.utc(2026, 11, 13, 7, 40), 10, 'next after Nov 8');
      final fromInside = nextBhadraAfter(DateTime.utc(2026, 11, 7, 12));
      _expectWithin(fromInside.beginsAtNpt,
          DateTime.utc(2026, 11, 13, 7, 40), 10,
          'the running Nov 7 window is skipped');
    });
  });

  group('dated window receipts (Swarnsiddhi, corpus-pinned edges)', () {
    for (final w in windows) {
      final date = w['date'] as String;
      test('$date ${w['tithi']} (${w['half']} half)', () {
        final day = _d(date);
        final near = bhadraNear(
            year: day.year, month: day.month, day: day.day);
        expect(near, isNotNull, reason: 'no Bhadra window begins $date');
        final begin = parseWallClock(w['npt_begin'] as String);
        final end = parseWallClock(w['npt_end'] as String);
        _expectWithin(near!.beginsAtNpt, begin, 10, '$date begin');
        _expectWithin(near.endsAtNpt, end, 10, '$date end');
        expect(near.karanaNumber, w['karana_number'],
            reason: '$date karana number');
        expect(near.tithiIndex, tithiIndexFromName(w['tithi'] as String),
            reason: '$date tithi identity');
        expect(near.firstHalfOfTithi, w['half'] == 'first',
            reason: '$date tithi half');
        final pin = w['corpus_pin'] as Map<String, dynamic>?;
        if (pin != null) {
          final pinned = parseWallClock(pin['published_npt'] as String);
          final edge = pin['edge'] == 'begin'
              ? near.beginsAtNpt
              : near.endsAtNpt;
          _expectWithin(
              edge,
              pinned,
              (pin['band_min'] as num).toDouble(),
              '$date corpus pin (${pin['receipt']}, ${pin['source']} '
              '${pin['corpus']})');
        }
      });
    }

    test('Nov 7 today window: BB festival page 10:47-23:04 IST agrees',
        () {
      final w = bhadraNear(year: 2026, month: 11, day: 7)!;
      _expectWithin(w.beginsAtNpt, DateTime.utc(2026, 11, 7, 11, 2), 10,
          'BB today begin (10:47 IST = 11:02 NPT)');
      _expectWithin(w.endsAtNpt, DateTime.utc(2026, 11, 7, 23, 19), 10,
          'BB today end (23:04 IST = 23:19 NPT)');
    });

    test('Dec 23 Purnima window (corpus-derived): begins at the HP '
        'corpus Purnima begin', () {
      final w = bhadraNear(year: 2026, month: 12, day: 23)!;
      expect(w.karanaNumber, 29);
      expect(w.firstHalfOfTithi, isTrue);
      _expectWithin(w.beginsAtNpt, DateTime.utc(2026, 12, 23, 11, 6), 12,
          'Purnima begin (HP corpus: Shukla Chaturdashi ends Dec 23 '
          '11:06)');
      _expectWithin(w.endsAtNpt, DateTime.utc(2026, 12, 23, 21, 9), 40,
          'Purnima midpoint (Purnima Dec 23 11:06 - Dec 24 07:13, '
          'time-midpoint 21:09; band absorbs the rate asymmetry)');
    });

    test('Dec 26 Krishna Tritiya window (corpus-derived): ends at the '
        'corpus Tritiya end', () {
      final w = bhadraNear(year: 2026, month: 12, day: 26)!;
      expect(w.karanaNumber, 36);
      expect(w.firstHalfOfTithi, isFalse);
      _expectWithin(w.endsAtNpt, DateTime.utc(2026, 12, 26, 20, 21), 3,
          'Tritiya end (bb corpus 20:21, hp 20:28)');
      _expectWithin(w.beginsAtNpt, DateTime.utc(2026, 12, 26, 10, 1), 40,
          'Tritiya midpoint (Tritiya Dec 25 23:41 - Dec 26 20:21, '
          'time-midpoint 10:01)');
    });

    test('Dec 29 Krishna Saptami window (corpus-derived): begins at the '
        'corpus Saptami begin', () {
      final w = bhadraNear(year: 2026, month: 12, day: 29)!;
      expect(w.karanaNumber, 43);
      expect(w.firstHalfOfTithi, isTrue);
      _expectWithin(w.beginsAtNpt, DateTime.utc(2026, 12, 29, 13, 40), 3,
          'Saptami begin (bb and hp both print 13:40)');
      _expectWithin(w.endsAtNpt, DateTime.utc(2026, 12, 30, 1, 16), 40,
          'Saptami midpoint (Saptami Dec 29 13:40 - Dec 30 12:52, '
          'time-midpoint 01:16)');
    });
  });

  group('loka paths', () {
    for (final w in windows) {
      final date = w['date'] as String;
      test('$date loka path', () {
        final day = _d(date);
        final near = bhadraNear(
            year: day.year, month: day.month, day: day.day);
        expect(near, isNotNull, reason: 'no Bhadra window begins $date');
        final engine =
            near!.lokaSegments.map((s) => s.rasi).toList();
        final receipt = (w['loka_rasi'] as List).cast<int>();
        expect(_lokaAllowed(engine, receipt, near), isTrue,
            reason: '$date: engine rashi path $engine vs receipt '
                '$receipt is not equal and not a window-edge '
                'knife-edge');
        for (final s in near.lokaSegments) {
          expect(s.loka, bhadraLokaByRasi[s.rasi],
              reason: '$date: rashi ${s.rasi} loka does not follow the '
                  'canonical map');
        }
      });
    }
  });

  group('mukha and puchha conventions', () {
    test('ghati rule: fixed durations (mukha 2 h, puchha 1 h 12 min)',
        () {
      final w = bhadraNear(year: 2026, month: 11, day: 13)!;
      expect(w.mukhaEndsAtNpt,
          w.beginsAtNpt.add(const Duration(hours: 2)));
      expect(
          w.puchhaBeginsAtNpt,
          w.endsAtNpt
              .subtract(const Duration(hours: 1, minutes: 12)));
    });

    test('fraction rule: Nov 7 window vs the Swarnsiddhi live values '
        '(mukha 2 h 03 m, puchha 1 h 14 m)', () {
      final w = bhadraNear(year: 2026, month: 11, day: 7)!;
      _expectWithin(w.mukhaEndsAtNptFractional,
          DateTime.utc(2026, 11, 7, 13, 6), 5,
          'fractional mukha end (12:51 IST = 13:06 NPT, 1/6 of the '
          '12 h 18 m window)');
      _expectWithin(w.puchhaBeginsAtNptFractional,
          DateTime.utc(2026, 11, 7, 22, 7), 5,
          'fractional puchha begin (21:52 IST = 22:07 NPT, 1/10 of '
          'the window)');
    });
  });

  group('conventions exposure (honesty fields)', () {
    test('both mukha/puchha rule families and both loka tables are '
        'exposed, the variant never absorbed', () {
      expect(bhadraConventions.containsKey('mukha_puchha_primary'),
          isTrue);
      expect(
          bhadraConventions.containsKey('mukha_puchha_fraction'), isTrue);
      expect(bhadraConventions.containsKey('loka_canonical'), isTrue);
      expect(bhadraConventions.containsKey('loka_variant'), isTrue);
      for (final rasi in [1, 2, 3, 4, 5, 8, 9, 10]) {
        expect(bhadraLokaByRasiContiguousVariant[rasi],
            bhadraLokaByRasi[rasi],
            reason: 'rasi $rasi: the variant must agree with the '
                'canonical table where the source rows coincide');
      }
      for (final rasi in [6, 7, 11, 12]) {
        expect(bhadraLokaByRasiContiguousVariant[rasi],
            isNot(bhadraLokaByRasi[rasi]),
            reason: 'rasi $rasi: the variant must disagree with the '
                'canonical table exactly at 6, 7, 11, 12');
      }
      final windows0 = bhadraWindows(
          start: DateTime.utc(2026, 11, 7), end: DateTime.utc(2026, 11, 8));
      expect(windows0, isNotEmpty);
      expect(windows0.first.provenance, contains('nMiti'));
      expect(windows0.first.evidenceTier, contains('bhadra_receipts'));
    });

    test('canonical loka map matches the fixture rule table', () {
      final canon =
          data['rules']['loka_canonical'] as Map<String, dynamic>;
      for (final entry in canon.entries) {
        for (final rasi in (entry.value as List).cast<int>()) {
          expect(bhadraLokaByRasi[rasi]!.name, entry.key,
              reason: 'rasi $rasi must be ${entry.key}');
        }
      }
    });
  });

  group('BhaktiBharat date lists (begins-date convention)', () {
    test('past dates: nine Bhadra days Oct 8 - Nov 7', () {
      final wins = bhadraWindows(
          start: DateTime.utc(2026, 10, 6),
          end: DateTime.utc(2026, 11, 8));
      _expectBeginsDates(
          wins, (dateLists['past'] as List).cast<String>(), 'past list');
    });

    test('next dates: seven Bhadra days Nov 7 - Nov 30', () {
      // The BB 'next' list starts at the crawl day (Nov 7), so the
      // scan floor must be Nov 7 too: a Nov 1 floor also contains
      // the Nov 3 Krishna Dashami window, which BB lists under
      // 'past'.
      final wins = bhadraWindows(
          start: DateTime.utc(2026, 11, 7),
          end: DateTime.utc(2026, 12, 1));
      _expectBeginsDates(
          wins, (dateLists['next'] as List).cast<String>(), 'next list');
    });
  });

  group('corpus karana receipts', () {
    test('every corpus Vishti day (BB noon, HP udaya) falls inside an '
        'engine Bhadra window', () {
      final cross = (data['karana_vishti_cross_check'] as List)
          .cast<Map<String, dynamic>>();
      for (final c in cross) {
        final day = _d(c['date'] as String);
        DateTime refWall;
        if (c['reference'] == 'noon') {
          refWall = DateTime.utc(day.year, day.month, day.day, 12);
        } else {
          refWall = dateTimeUtcFromJd(sunriseJdUt(
                  year: day.year, month: day.month, day: day.day))
              .add(const Duration(milliseconds: nptOffsetMs));
        }
        final wins = bhadraWindows(
            start: day.subtract(const Duration(days: 1)),
            end: day.add(const Duration(days: 2)));
        final inside = wins
            .where((w) =>
                !w.beginsAtNpt.isAfter(refWall) &&
                w.endsAtNpt.isAfter(refWall))
            .toList();
        expect(inside, isNotEmpty,
            reason: '${c['date']} ${c['reference']}: the corpus Vishti '
                'receipt falls in no engine Bhadra window');
      }
    });
  });
}
