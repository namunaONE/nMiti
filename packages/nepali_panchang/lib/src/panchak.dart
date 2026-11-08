import 'ayanamsa.dart';
import 'civil_time.dart';
import 'limbs.dart';
import 'solver.dart';

/// Panchak windows - R10.1 ritual layer 2, HYA-441.
///
/// Panchak is the Moon's transit of the last five nakshatras' span: from
/// the third pada of Dhanishta (sidereal 300 deg) to the end of Revati
/// (360 deg) - the last two padas of Dhanishta, then all of Shatabhisha,
/// Purva Bhadrapada, Uttara Bhadrapada and Revati. All four rule pages
/// state the same span (BhaktiBharat: the Moon in Aquarius and Pisces,
/// the five nakshatras; Swarnsiddhi: "from the second half of Dhanishta
/// to the end of Revati"; PanchangBodh and bhaktivoice: Dhanishta last
/// two quarters plus the four full nakshatras). The window lasts about
/// 4.5 days (the sidereal moon crosses 60 deg) and recurs once per
/// sidereal month - 13 windows in 2026.
///
/// The computation is not a separate theory: it is the same
/// apparent-sidereal moon ([moonSiderealDeg]) and the same calibrated
/// ayanamsa profiles the nakshatra limb uses, rooted on the 300 deg and
/// 360 deg crossings. The 360 deg end IS a nakshatra boundary (Revati
/// ends / Ashwini begins) that the locked golden corpora already gate to
/// the minute; the 300 deg begin is a pada boundary (mid-Dhanishta), so
/// this module carries its own wrap-safe sector solver - a 60-iteration
/// bisection with the same derivative-accelerated Newton cross-check
/// the limb solver enforces (two methods, one answer, on every served
/// edge).
///
/// Conventions are named, never absorbed (receipt corpus:
/// test/fixtures/panchak_receipts_2026.json, crawled 2026-11-08):
///   window     = the global instant pair of the 300-360 deg transit;
///                wall clocks differ by time zone only (the Indian
///                pages print IST = NPT minus 15 min); Swarnsiddhi
///                states it: "Panchak is the Moon's position, not a
///                local sunrise";
///   date label = the NPT civil day on which the window BEGINS
///                (Swarnsiddhi table rows and the BhaktiBharat date
///                lists agree; the Dec window is the knife-edge case,
///                see the fixture caveat);
///   type       = named by the weekday of the begin (NPT civil day):
///                Rog (Sunday), Rajya (Monday), Agni (Tuesday), Madhyam
///                (Wednesday/Thursday), Chor (Friday), Mrityu (Saturday)
///                - the Wed/Thu rows are printed as "Madhyam" by
///                PanchangBodh, as "Dosh-Mukt" by bhaktivoice and
///                untyped by Swarnsiddhi; the engine serves madhyam and
///                the collision is exposed in [panchakConventions];
///   nakshatras = the window's five nakshatra segments (the second
///                half of Dhanishta, then the four full nakshatras),
///                solved by the gated nakshatra limb boundary solver.
///
/// Honesty note: the bhaktivoice 2026 Panchak table is FABRICATED - its
/// thirteen windows all last 4 d 14 h 07-40 m (a real table tracks the
/// lunar speed: this year spans 4 d 07 h to 4 d 17 h) and every begin
/// sits ~20 h before the three agreeing sources. It is recorded as a
/// fixture caveat and never gated - the same treatment their Bhadra
/// window times received.

/// Sidereal longitude where Panchak begins: Dhanishta's third pada (the
/// last two padas of Dhanishta run 300 deg to 306 deg 40).
const double panchakBeginLonDeg = 300.0;

/// Sidereal longitude where Panchak ends: the end of Revati (0/360 deg).
const double panchakEndLonDeg = 360.0;

/// Length of the Panchak arc in degrees (300 -> 360).
const double panchakArcDeg = 60.0;

/// The five nakshatras of the Panchak arc, in transit order.
const List<String> panchakNakshatraNames = [
  'Dhanishta',
  'Shatabhisha',
  'Purva Bhadrapada',
  'Uttara Bhadrapada',
  'Revati',
];

/// Panchak type, named by the weekday on which the window begins.
enum PanchakType { rog, rajya, agni, madhyam, chor, mrityu }

/// Display names of the Panchak types (canonical label plus the
/// traditional association the rule pages state).
const Map<PanchakType, String> panchakTypeNames = {
  PanchakType.rog: 'Rog Panchak (begins Sunday - disease)',
  PanchakType.rajya: 'Rajya Panchak (begins Monday - kingdom/state)',
  PanchakType.agni: 'Agni Panchak (begins Tuesday - fire/conflict)',
  PanchakType.madhyam:
      'Madhyam Panchak (begins Wednesday/Thursday - moderate; also published as Dosh-Mukt or untyped)',
  PanchakType.chor: 'Chor Panchak (begins Friday - theft/loss)',
  PanchakType.mrityu: 'Mrityu Panchak (begins Saturday - death)',
};

/// The Panchak type for the weekday of the window's begin (NPT civil
/// day). [weekday] is DateTime.weekday: Monday = 1 .. Sunday = 7. The
/// mapping is PanchangBodh's printed table; every typed Swarnsiddhi and
/// BhaktiBharat row agrees with it.
PanchakType panchakTypeForWeekday(int weekday) {
  switch (weekday) {
    case 7:
      return PanchakType.rog;
    case 1:
      return PanchakType.rajya;
    case 2:
      return PanchakType.agni;
    case 3:
    case 4:
      return PanchakType.madhyam;
    case 5:
      return PanchakType.chor;
    case 6:
      return PanchakType.mrityu;
    default:
      throw ArgumentError('weekday out of range: ${weekday}');
  }
}

/// The named Panchak conventions, exposed for the site/API display
/// layer (HYA-441 honesty fields). Keys are stable identifiers, never
/// prose layout.
const Map<String, String> panchakConventions = {
  'identity':
      'Panchak = the Moon\'s sidereal transit of 300 to 360 deg - the last two padas of Dhanishta, Shatabhisha, Purva Bhadrapada, Uttara Bhadrapada and Revati; about 4.5 days per window, once per sidereal month, 13 windows in 2026.',
  'window_frame':
      'The window is a global instant pair; wall clocks differ by time zone only (IST = NPT minus 15 min). Swarnsiddhi states it: "Panchak is the Moon\'s position, not a local sunrise".',
  'date_label':
      'The Panchak date is the NPT civil day on which the window begins (Swarnsiddhi table rows and BhaktiBharat date lists).',
  'type_rule':
      'Type = the weekday of the begin (NPT civil day): Rog/Sunday, Rajya/Monday, Agni/Tuesday, Madhyam/Wednesday-Thursday, Chor/Friday, Mrityu/Saturday.',
  'type_naming_collision':
      'Wednesday/Thursday begins carry no specific dosha; PanchangBodh prints Madhyam, bhaktivoice prints Dosh-Mukt, Swarnsiddhi prints no type - one rule, three labels; served as madhyam, collision exposed.',
  'dec_midnight_knife_edge':
      'The December 2026 begin sits about 1.3 h before NPT midnight: Swarnsiddhi (Dec 14, Monday) and BhaktiBharat agree with the engine; PanchangBodh\'s ephemeris lands at 00:27 NPT Dec 15 (Tuesday), so their type column prints Agni - computed, not absorbed.',
  'prohibited':
      'Five traditionally cautioned activities (Muhurta Chintamani / Garuda Purana canon, per BhaktiBharat and bhaktivoice rule text): roofing or laying a lintel, buying or making a cot or bed, travel toward the South, gathering grass, wood or fuel, cremation without the Panchak Shanti vidhi.',
  'unreconciled_source':
      'The bhaktivoice 2026 table is fabricated (constant 4 d 14 h durations, begins about 20 h early) and never gated; Hamro Patro publishes no Panchak windows - recorded absence, not negative evidence.',
};

/// One nakshatra segment of a Panchak window: the span during which the
/// Moon transits one of the five Panchak nakshatras. A window always
/// holds exactly five segments - Dhanishta's second half, then the four
/// full nakshatras.
class PanchakNakshatraSegment {
  /// NPT wall clock (UTC fields) when this segment begins.
  final DateTime beginsAtNpt;

  /// Nakshatra sector index 0..26 (Ashwini = 0, Dhanishta = 22,
  /// Revati = 26).
  final int nakshatraIndex;

  /// Canonical nakshatra name.
  final String name;

  const PanchakNakshatraSegment({
    required this.beginsAtNpt,
    required this.nakshatraIndex,
    required this.name,
  });
}

/// One Panchak window: the 300-360 deg sidereal transit with its named
/// conventions resolved into fields.
class PanchakWindow {
  /// NPT wall clock (UTC fields) when the window begins - the 300 deg
  /// crossing.
  final DateTime beginsAtNpt;

  /// NPT wall clock (UTC fields) when the window ends - the 360 deg
  /// crossing (the Revati/Ashwini nakshatra boundary).
  final DateTime endsAtNpt;

  /// DateTime.weekday of the NPT civil day on which the window begins
  /// (Monday = 1 .. Sunday = 7) - the type rule input.
  final int beginsWeekdayNpt;

  /// The window's type under the weekday-of-begin rule.
  final PanchakType type;

  /// The five nakshatra segments, in transit order.
  final List<PanchakNakshatraSegment> nakshatraSegments;

  /// Engine and ayanamsa profile description for this value set.
  final String provenance;

  /// Evidence statement for every value in this window.
  final String evidenceTier;

  /// Wall-clock length of the window (about 4.5 days).
  Duration get durationNpt => endsAtNpt.difference(beginsAtNpt);

  /// Canonical display name of the window's type.
  String get typeName => panchakTypeNames[type]!;

  /// The NPT civil day on which the window begins (the date-label
  /// convention).
  DateTime get beginsDayNpt =>
      DateTime.utc(beginsAtNpt.year, beginsAtNpt.month, beginsAtNpt.day);

  const PanchakWindow({
    required this.beginsAtNpt,
    required this.endsAtNpt,
    required this.beginsWeekdayNpt,
    required this.type,
    required this.nakshatraSegments,
    required this.provenance,
    required this.evidenceTier,
  });
}

/// Panchak angle at [jdTt]: the apparent-sidereal Moon measured from
/// the 300 deg begin edge, in [0, 360). Inside Panchak the angle lies
/// in [0, 60).
double _panchakAngle(double jdTt, double sourceDelta) {
  return _norm360(moonSiderealDeg(jdTt, sourceDelta) - panchakBeginLonDeg);
}

/// Panchak sector index at [jdTt]: 0 inside the window (angle in
/// [0, 60)), 1..5 outside. Wrap-safe: the index is continuous across
/// the 0/360 seam and never compares raw longitudes.
int _panchakIndex0(double jdTt, double sourceDelta) {
  return (_panchakAngle(jdTt, sourceDelta) / panchakArcDeg).floor();
}

/// Maximum allowed |bisection - Newton| disagreement, in days (~0.86 ms;
/// the same tolerance class the limb solver enforces).
const double _crossCheckToleranceDays = 1.0e-8;

/// Central-difference step for the Newton rate, in days (~8.6 s).
const double _newtonRateStepDays = 1.0e-4;

/// The Moon never moves faster than this, degrees per day (the limb
/// rate band is 11.8-15.4); the linear jump in the boundary solver uses
/// it so the jump always lands BEFORE the crossing.
const double _maxMoonRateDegPerDay = 15.5;

/// TT Julian Day of the next Panchak sector boundary strictly after
/// [jdTtStart]: from inside the window that is the 360 deg end, from
/// outside it is the 300 deg begin. The coarse bracket is found with a
/// linear jump (fastest-rate lower bound on the travel time, so it
/// never overshoots) plus 0.25 day steps; the crossing is then solved
/// twice - 60-iteration bisection and the derivative-accelerated
/// Newton iteration - and the two must agree to
/// [_crossCheckToleranceDays] or the solver throws.
double _nextPanchakBoundaryJdTt(double jdTtStart, double sourceDelta) {
  final startIdx = _panchakIndex0(jdTtStart, sourceDelta);
  final boundaryDeg = startIdx == 0 ? panchakArcDeg : panchakEndLonDeg;
  final remainingDeg =
      boundaryDeg - _panchakAngle(jdTtStart, sourceDelta);
  // Linear jump to just before the crossing, then 0.25 d steps.
  var t = jdTtStart + (remainingDeg - 1.0) / _maxMoonRateDegPerDay;
  while (_panchakIndex0(t, sourceDelta) == startIdx) {
    t += 0.25;
    if (t - jdTtStart > 30.0) {
      throw StateError(
          'panchak boundary solver failed to bracket the next crossing '
          'from jdTt ${jdTtStart.toStringAsFixed(3)}');
    }
  }
  var hi = t;
  var lo = t - 0.25;
  while (_panchakIndex0(lo, sourceDelta) != startIdx) {
    hi = lo;
    lo -= 0.25;
  }
  final newton = _panchakNewtonSolve(sourceDelta, boundaryDeg, lo, hi);
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (_panchakIndex0(mid, sourceDelta) == startIdx) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  if ((newton - hi).abs() > _crossCheckToleranceDays) {
    throw StateError(
        'panchak boundary solver cross-check failed: bisection ${hi} vs '
        'Newton ${newton} (start jdTt ${jdTtStart})');
  }
  return hi;
}

/// Safeguarded Newton solve of the sector crossing inside the coarse
/// bracket [lo, hi] - the same formulation as the limb solver: the
/// wrap-safe signed distance to the boundary angle, central-difference
/// rate, bracket-clamped steps, quadratic convergence in ~4 iterations.
double _panchakNewtonSolve(
    double sourceDelta, double boundaryDeg, double lo, double hi) {
  double distanceDeg(double t) =>
      _wrap180(_panchakAngle(t, sourceDelta) - boundaryDeg);
  var t = (lo + hi) / 2;
  for (var i = 0; i < 12; i++) {
    final rate = (distanceDeg(t + _newtonRateStepDays) -
            distanceDeg(t - _newtonRateStepDays)) /
        (2.0 * _newtonRateStepDays);
    if (rate <= 0.0) {
      throw StateError('panchak Newton rate not positive at jdTt ${t}');
    }
    var next = t - distanceDeg(t) / rate;
    if (next < lo) next = lo;
    if (next > hi) next = hi;
    if ((next - t).abs() <= 1.0e-12) {
      return next;
    }
    t = next;
  }
  return t;
}

/// TT Julian Day of the previous Panchak boundary strictly before
/// [jdTtStart] - the begin instant of the window running at
/// [jdTtStart] (the caller checks the index is 0).
double _previousPanchakBoundaryJdTt(double jdTtStart, double sourceDelta) {
  final target = _panchakIndex0(jdTtStart, sourceDelta);
  var hi = jdTtStart;
  var lo = jdTtStart - 0.25;
  while (_panchakIndex0(lo, sourceDelta) == target) {
    hi = lo;
    lo -= 0.25;
    if (jdTtStart - lo > 8.0) {
      throw StateError(
          'panchak begin solver failed to bracket the previous crossing');
    }
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (_panchakIndex0(mid, sourceDelta) == target) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}

/// All Panchak windows whose BEGINS instant falls in [start, end) - NPT
/// wall-clock DateTimes (UTC fields), chronological order. A scan
/// spanning N sidereal months yields exactly N windows. Advances in
/// the JD domain, never through the millisecond-quantised wall clock
/// (the CI run 42386078588 hang lesson from the Bhadra module).
List<PanchakWindow> panchakWindows({
  required DateTime start,
  required DateTime end,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  var t = _jdTtFromNptWall(start);
  final endJdTt = _jdTtFromNptWall(end);
  final out = <PanchakWindow>[];
  while (t < endJdTt) {
    if (_panchakIndex0(t, sourceDelta) == 0) {
      final window = _windowFrom(t, sourceDelta);
      if (!window.beginsAtNpt.isBefore(start)) {
        out.add(window);
      }
      // The next boundary from inside the window IS its end.
      t = _nextPanchakBoundaryJdTt(t, sourceDelta);
    } else {
      // The next boundary from outside IS the next window's begin.
      t = _nextPanchakBoundaryJdTt(t, sourceDelta);
    }
  }
  return out;
}

/// The Panchak window whose BEGINS instant falls on the NPT civil date
/// [year]-[month]-[day], or null when no window begins that day (the
/// date-label query behind the published date lists).
PanchakWindow? panchakNear({
  required int year,
  required int month,
  required int day,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  final dayStart = DateTime.utc(year, month, day);
  final windows = panchakWindows(
      start: dayStart,
      end: dayStart.add(const Duration(days: 1)),
      sourceDelta: sourceDelta);
  if (windows.isEmpty) return null;
  return windows.first;
}

/// The Panchak window covering [atNpt] (NPT wall clock, UTC fields),
/// or null when the moment is outside every window - the "today"
/// query. Half-open semantics: the begin instant is inside, the end
/// instant is outside.
PanchakWindow? panchakOn(
  DateTime atNpt, {
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  final t = _jdTtFromNptWall(atNpt);
  if (_panchakIndex0(t, sourceDelta) != 0) return null;
  return _windowFrom(t, sourceDelta);
}

/// The first Panchak window that begins at or after [afterNpt] (NPT
/// wall clock, UTC fields). A window already running at [afterNpt] is
/// skipped: the function answers "next Panchak", not "current
/// Panchak" - the same contract as nextBhadraAfter.
PanchakWindow nextPanchakAfter(
  DateTime afterNpt, {
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  var t = _jdTtFromNptWall(afterNpt);
  while (true) {
    if (_panchakIndex0(t, sourceDelta) == 0) {
      final window = _windowFrom(t, sourceDelta);
      if (!window.beginsAtNpt.isBefore(afterNpt)) {
        return window;
      }
      // JD-domain advance (the hang lesson): the wall round-trip
      // quantises to 1 ms and can land back inside the running window.
      t = _nextPanchakBoundaryJdTt(t, sourceDelta);
    } else {
      t = _nextPanchakBoundaryJdTt(t, sourceDelta);
    }
  }
}

/// Builds the window running at [t] (the caller checks the index is
/// 0): begin/end edges plus the five nakshatra segments, whose
/// transitions are solved by the gated nakshatra limb boundary solver
/// (bisection + Newton cross-check, the same guarantees the daily
/// limbs carry).
PanchakWindow _windowFrom(double t, double sourceDelta) {
  final beginsJdTt = _previousPanchakBoundaryJdTt(t, sourceDelta);
  final endsJdTt = _nextPanchakBoundaryJdTt(t, sourceDelta);
  final beginsNpt = _nptWall(beginsJdTt);
  final endsNpt = _nptWall(endsJdTt);

  // The window opens inside Dhanishta (300 deg is its third pada) and
  // closes at Revati's end, so the chain is always the five Panchak
  // nakshatras; after Revati begins, the window end IS the next
  // boundary - no further transition can follow.
  final segments = <PanchakNakshatraSegment>[];
  var segmentBeginJdTt = beginsJdTt;
  while (true) {
    final idx = limbIndex('nakshatra', segmentBeginJdTt, sourceDelta);
    segments.add(PanchakNakshatraSegment(
      beginsAtNpt: _nptWall(segmentBeginJdTt),
      nakshatraIndex: idx,
      name: nakshatraNames[idx],
    ));
    if (idx == 26) break;
    final transition =
        nextLimbBoundaryJdTt('nakshatra', segmentBeginJdTt, sourceDelta);
    if (!transition.isBefore(endsJdTt)) break;
    segmentBeginJdTt = transition;
  }

  return PanchakWindow(
    beginsAtNpt: beginsNpt,
    endsAtNpt: endsNpt,
    beginsWeekdayNpt: beginsNpt.weekday,
    type: panchakTypeForWeekday(beginsNpt.weekday),
    nakshatraSegments: List.unmodifiable(segments),
    provenance: 'nMiti nepali_panchang engine: sidereal 300-360 deg '
        'transit of the apparent Meeus Ch.47 moon; edges by the local '
        'wrap-safe bisection + Newton cross-check solver, segments by '
        'the gated nakshatra limb solver; ayanamsa profile delta '
        '${sourceDelta.toStringAsFixed(4)} deg (BhaktiBharat-anchored '
        'fit).',
    evidenceTier: 'runtime-computed; gated by the 2026 Panchak receipt '
        'corpus (13 Swarnsiddhi windows, 13 PanchangBodh windows, '
        'BhaktiBharat window and date lists, golden-corpus Revati-end '
        'edge pins on the Oct/Nov/Dec windows; see '
        'test/fixtures/panchak_receipts_2026.json).',
  );
}

double _norm360(double deg) => deg % 360.0;

double _wrap180(double deg) {
  var d = deg % 360.0;
  if (d >= 180.0) d -= 360.0;
  if (d < -180.0) d += 360.0;
  return d;
}

/// NPT wall clock (UTC fields) for a TT Julian Day - the same mapping
/// the Bhadra module uses.
DateTime _nptWall(double jdTt) {
  return dateTimeUtcFromJd(jdUtFromJdTt(jdTt))
      .add(const Duration(milliseconds: nptOffsetMs));
}

/// TT Julian Day of an NPT wall-clock instant (UTC fields).
double _jdTtFromNptWall(DateTime nptWall) {
  return jdTtFromJdUt(jdFromDateTimeUtc(
      nptWall.subtract(const Duration(milliseconds: nptOffsetMs))));
}
