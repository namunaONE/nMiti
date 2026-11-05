import 'ayanamsa.dart';
import 'civil_time.dart';
import 'limbs.dart';
import 'sun.dart';
import 'sunrise.dart';

/// Lunar month (masa) layer: new-moon scan, sankranti overlay and
/// adhika/kshaya detection (ritual-complete L1 calendar core, HYA-419).
///
/// Own logic throughout - no data files, no external engines:
///   * amanta lunar months are new-moon to new-moon spans, found with the
///     engine's own wrap-safe tithi sector solver (the Amavasya -> Shukla
///     Pratipada boundary IS the new moon);
///   * the sankranti overlay uses the engine's own sidereal sun
///     (VSOP87D apparent longitude minus the base ayanamsa 23.87508 +
///     1.36062/cy - the SAME calibrated constants that define the verified
///     Commons Layer 1 sankranti artifact), solved with the secant ingress
///     method proven in packages/nepali_sankranti;
///   * month naming follows the classical amanta rule the receipts pin
///     (verified against the own festival corpus: Ghatasthapana Oct 11 2026
///     = Ashwin Shukla Pratipada, in the lunar month containing the Tula
///     sankranti): a lunar month is named after the solar month that ENDS
///     within it - the month containing the Mesha sankranti is CHAITRA,
///     Vrishabha sankranti -> Baisakh, ..., Meena sankranti -> Falgun;
///   * a lunar month containing NO sankranti is adhika (intercalated): it
///     takes the name of the following month;
///   * a lunar month containing TWO sankrantis is kshaya (elided): it takes
///     the name of the FIRST contained sankranti. No kshaya month occurs in
///     the 2026-2029 window; the kshaya naming branch is CI-covered by the
///     tithi_engine oracle sweep and needs a dated publisher receipt before
///     it is served as truth (honesty rule: no convention ships without a
///     receipt).
///
/// Receipts anchoring this layer (documented in test/masa_test.dart):
///   * Adhika Jyeshtha/Jestha 2026, amanta span May 17 - June 15/16, 2026
///     (Nepal News via the Panchanga Decision Committee, hindutone,
///     hindupad; Wikipedia "Vikram Samvat": the 2083 amanta year has 13
///     lunar months).

/// Nepali (Bikram Sambat) month names in order 1..12.
/// Month 1, Baisakh, is the lunar month containing the Vrishabha
/// sankranti (the Mesha sankranti falls in lunar Chaitra, month 12).
const List<String> masaNames = [
  'Baisakh', 'Jestha', 'Asharh', 'Shrawan', 'Bhadra', 'Ashwin',
  'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra',
];

/// Amanta month number 1..12 carried by the lunar month that contains the
/// ingress into rashi [rasi] (1..12): Mesha -> Chaitra (12), Vrishabha ->
/// Baisakh (1), ..., Meena -> Falgun (11).
int _monthOfRasi(int rasi) {
  if (rasi < 1 || rasi > 12) {
    throw ArgumentError('rasi index out of range: $rasi');
  }
  return rasi == 1 ? 12 : rasi - 1;
}

/// One amanta lunar month (masa), from new moon to new moon.
class MasaInfo {
  /// The new-moon instant that opens the month, NPT wall clock
  /// (UTC fields; no offset applied).
  final DateTime beginsAtNpt;

  /// The next new moon, NPT wall clock (UTC fields).
  final DateTime endsAtNpt;

  /// BS month number 1..12 (Baisakh = 1). Always assigned: adhika months
  /// carry the number of the following month.
  final int monthNumber;

  /// True when this lunar month contains no sankranti (intercalated).
  final bool isAdhika;

  /// True when this lunar month contains two sankrantis (elided).
  final bool isKshaya;

  /// The sidereal solar ingress (sankranti) instants inside this month,
  /// NPT wall clock (UTC fields). Empty for adhika months, two entries
  /// for kshaya months.
  final List<DateTime> sankrantiMomentsNpt;

  /// Engine and convention provenance (public truth-data policy).
  final String provenance;

  /// Evidence statement for this value set.
  final String evidenceTier;

  const MasaInfo({
    required this.beginsAtNpt,
    required this.endsAtNpt,
    required this.monthNumber,
    required this.isAdhika,
    required this.isKshaya,
    required this.sankrantiMomentsNpt,
    required this.provenance,
    required this.evidenceTier,
  });

  /// Canonical Nepali month name ('Baisakh'..'Chaitra').
  String get monthName => masaNames[monthNumber - 1];
}

/// TT Julian Day of the next new moon strictly after [jdTtStart].
///
/// A new moon is the instant the tithi sector wraps from Amavasya (29) to
/// Shukla Pratipada (0) - the same wrap-safe sector formulation the limb
/// solver uses, and ayanamsa-independent (tithi is pure elongation). Tithi
/// runs never shrink below ~19.6 h, so a 0.25-day step cannot skip the
/// Amavasya sector or the Pratipada sector on either side of the wrap.
double nextNewMoonJdTt(double jdTtStart) {
  var lo = jdTtStart;
  var hi = jdTtStart + 0.25;
  while (!(limbIndex('tithi', lo, 0.0) == 29 &&
      limbIndex('tithi', hi, 0.0) == 0)) {
    lo = hi;
    hi += 0.25;
    if (hi - jdTtStart > 35.0) {
      throw StateError('new-moon scan failed to bracket a wrap');
    }
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (limbIndex('tithi', mid, 0.0) == 29) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}

/// Sidereal longitude of the sun at [jdTt], degrees in [0, 360):
/// the engine's own apparent sun reduced by the ayanamsa profile.
double _siderealSunDeg(double jdTt, double sourceDelta) {
  return _norm360(sunApparentLongitude(jdTt) - ayanamsaTotal(jdTt, sourceDelta));
}

double _signedDiff(double a, double b) {
  var d = (a - b) % 360.0;
  if (d <= -180.0) d += 360.0;
  if (d > 180.0) d -= 360.0;
  return d;
}

/// TT Julian Day of the sidereal solar ingress at [targetDeg] inside the
/// bracket [jdLo, jdHi], by secant iteration (the sun moves ~0.9856 deg/day,
/// so the residual is monotone over any month-sized bracket).
double _ingressJdTt(double targetDeg, double jdLo, double jdHi, double sourceDelta) {
  double resid(double jd) => _signedDiff(_siderealSunDeg(jd, sourceDelta), targetDeg);
  var a = jdLo;
  var fa = resid(a);
  var b = jdHi;
  var fb = resid(b);
  if (fa * fb > 0.0) {
    throw StateError('ingress bracket does not straddle the target');
  }
  for (var i = 0; i < 60; i++) {
    final denom = fb - fa;
    if (denom.abs() < 1e-12) break;
    final c = b - fb * (b - a) / denom;
    final fc = resid(c);
    a = b;
    fa = fb;
    b = c;
    fb = fc;
    if ((b - a).abs() < 5.8e-6) break; // about half a second
  }
  return b;
}

/// (rasi index 1..12, TT Julian Day) of every sidereal ingress inside the
/// lunar month [jdLo, jdHi]. The sun advances 28-31 deg per lunar month, so
/// this returns 0 (adhika), 1 (normal) or 2 (kshaya) entries.
List<int> _sankrantiRasis(double jdLo, double jdHi, double sourceDelta) {
  final sLo = _siderealSunDeg(jdLo, sourceDelta);
  final sHi = _siderealSunDeg(jdHi, sourceDelta);
  final out = <int>[];
  for (var r = 1; r <= 12; r++) {
    final target = 30.0 * (r - 1);
    final crosses = sLo < sHi
        ? (sLo < target && target <= sHi)
        : (target > sLo || target <= sHi);
    if (crosses) out.add(r);
  }
  return out;
}

/// All amanta lunar months whose span intersects the NPT window
/// [startNpt, endNpt] (civil dates, UTC fields), classified and named.
///
/// The window is widened so the first month fully covers [startNpt] and the
/// last fully covers [endNpt]; one extra month is always scanned past the
/// end because an adhika month is named after the month that follows it.
List<MasaInfo> masaList({
  required DateTime startNpt,
  required DateTime endNpt,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  if (!startNpt.isBefore(endNpt)) {
    throw ArgumentError('startNpt must be before endNpt');
  }
  // TT bounds: scan new moons from at least one lunation before the window.
  final scanLoTt =
      jdTtFromJdUt(jdFromDateTimeUtc(startNpt.subtract(const Duration(days: 34))));
  final scanHiTt =
      jdTtFromJdUt(jdFromDateTimeUtc(endNpt.add(const Duration(days: 2))));

  // New-moon chain. The first new moon after scanLoTt is < 29.6 days before
  // startNpt, so months (nm_i, nm_{i+1}) cover the window head. Keep one
  // extra new moon past scanHiTt so the last month closes.
  final newMoonsTt = <double>[];
  var nm = nextNewMoonJdTt(scanLoTt);
  while (nm < scanHiTt + 32.0) {
    newMoonsTt.add(nm);
    nm = nextNewMoonJdTt(nm);
  }

  // Raw classification per month.
  final count = newMoonsTt.length - 1;
  final numbers = List<int>.filled(count, 0);
  final adhika = List<bool>.filled(count, false);
  final kshaya = List<bool>.filled(count, false);
  final sankrantiTt = List<List<double>>.generate(
      count, (_) => <double>[], growable: false);
  for (var i = 0; i < count; i++) {
    final lo = newMoonsTt[i];
    final hi = newMoonsTt[i + 1];
    final rasis = _sankrantiRasis(lo, hi, sourceDelta);
    for (final r in rasis) {
      sankrantiTt[i].add(_ingressJdTt(30.0 * (r - 1), lo, hi, sourceDelta));
    }
    if (rasis.isEmpty) {
      adhika[i] = true; // named after the following month (second pass)
    } else if (rasis.length >= 2) {
      kshaya[i] = true;
      numbers[i] = _monthOfRasi(rasis.first); // first contained sankranti
    } else {
      numbers[i] = _monthOfRasi(rasis.first);
    }
  }
  // Adhika months take the number of the following month.
  for (var i = 0; i < count; i++) {
    if (adhika[i]) {
      if (i + 1 >= count) {
        throw StateError('adhika month at scan tail: widen the window');
      }
      numbers[i] = numbers[i + 1];
    }
  }

  // Materialize with NPT wall clocks; keep months intersecting the window.
  final winLo = startNpt.subtract(const Duration(days: 1));
  final winHi = endNpt.add(const Duration(days: 1));
  final out = <MasaInfo>[];
  for (var i = 0; i < count; i++) {
    final begins = _nptWall(newMoonsTt[i]);
    final ends = _nptWall(newMoonsTt[i + 1]);
    if (begins.isAfter(winHi) || !ends.isAfter(winLo)) continue;
    out.add(MasaInfo(
      beginsAtNpt: begins,
      endsAtNpt: ends,
      monthNumber: numbers[i],
      isAdhika: adhika[i],
      isKshaya: kshaya[i],
      sankrantiMomentsNpt:
          [for (final jd in sankrantiTt[i]) _nptWall(jd)],
      provenance: 'nMiti nepali_panchang masa layer: new moons via the '
          'wrap-safe tithi solver, sankrantis via the VSOP87D apparent sun '
          'minus the ayanamsa profile (delta '
          '${sourceDelta.toStringAsFixed(4)} deg, BhaktiBharat-anchored fit); '
          'amanta naming rule sankranti-in-month, adhika = no sankranti, '
          'kshaya = two sankrantis.',
      evidenceTier: 'runtime-computed; anchored to the 2026 Adhika Jestha '
          'receipt (Nepal Panchanga Decision Committee via Nepal News, '
          'hindutone, hindupad) and cross-checked day-by-day against the '
          'Swiss-anchored tithi_engine oracle in CI',
    ));
  }
  return out;
}

/// The amanta lunar month of one NPT civil day: the month whose span
/// contains the day's udaya (sunrise) instant - the same convention the
/// panchang day and the tithi_engine oracle use for day attribution.
MasaInfo masaOf({
  required int year,
  required int month,
  required int day,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  final dateNpt = DateTime.utc(year, month, day);
  final months = masaList(
    startNpt: dateNpt.subtract(const Duration(days: 35)),
    endNpt: dateNpt.add(const Duration(days: 35)),
    sourceDelta: sourceDelta,
  );
  final udayaUtc = dateTimeUtcFromJd(sunriseJdUt(year: year, month: month, day: day));
  for (final m in months) {
    final b = _utcOfNptWall(m.beginsAtNpt);
    final e = _utcOfNptWall(m.endsAtNpt);
    if (!udayaUtc.isBefore(b) && udayaUtc.isBefore(e)) return m;
  }
  throw StateError('no lunar month contains the udaya of $dateNpt');
}

DateTime _nptWall(double jdTt) {
  return dateTimeUtcFromJd(jdUtFromJdTt(jdTt))
      .add(const Duration(milliseconds: nptOffsetMs));
}

DateTime _utcOfNptWall(DateTime nptWall) =>
    nptWall.subtract(const Duration(milliseconds: nptOffsetMs));

double _norm360(double deg) => deg % 360.0;
