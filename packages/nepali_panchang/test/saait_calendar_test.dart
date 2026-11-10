import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// R10.4 saait layer gate (HYA-441 item 5). The fixture
/// test/fixtures/saait_receipts_2083.json (schema
/// nmiti-saait-receipts/1, crawl 2026-11-10) freezes:
///
/// - the katigate BS 2083 sahit corpus: the merged upcoming table (249
///   ceremony-day rows, 127 distinct days, Kartik 26 2083 = 2026-11-12
///   through Chaitra 30 2083 = 2027-04-13) and the six per-ceremony
///   pages whose concatenated digit-string day lists resolve by hard
///   constraints (ascending day order + merged-table presence +
///   event-chip month anchors + strictly-increasing month attribution +
///   minimal segmentation), raw strings retained;
/// - the Sarvartha Siddhi vara-nakshatra table (dekhopanchang,
///   classical Muhurta Chintamani/Nirnaya Sindhu) and the Amrit Siddhi
///   pairs + 24 dated 2026 instance windows (hinducalendar.app, IST
///   computed for Ujjain).
///
/// The engine cross-checks: publisher tithi labels are checked against
/// the engine's udaya tithi with knife-edge-only tolerance - a label may
/// disagree ONLY on a borderline/vriddhi/kshaya day and only against the
/// udaya/noon/neighbour identities; every other disagreement fails the
/// gate. Honest records, not gaps: griha aramba serves only the
/// event-anchored Mangsir days (the remaining strings fit multiple
/// months), and the Dec 18 2026 Amrit window that opens mid-run under
/// the publisher's convention does not fire under this engine's
/// at-sunrise convention.

final Map<String, dynamic> _fixture =
    jsonDecode(File('test/fixtures/saait_receipts_2083.json')
        .readAsStringSync()) as Map<String, dynamic>;

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const Map<String, int> _fixtureWeekdayToDart = {
  'Monday': DateTime.monday,
  'Tuesday': DateTime.tuesday,
  'Wednesday': DateTime.wednesday,
  'Thursday': DateTime.thursday,
  'Friday': DateTime.friday,
  'Saturday': DateTime.saturday,
  'Sunday': DateTime.sunday,
};

DateTime _d(String s) {
  final p = s.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Bare tithi base name: 'Shukla Pratipada' -> 'Pratipada'.
String _baseTithi(String canonical) {
  var n = canonical;
  if (n.startsWith('Shukla ')) n = n.substring(7);
  if (n.startsWith('Krishna ')) n = n.substring(8);
  return n;
}

void main() {
  group('fixture integrity (nmiti-saait-receipts/1)', () {
    test('schema, crawl date, BS 2083 month starts', () {
      expect(_fixture['schema'], 'nmiti-saait-receipts/1');
      expect(_fixture['crawl_date'], '2026-11-10');
      final starts = _fixture['bs_2083_month_starts'] as Map<String, dynamic>;
      expect(starts['Kartik'], '2026-10-18');
      expect(starts['Mangsir'], '2026-11-17');
      expect(starts['Poush'], '2026-12-16');
      expect(starts['Magh'], '2027-01-15');
      expect(starts['Falgun'], '2027-02-13');
      expect(starts['Chaitra'], '2027-03-15');
      final v = _fixture['validation'] as Map<String, dynamic>;
      expect(v['merged_table_rows'], 249);
      expect(v['distinct_days'], 127);
      expect(v['weekday_selfcheck'] as String, startsWith('0 mismatches'));
    });

    test('ceremony claimed vs served counts and day rows', () {
      final cs = _fixture['ceremonies'] as Map<String, dynamic>;
      const expected = {
        'vivah': [41, 26],
        'bratabandha': [13, 9],
        'griha-pravesh': [2, 1],
        'griha-aramba': [9, 3],
        'pasni': [36, 14],
        'vyaparik': [44, 26],
      };
      expect(cs.keys.toSet(), expected.keys.toSet());
      for (final e in expected.entries) {
        final c = cs[e.key] as Map<String, dynamic>;
        expect(c['claimed_count_bs2083'], e.value[0],
            reason: '${e.key} claimed count');
        expect(c['served_count'], e.value[1], reason: '${e.key} served');
        final days = c['days'] as List;
        expect(days, hasLength(e.value[1]));
        for (final day in days) {
          final d = day as Map<String, dynamic>;
          expect(d['bs_month'], isNotNull, reason: '${e.key} month resolved');
          expect(d['month_number'], isNotNull);
          expect(d['bs_day'], isNotNull);
          expect(d['ad'], isNotEmpty);
          expect(d['weekday'], isNotEmpty);
          expect(d['tithi_label'], isNotEmpty);
        }
      }
      // griha aramba month ambiguity beyond Mangsir is recorded, not
      // guessed.
      expect(cs['griha-aramba']['unresolved'], isNotNull);
      expect(
        (cs['griha-aramba']['months'] as List)
            .where((m) => (m as Map<String, dynamic>)['bs_month'] == null)
            .length,
        2,
      );
    });

    test('merged-block singletons (dhanyachhedan, hom, rudri)', () {
      final merged = _fixture['merged_block_ceremonies'] as List;
      expect(merged, hasLength(3));
      expect((merged[0] as Map<String, dynamic>)['ad'], '2026-11-12');
      expect((merged[0] as Map<String, dynamic>)['ceremony'],
          'dhanyachhedan');
      expect((merged[1] as Map<String, dynamic>)['ad'], '2026-11-13');
      expect((merged[1] as Map<String, dynamic>)['ceremony'], 'hom');
      expect((merged[2] as Map<String, dynamic>)['ad'], '2026-11-14');
      expect((merged[2] as Map<String, dynamic>)['ceremony'], 'rudri');
    });

    test('SSY table shape, Amrit pairs, instance corpus', () {
      final ssy = _fixture['ssy'] as Map<String, dynamic>;
      final table = ssy['table'] as Map<String, dynamic>;
      expect(table.keys.toSet(),
          {'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
           'Saturday'});
      const counts = {
        'Sunday': 7,
        'Monday': 6,
        'Tuesday': 5,
        'Wednesday': 6,
        'Thursday': 6,
        'Friday': 6,
        'Saturday': 4,
      };
      table.forEach((k, v) {
        expect((v as List).length, counts[k], reason: k);
        for (final n in v as List) {
          expect(nakshatraNames.contains(n as String), isTrue,
              reason: '$k: $n is not a canonical nakshatra name');
        }
      });
      final amrit = ssy['amrit_table'] as Map<String, dynamic>;
      expect(amrit['Sunday'], 'Hasta');
      expect(amrit['Monday'], 'Mrigashira');
      expect(amrit['Tuesday'], 'Ashwini');
      expect(amrit['Wednesday'], 'Anuradha');
      expect(amrit['Thursday'], 'Pushya');
      expect(amrit['Friday'], 'Revati');
      expect(amrit['Saturday'], 'Rohini');
      expect(
          ssy['amrit_instances_2026_ist_ujjain'] as List, hasLength(24));
    });

    test('caveats recorded', () {
      final ids = ( _fixture['caveats'] as List)
          .map((c) => (c as Map<String, dynamic>)['id'] as String)
          .toSet();
      expect(ids, containsAll(<String>[
        'griha-aramba-month-attribution',
        'upcoming-only-window',
        'merged-block-singletons',
        'minimal-segmentation',
        'unattributed-merged-rows',
        'amrit-dec18-convention-collision',
        'griha-pravesh-ad-date',
      ]));
    });
  });

  group('engine profiles equal the frozen corpus', () {
    test('every ceremony profile matches its fixture days', () {
      final cs = _fixture['ceremonies'] as Map<String, dynamic>;
      final byCeremony = <String, SaaitCeremony>{
        'vivah': SaaitCeremony.vivah,
        'bratabandha': SaaitCeremony.bratabandha,
        'griha-pravesh': SaaitCeremony.grihaPravesh,
        'griha-aramba': SaaitCeremony.grihaAramba,
        'pasni': SaaitCeremony.pasni,
        'vyaparik': SaaitCeremony.vyaparik,
      };
      byCeremony.forEach((key, ceremony) {
        final f = cs[key] as Map<String, dynamic>;
        final p = saaitProfiles2083[ceremony]!;
        expect(p.ceremony, ceremony);
        expect(p.bsYear, 2083);
        expect(p.claimedCount, f['claimed_count_bs2083'],
            reason: key);
        expect(p.days, hasLength((f['days'] as List).length),
            reason: key);
        for (var i = 0; i < p.days.length; i++) {
          final d = p.days[i];
          final fd = (f['days'] as List)[i] as Map<String, dynamic>;
          expect(d.bsMonth, fd['month_number'],
              reason: '$key day $i bs month');
          expect(d.bsDay, fd['bs_day'], reason: '$key day $i bs day');
          expect(d.dateNpt, _d(fd['ad'] as String),
              reason: '$key day $i AD date');
          expect(d.tithiLabel, fd['tithi_label'],
              reason: '$key day $i tithi label');
          // Weekday self-check: derived from the AD date vs published.
          expect(_weekdayNames[d.dateNpt.weekday - 1], fd['weekday'],
              reason: '$key ${fd['ad']} weekday');
        }
      });
      // The merged-block singletons.
      for (final mb in _fixture['merged_block_ceremonies'] as List) {
        final m = mb as Map<String, dynamic>;
        final ceremony = SaaitCeremony.values
            .firstWhere((c) => c.name == m['ceremony'] as String);
        final p = saaitProfiles2083[ceremony]!;
        expect(p.days, hasLength(1), reason: m['ceremony'] as String);
        expect(p.days[0].dateNpt, _d(m['ad'] as String));
        expect(p.days[0].bsMonth, m['month_number']);
        expect(p.days[0].bsDay, m['bs_day']);
        expect(p.days[0].tithiLabel, m['tithi_label']);
        expect(p.claimedCount, -1);
        expect(p.caveats, isNotEmpty);
      }
    });

    test('82 served days in total (79 paged + 3 merged-block)', () {
      expect(
          saaitProfiles2083.values.expand((p) => p.days).length, 82);
      expect(saaitProfiles2083.keys.length, SaaitCeremony.values.length);
    });

    test('griha aramba serves only its event-anchored Mangsir days', () {
      final p = saaitProfiles2083[SaaitCeremony.grihaAramba]!;
      expect(p.days.map((d) => d.bsMonth).toSet(), {8}); // Mangsir
      expect(p.days.map((d) => d.bsDay).toList(), [5, 9, 10]);
      expect(p.caveats, isNotEmpty);
      expect(p.closureNote, isNotNull); // the Chaturmas/wet-season note
    });
  });

  test('every served AD date falls inside its BS month window', () {
    final starts = _fixture['bs_2083_month_starts'] as Map<String, dynamic>;
    const order = [
      'Kartik',
      'Mangsir',
      'Poush',
      'Magh',
      'Falgun',
      'Chaitra',
    ];
    final monthNumber = {
      'Kartik': 7,
      'Mangsir': 8,
      'Poush': 9,
      'Magh': 10,
      'Falgun': 11,
      'Chaitra': 12,
    };
    final allDays = <Map<String, dynamic>>[
      for (final c in (_fixture['ceremonies'] as Map<String, dynamic>)
          .values)
        for (final d in (c as Map<String, dynamic>)['days'] as List)
          d as Map<String, dynamic>,
      for (final m in _fixture['merged_block_ceremonies'] as List)
        m as Map<String, dynamic>,
    ];
    expect(allDays, hasLength(82));
    for (final d in allDays) {
      final name = d['bs_month'] as String;
      final i = order.indexOf(name);
      expect(i, greaterThanOrEqualTo(0), reason: 'unknown month $name');
      expect(d['month_number'], monthNumber[name]);
      final ad = _d(d['ad'] as String);
      final from = _d(starts[name] as String);
      final to = i + 1 < order.length
          ? _d(starts[order[i + 1]] as String)
          : DateTime.utc(2027, 4, 14);
      expect(ad.isBefore(to) && !ad.isBefore(from), isTrue,
          reason: '${d['ad']} outside ${name} window '
              'from $from to $to');
    }
  });

  group('publisher tithi labels vs engine (locked corpora window)', () {
    // Served days 2026-11-12..2026-12-31: the window where the golden
    // lunar corpora lock the engine's udaya chain (17/17 label matches
    // recorded at crawl time; knife-edges: Nov 21 Haribodhini
    // udaya-divergence, Nov 22 Dwadashi kshaya).
    List<Map<String, dynamic>> getCases() {
      final inWindow = <Map<String, dynamic>>[];
      void add(Map<String, dynamic> d) {
        final ad = d['ad'] as String;
        if (ad.compareTo('2026-11-12') >= 0 &&
            ad.compareTo('2026-12-31') <= 0) {
          inWindow.add(d);
        }
      }

      for (final c
          in (_fixture['ceremonies'] as Map<String, dynamic>).values) {
        for (final d in (c as Map<String, dynamic>)['days'] as List) {
          add(d as Map<String, dynamic>);
        }
      }
      for (final m in _fixture['merged_block_ceremonies'] as List) {
        add(m as Map<String, dynamic>);
      }
      return inWindow;
    }

    test('labels match the engine udaya tithi; knife-edge tolerance only',
        () {
      final cases = getCases();
      expect(cases.length, greaterThan(25));
      var knifeEdges = 0;
      for (final day in cases) {
        final ad = _d(day['ad'] as String);
        final p = panchangFor(year: ad.year, month: ad.month, day: ad.day);
        final label = day['tithi_label'] as String;
        final udayaBase = _baseTithi(p.tithiAtUdaya.name);
        if (label == udayaBase) continue;
        // A disagreement is tolerated ONLY on a knife-edge day and only
        // against neighbouring tithi identities.
        final flagged =
            p.tithiBorderline || p.tithiKshaya || p.tithiVriddhi;
        expect(flagged, isTrue,
            reason: '${day['ad']}: label "$label" vs engine udaya '
            '"$udayaBase" is a non-knife-edge disagreement');
        final candidates = <String>{
          udayaBase,
          _baseTithi(p.tithiAtNoon.name),
          _baseTithi(panchangFor(
                  year: ad.subtract(const Duration(days: 1)).year,
                  month: ad.subtract(const Duration(days: 1)).month,
                  day: ad.subtract(const Duration(days: 1)).day)
              .tithiAtUdaya
              .name),
          _baseTithi(panchangFor(
                  year: ad.add(const Duration(days: 1)).year,
                  month: ad.add(const Duration(days: 1)).month,
                  day: ad.add(const Duration(days: 1)).day)
              .tithiAtUdaya
              .name),
        };
        expect(candidates.contains(label), isTrue,
            reason: '${day['ad']}: knife-edge label "$label" is not among '
            'the neighbouring tithis $candidates');
        knifeEdges++;
      }
      // The window must be exercised, not vacuously passed.
      expect(knifeEdges, lessThan(cases.length));
    });
  });

  group('Sarvartha/Amrit Siddhi finders', () {
    test('SSY index consts equal the fixture table', () {
      final table = (_fixture['ssy'] as Map<String, dynamic>)['table']
          as Map<String, dynamic>;
      table.forEach((k, names) {
        final expected = (names as List)
            .map((n) => nakshatraNames.indexOf(n as String))
            .toList();
        expect(sarvarthaSiddhiNakshatrasByWeekday[_fixtureWeekdayToDart[k]],
            expected,
            reason: k);
      });
      final amrit = (_fixture['ssy'] as Map<String, dynamic>)['amrit_table']
          as Map<String, dynamic>;
      amrit.forEach((k, n) {
        expect(
            amritSiddhiNakshatraByWeekday[_fixtureWeekdayToDart[k]],
            nakshatraNames.indexOf(n as String),
            reason: k);
      });
      // Name helper agrees with the indices.
      expect(sarvarthaSiddhiNames(DateTime.wednesday).contains('Anuradha'),
          isTrue);
    });

    test('fires iff the udaya nakshatra is in the weekday table '
        '(Nov 12 - Dec 31 2026, both directions)', () {
      var fired = 0;
      for (var d = DateTime.utc(2026, 11, 12);
          !d.isAfter(DateTime.utc(2026, 12, 31));
          d = d.add(const Duration(days: 1))) {
        final p = panchangFor(year: d.year, month: d.month, day: d.day);
        final s =
            sarvarthaSiddhiOn(year: d.year, month: d.month, day: d.day);
        final inTable = sarvarthaSiddhiNakshatrasByWeekday[d.weekday]!
            .contains(p.nakshatraAtUdaya.index);
        expect(s != null, inTable, reason: '$d');
        if (s != null) {
          fired++;
          expect(s.dateNpt, d);
          expect(
              s.amrit,
              amritSiddhiNakshatraByWeekday[d.weekday] ==
                  p.nakshatraAtUdaya.index,
              reason: '$d amrit flag');
          expect(s.nakshatraName, p.nakshatraAtUdaya.name);
          expect(s.beginsAtNpt, p.sunriseNpt);
          expect(s.endsAtNpt, p.nakshatraAtUdaya.endsAtNpt);
          expect(s.beginsAtNpt.isBefore(s.endsAtNpt), isTrue);
        }
      }
      // The classical table fires on roughly 40% of days.
      expect(fired, greaterThan(10));
    });

    test('Amrit receipt: Wed Nov 11 2026, Anuradha at sunrise '
        '(hinducalendar 06:39-11:37 IST, Ujjain)', () {
      final s = sarvarthaSiddhiOn(year: 2026, month: 11, day: 11);
      expect(s, isNotNull);
      expect(s!.amrit, isTrue);
      expect(s.nakshatraName, 'Anuradha');
      final p = panchangFor(year: 2026, month: 11, day: 11);
      expect(s.beginsAtNpt, p.sunriseNpt);
      // The receipt window is ~4h58m at Ujjain; the engine's Kathmandu
      // window must be the same order (Anuradha spans the whole morning
      // across the region).
      expect(s.endsAtNpt.difference(s.beginsAtNpt).inMinutes,
          inInclusiveRange(240, 360));
    });

    test('Amrit collision receipt: Fri Dec 18 2026 (window opens 16:09 '
        'IST mid-run) does NOT fire at sunrise', () {
      expect(sarvarthaSiddhiOn(year: 2026, month: 12, day: 18), isNull);
    });

    test('Dec 19 2026 knife-edge: no fire, or Revati SSY without Amrit '
        '(Saturday Amrit is Rohini)', () {
      final s = sarvarthaSiddhiOn(year: 2026, month: 12, day: 19);
      if (s != null) {
        expect(s.nakshatraName, 'Revati');
        expect(s.amrit, isFalse);
      }
    });
  });

  group('window composition (L4)', () {
    test('Thursday Nov 25 2026 smoke: Abhijit equality, good choghadiya, '
        'auspicious horas', () {
      final w = saaitWindowsFor(year: 2026, month: 11, day: 25);
      final m = muhurtaFor(year: 2026, month: 11, day: 25);
      expect(w.abhijit.beginsAtNpt, m.abhijitMuhurta.beginsAtNpt);
      expect(w.abhijit.endsAtNpt, m.abhijitMuhurta.endsAtNpt);
      // Thursday choghadia: day from Jupiter [Shubh, Rog, Udveg, Chal,
      // Labh, Amrut, Kal] -> 3 good; night [Udveg, Shubh, Amrut, Chal,
      // Rog, Kal, Labh] -> 3 good.
      expect(w.goodChoghadiya.length, 6);
      expect(
          w.goodChoghadiya
              .every((s) => _goodTypes.contains(s.type)),
          isTrue);
      for (final s in w.goodChoghadiya) {
        expect(s.beginsAtNpt.isBefore(s.endsAtNpt), isTrue);
      }
      expect(w.auspiciousHoras, isNotEmpty);
      expect(
          w.auspiciousHoras
              .every((h) => _auspiciousLords.contains(h.lord)),
          isTrue);
    });
  });

  group('engine knife-edge receipts', () {
    test('Nov 18 2026: Navami begins 06:21 (one minute after sunrise) - '
        'borderline, udaya tithi Ashtami', () {
      final p = panchangFor(year: 2026, month: 11, day: 18);
      expect(p.tithiBorderline, isTrue);
      expect(_baseTithi(p.tithiAtUdaya.name), 'Ashtami');
    });

    test('Nov 22 2026: Dwadashi kshaya at Kathmandu - kshaya flag, '
        'udaya tithi Trayodashi (the katigate label)', () {
      final p = panchangFor(year: 2026, month: 11, day: 22);
      expect(p.tithiKshaya, isTrue);
      expect(_baseTithi(p.tithiAtUdaya.name), 'Trayodashi');
    });

    test('SaaitDay composes and passes engine flags through '
        '(vyaparik Nov 21-22 2026)', () {
      final days = saaitDaysBetween(SaaitCeremony.vyaparik,
          DateTime.utc(2026, 11, 20), DateTime.utc(2026, 11, 23));
      expect(days, hasLength(2)); // Mangsir 5 + 6
      expect(days[0].fixed.dateNpt, DateTime.utc(2026, 11, 21));
      expect(days[0].fixed.tithiLabel, 'Ekadashi');
      final nov22 = days[1];
      expect(nov22.fixed.dateNpt, DateTime.utc(2026, 11, 22));
      expect(nov22.tithiKshaya, isTrue);
      expect(nov22.profile.ceremony, SaaitCeremony.vyaparik);
      expect(nov22.windows.abhijit.beginsAtNpt
          .isBefore(nov22.windows.abhijit.endsAtNpt), isTrue);
      expect(nov22.provenance, isNotEmpty);
      expect(nov22.evidenceTier, contains('nmiti-saait-receipts/1'));
    });

    test('conventions exposed for the honesty pages', () {
      expect(saaitConventions.keys, containsAll(<String>[
        'dayLists',
        'ssy',
        'ssyOverrides',
        'windows',
        'guruShukraAsta',
        'location',
      ]));
      expect(saaitConventions['guruShukraAsta'], contains('NOT computed'));
      expect(saaitConventions['ssyOverrides'], contains('NOT applied'));
    });

    test('saaitAllDaysBetween: 82 days, date-sorted, through Apr 12 2027',
        () {
      final all = saaitAllDaysBetween(
          DateTime.utc(2026, 11, 1), DateTime.utc(2027, 4, 30));
      expect(all, hasLength(82));
      for (var i = 1; i < all.length; i++) {
        expect(
            all[i - 1].fixed.dateNpt.isBefore(all[i].fixed.dateNpt) ||
                all[i - 1].fixed.dateNpt == all[i].fixed.dateNpt,
            isTrue,
            reason: 'not sorted at index $i');
      }
      expect(all.last.fixed.dateNpt, DateTime.utc(2027, 4, 12));
      // The griha pravesh singleton is Falgun 20 = 2027-03-04.
      final gp = saaitDaysBetween(SaaitCeremony.grihaPravesh,
          DateTime.utc(2026, 11, 1), DateTime.utc(2027, 4, 30));
      expect(gp, hasLength(1));
      expect(gp[0].fixed.dateNpt, DateTime.utc(2027, 3, 4));
      expect(gp[0].fixed.tithiLabel, 'Ekadashi');
    });
  });
}

const Set<String> _goodTypes = {'Amrut', 'Shubh', 'Labh'};
const Set<String> _auspiciousLords = {'Moon', 'Mercury', 'Jupiter', 'Venus'};
