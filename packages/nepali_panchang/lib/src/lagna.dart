import 'dart:math' as math;

import 'ayanamsa.dart';
import 'civil_time.dart';

/// Lagna (rising sign) boundaries - R10.2, HYA-441.
///
/// Lagna is the sidereal zodiac degree occupying the eastern horizon at a
/// given instant and place - the ascendant. A rashi lagna window is the span
/// during which one sidereal sign rises; the full cycle is one sidereal day
/// (1436.07 min), so a day table holds twelve boundaries and a thirteenth
/// close returns the frame sign.
///
/// The computation composes three named channels, none of them new theory:
///   sidereal time = Greenwich mean sidereal time, Meeus chapter 12.4
///                   (UT domain), plus the observer longitude;
///   obliquity     = the mean obliquity of the ecliptic, Meeus chapter 22.2;
///   ayanamsa     = the engine base (23.87508 deg at J2000, +1.36062 deg
///                   per Julian century) - the same profile the solar limbs
///                   use, with NO per-source delta: the 2026-11 receipt
///                   corpus (test/fixtures/lagna_receipts_2026_11.json)
///                   fits Swarnsiddhi and nepaljyotish boundaries to
///                   0.05 min and PanchangBodh signs exactly against the
///                   base alone.
///
/// The tropical ascendant is the standard closed form in LST, obliquity
/// and latitude; it was validated to 0.000 deg against an independent
/// altitude-zero eastern root-find, and the whole chain against the
/// crawled corpus: all 78 Swarnsiddhi boundary receipts (six cities,
/// twelve boundaries plus the frame close each) within 0.05 min, all
/// six live "Rising now" degree receipts within 0.19 deg, all twelve
/// nepaljyotish interior boundaries within 2.28 min (minute-rounded
/// publisher print), and nine of nine PanchangBodh sunrise-sign
/// day-calls exactly. Zero divergences across the corpus.
///
/// The published day-table frame starts at the TRUE begin of the window
/// containing the publisher's printed sunrise, so the engine SOLVES the
/// frame start by walking back from that sunrise instant - never by a
/// fixed-hour scan, which misaligns cities whose previous window began
/// after the scan hour (Mumbai 2026-11-08: the Virgo window began 03:06
/// local; see [lagnaConventions] 'scan_alignment').
///
/// Deliberately skipped, named (the sun.dart precedent): nutation in
/// right ascension (~1 arcsec, ~0.15 s of clock) - an order of magnitude
/// below the tightest receipt band (2 min) and below the publisher
/// second-precision print itself.
///
/// The boundary solver follows the house discipline: the rashi-index
/// formulation is wrap-safe (never compares raw degrees across the 0/360
/// seam), the scan bracket is bisected 60 times on sign membership, and
/// every served edge is solved a second time by a derivative-accelerated
/// Newton iteration that must agree to 1e-8 days or the solver throws -
/// two methods, one answer, on every boundary the engine serves.

const double _radPerDeg = math.pi / 180;

/// One sidereal day in minutes (23 h 56 m 04.1 s) - the lagna cycle.
const double lagnaSiderealDayMinutes = 1436.0682;

/// The twelve sidereal rashi names in zodiac order (Aries = 0 deg).
const List<String> lagnaRashiNames = [
  'Aries',
  'Taurus',
  'Gemini',
  'Cancer',
  'Leo',
  'Virgo',
  'Libra',
  'Scorpio',
  'Sagittarius',
  'Capricorn',
  'Aquarius',
  'Pisces',
];

/// The Nepali rashi spellings the nepaljyotish table prints
/// (Mesha .. Meena), aligned by index with [lagnaRashiNames].
const List<String> lagnaRashiNamesNepali = [
  'Mesha',
  'Vrishabha',
  'Mithuna',
  'Karka',
  'Simha',
  'Kanya',
  'Tula',
  'Vrishchik',
  'Dhanu',
  'Makar',
  'Kumbha',
  'Meena',
];

/// The named lagna conventions, exposed for the site/API display layer
/// (HYA-441 honesty fields). Keys are stable identifiers, never prose
/// layout.
const Map<String, String> lagnaConventions = {
  'identity':
      'Lagna = the sidereal zodiac degree rising on the eastern horizon at a given instant and place; a rashi lagna window is the span while one sidereal sign occupies the ascendant. The full cycle is one sidereal day (1436.07 min), so a day table holds 12 boundaries.',
  'frame':
      'A published day-table frame is one full lagna cycle. Swarnsiddhi starts it at the TRUE rising instant of the window containing their printed sunrise; nepaljyotish re-anchors row 1 at the sunrise instant itself. Both conventions decoded, never merged.',
  'day_rule':
      'The published tables are for the printed page date. Swarnsiddhi\'s page-date label lags the live "Rising now" clock for some cities (CDN caching), but the boundary tables match the LABELED date (engine deltas 0.05 min as labeled vs 3.9 min one day later) - each receipt records its printed page date.',
  'ayanamsa':
      'All three publishers fit the engine BASE ayanamsa with no per-source delta: boundaries to 0.05 min (Swarnsiddhi, nepaljyotish) and signs exactly (PanchangBodh). The lagna corpus pins the same ayanamsa the solar limbs use.',
  'nj_anchor':
      'nepaljyotish row 1 is the sunrise window re-anchored at their printed sunrise 06:20 NPT (Swarnsiddhi prints the same instant 06:19:48, the engine 06:19:50); rows 2-13 chain to the next day\'s sunrise. Interior boundaries carry their minute-rounded print (up to 2.28 min from the engine).',
  'rising_now':
      'Swarnsiddhi\'s live "Rising now (HH:MM): <Rashi> lagna at D deg M min" receipt is the ascendant at the printed instant on the live clock date; engine deltas 0.02-0.19 deg across the six corpus cities.',
  'pb_ist_seam':
      'PanchangBodh prints Kathmandu wall times 15 minutes early vs NPT (IST-labeled instants; their Nov 9 sunrise prints 6:05 AM vs nepaljyotish 06:20): treat the printed time as IST, +15 min gives NPT. Their "Lagna (Sunrise)" receipt is the sign rising at their sunrise.',
  'pb_jun16_resolved':
      'The 2026-06-16 PanchangBodh row (Taurus) looked suspect because the sun enters sidereal Gemini midday Jun 15 - resolved: the sunrise ascendant lags the sun by about 0.9-1.0 deg at Kathmandu in June, so the lagna is Taurus 59.5 deg while the sun has entered Gemini. Printed sign kept, suspect flag retired.',
  'scan_alignment':
      'A published day-table frame starts at the true begin of the window containing the publisher\'s printed sunrise, so the frame start is solved by walking back from the sunrise instant - never scanned from a fixed hour. On 2026-11-08 Mumbai\'s Virgo window began 03:06 local: a naive 03:00 scan would chain one boundary early and fabricate a ~128 min "divergence". All 78 Swarnsiddhi receipts (six cities x 13) agree with the engine to 0.05 min once aligned by construction.',
  'unreconciled_source':
      'hinducalculator.com blocks machines (403 at crawl time); hinducalendar.app and muhuratchoghadiya load their lagna tables client-side; the nepaljyotish /en/ twin serves today regardless of ?date=. Recorded absences, never negative evidence.',
  'location':
      'The engine defaults to the nMiti Kathmandu anchor 27.7172 N / 85.324 E; the corpus spans six cities (Kathmandu, New Delhi, Mumbai, Bengaluru, Chennai, London). The solver is valid below the polar circles (|latitude| < 66.5 deg) where the ascendant advances monotonically; it refuses higher latitudes rather than serving a stalled or retrograde ascendant.',
};

/// Greenwich mean sidereal time, Meeus Astronomical Algorithms chapter 12.4,
/// degrees, normalized to [0, 360). UT domain - the ascendant depends on
/// Earth rotation, so no Delta-T shift is applied.
double greenwichMeanSiderealTimeDeg(double jdUt) {
  final t = (jdUt - 2451545.0) / 36525.0;
  return _norm360(280.46061837 +
      360.98564736629 * (jdUt - 2451545.0) +
      0.000387933 * t * t -
      t * t * t / 38710000.0);
}

/// Mean obliquity of the ecliptic, Meeus chapter 22.2, degrees.
double meanObliquityOfEclipticDeg(double jdUt) {
  final t = (jdUt - 2451545.0) / 36525.0;
  return 23.439291111 -
      0.0130041667 * t -
      1.6389e-7 * t * t +
      5.0361e-7 * t * t * t;
}

/// Tropical ascendant: the ecliptic longitude on the eastern horizon,
/// from the local sidereal time [lstDeg], obliquity [epsDeg] and latitude
/// [latitudeDeg]. The standard closed form; validated 0.000 deg against an
/// independent altitude-zero eastern root-find.
double _tropicalAscendantDeg(double lstDeg, double epsDeg, double latitudeDeg) {
  return _norm360(math.atan2(
          math.cos(lstDeg * _radPerDeg),
          -(math.sin(lstDeg * _radPerDeg) * math.cos(epsDeg * _radPerDeg) +
              math.tan(latitudeDeg * _radPerDeg) *
                  math.sin(epsDeg * _radPerDeg))) /
      _radPerDeg);
}

/// Sidereal ascendant (lagna) in degrees, normalized to [0, 360):
/// the tropical ascendant minus the ayanamsa profile ([sourceDelta]
/// defaults to the base - the corpus fits the base alone).
///
/// [jdUt] is a UT Julian Day; [longitudeDeg] is east-positive.
double siderealAscendantDeg({
  required double jdUt,
  required double latitudeDeg,
  required double longitudeDeg,
  double sourceDelta = 0.0,
}) {
  _checkLatitude(latitudeDeg);
  final jdTt = jdTtFromJdUt(jdUt);
  final ayanamsa = ayanamsaTotal(jdTt, sourceDelta);
  return _norm360(_tropicalAscendantDeg(
          _norm360(greenwichMeanSiderealTimeDeg(jdUt) + longitudeDeg),
          meanObliquityOfEclipticDeg(jdUt),
          latitudeDeg) -
      ayanamsa);
}

/// Rashi index 0..11 (Aries = 0, Pisces = 11) of a sidereal ascendant
/// degree.
int lagnaRashiIndexOf(double siderealAscendantDeg) {
  return (siderealAscendantDeg / 30.0).floor();
}

/// One rashi-begin boundary: the instant [jdUt] at which the sidereal
/// ascendant crosses the exact multiple [rashiIndex] * 30 deg, and that
/// sign begins to rise.
class LagnaBoundary {
  /// The sign that BEGINS at this instant, 0..11 (Aries = 0).
  final int rashiIndex;

  /// UT Julian Day of the crossing (the solver's upper-bound convention:
  /// the smallest double strictly after the crossing, the same contract
  /// the limb solver serves).
  final double jdUt;

  const LagnaBoundary({required this.rashiIndex, required this.jdUt});

  /// Canonical English name of the rising sign.
  String get rashiName => lagnaRashiNames[rashiIndex];

  /// Nepali spelling (the nepaljyotish print).
  String get rashiNameNepali => lagnaRashiNamesNepali[rashiIndex];
}

/// One rashi lagna window: the span between two consecutive boundaries
/// during which [rashiIndex] occupies the ascendant.
class LagnaWindow {
  /// The rising sign, 0..11 (Aries = 0).
  final int rashiIndex;

  /// UT Julian Day when the sign begins to rise.
  final double beginsJdUt;

  /// UT Julian Day when the next sign begins (window is [begin, end)).
  final double endsJdUt;

  const LagnaWindow({
    required this.rashiIndex,
    required this.beginsJdUt,
    required this.endsJdUt,
  });

  /// Wall-clock length of the window (60-240 min at corpus latitudes).
  Duration get duration =>
      Duration(microseconds: ((endsJdUt - beginsJdUt) * 86400e6).round());

  /// Canonical English name of the rising sign.
  String get rashiName => lagnaRashiNames[rashiIndex];

  /// Nepali spelling (the nepaljyotish print).
  String get rashiNameNepali => lagnaRashiNamesNepali[rashiIndex];

  /// Engine and ayanamsa profile description for this value set.
  String get provenance =>
      'nMiti nepali_panchang engine: closed-form tropical ascendant '
      '(GMST Meeus 12.4 + mean obliquity Meeus 22.2) minus the engine '
      'base ayanamsa; boundaries by the wrap-safe membership bisection '
      'with the Newton cross-check.';

  /// Evidence statement for every value in this window.
  String get evidenceTier =>
      'runtime-computed; gated by the 2026-11 lagna receipt corpus '
      '(Swarnsiddhi six-city boundary tables, frame closes and rising-now '
      'degrees; nepaljyotish Kathmandu table; PanchangBodh day-calls; see '
      'test/fixtures/lagna_receipts_2026_11.json).';
}

/// The running lagna at an instant: the sign occupying the ascendant, its
/// degree, and the begin/next-boundary instants - the "rising now" query.
class RunningLagna {
  /// The rising sign, 0..11 (Aries = 0).
  final int rashiIndex;

  /// Sidereal ascendant degree, [0, 360).
  final double ascendantDeg;

  /// UT Julian Day when the running window began.
  final double beginsJdUt;

  /// UT Julian Day of the next boundary.
  final double nextBoundaryJdUt;

  const RunningLagna({
    required this.rashiIndex,
    required this.ascendantDeg,
    required this.beginsJdUt,
    required this.nextBoundaryJdUt,
  });

  /// Ascendant degree within the sign, [0, 30).
  double get degreeInRashi => ascendantDeg - rashiIndex * 30.0;

  /// NPT wall clock (UTC fields) when the running window began.
  DateTime get beginsAtNpt => _nptWall(beginsJdUt);

  /// NPT wall clock (UTC fields) of the next boundary.
  DateTime get nextBoundaryAtNpt => _nptWall(nextBoundaryJdUt);

  /// Canonical English name of the rising sign.
  String get rashiName => lagnaRashiNames[rashiIndex];

  /// Nepali spelling (the nepaljyotish print).
  String get rashiNameNepali => lagnaRashiNamesNepali[rashiIndex];

  /// Engine and ayanamsa profile description for this value set.
  String get provenance =>
      'nMiti nepali_panchang engine: closed-form tropical ascendant '
      '(GMST Meeus 12.4 + mean obliquity Meeus 22.2) minus the engine '
      'base ayanamsa; boundaries by the wrap-safe membership bisection '
      'with the Newton cross-check.';

  /// Evidence statement for every value in this object.
  String get evidenceTier =>
      'runtime-computed; gated by the 2026-11 lagna receipt corpus '
      '(Swarnsiddhi rising-now degrees and boundary tables; see '
      'test/fixtures/lagna_receipts_2026_11.json).';
}

/// Solver scan step, days (2 min): the ascendant moves at most ~0.7 deg
/// per step at corpus latitudes (rising rate <= ~20 deg/h), so a step can
/// never skip a whole 30-deg sign and the rashi index changes by at most
/// one across a bracket.
const double _lagnaScanStepDays = 1.0 / 720.0;

/// Maximum allowed |bisection - Newton| disagreement, in days (~0.86 ms;
/// the same tolerance class the limb and panchak solvers enforce).
const double _lagnaCrossCheckToleranceDays = 1.0e-8;

/// Central-difference step for the Newton rate, in days (~8.6 s).
const double _lagnaNewtonRateStepDays = 1.0e-4;

/// Below the polar circles the ascendant advances monotonically; above
/// them it can stall or run retrograde, and the solver refuses rather
/// than serve a bogus boundary.
const double _lagnaMaxAbsLatitudeDeg = 66.5;

void _checkLatitude(double latitudeDeg) {
  if (latitudeDeg.abs() >= _lagnaMaxAbsLatitudeDeg) {
    throw ArgumentError(
        'lagna solver refuses |latitude| >= $_lagnaMaxAbsLatitudeDeg deg '
        '(ascendant not monotone below the horizon geometry there); got '
        '${latitudeDeg}');
  }
}

int _rashiIndexAt(double jdUt, double latitudeDeg, double longitudeDeg,
        double sourceDelta) =>
    lagnaRashiIndexOf(siderealAscendantDeg(
        jdUt: jdUt,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        sourceDelta: sourceDelta));

/// UT Julian Day of the next rashi-begin crossing strictly after
/// [jdUtStart]: a 2-min membership scan until the rashi index changes,
/// then a 60-iteration bisection of the 2-min bracket plus the
/// derivative-accelerated Newton cross-check (two methods, one answer).
LagnaBoundary _nextLagnaBoundary(double jdUtStart, double latitudeDeg,
    double longitudeDeg, double sourceDelta) {
  final idx0 = _rashiIndexAt(jdUtStart, latitudeDeg, longitudeDeg, sourceDelta);
  // One sidereal day holds exactly one crossing of any given degree, so
  // 1.05 d always brackets the next one.
  final maxT = jdUtStart + 1.05;
  var lo = jdUtStart;
  while (lo < maxT) {
    final hi = lo + _lagnaScanStepDays;
    final idx1 = _rashiIndexAt(hi, latitudeDeg, longitudeDeg, sourceDelta);
    if (idx1 != idx0) {
      // Bisection on sign membership - wrap-safe by construction.
      var a = lo;
      var b = hi;
      for (var i = 0; i < 60; i++) {
        final mid = (a + b) / 2;
        if (_rashiIndexAt(mid, latitudeDeg, longitudeDeg, sourceDelta) ==
            idx0) {
          a = mid;
        } else {
          b = mid;
        }
      }
      // Newton cross-check on the wrap-safe signed distance to the
      // boundary degree (the BEGIN of the new sign).
      final target = idx1 * 30.0;
      double distanceDeg(double t) => _wrap180(
          siderealAscendantDeg(
                  jdUt: t,
                  latitudeDeg: latitudeDeg,
                  longitudeDeg: longitudeDeg,
                  sourceDelta: sourceDelta) -
              target);
      var t = (lo + hi) / 2;
      for (var i = 0; i < 12; i++) {
        final rate = (distanceDeg(t + _lagnaNewtonRateStepDays) -
                distanceDeg(t - _lagnaNewtonRateStepDays)) /
            (2.0 * _lagnaNewtonRateStepDays);
        if (rate <= 0.0) {
          throw StateError(
              'lagna Newton rate not positive at jdUt ${t.toStringAsFixed(6)}');
        }
        var next = t - distanceDeg(t) / rate;
        if (next < lo) next = lo;
        if (next > hi) next = hi;
        if ((next - t).abs() <= 1.0e-12) {
          t = next;
          break;
        }
        t = next;
      }
      if ((t - b).abs() > _lagnaCrossCheckToleranceDays) {
        throw StateError(
            'lagna boundary solver cross-check failed: bisection ${b} vs '
            'Newton ${t} (start jdUt ${jdUtStart})');
      }
      return LagnaBoundary(rashiIndex: idx1, jdUt: b);
    }
    lo = hi;
  }
  throw StateError(
      'lagna boundary solver failed to bracket the next crossing from '
      'jdUt ${jdUtStart.toStringAsFixed(3)}');
}

/// UT Julian Day of the previous rashi-begin crossing strictly before
/// [jdUtStart] - the instant the running window began. Same 2-min
/// membership scan (backwards), bisection and Newton cross-check.
LagnaBoundary previousLagnaBoundaryBefore({
  required double jdUt,
  required double latitudeDeg,
  required double longitudeDeg,
  double sourceDelta = 0.0,
}) {
  _checkLatitude(latitudeDeg);
  final idx0 = _rashiIndexAt(jdUt, latitudeDeg, longitudeDeg, sourceDelta);
  var b = jdUt;
  var a = jdUt - _lagnaScanStepDays;
  while (_rashiIndexAt(a, latitudeDeg, longitudeDeg, sourceDelta) == idx0) {
    b = a;
    a -= _lagnaScanStepDays;
    if (jdUt - a > 1.05) {
      throw StateError(
          'lagna begin solver failed to bracket the previous crossing from '
          'jdUt ${jdUt.toStringAsFixed(3)}');
    }
  }
  for (var i = 0; i < 60; i++) {
    final mid = (a + b) / 2;
    if (_rashiIndexAt(mid, latitudeDeg, longitudeDeg, sourceDelta) == idx0) {
      b = mid;
    } else {
      a = mid;
    }
  }
  final target = idx0 * 30.0;
  double distanceDeg(double t) => _wrap180(
      siderealAscendantDeg(
              jdUt: t,
              latitudeDeg: latitudeDeg,
              longitudeDeg: longitudeDeg,
              sourceDelta: sourceDelta) -
          target);
  var t = (a + b) / 2;
  for (var i = 0; i < 12; i++) {
    final rate = (distanceDeg(t + _lagnaNewtonRateStepDays) -
            distanceDeg(t - _lagnaNewtonRateStepDays)) /
        (2.0 * _lagnaNewtonRateStepDays);
    if (rate <= 0.0) {
      throw StateError(
          'lagna Newton rate not positive at jdUt ${t.toStringAsFixed(6)}');
    }
    var next = t - distanceDeg(t) / rate;
    if (next < a) next = a;
    if (next > b) next = b;
    if ((next - t).abs() <= 1.0e-12) {
      t = next;
      break;
    }
    t = next;
  }
  if ((t - b).abs() > _lagnaCrossCheckToleranceDays) {
    throw StateError(
        'lagna begin solver cross-check failed: bisection ${b} vs '
        'Newton ${t} (start jdUt ${jdUt})');
  }
  return LagnaBoundary(rashiIndex: idx0, jdUt: b);
}

/// The next rashi-begin boundary strictly after [jdUt] at the location.
LagnaBoundary nextLagnaBoundaryAfter({
  required double jdUt,
  required double latitudeDeg,
  required double longitudeDeg,
  double sourceDelta = 0.0,
}) {
  _checkLatitude(latitudeDeg);
  return _nextLagnaBoundary(jdUt, latitudeDeg, longitudeDeg, sourceDelta);
}

/// All rashi-begin boundaries with the crossing instant in
/// [jdUtStart, jdUtEnd), chronological order - the day-table query.
/// A window spanning one sidereal day yields exactly twelve; a slightly
/// wider one also catches the frame close (the next cycle's first).
List<LagnaBoundary> lagnaBoundariesBetween({
  required double jdUtStart,
  required double jdUtEnd,
  required double latitudeDeg,
  required double longitudeDeg,
  double sourceDelta = 0.0,
}) {
  _checkLatitude(latitudeDeg);
  if (jdUtEnd <= jdUtStart) {
    throw ArgumentError('jdUtEnd must be after jdUtStart');
  }
  final out = <LagnaBoundary>[];
  var t = jdUtStart;
  while (t < jdUtEnd) {
    final boundary =
        _nextLagnaBoundary(t, latitudeDeg, longitudeDeg, sourceDelta);
    if (boundary.jdUt >= jdUtEnd) break;
    out.add(boundary);
    t = boundary.jdUt;
  }
  return List.unmodifiable(out);
}

/// All lagna windows whose BEGIN instant falls in [jdUtStart, jdUtEnd),
/// chronological order. Each window ends at the next boundary, which may
/// fall after [jdUtEnd] (the frame-close window is served complete).
List<LagnaWindow> lagnaWindowsBetween({
  required double jdUtStart,
  required double jdUtEnd,
  required double latitudeDeg,
  required double longitudeDeg,
  double sourceDelta = 0.0,
}) {
  final boundaries = lagnaBoundariesBetween(
    jdUtStart: jdUtStart,
    jdUtEnd: jdUtEnd,
    latitudeDeg: latitudeDeg,
    longitudeDeg: longitudeDeg,
    sourceDelta: sourceDelta,
  );
  final out = <LagnaWindow>[];
  for (final b in boundaries) {
    final end = _nextLagnaBoundary(
        b.jdUt, latitudeDeg, longitudeDeg, sourceDelta);
    out.add(LagnaWindow(
      rashiIndex: b.rashiIndex,
      beginsJdUt: b.jdUt,
      endsJdUt: end.jdUt,
    ));
  }
  return List.unmodifiable(out);
}

/// The running lagna at an NPT wall-clock instant [atNpt] (UTC fields) -
/// the "rising now" query. Defaults to the Kathmandu anchor; other
/// locations pass their coordinates.
RunningLagna lagnaAtNpt(
  DateTime atNpt, {
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
  double sourceDelta = 0.0,
}) {
  _checkLatitude(latitudeDeg);
  final jdUt = jdFromDateTimeUtc(
      atNpt.subtract(const Duration(milliseconds: nptOffsetMs)));
  final asc = siderealAscendantDeg(
      jdUt: jdUt,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      sourceDelta: sourceDelta);
  final begins = previousLagnaBoundaryBefore(
      jdUt: jdUt,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      sourceDelta: sourceDelta);
  final next = _nextLagnaBoundary(jdUt, latitudeDeg, longitudeDeg, sourceDelta);
  return RunningLagna(
    rashiIndex: lagnaRashiIndexOf(asc),
    ascendantDeg: asc,
    beginsJdUt: begins.jdUt,
    nextBoundaryJdUt: next.jdUt,
  );
}

double _norm360(double deg) => deg % 360.0;

double _wrap180(double deg) {
  var d = deg % 360.0;
  if (d >= 180.0) d -= 360.0;
  if (d < -180.0) d += 360.0;
  return d;
}

/// NPT wall clock (UTC fields) for a UT Julian Day - the same mapping the
/// panchak module uses.
DateTime _nptWall(double jdUt) {
  return dateTimeUtcFromJd(jdUt).add(const Duration(milliseconds: nptOffsetMs));
}
