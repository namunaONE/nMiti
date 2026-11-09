import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Vrat calendar receipt gate (R10.3, HYA-441).
///
/// Loads test/fixtures/vrat_receipts_2026_11_12.json (frozen Nov 9
/// 2026: Hamro Patro named-vrat labels over the Mangsir panel pages,
/// BhaktiBharat Kathmandu tithi edges for Nov + Dec 2026, the
/// astrologger New Delhi IST vrat tables, the bhaktiras 2026 sankashti
/// list) and gates the engine against every receipt. Bands:
///   BhaktiBharat       13 tithi edges within 1.5 min (the locked
///                      lunar-corpus band);
///   Hamro Patro        13 tithi edges within 12 min (their print
///                      band);
///   astrologger (IST)   8 edges within 12 min after the +15 min
///                      IST-to-NPT shift;
///   day identities      every vrat_days row served exactly once with
///                      the receipt tithi and the receipt borderline
///                      state;
///   moonrise            the Nov 27 / Dec 26 / Dec 27 BhaktiBharat
///                      moonrise anchors within 12 min (the
///                      published provisional band), with the Nov 27
///                      chandrodaya-vyapti and Dec 26 sink-case
///                      membership checks;
///   supporting vrats    every named-vrat udaya receipt inside the
///                      engine run of its tithi, the Kushmand Navami
///                      vriddhi holding both sunrises;
///   year scan           the BS-2083 grid counts, ordering, spacing
///                      and uniqueness.
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

/// The DateTime.utc of a "yyyy-MM-dd" fixture date.
DateTime _utcDate(String s) => DateTime.utc(int.parse(s.substring(0, 4)),
    int.parse(s.substring(5, 7)), int.parse(s.substring(8, 10)));

double _wallDeltaMin(DateTime a, DateTime b) =>
    a.difference(b).inMicroseconds / 60e6;

/// The engine sunrise of a civil date, NPT wall clock.
DateTime _sunriseOf(DateTime d) =>
    dateTimeUtcFromJd(sunriseJdUt(year: d.year, month: d.month, day: d.day))
        .add(const Duration(milliseconds: nptOffsetMs));

/// The VratFamily of a fixture family key.
VratFamily _familyOf(String key) =>
    VratFamily.values.firstWhere((f) => vratFamilyName(f) == key);

/// The reference kind each family pins its day with.
String _referenceKindOf(VratFamily f) {
  switch (f) {
    case VratFamily.ekadashi:
      return 'madhyahna';
    case VratFamily.pradosham:
      return 'sunset';
    case VratFamily.sankashtiChaturthi:
      return 'moonrise';
    case VratFamily.purnima:
    case VratFamily.amavasya:
      return 'udaya';
  }
}

void main() {
  final fx = _loadFixture('vrat_receipts_2026_11_12.json');
  final boundaries =
      (fx['tithi_boundaries'] as List).cast<Map<String, dynamic>>();
  final vratDayRows =
      (fx['vrat_days'] as List).cast<Map<String, dynamic>>();
  final supporting =
      (fx['supporting_named_vrats'] as List).cast<Map<String, dynamic>>();
  final moonrises =
      (fx['moonrise_receipts'] as List).cast<Map<String, dynamic>>();
  final caveats = (fx['caveats'] as List).cast<Map<String, dynamic>>();

  test('schema and corpus shape', () {
    expect(fx['schema'], 'nmiti-vrat-receipts/1');
    expect(fx['crawl_date'], '2026-11-09');
    expect(boundaries.length, 34,
        reason: '13 bb + 13 hp + 8 ist tithi edges');
    expect(vratDayRows.length, 12);
    expect(supporting.length, 5);
    expect(moonrises.length, 3);
    expect(caveats.length, 6);
    // Every tithi name is a canonical engine name.
    for (final row in boundaries) {
      expect(tithiIndexFromName(row['tithi'] as String),
          greaterThanOrEqualTo(0),
          reason: '${row['tithi']} is not a canonical tithi name');
    }
  });

  test('tithi boundary receipts: engine edges inside the publisher bands',
      () {
    for (final row in boundaries) {
      final idx = tithiIndexFromName(row['tithi'] as String);
      // IST prints (tz 330) land on NPT 15 minutes later on the clock.
      final tz = (row['tz_offset_min'] as int?) ?? 345;
      final inst =
          parseWallClock(row['npt'] as String).add(
              Duration(minutes: 345 - tz));
      final band = (row['band_min'] as num).toDouble();
      final runs = tithiRunsBetween(
          startNpt: inst.subtract(const Duration(days: 2)),
          endNpt: inst.add(const Duration(days: 2)));
      final candidates = runs
          .where((r) => r.tithiIndex == idx)
          .where((r) => (row['edge'] == 'begins'
                  ? _wallDeltaMin(r.beginsNpt, inst)
                  : _wallDeltaMin(r.endsNpt, inst))
              .abs() < 36 * 60)
          .toList();
      expect(candidates.length, 1,
          reason: '${row['source']} ${row['tithi']} ${row['edge']} '
          '${row['npt']}: expected exactly one matching run');
      final run = candidates.first;
      final engineEdge =
          row['edge'] == 'begins' ? run.beginsNpt : run.endsNpt;
      final d = _wallDeltaMin(engineEdge, inst);
      expect(d.abs(), lessThan(band),
          reason: '${row['source']} ${row['tithi']} ${row['edge']} '
          '${row['npt']} delta ${d.toStringAsFixed(2)} min '
          '(band $band)');
    }
  });

  test('tithi runs are contiguous, ordered and sane over a week', () {
    final runs = tithiRunsBetween(
        startNpt: DateTime.utc(2026, 11, 15),
        endNpt: DateTime.utc(2026, 11, 22));
    expect(runs.length, greaterThan(6));
    for (var i = 0; i < runs.length; i++) {
      final durH = runs[i].endsNpt.difference(runs[i].beginsNpt).inMinutes /
          60.0;
      expect(durH, inExclusiveRange(17.5, 30.5),
          reason: '${runs[i].tithiName} run duration ${durH.toStringAsFixed(2)} h');
      if (i > 0) {
        expect(runs[i].tithiIndex, (runs[i - 1].tithiIndex + 1) % 30,
            reason: 'tithi indices must advance by one');
        // Two coarse brackets converge to within ULPs of the same
        // crossing - the shared edge must agree far below any band.
        expect(
            _wallDeltaMin(runs[i].beginsNpt, runs[i - 1].endsNpt).abs(),
            lessThan(1.0 / 60.0),
            reason: 'runs must share edges');
      }
    }
  });

  test('vrat day identity receipts: every row served exactly once', () {
    final days = vratDays(
        startNpt: DateTime.utc(2026, 11, 15),
        endNpt: DateTime.utc(2026, 12, 31, 23, 59));
    for (final row in vratDayRows) {
      final family = _familyOf(row['family'] as String);
      final date = _utcDate(row['date'] as String);
      final hits = days
          .where((d) =>
              d.family == family &&
              d.dateNpt.year == date.year &&
              d.dateNpt.month == date.month &&
              d.dateNpt.day == date.day)
          .toList();
      expect(hits.length, 1,
          reason: '${row['family']} ${row['date']} (${row['source']} '
          '${row['label']}) must be served exactly once');
      final hit = hits.first;
      expect(hit.tithiName, row['tithi'] as String,
          reason: '${row['family']} ${row['date']} tithi');
      expect(hit.familyName, row['family'] as String);
      expect(hit.referenceKind, _referenceKindOf(family),
          reason: '${row['family']} ${row['date']} reference kind');
      if (row.containsKey('engine_borderline')) {
        expect(hit.borderline, row['engine_borderline'] as bool,
            reason: '${row['family']} ${row['date']} borderline state '
            '(engine reason: ${hit.borderlineReason})');
      }
      // The observed tithi run brackets the chosen day.
      expect(hit.tithiBeginsNpt.isBefore(hit.tithiEndsNpt), isTrue);
    }
  });

  test('borderline semantics decode as the receipts say', () {
    final days = vratDays(
        startNpt: DateTime.utc(2026, 11, 15),
        endNpt: DateTime.utc(2026, 12, 31, 23, 59));
    VratDay day(String family, String date) {
      final f = _familyOf(family);
      final y = int.parse(date.substring(0, 4));
      final m = int.parse(date.substring(5, 7));
      final d = int.parse(date.substring(8, 10));
      return days.firstWhere((x) =>
          x.family == f && x.dateNpt.year == y && x.dateNpt.month == m && x.dateNpt.day == d);
    }

    // The Nov 20 Haribodhini Ekadashi: madhyahna keeps Nov 20 where a
    // strict udaya rule moves it to Nov 21 - convention-sensitive.
    final ek20 = day('ekadashi', '2026-11-20');
    expect(ek20.borderline, isTrue);
    expect(ek20.borderlineReason, 'udaya-divergence');
    expect(ek20.referenceKind, 'madhyahna');
    // The Dec 8 Aunsi: the run ends 06:37 NPT, minutes before the Dec
    // 9 sunrise (~06:42) - the membership of Dec 9 flips on minutes.
    final am8 = day('amavasya', '2026-12-08');
    expect(am8.borderline, isTrue);
    expect(am8.borderlineReason, 'sunrise-knife-edge');
    final sr9 = _sunriseOf(DateTime.utc(2026, 12, 9));
    final gapMin = _wallDeltaMin(sr9, am8.tithiEndsNpt);
    expect(gapMin.abs(), lessThan(30),
        reason: 'the Dec 9 sunrise sits ${gapMin.toStringAsFixed(1)} '
        'min from the amavasya end (knife-edge)');
    // The Dec 26 Sankashti: NO moonrise inside the run - the nearest
    // moonrise (Dec 26 19:56, 25 min before the 20:21 begin) names
    // the day; a fallback riding a moonrise knife-edge.
    final s26 = day('sankashti_chaturthi', '2026-12-26');
    expect(s26.borderline, isTrue,
        reason: 'the sink case is a fallback day');
    expect(s26.borderlineReason, contains('moonrise'));
    expect(s26.referenceKind, 'moonrise');
    // The unambiguous receipts are not flagged.
    for (final entry in [
      ['ekadashi', '2026-12-04'],
      ['pradosham', '2026-11-22'],
      ['pradosham', '2026-12-06'],
      ['sankashti_chaturthi', '2026-11-27'],
      ['purnima', '2026-11-24'],
    ]) {
      final d = day(entry[0], entry[1]);
      expect(d.borderline, isFalse,
          reason: '${entry[0]} ${entry[1]} must not be borderline '
          '(${d.borderlineReason})');
    }
  });

  test('sankashti moonrise receipts: engine moonrises inside the BB band',
      () {
    for (final row in moonrises) {
      final date = _utcDate(row['date'] as String);
      final mr = moonriseNpt(
          year: date.year, month: date.month, day: date.day);
      expect(mr, isNotNull, reason: 'the Moon rises on ${row['date']}');
      final rec = parseWallClock(row['npt'] as String);
      final d = _wallDeltaMin(mr!, rec);
      final band = (row['band_min'] as num).toDouble();
      expect(d.abs(), lessThan(band),
          reason: 'BB moonrise receipt ${row['date']} delta '
          '${d.toStringAsFixed(2)} min (band $band)');
    }
    // The chandrodaya-vyapti anchor: the Nov 27 moonrise falls inside
    // the Krishna Chaturthi run.
    final mr27 = moonriseNpt(year: 2026, month: 11, day: 27)!;
    final runsNov = tithiRunsBetween(
        startNpt: DateTime.utc(2026, 11, 25),
        endNpt: DateTime.utc(2026, 11, 30));
    final chatNov = runsNov.firstWhere(
        (r) => r.tithiIndex == tithiIndexFromName('Krishna Chaturthi'));
    expect(chatNov.beginsNpt.isBefore(mr27) && mr27.isBefore(chatNov.endsNpt),
        isTrue,
        reason: 'the Nov 27 moonrise must fall inside the Krishna '
        'Chaturthi run (${chatNov.beginsNpt} -> ${chatNov.endsNpt})');
    // The Dec 26 sink case: NO moonrise inside the chaturthi run -
    // the Dec 26 moonrise sits before the begin, the Dec 27 moonrise
    // past the end, and the nearest-moonrise comparison must favor
    // Dec 26 decisively.
    final runsDec = tithiRunsBetween(
        startNpt: DateTime.utc(2026, 12, 24),
        endNpt: DateTime.utc(2026, 12, 29));
    final chatDec = runsDec.firstWhere(
        (r) => r.tithiIndex == tithiIndexFromName('Krishna Chaturthi'));
    final mr26 = moonriseNpt(year: 2026, month: 12, day: 26)!;
    final mr27dec = moonriseNpt(year: 2026, month: 12, day: 27)!;
    expect(mr26.isBefore(chatDec.beginsNpt), isTrue,
        reason: 'the Dec 26 moonrise must sit before the chaturthi '
        'begin (${chatDec.beginsNpt})');
    expect(mr27dec.isBefore(chatDec.endsNpt), isFalse,
        reason: 'the Dec 27 moonrise must sit past the chaturthi '
        'end (${chatDec.endsNpt})');
    final d26 = chatDec.beginsNpt.difference(mr26);
    final d27 = mr27dec.difference(chatDec.endsNpt);
    expect(d26 < d27, isTrue,
        reason: 'the nearest-moonrise comparison must favor Dec 26 '
        '(${d26.inMinutes} min vs ${d27.inMinutes} min)');
  });

  test('supporting named vrats: every udaya receipt inside the engine run',
      () {
    for (final row in supporting) {
      final date = _utcDate(row['date'] as String);
      final sr = _sunriseOf(date);
      final idx = tithiIndexFromName(row['tithi'] as String);
      final runs = tithiRunsBetween(
          startNpt: date.subtract(const Duration(days: 1)),
          endNpt: date.add(const Duration(days: 1)));
      // firstWhere throws when the udaya membership fails.
      final run = runs.firstWhere(
          (r) => r.tithiIndex == idx && r.beginsNpt.isBefore(sr) && sr.isBefore(r.endsNpt));
      expect(run.tithiName, row['tithi'] as String,
          reason: '${row['date']} ${row['labels']}');
    }
    // The Kushmand Navami vriddhi: BOTH Nov 18 and Nov 19 sunrises
    // inside the same navami run (the first udaya day, Nov 18, is the
    // printed vrat day).
    final runs = tithiRunsBetween(
        startNpt: DateTime.utc(2026, 11, 16),
        endNpt: DateTime.utc(2026, 11, 21));
    final nav = runs.firstWhere((r) => r.tithiIndex == tithiIndexFromName('Shukla Navami'));
    final sr18 = _sunriseOf(DateTime.utc(2026, 11, 18));
    final sr19 = _sunriseOf(DateTime.utc(2026, 11, 19));
    expect(nav.beginsNpt.isBefore(sr18) && sr18.isBefore(nav.endsNpt),
        isTrue,
        reason: 'the Nov 18 sunrise must be inside the vriddhi navami');
    expect(nav.beginsNpt.isBefore(sr19) && sr19.isBefore(nav.endsNpt),
        isTrue,
        reason: 'the Nov 19 sunrise must be inside the vriddhi navami');
  });

  test('BS-2083 year grid: counts, ordering, spacing, uniqueness', () {
    final days = vratDays(
        startNpt: DateTime.utc(2026, 4, 15),
        endNpt: DateTime.utc(2027, 4, 14, 23, 59));
    expect(days.length, inExclusiveRange(75, 105),
        reason: 'five families over one BS year (expected ~84-91)');
    // Ordering: dates non-decreasing, then family order.
    for (var i = 1; i < days.length; i++) {
      expect(!days[i].dateNpt.isBefore(days[i - 1].dateNpt), isTrue,
          reason: 'the grid must be date-sorted');
    }
    final counts = <VratFamily, int>{};
    for (final d in days) {
      counts[d.family] = (counts[d.family] ?? 0) + 1;
    }
    // Monthly families: 12-13 lunations, edge days may cost or gain
    // one. Twice-monthly families: 24-25, with the same one-day edge.
    for (final f in [VratFamily.sankashtiChaturthi, VratFamily.purnima, VratFamily.amavasya]) {
      expect(counts[f] ?? 0, inExclusiveRange(10, 15),
          reason: '$f count ${counts[f]}');
    }
    for (final f in [VratFamily.ekadashi, VratFamily.pradosham]) {
      expect(counts[f] ?? 0, inExclusiveRange(21, 29),
          reason: '$f count ${counts[f]}');
    }
    // Uniqueness: no (family, date) duplicates.
    final keys = days
        .map((d) => '${d.familyName}-${d.dateNpt.toIso8601String()}')
        .toSet();
    expect(keys.length, days.length, reason: 'no duplicate vrat days');
    // Spacing: strictly increasing dates per family, never bunched.
    for (final f in VratFamily.values) {
      final fd = days.where((d) => d.family == f).map((d) => d.dateNpt).toList();
      for (var i = 1; i < fd.length; i++) {
        final gap = fd[i].difference(fd[i - 1]).inDays;
        final minGap = (f == VratFamily.ekadashi || f == VratFamily.pradosham) ? 12 : 24;
        expect(gap, greaterThanOrEqualTo(minGap),
            reason: '$f spacing gap $gap days at ${fd[i]}');
      }
    }
  });

  test('conventions and caveats are exposed for the display layer', () {
    expect(vratConventions.length, 14);
    expect(
        vratConventions.keys,
        containsAll([
          'identity',
          'ekadashi_rule',
          'pradosham_rule',
          'sankashti_rule',
          'purnima_amavasya_rule',
          'borderline_rule',
          'moonrise_dependency',
          'hp_bb_sankashti_absence',
          'hp_flagged_panel_shift',
          'ist_convention_divergence',
          'amanta_month_naming',
          'publisher_divergence',
          'corroboration',
          'location',
        ]));
    expect(vratConventions['ekadashi_rule'], contains('madhyahna'));
    expect(vratConventions['sankashti_rule'], contains('chandrodaya'));
    expect(vratConventions['ist_convention_divergence'],
        allOf(contains('Rama'), contains('Mokshada'), contains('Vijaya')));
    expect(vratConventions['hp_bb_sankashti_absence'],
        contains('absence'));
    final ids = caveats.map((c) => c['id']).toList();
    expect(ids, containsAll([
      'sankashti-label-absence',
      'hp-flagged-panel-shift',
      'ist-convention-divergence',
      'amanta-month-naming',
      'borderline-semantics',
    ]));
  });

  test('family name tables and tithi index bindings', () {
    expect(vratFamilyNames.length, 5);
    expect(vratFamilyNamesNepali.length, 5);
    expect(vratFamilyNames[VratFamily.ekadashi.index], 'ekadashi');
    expect(vratFamilyNamesNepali[VratFamily.sankashtiChaturthi.index],
        'संकष्टी चतुर्थी');
    expect(vratFamilyTithiIndices[VratFamily.sankashtiChaturthi], [18]);
    expect(vratFamilyTithiIndices[VratFamily.pradosham], [12, 27]);
    expect(vratFamilyTithiIndices[VratFamily.ekadashi], [10, 25]);
    expect(vratFamilyTithiIndices[VratFamily.purnima], [14]);
    expect(vratFamilyTithiIndices[VratFamily.amavasya], [29]);
    // The indices match the canonical names.
    expect(tithiName(18), 'Krishna Chaturthi');
    expect(tithiName(12), 'Shukla Trayodashi');
    expect(tithiName(27), 'Krishna Trayodashi');
    expect(tithiName(10), 'Shukla Ekadashi');
    expect(tithiName(25), 'Krishna Ekadashi');
  });

  test('honesty fields name the layer and the corpus', () {
    final days = vratDays(
        startNpt: DateTime.utc(2026, 11, 20),
        endNpt: DateTime.utc(2026, 11, 20, 23, 59));
    expect(days.length, 1,
        reason: 'Nov 20 2026 serves exactly the Haribodhini Ekadashi');
    final d = days.first;
    expect(d.provenance, contains('nMiti nepali_panchang engine'));
    expect(d.evidenceTier, contains('vrat_receipts_2026_11_12'));
    expect(d.dayRule, contains('madhyahna'));
  });

}
