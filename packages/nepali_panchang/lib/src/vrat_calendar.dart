import 'ayanamsa.dart';
import 'civil_time.dart';
import 'limbs.dart';
import 'moonrise.dart';
import 'solver.dart';
import 'sunrise.dart';
import 'sunset.dart';

/// Vrat calendar layer (R10.3, HYA-441): the recurring vrat days as a
/// tithi-run scan with per-family day-choosing rules - no new astronomy.
///
/// The layer walks the tithi chain (the same wrap-safe, cross-checked
/// boundary solver every corpus gate uses) and turns each run of a
/// family tithi into the ONE civil day the publishers print the vrat
/// on. The day-choosing conventions were decoded from the frozen 2026
/// receipt corpus and are exposed per day, never silently picked:
///
///   sankashti chaturthi = chandrodaya-vyapti: the day whose MOONRISE
///       falls inside the Krishna Chaturthi run (the receipt: Nov 27
///       2026, BhaktiBharat moonrise 19:56 inside the 10:13 -> 06:55+1
///       run; neither Hamro Patro nor BhaktiBharat prints a sankashti
///       label - the day is derived from their own tithi and moonrise
///       data and corroborated by the bhaktiras list);
///   pradosham = trayodashi vyapta at SUNSET (the pradosh kala
///       anchor; both pakshas, 24 a year - the receipts: Nov 22 and
///       Dec 6 2026, HP prints प्रदोष on both);
///   ekadashi (both pakshas) = madhyahna-vyapini: the LAST civil day
///       whose NOON falls inside the run (the discriminating receipt:
///       Haribodhini Ekadashi printed Nov 20 2026 though the tithi
///       begins 07:31, after the sunrise - a strict udaya rule would
///       print Nov 21);
///   purnima / amavasya = the udaya day (the sunrise inside the run);
///       on vriddhi the FIRST udaya day (the receipt: Kushmand Navami
///       Nov 18 2026, the first of the two udaya days).
///
/// Fallbacks (no receipt in the corpus pins them; every fallback day
/// carries borderline=true): a run that traps no reference instant
/// names the begin day (ekadashi/pradosham), the udaya day
/// (sankashti) or the day holding the run's midpoint
/// (purnima/amavasya). Borderline also flags the knife-edges: a run
/// edge within 30 minutes of a reference instant, a run holding two
/// reference instants, and - for ekadashi - any day a strict udaya
/// rule would have printed instead. Borderline means
/// convention-sensitivity, not engine doubt: the corpus holds
/// receipt-verified days in both states.

/// The five vrat families the year grid serves.
enum VratFamily { sankashtiChaturthi, pradosham, ekadashi, purnima, amavasya }

/// Canonical family keys, in enum order.
const List<String> vratFamilyNames = [
  'sankashti_chaturthi',
  'pradosham',
  'ekadashi',
  'purnima',
  'amavasya',
];

/// Nepali family labels for the display layer.
const List<String> vratFamilyNamesNepali = [
  'संकष्टी चतुर्थी',
  'प्रदोष',
  'एकादशी',
  'पूर्णिमा',
  'औंसी',
];

/// The tithi indices (0-based, Shukla Pratipada = 0) each family rides.
const Map<VratFamily, List<int>> vratFamilyTithiIndices = {
  VratFamily.sankashtiChaturthi: [18],
  VratFamily.pradosham: [12, 26],
  VratFamily.ekadashi: [10, 24],
  VratFamily.purnima: [14],
  VratFamily.amavasya: [29],
};

/// Canonical English family name of [family].
String vratFamilyName(VratFamily family) =>
    vratFamilyNames[family.index];

/// One tithi run: a sector of the elongation with its NPT wall-clock
/// edges. A run is a global instant pair - every location on Earth
/// sees the same run (IST = NPT - 15 min on the clock).
class TithiRun {
  /// Sector index 0..29.
  final int tithiIndex;

  /// Canonical tithi name, e.g. 'Krishna Chaturthi'.
  final String tithiName;

  /// NPT wall clock (UTC fields) when the run began.
  final DateTime beginsNpt;

  /// NPT wall clock (UTC fields) when the run ends.
  final DateTime endsNpt;

  const TithiRun({
    required this.tithiIndex,
    required this.tithiName,
    required this.beginsNpt,
    required this.endsNpt,
  });
}

/// One vrat day: the civil day a family's tithi run is observed on.
class VratDay {
  /// The vrat family.
  final VratFamily family;

  /// Canonical English family key, e.g. 'sankashti_chaturthi'.
  final String familyName;

  /// Nepali family label, e.g. 'संकष्टी चतुर्थी'.
  final String familyNameNepali;

  /// The tithi index (0..29) whose run the day observes.
  final int tithiIndex;

  /// Canonical tithi name, e.g. 'Krishna Chaturthi'.
  final String tithiName;

  /// The chosen civil date (NPT day, UTC fields).
  final DateTime dateNpt;

  /// NPT wall clock when the observed tithi run began.
  final DateTime tithiBeginsNpt;

  /// NPT wall clock when the observed tithi run ends.
  final DateTime tithiEndsNpt;

  /// The choosing rule's reference kind: 'madhyahna' (ekadashi),
  /// 'sunset' (pradosham), 'moonrise' (sankashti) or 'udaya'
  /// (purnima/amavasya).
  final String referenceKind;

  /// The reference instant that pinned the choice, NPT wall clock.
  /// On fallback days it may lie outside the run - the dayRule string
  /// says which fallback fired.
  final DateTime referenceInstantNpt;

  /// The decoded rule that chose the day, human-readable.
  final String dayRule;

  /// True when the choice is convention-sensitive: a run edge within
  /// 30 minutes of a reference instant, a run holding two reference
  /// instants, a fallback day, or (ekadashi) a day a strict udaya
  /// rule would print instead.
  final bool borderline;

  /// Why [borderline] fired, or the empty string.
  final String borderlineReason;

  /// Engine and channel description for this value set.
  final String provenance;

  /// Evidence statement for this day.
  final String evidenceTier;

  const VratDay({
    required this.family,
    required this.familyName,
    required this.familyNameNepali,
    required this.tithiIndex,
    required this.tithiName,
    required this.dateNpt,
    required this.tithiBeginsNpt,
    required this.tithiEndsNpt,
    required this.referenceKind,
    required this.referenceInstantNpt,
    required this.dayRule,
    required this.borderline,
    required this.borderlineReason,
    required this.provenance,
    required this.evidenceTier,
  });
}

/// All tithi runs overlapping the NPT window [startNpt, endNpt].
///
/// The walk starts a day before [startNpt] so a run straddling the
/// window edge is reported whole; every boundary comes from the
/// wrap-safe cross-checked solver (two methods, one answer).
List<TithiRun> tithiRunsBetween({
  required DateTime startNpt,
  required DateTime endNpt,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  final startJdUt = _jdUtOfNptWall(startNpt);
  final endJdUt = _jdUtOfNptWall(endNpt);
  var cursorJdTt = jdTtFromJdUt(startJdUt) - 1.0;
  final endJdTt = jdTtFromJdUt(endJdUt);
  final out = <TithiRun>[];
  final maxRuns = 4.0 + (endJdUt - startJdUt) * 1.6;
  var guard = 0;
  while (true) {
    final idx = limbIndex('tithi', cursorJdTt, sourceDelta);
    final endB = nextLimbBoundaryJdTt('tithi', cursorJdTt, sourceDelta);
    final beginB = _previousTithiBoundaryJdTt(cursorJdTt, idx, sourceDelta);
    final run = TithiRun(
      tithiIndex: idx,
      tithiName: tithiName(idx),
      beginsNpt: _nptWall(beginB),
      endsNpt: _nptWall(endB),
    );
    final overlaps = !run.endsNpt.isBefore(startNpt) &&
        !run.beginsNpt.isAfter(endNpt);
    if (overlaps) {
      out.add(run);
    }
    if (run.beginsNpt.isAfter(endNpt)) {
      break;
    }
    cursorJdTt = endB + 1.0e-7;
    guard++;
    if (guard > maxRuns) {
      throw StateError('tithi run scan exceeded the window guard');
    }
  }
  return out;
}

/// The vrat days whose CHOSEN civil date falls in the NPT window
/// [startNpt, endNpt], for [families] (default: all five).
///
/// Runs straddling a window edge are scanned whole, then filtered on
/// the chosen date - a grid query returns exactly the days the grid
/// displays. Output is sorted by date, then family order.
List<VratDay> vratDays({
  required DateTime startNpt,
  required DateTime endNpt,
  Set<VratFamily>? families,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  final wanted = families ?? VratFamily.values.toSet();
  final runs = tithiRunsBetween(
      startNpt: startNpt, endNpt: endNpt, sourceDelta: sourceDelta);
  final out = <VratDay>[];
  for (final family in VratFamily.values) {
    if (!wanted.contains(family)) {
      continue;
    }
    for (final run in runs) {
      if (!vratFamilyTithiIndices[family]!.contains(run.tithiIndex)) {
        continue;
      }
      final day = _vratDayForRun(family, run);
      final inWindow = !day.dateNpt.isBefore(startNpt) &&
          !day.dateNpt.isAfter(endNpt);
      if (inWindow) {
        out.add(day);
      }
    }
  }
  out.sort((a, b) {
    final byDate = a.dateNpt.compareTo(b.dateNpt);
    if (byDate != 0) {
      return byDate;
    }
    return a.family.index.compareTo(b.family.index);
  });
  return out;
}

/// The named conventions of the vrat layer, for the honesty pages.
const Map<String, String> vratConventions = {
  'identity':
      'The recurring vrat days (Sankashti Chaturthi, Pradosham, Ekadashi, '
      'Purnima, Amavasya) as a tithi-run scan over the shipped limb engine - '
      'no new astronomy, full BS range inherited from the lunar core. Tithi '
      'runs are global instant pairs (IST = NPT - 15 min on the clock); the '
      'day label is the Kathmandu NPT civil day.',
  'ekadashi_rule':
      'Madhyahna-vyapini, both pakshas (24 a year): the last civil day whose '
      'noon (12:00 NPT) falls inside the Ekadashi run. Receipt: Haribodhini '
      'Ekadashi printed 2026-11-20 though the tithi begins 07:31 NPT, after '
      'the sunrise - a strict udaya rule would print Nov 21; the Utpanna '
      'receipt (Dec 4) is unambiguous. On a run holding two noons the later '
      'day wins; a run trapping no noon falls back to the begin day, '
      'borderline flagged.',
  'pradosham_rule':
      'Trayodashi vyapta at sunset - the pradosh kala anchor (Hamro Patro '
      'prints pradosh kala as sunset -45 min to sunset +45 min). Both '
      'pakshas, 24 a year. Receipts: Shukla Nov 22 and Krishna Dec 6 2026 '
      '(HP labels and the astrologger New Delhi list agree). The day whose '
      'sunset falls inside the Trayodashi run; a run trapping no sunset '
      'falls back to the begin day, borderline flagged.',
  'sankashti_rule':
      'Chandrodaya-vyapti: the day whose MOONRISE falls inside the Krishna '
      'Chaturthi run - the receipt: 2026-11-27, BhaktiBharat moonrise 19:56 '
      'NPT inside the 10:13 -> 06:55+1 run, corroborated by the bhaktiras '
      '2026 list (next: Dec 26). A run trapping no moonrise falls back to '
      'its udaya day, borderline flagged.',
  'purnima_amavasya_rule':
      'The udaya day - the civil day whose sunrise falls inside the run. On '
      'vriddhi (two sunrises) the FIRST udaya day, the receipt being '
      'Kushmand Navami 2026-11-18 (first of the two udaya days). A run '
      'trapping no sunrise names the day holding its midpoint, borderline '
      'flagged. Receipts: Purnima 2026-11-24 (Sakimana Punhi / Guru Nanak / '
      'Kartik snan end), Amavasya 2026-12-08 (udaya Aunsi).',
  'borderline_rule':
      'Borderline marks convention-sensitivity, not engine doubt: a run '
      'edge within 30 minutes of a reference instant, a run holding two '
      'reference instants, a fallback day, or (ekadashi) a day a strict '
      'udaya rule would print instead. Receipt-verified days exist in both '
      'states - the Nov 20 Haribodhini Ekadashi is borderline (udaya '
      'divergence) and the Dec 8 Amavasya is borderline (the run ends 06:37 '
      'NPT, minutes before the Dec 9 sunrise), while Nov 22 / Dec 6 Pradosham, '
      'Nov 27 Sankashti, Nov 24 Purnima and Dec 4 Utpanna are not.',
  'moonrise_dependency':
      'Sankashti depends on the Meeus 15.1 moonrise solver (provisional '
      '+-12 min band, the published error bar); every other family depends '
      'only on tithi runs and the USNO sunrise/sunset solvers. A moonrise '
      'within 30 minutes of a Chaturthi run edge is flagged borderline - '
      'the Dec 26 2026 bhaktiras receipt sits exactly there (moonrise ~20:20 '
      'vs the 20:21 run end), and the udaya fallback names Dec 26 either '
      'way.',
  'hp_bb_sankashti_absence':
      'Neither Hamro Patro nor BhaktiBharat prints a sankashti label on '
      '2026-11-27 - a recorded publisher absence, not an engine doubt: the '
      'day is derived from their own printed tithi windows and the '
      'BhaktiBharat moonrise, and corroborated by the bhaktiras sankashti '
      'list (13 dates in 2026, Nov 27 included).',
  'hp_flagged_panel_shift':
      'In a vriddhi stretch Hamro Patro panel labels ride the begin day: '
      'on 2026-11-20 the panel reads Ekadashi while the Nepal Sambat line '
      'reads Dashami (the true udaya chain); the flagged pages print the '
      'flagged tithi START in the samapti field. The vrat day rules key on '
      'tithi runs, not panel labels, so the shift cannot leak in.',
  'ist_convention_divergence':
      'The Indian portals name ekadashis by the udaya family: astrologger '
      'prints Rama Ekadashi on the udaya day Nov 5 2026 (noon day Nov 4) '
      'and Mokshada on the udaya day Dec 20 2026 (no noon inside that '
      'run); the Vijaya vriddhi (Mar 4 2027) is named on the second udaya '
      'day. The engine madhyahna rule reproduces every in-window receipt '
      '(Nov 20, Dec 4 2026 - astrologger agrees on both); the '
      'out-of-window udaya rows are recorded here, never absorbed.',
  'amanta_month_naming':
      'The receipts confirm amanta month naming: Guru Nanak Jayanti on '
      'Kartik Purnima (2026-11-24) and Haribodhini on Kartik Shukla '
      'Ekadashi (2026-11-20), both inside amanta Kartika (2026-11-10 to '
      '12-08).',
  'publisher_divergence':
      'BB and HP print tithi edges minutes apart (the locked corpora: '
      'ekadashi ends 06:47 BB vs 06:48 HP; Chaturthi ends 06:55 BB vs '
      '07:02 HP on 2026-11-28; Amavasya ends 06:37 BB vs 06:35 HP on '
      '12-09). The engine is banded against both (BB +-1.5 min, HP '
      '+-12 min, the published corpus bands) and never absorbs either.',
  'corroboration':
      'The astrologger New Delhi tables (tithi begins/ends in IST, pradosh '
      'kaal columns) corroborate the decoded rules: Prabodhini Ekadashi '
      'named Nov 20 (begins 07:16 IST = 07:31 NPT), Utpanna Dec 4, Ravi '
      'Pradosh Nov 22 and Dec 6 - the same days the engine serves for '
      'Kathmandu, because the day-choosing instants fall hours inside the '
      'runs.',
  'location':
      'Kathmandu anchor 27.7172 N / 85.324 E, NPT (UTC+05:45) throughout - '
      'the nMiti convention. Day-choosing reference instants (sunrise, '
      'sunset, noon, moonrise) are location-dependent; tithi runs are not.',
};

/// Engine honesty strings served on every VratDay.
const String _vratProvenance =
    'nMiti nepali_panchang engine: tithi runs from the separation-frame '
    'elongation (60-term Meeus Ch.47 moon, VSOP87D sun, hybrid Delta T); '
    'reference instants from the USNO sunrise/sunset solvers and the Meeus '
    '15.1 moonrise solver; Kathmandu anchor 27.7172 N / 85.324 E, NPT '
    'throughout.';

const String _vratEvidenceTier =
    'runtime-computed; day-identity calibrated against the locked vrat '
    'receipts corpus (vrat_receipts_2026_11_12: Hamro Patro named-vrat '
    'labels, BB/HP tithi edges cross-locked with the golden lunar corpora, '
    'BhaktiBharat moonrise, astrologger IST corroborations, the bhaktiras '
    'sankashti list; see docs/methodology)';

const Duration _knifeEdge = Duration(minutes: 30);

/// NPT wall clock (UTC fields) of a TT Julian Day.
DateTime _nptWall(double jdTt) {
  return dateTimeUtcFromJd(jdUtFromJdTt(jdTt))
      .add(const Duration(milliseconds: nptOffsetMs));
}

/// UT Julian Day of an NPT wall-clock instant (UTC fields).
double _jdUtOfNptWall(DateTime npt) {
  return jdFromDateTimeUtc(
      npt.subtract(const Duration(milliseconds: nptOffsetMs)));
}

/// TT Julian Day of the tithi crossing strictly before [jdTt] where
/// [idx] is the sector running at [jdTt]: walk back into the previous
/// sector, then let the cross-checked forward solver find the crossing
/// (two methods, one answer - the same discipline every served edge
/// gets).
double _previousTithiBoundaryJdTt(double jdTt, int idx, double sourceDelta) {
  var probe = jdTt - 0.25;
  while (limbIndex('tithi', probe, sourceDelta) == idx) {
    probe -= 0.25;
    if (jdTt - probe > 4.0) {
      throw StateError('failed to bracket the previous tithi crossing');
    }
  }
  return nextLimbBoundaryJdTt('tithi', probe, sourceDelta);
}

/// The NPT noon of a civil date.
DateTime _noonNpt(DateTime d) => DateTime.utc(d.year, d.month, d.day, 12);

/// The engine sunrise of a civil date, NPT wall clock.
DateTime _sunriseNpt(DateTime d) {
  return dateTimeUtcFromJd(
          sunriseJdUt(year: d.year, month: d.month, day: d.day))
      .add(const Duration(milliseconds: nptOffsetMs));
}

/// The engine sunset of a civil date, NPT wall clock.
DateTime _sunsetNpt(DateTime d) {
  return dateTimeUtcFromJd(
          sunsetJdUt(year: d.year, month: d.month, day: d.day))
      .add(const Duration(milliseconds: nptOffsetMs));
}

/// The engine moonrise of a civil date, NPT wall clock, or null.
DateTime? _moonriseNpt(DateTime d) {
  return moonriseNpt(year: d.year, month: d.month, day: d.day);
}

/// The civil dates a run's reference instants can land on: every date
/// from the begin day to the end day inclusive.
List<DateTime> _candidateDates(TithiRun run) {
  final out = <DateTime>[];
  var d = DateTime.utc(
      run.beginsNpt.year, run.beginsNpt.month, run.beginsNpt.day);
  final last = DateTime.utc(
      run.endsNpt.year, run.endsNpt.month, run.endsNpt.day);
  while (!d.isAfter(last)) {
    out.add(d);
    d = DateTime.utc(d.year, d.month, d.day + 1);
  }
  return out;
}

/// True when [a] and [b] are the same civil date.
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Midnight following the civil date [d].
DateTime _nextMidnight(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day + 1);

/// The first civil date in [dates] whose sunrise falls inside [run],
/// or null when the run traps no sunrise.
DateTime? _udayaDay(TithiRun run, List<DateTime> dates) {
  for (final d in dates) {
    final sr = _sunriseNpt(d);
    if (!sr.isBefore(run.beginsNpt) && sr.isBefore(run.endsNpt)) {
      return d;
    }
  }
  return null;
}

/// The chosen vrat day of [family] for [run], conventions decoded from
/// the 2026 receipt corpus (see [vratConventions]).
VratDay _vratDayForRun(VratFamily family, TithiRun run) {
  final dates = _candidateDates(run);
  var day = DateTime.utc(
      run.beginsNpt.year, run.beginsNpt.month, run.beginsNpt.day);
  var reference = _noonNpt(day);
  var borderline = false;
  var reason = '';

  switch (family) {
    case VratFamily.ekadashi:
      // The LAST noon inside the run; fallback the begin day.
      final noons = <DateTime>[];
      for (final d in dates) {
        final n = _noonNpt(d);
        if (!n.isBefore(run.beginsNpt) && n.isBefore(run.endsNpt)) {
          noons.add(d);
        }
      }
      if (noons.isEmpty) {
        day = DateTime.utc(
            run.beginsNpt.year, run.beginsNpt.month, run.beginsNpt.day);
        borderline = true;
        reason = 'no-madhyahna-fallback';
      } else {
        day = noons.last;
        if (noons.length > 1) {
          borderline = true;
          reason = 'two-madhyahna-in-run';
        }
      }
      reference = _noonNpt(day);
      // Knife-edge: a run edge within 30 min of a candidate noon.
      for (final d in dates) {
        final n = _noonNpt(d);
        if (run.beginsNpt.difference(n).abs() < _knifeEdge ||
            run.endsNpt.difference(n).abs() < _knifeEdge) {
          borderline = true;
          reason = 'madhyahna-knife-edge';
        }
      }
      // Convention divergence: a strict udaya rule prints another day.
      final udaya = _udayaDay(run, dates);
      if (udaya != null && !_sameDay(udaya, day)) {
        borderline = true;
        reason = 'udaya-divergence';
      }
      break;

    case VratFamily.pradosham:
      // The LAST sunset inside the run; fallback the begin day.
      final sunsets = <DateTime>[];
      for (final d in dates) {
        final s = _sunsetNpt(d);
        if (!s.isBefore(run.beginsNpt) && s.isBefore(run.endsNpt)) {
          sunsets.add(d);
        }
      }
      if (sunsets.isEmpty) {
        day = DateTime.utc(
            run.beginsNpt.year, run.beginsNpt.month, run.beginsNpt.day);
        borderline = true;
        reason = 'no-sunset-fallback';
      } else {
        day = sunsets.last;
        if (sunsets.length > 1) {
          borderline = true;
          reason = 'two-sunset-in-run';
        }
      }
      reference = _sunsetNpt(day);
      for (final d in dates) {
        final s = _sunsetNpt(d);
        if (run.beginsNpt.difference(s).abs() < _knifeEdge ||
            run.endsNpt.difference(s).abs() < _knifeEdge) {
          borderline = true;
          reason = 'sunset-knife-edge';
        }
      }
      break;

    case VratFamily.sankashtiChaturthi:
      // The day whose moonrise falls inside the run; fallback the
      // udaya day (else the begin day).
      DateTime? moonriseDay;
      DateTime? moonriseAt;
      for (final d in dates) {
        final m = _moonriseNpt(d);
        if (m == null) {
          continue;
        }
        if (!m.isBefore(run.beginsNpt) && m.isBefore(run.endsNpt)) {
          moonriseDay = d;
          moonriseAt = m;
          break;
        }
      }
      if (moonriseDay == null) {
        final udaya = _udayaDay(run, dates);
        day = udaya ??
            DateTime.utc(
                run.beginsNpt.year, run.beginsNpt.month, run.beginsNpt.day);
        borderline = true;
        reason = 'no-moonrise-fallback';
        reference = _sunriseNpt(day);
      } else {
        day = moonriseDay;
        reference = moonriseAt!;
        if (run.beginsNpt.difference(moonriseAt).abs() < _knifeEdge ||
            run.endsNpt.difference(moonriseAt).abs() < _knifeEdge) {
          borderline = true;
          reason = 'moonrise-knife-edge';
        }
      }
      break;

    case VratFamily.purnima:
    case VratFamily.amavasya:
      // The FIRST sunrise inside the run (vriddhi -> first udaya day);
      // fallback the day holding the run midpoint.
      final udaya = _udayaDay(run, dates);
      if (udaya == null) {
        final mid = run.beginsNpt.add(
            Duration(milliseconds: run.endsNpt.difference(run.beginsNpt).inMilliseconds ~/ 2));
        day = DateTime.utc(mid.year, mid.month, mid.day);
        borderline = true;
        reason = 'no-udaya-fallback';
      } else {
        day = udaya;
        // A second sunrise inside the run = vriddhi; the FIRST day is
        // the convention (the Kushmand Navami receipt).
        for (final d in dates) {
          if (_sameDay(d, day)) {
            continue;
          }
          final sr = _sunriseNpt(d);
          if (!sr.isBefore(run.beginsNpt) && sr.isBefore(run.endsNpt)) {
            borderline = true;
            reason = 'vriddhi-first-udaya';
          }
        }
      }
      reference = _sunriseNpt(day);
      for (final d in dates) {
        final sr = _sunriseNpt(d);
        if (run.beginsNpt.difference(sr).abs() < _knifeEdge ||
            run.endsNpt.difference(sr).abs() < _knifeEdge) {
          borderline = true;
          reason = 'sunrise-knife-edge';
        }
      }
      break;
  }

  final ruleText = _dayRuleText(family);
  return VratDay(
    family: family,
    familyName: vratFamilyName(family),
    familyNameNepali: vratFamilyNamesNepali[family.index],
    tithiIndex: run.tithiIndex,
    tithiName: run.tithiName,
    dateNpt: day,
    tithiBeginsNpt: run.beginsNpt,
    tithiEndsNpt: run.endsNpt,
    referenceKind: _referenceKind(family),
    referenceInstantNpt: reference,
    dayRule: ruleText,
    borderline: borderline,
    borderlineReason: reason,
    provenance: _vratProvenance,
    evidenceTier: _vratEvidenceTier,
  );
}

String _referenceKind(VratFamily family) {
  switch (family) {
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

String _dayRuleText(VratFamily family) {
  switch (family) {
    case VratFamily.ekadashi:
      return 'ekadashi = madhyahna-vyapini: the last civil day whose noon '
          'falls inside the run (fallback: the begin day)';
    case VratFamily.pradosham:
      return 'pradosham = trayodashi vyapta at sunset, both pakshas '
          '(fallback: the begin day)';
    case VratFamily.sankashtiChaturthi:
      return 'sankashti = chandrodaya-vyapti: the day whose moonrise falls '
          'inside the Krishna Chaturthi run (fallback: the udaya day)';
    case VratFamily.purnima:
    case VratFamily.amavasya:
      return 'udaya day: the civil day whose sunrise falls inside the run '
          '(vriddhi: the first; fallback: the midpoint day)';
  }
}
