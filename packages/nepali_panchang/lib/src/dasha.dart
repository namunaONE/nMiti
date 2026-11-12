import 'limbs.dart';
import 'moon.dart';
import 'sun.dart';

/// Vimshottari dasha engine (Wave 2, HYA-451).
///
/// Pure arithmetic on the Moon's apparent-sidereal nakshatra at the birth
/// instant: the nine-lord cycle of BPHS Ch. 46 (Ketu, Venus, Sun, Moon,
/// Mars, Rahu, Jupiter, Saturn, Mercury; 7+20+6+10+7+18+16+19+17 = 120
/// years), the balance of the first mahadasha from the elapsed nakshatra
/// fraction, and the proportional antardasha/pratyantardasha nesting. The
/// nakshatra itself comes from the calibrated limb machinery - the same
/// apparent-sidereal moon the panchang serves, with sub-minute boundary
/// accuracy.
///
/// HONESTY STATUS (receipts-first rule): the arithmetic is closed and
/// self-tested, but NO publisher receipt corpus gates it yet - the
/// deterministic dasha calculators are client-side forms (reconnaissance
/// recorded on HYA-451, 2026-11-12). Two conventions are therefore
/// explicit PARAMETERS, never silent choices, and served dates must carry
/// their convention label until dated receipts decode them:
///   1. the dasha-year length (vimshottariYearDaysSolar vs
///      vimshottariYearDaysClassical360 - a ~629-day drift across the
///      120-year cycle, trivially decodable from any dated receipt);
///   2. the ayanamsa frame of the birth moon (the Swiss-Lahiri reference
///      line of ayanamsa.dart vs the per-source publisher profiles).

/// Dasha lords in cycle order: the lord of Ashwini opens the cycle.
const List<String> vimshottariLords = [
  'Ketu', 'Venus', 'Sun', 'Moon', 'Mars', 'Rahu', 'Jupiter', 'Saturn',
  'Mercury',
];

/// Full mahadasha span of each lord, in years (same order; total 120).
const List<int> vimshottariYears = [7, 20, 6, 10, 7, 18, 16, 19, 17];

/// Dasha year = 365.25 days (the common software convention).
const double vimshottariYearDaysSolar = 365.25;

/// Dasha year = 360 days (the classical count).
const double vimshottariYearDaysClassical360 = 360.0;

/// One dasha period at any level of the Vimshottari nesting.
class DashaSpan {
  final String lord;

  final String level;

  final double startJdTt;

  final double endJdTt;

  final List<DashaSpan> children;

  const DashaSpan({
    required this.lord,
    required this.level,
    required this.startJdTt,
    required this.endJdTt,
    this.children = const [],
  });

  /// True when [jdTt] lies in [startJdTt, endJdTt). A query exactly at a
  /// boundary resolves to the following period.
  bool contains(double jdTt) => jdTt >= startJdTt && jdTt < endJdTt;

  /// Span of the period in days.
  double get spanDays => endJdTt - startJdTt;
}

/// Balance of the first mahadasha at the birth instant.
class VimshottariBalance {
  /// Nakshatra of the birth moon, 0..26 from Ashwini.
  final int nakshatraIndex;

  /// Index of the first mahadasha lord into [vimshottariLords], 0..8.
  final int lordIndex;

  /// Elapsed fraction of the birth nakshatra, 0..1.
  final double nakshatraElapsedFraction;

  /// Remaining days of the first mahadasha at the birth instant.
  final double balanceDays;

  const VimshottariBalance({
    required this.nakshatraIndex,
    required this.lordIndex,
    required this.nakshatraElapsedFraction,
    required this.balanceDays,
  });
}

/// Apparent sidereal longitude of the moon at [jdTt] in the frame of
/// [ayanamsaDeg] (evaluated at the same instant) - the publishers'
/// apparent-sidereal convention with a caller-chosen ayanamsa line (the
/// Swiss-Lahiri reference line of ayanamsa.dart for the display channel,
/// or ayanamsaTotal with a per-source delta for a publisher profile).
double moonSiderealInFrameDeg(double jdTt, double ayanamsaDeg) {
  final moon = moonPosition(jdTt).longitudeDeg + nutationInLongitudeDeg(jdTt);
  return _norm360(moon - ayanamsaDeg);
}

/// Vimshottari balance from a sidereal moon longitude (pure; the jdTt
/// wrapper is [vimshottariBalance]).
VimshottariBalance vimshottariBalanceFromMoonDeg(double moonDeg,
    {required double yearDays}) {
  final nak = (moonDeg / nakshatraSpanDeg).floor() % 27;
  final frac = (moonDeg - nak * nakshatraSpanDeg) / nakshatraSpanDeg;
  final lord = nak % 9;
  final remaining = (1.0 - frac) * vimshottariYears[lord] * yearDays;
  return VimshottariBalance(
    nakshatraIndex: nak,
    lordIndex: lord,
    nakshatraElapsedFraction: frac,
    balanceDays: remaining,
  );
}

/// Balance of the first mahadasha for a birth at [birthJdTt] (TT Julian
/// Day), with the birth moon read in the frame of [ayanamsaDeg].
VimshottariBalance vimshottariBalance(double birthJdTt, double ayanamsaDeg,
    {required double yearDays}) {
  return vimshottariBalanceFromMoonDeg(
      moonSiderealInFrameDeg(birthJdTt, ayanamsaDeg),
      yearDays: yearDays);
}

/// The mahadasha chain for a birth at [birthJdTt], from a sidereal moon
/// longitude (pure). The first mahadasha opens at the birth instant with
/// the balance remainder; the rest run their full spans in cycle order.
List<DashaSpan> vimshottariMahadashasFromMoonDeg(
    {required double moonDeg,
    required double birthJdTt,
    required double yearDays,
    int count = 9}) {
  final bal = vimshottariBalanceFromMoonDeg(moonDeg, yearDays: yearDays);
  final spans = <DashaSpan>[];
  var start = birthJdTt;
  for (var k = 0; k < count; k++) {
    final lord = (bal.lordIndex + k) % 9;
    final days = k == 0 ? bal.balanceDays : vimshottariYears[lord] * yearDays;
    spans.add(DashaSpan(
      lord: vimshottariLords[lord],
      level: 'mahadasha',
      startJdTt: start,
      endJdTt: start + days,
    ));
    start += days;
  }
  return spans;
}

/// The mahadasha chain for a birth at [birthJdTt], with the birth moon
/// read in the frame of [ayanamsaDeg].
List<DashaSpan> vimshottariMahadashas(
    {required double birthJdTt,
    required double ayanamsaDeg,
    required double yearDays,
    int count = 9}) {
  return vimshottariMahadashasFromMoonDeg(
    moonDeg: moonSiderealInFrameDeg(birthJdTt, ayanamsaDeg),
    birthJdTt: birthJdTt,
    yearDays: yearDays,
    count: count,
  );
}

/// The nine proportional sub-periods of [parent], opening with the
/// parent's own lord (the BPHS Ch. 46 antardasha/pratyantardasha rule):
/// each child spans vimshottariYears/120 of the parent span.
List<DashaSpan> vimshottariSubPeriods(DashaSpan parent,
    {required double yearDays, String childLevel = 'antardasha'}) {
  final lordIdx = vimshottariLords.indexOf(parent.lord);
  if (lordIdx < 0) {
    throw ArgumentError('unknown dasha lord: ' + parent.lord);
  }
  final spanDays = parent.spanDays;
  final spans = <DashaSpan>[];
  var start = parent.startJdTt;
  for (var k = 0; k < 9; k++) {
    final lord = (lordIdx + k) % 9;
    final days = vimshottariYears[lord] / 120.0 * spanDays;
    spans.add(DashaSpan(
      lord: vimshottariLords[lord],
      level: childLevel,
      startJdTt: start,
      endJdTt: start + days,
    ));
    start += days;
  }
  return spans;
}

/// The dasha stack running at a query instant.
class VimshottariAt {
  final DashaSpan mahadasha;

  final DashaSpan? antardasha;

  final DashaSpan? pratyantardasha;

  const VimshottariAt({
    required this.mahadasha,
    this.antardasha,
    this.pratyantardasha,
  });
}

/// The Vimshottari stack running at [queryJdTt] for a birth at
/// [birthJdTt] (both TT Julian Days). Throws when the query lies before
/// the birth instant or beyond the served nine-mahadasha (120-year)
/// window - out-of-window queries are an error, never a silent wrap.
VimshottariAt vimshottariAt(
    {required double birthJdTt,
    required double queryJdTt,
    required double ayanamsaDeg,
    required double yearDays,
    bool withPratyantardasha = true}) {
  if (queryJdTt < birthJdTt) {
    throw ArgumentError('query before the birth instant');
  }
  final mahas = vimshottariMahadashas(
      birthJdTt: birthJdTt, ayanamsaDeg: ayanamsaDeg, yearDays: yearDays);
  DashaSpan? maha;
  for (final s in mahas) {
    if (s.contains(queryJdTt)) {
      maha = s;
      break;
    }
  }
  if (maha == null) {
    throw ArgumentError('query beyond the 120-year Vimshottari window');
  }
  final antars =
      vimshottariSubPeriods(maha, yearDays: yearDays, childLevel: 'antardasha');
  DashaSpan? antar;
  for (final s in antars) {
    if (s.contains(queryJdTt)) {
      antar = s;
      break;
    }
  }
  DashaSpan? praty;
  if (withPratyantardasha && antar != null) {
    final pratyantars = vimshottariSubPeriods(antar,
        yearDays: yearDays, childLevel: 'pratyantardasha');
    for (final s in pratyantars) {
      if (s.contains(queryJdTt)) {
        praty = s;
        break;
      }
    }
  }
  return VimshottariAt(
      mahadasha: maha, antardasha: antar, pratyantardasha: praty);
}

double _norm360(double deg) => deg % 360.0;