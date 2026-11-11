import 'ayanamsa.dart';
import 'civil_time.dart';
import 'limbs.dart';
import 'solver.dart';

/// Bhadra (Vishti karana) windows - R10.1 ritual layer 1, HYA-441.
///
/// Bhadra is not a separate computation: it IS the Vishti karana, the last
/// of the seven movable karanas, whose half-tithi runs eight times per
/// lunar month. Every Bhadra window is the Vishti karana sector itself -
/// [previous karana boundary, next karana boundary) - derived from the
/// karana limb the engine already serves, so it inherits the limb layer's
/// calibration (the golden corpora pin these same sector boundaries to
/// the minute) and its convergence guarantees (bisection + Newton cross-check).
///
/// Karana arithmetic: the 60 half-tithi sectors carry karana numbers
/// 1..60 (sector index + 1); Vishti lands where (n - 2) % 7 == 6, i.e.
/// n in [bhadraVishtiKaranaNumbers], eight windows per lunar month in
/// ascending order. The month-end fixed karanas (Shakuni, Chatushpada,
/// Naga, then Kimstughna of the new month) break the 7-cycle across
/// Amavasya, which is why the Krishna Chaturdashi window and the next
/// Shukla Chaturthi window are only ~6.4 days apart - structural, the
/// same reset the karana rule table documents.
///
/// Conventions are named, never absorbed (receipt corpus:
/// test/fixtures/bhadra_receipts_2026.json, crawled 2026-11-07):
///   window       = the Vishti half-tithi, a global instant pair - every
///                  publisher serves the same moments, only the wall clock
///                  differs (NPT here; the Indian pages print IST =
///                  NPT minus 15 min);
///   date label   = the NPT civil day on which the window BEGINS
///                  (BhaktiBharat date lists and the Swarnsiddhi table
///                  rows agree on this convention; the Dec 16 row prints
///                  the end day '(17 Dec)' alongside);
///   tithi half   = Shukla Chaturthi 2nd, Ashtami 1st, Ekadashi 2nd,
///                  Purnima 1st; Krishna Tritiya 2nd, Saptami 1st,
///                  Dashami 2nd, Chaturdashi 1st - BhaktiBharat's festival
///                  page states the halves and the karana arithmetic
///                  reproduces all eight symbolically;
///   loka         = the moon's rashi during the window maps to the abode
///                  Swarga/Prithvi/Patala - the canonical
///                  [bhadraLokaByRasi] table (BhaktiBharat, PanchangBodh
///                  and the Swarnsiddhi live windows agree) with the
///                  contiguous variant [bhadraLokaByRasiContiguousVariant]
///                  exposed, never silently resolved;
///   mukha/puchha = two published rule families, both computed and
///                  exposed: the ghati rule (primary; BhaktiBharat: the
///                  first 5 ghatis = 2 h are the mukha and are discarded,
///                  the last 3 ghatis = 1 h 12 min are the auspicious
///                  puchha) and the fraction rule (Swarnsiddhi live
///                  windows: mukha = first 1/6, puchha = last 1/10 of
///                  the window - verified exactly on the Nov 7 window).
///
/// Honesty note: the bhaktivoice live-page window times could NOT be
/// reconciled with the locked golden corpora (their cached Nov 3 window
/// matches no Vishti sector; the engine and the corpora place that
/// Krishna Dashami Vishti at Nov 3 ~23:43 - Nov 4 11:19 NPT). Their
/// window times are therefore recorded as a caveat in the fixture and
/// never gated; only their rule statements (ghati mukha/puchha, the
/// contiguous loka variant) are used.

/// The eight Vishti karana numbers, ascending over one lunar month.
const List<int> bhadraVishtiKaranaNumbers = [8, 15, 22, 29, 36, 43, 50, 57];

/// The 12 rashi names in sector order from Mesha.
const List<String> bhadraRasiNames = [
  'Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya', 'Tula',
  'Vrischika', 'Dhanu', 'Makara', 'Kumbha', 'Meena',
];

/// Bhadra loka (abode) of the moon's transit through a rashi.
enum BhadraLoka { swarga, prithvi, patala }

/// Canonical rashi -> loka map (BhaktiBharat festival page, PanchangBodh
/// guide and the Swarnsiddhi live windows all print this table).
const Map<int, BhadraLoka> bhadraLokaByRasi = {
  1: BhadraLoka.swarga,
  2: BhadraLoka.swarga,
  3: BhadraLoka.swarga,
  4: BhadraLoka.prithvi,
  5: BhadraLoka.prithvi,
  6: BhadraLoka.patala,
  7: BhadraLoka.patala,
  8: BhadraLoka.swarga,
  9: BhadraLoka.patala,
  10: BhadraLoka.patala,
  11: BhadraLoka.prithvi,
  12: BhadraLoka.prithvi,
};

/// The contiguous-arc loka variant (bhaktivoice): Prithvi = Karka..Tula
/// (rashi 4-7), Patala = Dhanu..Meena (rashi 9-12). The source states only
/// those two rows; rashi 1-3 and 8 are completed here as Swarga by
/// elimination and the completion is named in [bhadraConventions]. The
/// variant exists for display and comparison - it is never absorbed into
/// the canonical map, and the two maps disagree exactly at rashi
/// 6, 7, 11 and 12.
const Map<int, BhadraLoka> bhadraLokaByRasiContiguousVariant = {
  1: BhadraLoka.swarga,
  2: BhadraLoka.swarga,
  3: BhadraLoka.swarga,
  4: BhadraLoka.prithvi,
  5: BhadraLoka.prithvi,
  6: BhadraLoka.prithvi,
  7: BhadraLoka.prithvi,
  8: BhadraLoka.swarga,
  9: BhadraLoka.patala,
  10: BhadraLoka.patala,
  11: BhadraLoka.patala,
  12: BhadraLoka.patala,
};

/// Mukha duration, ghati rule: the first 5 ghatis (2 h) of the window.
const Duration bhadraMukhaGhatiDuration = Duration(hours: 2);

/// Puchha duration, ghati rule: the last 3 ghatis (1 h 12 min) of the
/// window.
const Duration bhadraPuchhaGhatiDuration = Duration(hours: 1, minutes: 12);

/// Mukha fraction of the window, fraction rule (Swarnsiddhi live pages).
const double bhadraMukhaFraction = 1.0 / 6.0;

/// Puchha fraction of the window, fraction rule (Swarnsiddhi live pages).
const double bhadraPuchhaFraction = 1.0 / 10.0;

/// The named Bhadra conventions, exposed for the site/API display layer
/// (HYA-441 honesty fields). Keys are stable identifiers, never prose
/// layout.
const Map<String, String> bhadraConventions = {
  'identity':
      'Bhadra = the Vishti karana half-tithi; eight windows per lunar '
      'month, karana numbers 8, 15, 22, 29, 36, 43, 50, 57.',
  'window_frame':
      'The window is the Vishti sector itself, a global instant pair; '
      'wall clocks differ by time zone only (IST = NPT minus 15 min).',
  'date_label':
      'The Bhadra date is the NPT civil day on which the window begins '
      '(BhaktiBharat date lists and Swarnsiddhi table rows).',
  'mukha_puchha_primary':
      'Ghati rule (BhaktiBharat): mukha = first 5 ghatis (2 h), '
      'discarded; puchha = last 3 ghatis (1 h 12 min), auspicious.',
  'mukha_puchha_fraction':
      'Fraction rule (Swarnsiddhi live windows): mukha = first 1/6, '
      'puchha = last 1/10 of the window; both conventions are computed '
      'and exposed, neither is absorbed.',
  'loka_canonical':
      'Canonical rashi->loka table (BhaktiBharat, PanchangBodh, '
      'Swarnsiddhi agree): Swarga = Mesha, Vrishabha, Mithuna, '
      'Vrischika; Prithvi = Karka, Simha, Kumbha, Meena; Patala = '
      'Kanya, Tula, Dhanu, Makara.',
  'loka_variant':
      'Contiguous variant (bhaktivoice): Prithvi = rashi 4-7, Patala = '
      'rashi 9-12; rashi 1-3 and 8 completed as Swarga by elimination '
      '(completion named, not sourced). Disagrees with the canonical '
      'table exactly at rashi 6, 7, 11, 12.',
  'unreconciled_source':
      'bhaktivoice live window times are not corpus-reconcilable and are '
      'never gated; only their rule statements are used (fixture '
      'caveat, 2026-11-07).',
};

/// One loka segment: the span of the Bhadra window during which the
/// moon transits one rashi. Most windows hold one or two segments.
class BhadraLokaSegment {
  /// NPT wall clock (UTC fields) when this segment begins.
  final DateTime beginsAtNpt;

  /// Rashi number 1..12 (Mesha = 1).
  final int rasi;

  /// Loka of this rashi under the canonical [bhadraLokaByRasi] map.
  final BhadraLoka loka;

  const BhadraLokaSegment({
    required this.beginsAtNpt,
    required this.rasi,
    required this.loka,
  });
}

/// One Bhadra window: the Vishti karana half-tithi with its named
/// conventions resolved into fields.
class BhadraWindow {
  /// NPT wall clock (UTC fields) when the window begins - the Vishti
  /// sector's first instant.
  final DateTime beginsAtNpt;

  /// NPT wall clock (UTC fields) when the window ends.
  final DateTime endsAtNpt;

  /// Karana number of the window, one of [bhadraVishtiKaranaNumbers].
  final int karanaNumber;

  /// Tithi index 0..29 of the tithi the window halves.
  final int tithiIndex;

  /// True when the window is the first half of its tithi.
  final bool firstHalfOfTithi;

  /// Rashi segments of the window in time order (1-2 entries).
  final List<BhadraLokaSegment> lokaSegments;

  /// End of the mukha under the ghati rule (begins + 2 h).
  final DateTime mukhaEndsAtNpt;

  /// Begin of the puchha under the ghati rule (ends - 1 h 12 min).
  final DateTime puchhaBeginsAtNpt;

  /// End of the mukha under the fraction rule (begins + window/6).
  final DateTime mukhaEndsAtNptFractional;

  /// Begin of the puchha under the fraction rule (ends - window/10).
  final DateTime puchhaBeginsAtNptFractional;

  /// Engine and ayanamsa profile description for this value set.
  final String provenance;

  /// Evidence statement for every value in this window.
  final String evidenceTier;

  /// Wall-clock length of the window.
  Duration get durationNpt => endsAtNpt.difference(beginsAtNpt);

  const BhadraWindow({
    required this.beginsAtNpt,
    required this.endsAtNpt,
    required this.karanaNumber,
    required this.tithiIndex,
    required this.firstHalfOfTithi,
    required this.lokaSegments,
    required this.mukhaEndsAtNpt,
    required this.puchhaBeginsAtNpt,
    required this.mukhaEndsAtNptFractional,
    required this.puchhaBeginsAtNptFractional,
    required this.provenance,
    required this.evidenceTier,
  });
}

/// True when karana sector index [idx] (karana number minus one) is a
/// Vishti sector inside the movable range: idx % 7 == 0 with
/// 7 <= idx <= 56. The month-end fixed karanas (idx 0, 57, 58, 59) are
/// never Vishti.
bool _isVishtiKaranaIndex(int idx) => idx >= 7 && idx <= 56 && idx % 7 == 0;

/// All Bhadra windows whose BEGINS instant falls in [start, end) - NPT
/// wall-clock DateTimes (UTC fields), the same convention the rest of
/// the engine uses. Windows are returned in chronological order; a scan
/// spanning N lunar months yields exactly 8N windows.
List<BhadraWindow> bhadraWindows({
  required DateTime start,
  required DateTime end,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  var t = _jdTtFromNptWall(start);
  final endJdTt = _jdTtFromNptWall(end);
  final out = <BhadraWindow>[];
  while (t < endJdTt) {
    final idx = limbIndex('karana', t, sourceDelta);
    if (_isVishtiKaranaIndex(idx)) {
      final window = _windowFrom(t, sourceDelta);
      if (!window.beginsAtNpt.isBefore(start)) {
        out.add(window);
      }
      // Advance in the JD domain, never through the NPT wall clock.
      // dateTimeUtcFromJd quantises to whole milliseconds, so the wall
      // round-trip reconstructs the end instant only to the 1 ms grid;
      // a reconstruction that lands before the true boundary re-enters
      // the same Vishti sector and re-emits the same window forever
      // (CI run 42386078588 hung this way). The next karana boundary
      // after t inside the Vishti sector IS the window end, so this
      // advances monotonically in the JD domain.
      t = nextLimbBoundaryJdTt('karana', t, sourceDelta);
    } else {
      t = nextLimbBoundaryJdTt('karana', t, sourceDelta);
    }
  }
  return out;
}

/// The Bhadra window whose begins instant falls on the NPT civil date
/// [year]-[month]-[day], or null when no window begins that day (most
/// days). Consecutive windows begin at least ~2.9 days apart, so at most
/// one window can begin on a given civil date.
BhadraWindow? bhadraNear({
  required int year,
  required int month,
  required int day,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  final dayStart = DateTime.utc(year, month, day);
  final windows = bhadraWindows(
      start: dayStart,
      end: dayStart.add(const Duration(days: 1)),
      sourceDelta: sourceDelta);
  if (windows.isEmpty) return null;
  return windows.first;
}

/// The first Bhadra window that begins at or after [afterNpt] (NPT wall
/// clock, UTC fields). A window already running at [afterNpt] is skipped:
/// the function answers 'next Bhadra', not 'current Bhadra'.
BhadraWindow nextBhadraAfter(
  DateTime afterNpt, {
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  var t = _jdTtFromNptWall(afterNpt);
  while (true) {
    final idx = limbIndex('karana', t, sourceDelta);
    if (_isVishtiKaranaIndex(idx)) {
      final window = _windowFrom(t, sourceDelta);
      if (!window.beginsAtNpt.isBefore(afterNpt)) {
        return window;
      }
      // Same JD-domain advance as bhadraWindows: the wall-clock
      // round-trip quantises to 1 ms and can land back inside the
      // running Vishti sector, looping forever.
      t = nextLimbBoundaryJdTt('karana', t, sourceDelta);
    } else {
      t = nextLimbBoundaryJdTt('karana', t, sourceDelta);
    }
  }
}

/// Builds the Vishti window of the sector running at [t] (t must lie
/// inside a Vishti sector, checked by the caller).
BhadraWindow _windowFrom(double t, double sourceDelta) {
  final idx = limbIndex('karana', t, sourceDelta);
  final beginsJdTt = _previousKaranaBoundaryJdTt(t, sourceDelta);
  final endsJdTt = nextLimbBoundaryJdTt('karana', t, sourceDelta);
  final beginsNpt = _nptWall(beginsJdTt);
  final endsNpt = _nptWall(endsJdTt);

  // Loka segments: bisect the moon's rashi crossings inside the window.
  // The rashi bisection reuses the sector-index formulation (wrap-safe,
  // never compares raw angles across the 0/360 seam) but skips the
  // Newton cross-check: segment transitions are display values inside a
  // gated window, not served limb boundaries, and the 60-iteration
  // bisection already converges to ~100 microseconds.
  final segments = <BhadraLokaSegment>[];
  var segmentBeginJdTt = beginsJdTt;
  while (true) {
    final rasi = _rasiIndex0(segmentBeginJdTt, sourceDelta) + 1;
    final transitionJdTt =
        _nextRasiBoundaryJdTt(segmentBeginJdTt, sourceDelta);
    if (transitionJdTt >= endsJdTt) {
      segments.add(BhadraLokaSegment(
          beginsAtNpt: _nptWall(segmentBeginJdTt),
          rasi: rasi,
          loka: bhadraLokaByRasi[rasi]!));
      break;
    }
    segments.add(BhadraLokaSegment(
        beginsAtNpt: _nptWall(segmentBeginJdTt),
        rasi: rasi,
        loka: bhadraLokaByRasi[rasi]!));
    segmentBeginJdTt = transitionJdTt;
  }

  // Mukha/puchha under both rule families, wall-clock durations.
  final duration = endsNpt.difference(beginsNpt);
  final mukhaFractional = Duration(
      microseconds:
          (duration.inMicroseconds * bhadraMukhaFraction).round());
  final puchhaFractional = Duration(
      microseconds:
          (duration.inMicroseconds * bhadraPuchhaFraction).round());

  return BhadraWindow(
    beginsAtNpt: beginsNpt,
    endsAtNpt: endsNpt,
    karanaNumber: idx + 1,
    tithiIndex: idx ~/ 2,
    firstHalfOfTithi: idx % 2 == 0,
    lokaSegments: List.unmodifiable(segments),
    mukhaEndsAtNpt: beginsNpt.add(bhadraMukhaGhatiDuration),
    puchhaBeginsAtNpt: endsNpt.subtract(bhadraPuchhaGhatiDuration),
    mukhaEndsAtNptFractional: beginsNpt.add(mukhaFractional),
    puchhaBeginsAtNptFractional: endsNpt.subtract(puchhaFractional),
    provenance: 'nMiti nepali_panchang engine: Vishti karana sector of '
        'the ELP2000-82B moon / Meeus Ch.25 sun separation frame; loka '
        'rashi path from the apparent-sidereal moon, ayanamsa profile '
        'delta ${sourceDelta.toStringAsFixed(4)} deg (BhaktiBharat-'
        'anchored fit).',
    evidenceTier: 'runtime-computed; gated by the 2026 Bhadra receipt '
        'corpus (12 Swarnsiddhi windows with golden-corpus edge pins, '
        'BhaktiBharat rule text and date lists; see '
        'test/fixtures/bhadra_receipts_2026.json).',
  );
}

/// Rashi sector index 0..11 of the sidereal moon (Mesha = 0).
int _rasiIndex0(double jdTt, double sourceDelta) {
  return (moonSiderealDeg(jdTt, sourceDelta) / 30.0).floor();
}

/// TT Julian Day of the next rashi boundary strictly after [jdTtStart].
/// The sidereal moon moves 11.8-15.0 deg/day, so a 30 deg rashi ends
/// within 2.6 days - the 0.25 day steps bracket it inside the guard.
double _nextRasiBoundaryJdTt(double jdTtStart, double sourceDelta) {
  final target = _rasiIndex0(jdTtStart, sourceDelta);
  var lo = jdTtStart;
  var hi = jdTtStart + 0.25;
  while (_rasiIndex0(hi, sourceDelta) == target) {
    lo = hi;
    hi += 0.25;
    if (hi - jdTtStart > 3.0) {
      throw StateError(
          'rashi boundary solver failed to bracket the next crossing');
    }
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (_rasiIndex0(mid, sourceDelta) == target) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}

/// TT Julian Day of the previous karana boundary strictly before
/// [jdTtStart] - the begin instant of the karana sector running at
/// [jdTtStart] (same pattern as the panchang day module's private
/// helper, kept local so the layers stay independent).
double _previousKaranaBoundaryJdTt(
    double jdTtStart, double sourceDelta) {
  final target = limbIndex('karana', jdTtStart, sourceDelta);
  var hi = jdTtStart;
  var lo = jdTtStart - 0.25;
  while (limbIndex('karana', lo, sourceDelta) == target) {
    hi = lo;
    lo -= 0.25;
    if (jdTtStart - lo > 4.0) {
      throw StateError(
          'karana boundary solver failed to bracket the previous '
          'crossing');
    }
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (limbIndex('karana', mid, sourceDelta) == target) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}

/// NPT wall clock (UTC fields) for a TT Julian Day - the same mapping
/// the daily-shape layer uses.
DateTime _nptWall(double jdTt) {
  return dateTimeUtcFromJd(jdUtFromJdTt(jdTt))
      .add(const Duration(milliseconds: nptOffsetMs));
}

/// TT Julian Day of an NPT wall-clock instant (UTC fields).
double _jdTtFromNptWall(DateTime nptWall) {
  return jdTtFromJdUt(jdFromDateTimeUtc(
      nptWall.subtract(const Duration(milliseconds: nptOffsetMs))));
}
