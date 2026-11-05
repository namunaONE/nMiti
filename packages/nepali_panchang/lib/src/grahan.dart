import 'dart:math' as math;

import 'civil_time.dart';
import 'eclipse_lunar.dart';
import 'eclipse_solar.dart';
import 'julian_day.dart';
import 'moonrise.dart';
import 'sun.dart';

const double _radPerDeg = math.pi / 180;
const double _degPerRad = 180 / math.pi;

/// L6 grahan assembly layer - the shastra module (HYA-421 step 4).
///
/// [grahanNear], [grahanInYear] and [nextGrahanAfter] compose the
/// astronomy of the two eclipse solvers with the traditional Nepali
/// grahan rules. Every rule is receipt-anchored and every convention
/// collision is decoded, never silently picked - the verbatim quotes
/// live in test/fixtures/grahan_shastra_receipts.json (parsed
/// 2026-11-05 from BhaktiBharat, PanchangBodh, HinduCalculator,
/// nepalipatro, Nepal Jyotish, Hamro Patro, ratopati and the
/// timeanddate Kathmandu stage tables):
///
/// - Sutak: 12 hours (4 prahar) before a solar eclipse, 9 hours
///   (3 prahar) before a lunar eclipse, counted from the LOCAL
///   visible contacts and ending at the locally visible moksha.
/// - Visibility gating (collision C4, prevailing rule): an eclipse
///   not visible from the location carries no sutak.
/// - Grastodit: when the body rises already eclipsed the sutak is
///   anchored to the local rise - the nepalipatro committee receipt
///   says the sutak is 'calculated based on the time when the moon
///   rises in that particular place'.
/// - Upachhaya (collision C5): a penumbral lunar eclipse is not kept
///   as a grahan - keptAsGrahan false, no sutak.
/// - Naming: Khagras total / Khandagras partial / Upachhaya
///   penumbral, with the publisher collision exposed (C6: Hamro Patro
///   titles the 3 Mar 2026 total lunar eclipse Khandagras Chandra
///   Grahan because Nepal observes only the partial phase at
///   moonrise, so grahanClass is the global class while
///   risesEclipsed carries the local observation).
///
/// The lunar local window is computed against the same Meeus eq. 15.1
/// rise target the moonrise solver uses (upper limb plus 34' of
/// refraction on geocentric altitude), so 'visible from Kathmandu'
/// and the printed moonrise receipts agree by construction. The solar
/// window uses the sunrise solver's -0.8333 deg geometric center
/// convention.
///
/// Mapping sutak windows onto Nepali civil days (a sutak can begin the
/// previous evening, and a 12-hour solar sutak always does) is the
/// job of the display layer (step 5), not of this module.

/// Sutak hours before a solar eclipse: 4 prahars of 3 hours each
/// (BhaktiBharat, PanchangBodh, HinduCalculator, drik - one rule).
const double sutakSolarHours = 12.0;

/// Sutak hours before a lunar eclipse: 3 prahars of 3 hours each,
/// counted from the umbral first contact (HinduCalculator states the
/// umbral anchor explicitly; PanchangBodh's 3 Mar 2026 sutak window
/// arithmetic confirms it).
const double sutakLunarHours = 9.0;

/// Which body is eclipsed.
enum GrahanKind { suryaGrahan, chandraGrahan }

/// The traditional Nepali classification of the eclipse itself
/// (globally, not as locally observed).
enum GrahanClass {
  /// Total: the whole disc is swallowed (a central annular ring
  /// included - see the conventions map's annularNaming entry).
  khagras,

  /// Partial.
  khandagras,

  /// Penumbral lunar eclipse: not kept as a grahan (collision C5).
  upachhaya,
}

/// One grahan event assembled for a location; all instants are UT
/// Julian Days unless the field name says Npt.
class GrahanEvent {
  /// Surya or Chandra grahan.
  final GrahanKind kind;

  /// Global classification: khagras / khandagras / upachhaya.
  final GrahanClass grahanClass;

  /// The composed Nepali name, e.g. 'Khagras Chandra Grahan
  /// (grastodit)' or 'Upachhaya Chandra Grahan (not kept as grahan)'.
  final String nepaliName;

  /// False only for upachhaya lunar eclipses (collision C5): visible
  /// or not, tradition does not keep them as grahan.
  final bool keptAsGrahan;

  /// Instant of greatest eclipse.
  final double jdUtGreatest;

  /// Moksha, the eclipse end per the engine convention: the fourth
  /// contact for a solar eclipse, the umbral end for a lunar eclipse
  /// that touches the umbra (the penumbral tail is not a grahan),
  /// else the penumbral end.
  final double jdUtMoksha;

  /// Whether any grahan phase is visible from the location (the
  /// sutak gate, collision C4). Below-horizon solar grazes are
  /// returned with false - shown with the not-visible flag, never
  /// suppressed.
  final bool visibleAtLocation;

  /// Grastodit: the body rises while the eclipse is in progress, so
  /// the local first contact is the rise itself and the sutak is
  /// anchored to it.
  final bool risesEclipsed;

  /// The body sets before moksha, so the local last contact is the
  /// set (the locally visible moksha).
  final bool setsEclipsed;

  /// First contact visible from the location; null when not visible.
  final double? jdUtVisibleStart;

  /// Last contact visible from the location; null when not visible.
  final double? jdUtVisibleEnd;

  /// Sutak start: sutakHours before the local first visible contact;
  /// null when no sutak applies (not visible, or upachhaya).
  final double? jdUtSutakStart;

  /// Sutak end: the locally visible moksha; null when no sutak
  /// applies.
  final double? jdUtSutakEnd;

  /// Solar: the covered fraction of the solar diameter. Lunar: the
  /// umbral magnitude, or the penumbral magnitude for upachhaya.
  final double magnitude;

  /// Solar only: the covered fraction of the solar disc area.
  final double? obscuration;

  /// The underlying solar circumstances when kind is suryaGrahan.
  final SolarEclipseCircumstances? solar;

  /// The underlying lunar circumstances when kind is chandraGrahan.
  final LunarEclipseCircumstances? lunar;

  /// The decoded convention collisions (C1-C6 and the sutak rules),
  /// mirroring the muhurta layer's conventions map.
  final Map<String, String> conventions;

  final String provenance;

  final String evidenceTier;

  /// The exemption note (children/sick/elderly one prahar, pregnant
  /// women precautions) - noted, never computed.
  final String exemptionsNote;

  const GrahanEvent({
    required this.kind,
    required this.grahanClass,
    required this.nepaliName,
    required this.keptAsGrahan,
    required this.jdUtGreatest,
    required this.jdUtMoksha,
    required this.visibleAtLocation,
    required this.risesEclipsed,
    required this.setsEclipsed,
    required this.jdUtVisibleStart,
    required this.jdUtVisibleEnd,
    required this.jdUtSutakStart,
    required this.jdUtSutakEnd,
    required this.magnitude,
    required this.obscuration,
    required this.solar,
    required this.lunar,
    required this.conventions,
    required this.provenance,
    required this.evidenceTier,
    required this.exemptionsNote,
  });

  /// Greatest eclipse as an NPT wall clock (UTC fields).
  DateTime get greatestNpt => _nptWall(jdUtGreatest);

  /// Moksha as an NPT wall clock (UTC fields).
  DateTime get mokshaNpt => _nptWall(jdUtMoksha);

  /// Sutak start as an NPT wall clock, or null.
  DateTime? get sutakStartNpt =>
      jdUtSutakStart == null ? null : _nptWall(jdUtSutakStart!);

  /// Sutak end (the locally visible moksha) as NPT, or null.
  DateTime? get sutakEndNpt =>
      jdUtSutakEnd == null ? null : _nptWall(jdUtSutakEnd!);

  /// First visible contact as an NPT wall clock, or null.
  DateTime? get visibleStartNpt =>
      jdUtVisibleStart == null ? null : _nptWall(jdUtVisibleStart!);

  /// Last visible contact as an NPT wall clock, or null.
  DateTime? get visibleEndNpt =>
      jdUtVisibleEnd == null ? null : _nptWall(jdUtVisibleEnd!);
}

DateTime _nptWall(double jdUt) {
  return dateTimeUtcFromJd(jdUt)
      .add(const Duration(milliseconds: nptOffsetMs));
}

const Map<String, String> _grahanConventions = {
  'shadowEnlargement':
      'Danjon 1/85 by default (the NASA/GSFC bulletins the lunar '
      'receipts are published with); the Chauvenet 1/50 rule is '
      'exposed via the shadowEnlargement parameter - collision C1, '
      'never silently picked',
  'sutakHours':
      'solar 12 h (4 prahar) before the local first contact, lunar '
      '9 h (3 prahar) before the local umbral first contact - '
      'BhaktiBharat, PanchangBodh, HinduCalculator, nepalipatro and '
      'drik agree; the varna short table (12/9/6/3) exists but the '
      'common panchang clock is served',
  'sutakAnchor':
      'local visible contacts only: an eclipse not visible from the '
      'location carries no sutak - collision C4 resolved to the '
      'prevailing rule (drik, PanchangBodh, HinduCalculator)',
  'sutakEnd':
      'at moksha, the locally visible last contact (the umbral end '
      'for a lunar eclipse, the fourth contact for a solar one); '
      'when the body sets before the eclipse ends, the local set is '
      'the moksha',
  'grastodit':
      'the body rises already eclipsed: the sutak clock is anchored '
      'to the local rise (nepalipatro committee receipt - the sutak '
      'is calculated based on the time when the moon rises in that '
      'particular place); risesEclipsed is exposed so the display '
      'layer can say what is observed',
  'upachhaya':
      'a penumbral lunar eclipse is not kept as a grahan - '
      'keptAsGrahan false, no sutak - collision C5, pinned by '
      'HinduCalculator, PanchangBodh and Nepal Jyotish',
  'sutakExemptions':
      'children, the sick and the elderly observe one prahar (about '
      '3 h) of the food restriction; pregnant women are advised '
      'precautions - noted, not computed (family custom varies)',
  'naming':
      'Khagras total / Khandagras partial / Upachhaya penumbral; '
      'publishers may name by the locally observed phase (Hamro Patro '
      'titles the 3 Mar 2026 total lunar eclipse Khandagras Chandra '
      'Grahan for Nepal) - collision C6: grahanClass is the global '
      'class, risesEclipsed carries the local observation',
  'annularNaming':
      'a central annular eclipse is named Khagras (the whole disc is '
      'swallowed); some sources prefer Kankana-akriti - recorded, '
      'Khagras kept',
  'belowHorizonSolar':
      'penumbral solar grazes past the terminator are returned with '
      'visibleAtLocation false (timeanddate: not visible) - shown '
      'with the not-visible flag, never suppressed',
  'publisherDivergence':
      'the Hamro Patro 3 Mar 2026 article concludes (moksha) at '
      '2:38 AM with duration 59 min against NASA umbral contacts '
      'ending 19:02 NPT - collision C2, receipt-recorded, never '
      'chased',
  'sutakHoursReversedFaq':
      'the HinduCalculator eclipse-calendar FAQ reverses the hours in '
      'one sentence (nine before solar, twelve before lunar) against '
      'its own table and myths section - collision C3, '
      'receipt-recorded',
};

const String _grahanProvenance =
    'nMiti nepali_panchang engine: the geocentric lunar solver (Meeus '
    'Ch.54 style shadow geometry, Danjon default) and the topocentric '
    'solar solver compose the events; the sutak and naming rules are '
    'receipt-anchored to the grahan shastra corpus '
    '(nmiti-grahan-shastra-receipts/1, crawled 2026-11-05).';

const String _grahanEvidenceTier =
    'runtime-computed eclipse geometry; the sutak rules are '
    'triple-confirmed (BhaktiBharat, PanchangBodh, HinduCalculator, '
    'nepalipatro, drik); the local windows are banded against the '
    'timeanddate Kathmandu stage tables in test/grahan_test.dart.';

const String _grahanExemptionsNote =
    'Children, the sick and the elderly traditionally observe one '
    'prahar (about 3 hours) of the food restriction instead of the '
    'full sutak; pregnant women are advised to stay indoors and take '
    'precautions. Family and regional custom varies.';

/// Geocentric altitude of the Sun's center above the astronomical
/// horizon (degrees) at a UT Julian Day - the same mean-equinox-of-date
/// frame every other limb shares (obliquity Meeus eq. 22.2, sidereal
/// time Meeus eq. 12.4, ecliptic-to-equatorial Meeus eqs. 13.3/13.4).
double _sunGeocentricAltitudeDeg(double jdUt, double latitudeDeg,
    double longitudeDeg) {
  final jdTt = jdTtFromJdUt(jdUt);
  final t = (jdUt - 2451545.0) / 36525.0;
  final epsDeg = 23.439291111 -
      0.013004167 * t -
      0.000000164 * t * t +
      0.000000504 * t * t * t;
  final lam = sunTrueLongitude(jdTt) * _radPerDeg;
  final eps = epsDeg * _radPerDeg;
  final raDeg =
      math.atan2(math.sin(lam) * math.cos(eps), math.cos(lam)) *
          _degPerRad;
  final decDeg = math.asin(math.sin(eps) * math.sin(lam)) * _degPerRad;
  final gmstDeg = 280.46061837 +
      360.98564736629 * (jdUt - 2451545.0) +
      0.000387933 * t * t -
      t * t * t / 38710000;
  final hourAngleDeg = gmstDeg + longitudeDeg - raDeg;
  final lat = latitudeDeg * _radPerDeg;
  final dec = decDeg * _radPerDeg;
  final h = hourAngleDeg * _radPerDeg;
  return math.asin(math.sin(lat) * math.sin(dec) +
          math.cos(lat) * math.cos(dec) * math.cos(h)) *
      _degPerRad;
}

/// Moon rise-target margin (Meeus eq. 15.1): the exact quantity the
/// moonrise solver bisects, reused so the grahan window and the
/// printed moonrise receipts share one convention.
double _moonMargin(double jdUt, double latitudeDeg, double longitudeDeg) {
  return moonGeocentricAltitudeDeg(
          jdUt: jdUt, latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg) -
      moonRiseTargetAltitudeDeg(jdUt);
}

/// Sun rise-target margin: the USNO sunrise solver's -0.8333 deg
/// geometric center convention (standard refraction plus solar
/// semidiameter).
double _sunMargin(double jdUt, double latitudeDeg, double longitudeDeg) {
  return _sunGeocentricAltitudeDeg(jdUt, latitudeDeg, longitudeDeg) +
      0.8333;
}

/// First [rising] crossing of the zero margin between [jdStart] and
/// [jdEnd] (30-minute steps, then 40 bisections), or null.
double? _crossingBetween(double jdStart, double jdEnd,
    double Function(double) margin, bool rising) {
  const step = 1.0 / 48.0;
  var prevJd = jdStart;
  var prevM = margin(jdStart);
  while (prevJd < jdEnd) {
    var jd = prevJd + step;
    if (jd > jdEnd) {
      jd = jdEnd;
    }
    final m = margin(jd);
    if (rising && prevM < 0.0 && m >= 0.0) {
      return _bisectCrossing(prevJd, jd, margin, rising);
    }
    if (!rising && prevM >= 0.0 && m < 0.0) {
      return _bisectCrossing(prevJd, jd, margin, rising);
    }
    prevJd = jd;
    prevM = m;
  }
  return null;
}

double _bisectCrossing(
    double lo, double hi, double Function(double) margin, bool rising) {
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2.0;
    final m = margin(mid);
    final inside = rising ? (m < 0.0) : (m >= 0.0);
    if (inside) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}

/// Assemble the shastra event for a solar eclipse at the location.
GrahanEvent _solarGrahanEvent(
    SolarEclipseCircumstances c, double latitudeDeg, double longitudeDeg) {
  final visible = c.visibility != SolarEclipseVisibility.belowHorizon;
  double sunMargin(double jdUt) =>
      _sunMargin(jdUt, latitudeDeg, longitudeDeg);
  double? visStart;
  double? visEnd;
  var rises = false;
  var sets = false;
  if (visible) {
    if (c.sunAltitudeDegAtStart > 0.0) {
      visStart = c.jdUtPartialStart;
    } else {
      // A sunrise eclipse (grastodit): the first visible contact is
      // the sunrise itself, searched over the whole partial phase.
      visStart = _crossingBetween(
              c.jdUtPartialStart, c.jdUtPartialEnd, sunMargin, true) ??
          c.jdUtPartialStart;
      rises = true;
    }
    if (c.sunAltitudeDegAtEnd > 0.0) {
      visEnd = c.jdUtPartialEnd;
    } else {
      // A sunset eclipse: the local moksha is the sunset.
      visEnd = _crossingBetween(
              visStart!, c.jdUtPartialEnd, sunMargin, false) ??
          c.jdUtPartialEnd;
      sets = true;
    }
  }
  final cls =
      c.centralAtGreatest ? GrahanClass.khagras : GrahanClass.khandagras;
  final base = cls == GrahanClass.khagras
      ? 'Khagras Surya Grahan'
      : 'Khandagras Surya Grahan';
  return GrahanEvent(
    kind: GrahanKind.suryaGrahan,
    grahanClass: cls,
    nepaliName: rises ? base + ' (grastodit)' : base,
    keptAsGrahan: true,
    jdUtGreatest: c.jdUtGreatest,
    jdUtMoksha: c.jdUtPartialEnd,
    visibleAtLocation: visible,
    risesEclipsed: rises,
    setsEclipsed: sets,
    jdUtVisibleStart: visStart,
    jdUtVisibleEnd: visEnd,
    jdUtSutakStart:
        visible ? visStart! - sutakSolarHours / 24.0 : null,
    jdUtSutakEnd: visible ? visEnd : null,
    magnitude: c.magnitude,
    obscuration: c.obscuration,
    solar: c,
    lunar: null,
    conventions: _grahanConventions,
    provenance: _grahanProvenance,
    evidenceTier: _grahanEvidenceTier,
    exemptionsNote: _grahanExemptionsNote,
  );
}

/// Assemble the shastra event for a lunar eclipse at the location.
GrahanEvent _lunarGrahanEvent(LunarEclipseCircumstances c,
    double latitudeDeg, double longitudeDeg) {
  final umbral = c.jdUtPartialStart != null && c.jdUtPartialEnd != null;
  // The grahan interval: the umbral phase when it exists (the
  // penumbral tail is not a grahan), else the penumbral one for the
  // upachhaya display.
  final intervalStart =
      umbral ? c.jdUtPartialStart! : c.jdUtPenumbralStart;
  final intervalEnd = umbral ? c.jdUtPartialEnd! : c.jdUtPenumbralEnd;
  double moonMargin(double jdUt) =>
      _moonMargin(jdUt, latitudeDeg, longitudeDeg);
  double? visStart;
  double? visEnd;
  var rises = false;
  var sets = false;
  if (_moonMargin(intervalStart, latitudeDeg, longitudeDeg) >= 0.0) {
    visStart = intervalStart;
    final moonset =
        _crossingBetween(intervalStart, intervalEnd, moonMargin, false);
    visEnd = moonset ?? intervalEnd;
    sets = moonset != null;
  } else {
    final moonrise =
        _crossingBetween(intervalStart, intervalEnd, moonMargin, true);
    if (moonrise != null) {
      // Grastodit: the Moon rises while the eclipse is in progress,
      // so the local first contact is the moonrise.
      visStart = moonrise;
      rises = true;
      final moonset =
          _crossingBetween(moonrise, intervalEnd, moonMargin, false);
      visEnd = moonset ?? intervalEnd;
      sets = moonset != null;
    }
  }
  final visible = visStart != null;
  final cls = c.type == LunarEclipseType.total
      ? GrahanClass.khagras
      : (c.type == LunarEclipseType.partial
          ? GrahanClass.khandagras
          : GrahanClass.upachhaya);
  final String base;
  if (cls == GrahanClass.khagras) {
    base = 'Khagras Chandra Grahan';
  } else if (cls == GrahanClass.khandagras) {
    base = 'Khandagras Chandra Grahan';
  } else {
    base = 'Upachhaya Chandra Grahan (not kept as grahan)';
  }
  // Upachhaya is never kept: no sutak even when the penumbral dimming
  // is visible (collision C5).
  final sutak = visible && umbral;
  return GrahanEvent(
    kind: GrahanKind.chandraGrahan,
    grahanClass: cls,
    nepaliName: rises ? base + ' (grastodit)' : base,
    keptAsGrahan: umbral,
    jdUtGreatest: c.jdUtGreatest,
    jdUtMoksha: intervalEnd,
    visibleAtLocation: visible,
    risesEclipsed: rises,
    setsEclipsed: sets,
    jdUtVisibleStart: visStart,
    jdUtVisibleEnd: visEnd,
    jdUtSutakStart: sutak ? visStart! - sutakLunarHours / 24.0 : null,
    jdUtSutakEnd: sutak ? visEnd : null,
    magnitude: umbral ? c.umbralMagnitude : c.penumbralMagnitude,
    obscuration: null,
    solar: null,
    lunar: c,
    conventions: _grahanConventions,
    provenance: _grahanProvenance,
    evidenceTier: _grahanEvidenceTier,
    exemptionsNote: _grahanExemptionsNote,
  );
}

/// The grahan whose greatest eclipse falls in the window from one day
/// before [day] to 1.6 days after it - solar or lunar, whichever is
/// nearer - or null when there is none.
///
/// Below-horizon grazes and upachhaya eclipses are returned (the
/// display policy shows them with their flags), never suppressed.
GrahanEvent? grahanNear(int year, int month, int day,
    {double latitudeDeg = 27.7172,
    double longitudeDeg = 85.324,
    double shadowEnlargement = danjonShadowEnlargement}) {
  final jdUt = julianDayFromCivil(year, month, day.toDouble());
  final lunar = lunarEclipseNear(year, month, day,
      shadowEnlargement: shadowEnlargement);
  final solar = solarEclipseNear(year, month, day,
      latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg);
  GrahanEvent? best;
  var bestGap = double.infinity;
  final anchor = jdUt + 0.8;
  if (lunar != null) {
    best = _lunarGrahanEvent(lunar, latitudeDeg, longitudeDeg);
    bestGap = (best.jdUtGreatest - anchor).abs();
  }
  if (solar != null) {
    final e = _solarGrahanEvent(solar, latitudeDeg, longitudeDeg);
    final gap = (e.jdUtGreatest - anchor).abs();
    if (best == null || gap < bestGap) {
      best = e;
    }
  }
  return best;
}

/// All grahan events of the Gregorian [year] at the location, in time
/// order, including below-horizon grazes and upachhaya eclipses.
List<GrahanEvent> grahanInYear(int year,
    {double latitudeDeg = 27.7172,
    double longitudeDeg = 85.324,
    double shadowEnlargement = danjonShadowEnlargement}) {
  final out = <GrahanEvent>[];
  for (final l
      in lunarEclipsesInYear(year, shadowEnlargement: shadowEnlargement)) {
    out.add(_lunarGrahanEvent(l, latitudeDeg, longitudeDeg));
  }
  for (final s in solarEclipsesInYear(year,
      latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg)) {
    out.add(_solarGrahanEvent(s, latitudeDeg, longitudeDeg));
  }
  out.sort((a, b) => a.jdUtGreatest.compareTo(b.jdUtGreatest));
  return out;
}

/// The next grahan event whose greatest eclipse falls on or after the
/// civil date [year]-[month]-[day], or null within twelve years.
GrahanEvent? nextGrahanAfter(int year, int month, int day,
    {double latitudeDeg = 27.7172,
    double longitudeDeg = 85.324,
    double shadowEnlargement = danjonShadowEnlargement}) {
  final jdUt = julianDayFromCivil(year, month, day.toDouble());
  for (var y = year; y <= year + 12; y++) {
    for (final e in grahanInYear(y,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg,
        shadowEnlargement: shadowEnlargement)) {
      if (e.jdUtGreatest >= jdUt) {
        return e;
      }
    }
  }
  return null;
}
