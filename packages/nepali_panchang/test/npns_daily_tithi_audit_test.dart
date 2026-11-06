import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// NPNS full-year daily-tithi audit corpus (HYA-369 deliverable 3).
///
/// The corpus: every day of BS 2082 and BS 2083 (730 receipts, 365 per
/// year) crawled live from the public Hamro Patro portal (the NPNS-aligned
/// publisher) on 2026-11-06 - the per-day tithi label and paksha exactly
/// as displayed, with the portal-rendered AD date parsed to ISO. Every
/// receipt carries its source URL; see the fixture provenance block.
///
/// Three gates, in the honesty order of this repository:
///  1. structural - the corpus itself is complete and continuous: 730
///     receipts, month lengths matching the portal month ends, and a
///     strictly consecutive AD chain (an independent cross-check of the
///     portal BS-to-AD mapping: 2082-1-1 = 2025-04-14 through
///     2083-12-30 = 2027-04-13, no gaps, no repeats).
///  2. chain sanity - the portal labels walk the tithi cycle correctly:
///     step deltas of 1 (normal), 2 (kshaya, a tithi skipped between
///     udayas) or 0 (vriddhi, the same tithi at consecutive udayas) -
///     nothing else, ever. This is astronomy visible in the raw labels.
///  3. engine agreement - the runtime engine tithi at udaya (the Hamro
///     Patro display convention) must equal the portal label on every
///     day, except on knife-edge days: a tithi boundary within half an
///     hour of sunrise (engine tithiBorderline) or a vriddhi/kshaya
///     day (engine flags or the portal's own mark), where publishers
///     legitimately diverge. The scoreboard prints every mismatch for
///     the audit trail. Overall agreement floor 90% - measured, not
///     aspiration: the first CI run (2026-11-06) agreed 671/730
///     (91.92%) with every one of the 59 mismatches on a knife-edge
///     day and zero disagreements elsewhere; the hard gate is the
///     non-knife-edge fail() below, the floor only guards against a
///     bulk regression.

/// Devanagari portal label -> within-paksha number (1..14, Purnima 15,
/// Aunsi 30 - the amavasya). The test decodes the raw labels itself; the
/// fixture carries no derived index.
const _labelIndex = <String, int>{
  'प्रतिपदा': 1,
  'द्वितीया': 2,
  'तृतिया': 3,
  'चतुर्थी': 4,
  'पञ्चमी': 5,
  'षष्ठी': 6,
  'सप्तमी': 7,
  'अष्टमी': 8,
  'नवमी': 9,
  'दशमी': 10,
  'एकादशी': 11,
  'द्वादशी': 12,
  'त्रयोदशी': 13,
  'चतुर्दशी': 14,
  'पूर्णिमा': 15,
  'औंसी': 30,
};

/// Engine tithi index 0..29 expected from a raw portal receipt.
/// Shukla: Pratipada 0 .. Chaturdashi 13, Purnima 14; Krishna:
/// Pratipada 15 .. Chaturdashi 28, Aunsi (Amavasya) 29.
int _expectedIndex(Map<String, dynamic> r) {
  final tithi = r['tithi'] as String;
  final paksha = r['paksha'] as String;
  final n = _labelIndex[tithi];
  if (n == null) {
    fail('unknown tithi label in corpus: $tithi');
  }
  if (n == 15) return 14;
  if (n == 30) return 29;
  final shukla = paksha.startsWith('शुक्ल');
  return shukla ? n - 1 : 15 + n - 1;
}

/// English canonical name of an engine tithi index (for the report).
String _labelName(int index) => tithiName(index);

void main() {
  final file = File('test/fixtures/npns_daily_tithi_2082_2083.json');
  final Map<String, dynamic> data;
  if (file.existsSync()) {
    data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } else {
    // CI runs from the package root; also try the repo-root variant.
    final alt = File(
        'packages/nepali_panchang/test/fixtures/npns_daily_tithi_2082_2083.json');
    data = jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
  }
  final receipts = (data['receipts'] as List).cast<Map<String, dynamic>>();
  final years = (data['years'] as Map<String, dynamic>).cast<String, dynamic>();

  group('NPNS daily tithi audit corpus (BS 2082 + 2083)', () {
    test('corpus is complete and continuous', () {
      expect(receipts.length, 730,
          reason: 'two full BS years, 365 receipts each');
      for (final entry in years.entries) {
        final y = int.parse(entry.key);
        final info =
            (entry.value as Map<String, dynamic>).cast<String, dynamic>();
        final monthEnds = (info['month_ends'] as List).cast<int>();
        expect(monthEnds.length, 12);
        expect(monthEnds.reduce((a, b) => a + b), info['days'] as int,
            reason: 'BS $y: month ends must sum to the day count');
        expect(info['days'] as int, 365, reason: 'BS $y day count');
        final perMonth = <int, List<int>>{};
        for (final r in receipts) {
          final parts = (r['bs'] as String).split('-');
          if (int.parse(parts[0]) != y) continue;
          perMonth
              .putIfAbsent(int.parse(parts[1]), () => [])
              .add(int.parse(parts[2]));
        }
        for (var m = 1; m <= 12; m++) {
          final days = perMonth[m] ?? <int>[];
          expect(days.length, monthEnds[m - 1],
              reason: 'BS $y month $m: ${days.length} receipts, '
                  'month end ${monthEnds[m - 1]}');
          expect(days.toSet().length, days.length,
              reason: 'BS $y month $m: duplicate days');
        }
      }
      // AD chain: strictly consecutive civil days across both years.
      for (var i = 1; i < receipts.length; i++) {
        final prev = DateTime.parse(receipts[i - 1]['ad'] as String);
        final cur = DateTime.parse(receipts[i]['ad'] as String);
        expect(cur.difference(prev).inDays, 1,
            reason: 'AD chain broken at ${receipts[i]['bs']} '
                '${receipts[i]['ad']} (prev ${receipts[i - 1]['ad']})');
      }
      expect(receipts.first['ad'], '2025-04-14',
          reason: 'BS 2082 new year anchor');
      expect(receipts.last['ad'], '2027-04-13',
          reason: 'BS 2083 last day anchor');
    });

    test('portal tithi chain is astronomically sane', () {
      // Walk the decoded indices: deltas of 1 (normal), 2 (kshaya)
      // or 0 (vriddhi) are the only legal steps of a udaya chain.
      var prev = -1;
      for (final r in receipts) {
        final idx = _expectedIndex(r);
        if (prev >= 0) {
          final delta = (idx - prev + 30) % 30;
          expect(delta, lessThanOrEqualTo(2),
              reason: 'BS ${r['bs']}: tithi chain jumped $prev -> $idx '
                  '(delta $delta) - impossible without a publisher error');
        }
        prev = idx;
      }
    });

    test('engine udaya tithi agrees with the portal (knife edges exposed)',
        () {
      var agree = 0;
      final mismatch = <String>[];
      var engineVriddhi = 0;
      var engineKshaya = 0;
      var engineBorderline = 0;
      var portalMarked = 0;
      for (final r in receipts) {
        final ad = DateTime.parse(r['ad'] as String);
        final day =
            panchangFor(year: ad.year, month: ad.month, day: ad.day);
        final expected = _expectedIndex(r);
        final engine = day.tithiAtUdaya.index;
        if (day.tithiVriddhi) engineVriddhi++;
        if (day.tithiKshaya) engineKshaya++;
        if (day.tithiBorderline) engineBorderline++;
        if (r['vriddhi_kshaya_mark'] == true) portalMarked++;
        if (engine == expected) {
          agree++;
          continue;
        }
        // Knife-edge allowance: convention-sensitive days where
        // publishers legitimately diverge.
        final knifeEdge = day.tithiBorderline ||
            day.tithiVriddhi ||
            day.tithiKshaya ||
            r['vriddhi_kshaya_mark'] == true;
        final tag = knifeEdge
            ? 'knife-edge (borderline ${day.tithiBorderline}, vriddhi '
                '${day.tithiVriddhi}, kshaya ${day.tithiKshaya}, '
                'portal-mark ${r['vriddhi_kshaya_mark'] == true})'
            : 'NOT knife-edge';
        final line = 'BS ${r['bs']} (${r['ad']}): portal '
            '${_labelName(expected)} vs engine ${day.tithiAtUdaya.name} '
            '[$tag]';
        mismatch.add(line);
        if (!knifeEdge) {
          fail('engine/portal disagreement on a non-knife-edge day: '
              '$line');
        }
      }
      final pct = 100.0 * agree / receipts.length;
      print('NPNS daily tithi audit: $agree/${receipts.length} agree '
          '(${pct.toStringAsFixed(2)}%); mismatches ${mismatch.length}');
      print('engine flags: borderline $engineBorderline, vriddhi '
          '$engineVriddhi, kshaya $engineKshaya; portal-marked days '
          '$portalMarked');
      for (final m in mismatch) {
        print(m);
      }
      expect(pct, greaterThanOrEqualTo(90.0),
          reason: 'agreement floor for the permanent gate');
    });
  });
}
