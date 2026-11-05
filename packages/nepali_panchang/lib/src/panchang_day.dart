import 'ayanamsa.dart';
import 'civil_time.dart';
import 'limbs.dart';
import 'solver.dart';
import 'sunrise.dart';

/// Daily panchang shape (R6a-3, HYA-416).
///
/// [panchangFor] composes the limb layer into the per-day block the site and
/// the future API serve: the tithi, nakshatra, yoga and karana running at the
/// udaya (sunrise) reference moment, the noon (madhyahna) elements for the
/// BhaktiBharat display convention, and sunrise. Conventions are exposed,
/// never silently picked: every element records the reference moment it was
/// evaluated at, and both frames are always available.
///
/// Vriddhi/kshaya flags are decoded with the rules the golden corpus pinned:
/// vriddhi = the same tithi at two consecutive udayas; kshaya = a tithi that
/// ends between two udayas without running at either (the udaya chain skips
/// an index). Both affected days are flagged, matching how publishers mark
/// the day after as well. Honesty fields per the public truth-data policy:
/// provenance names the engine and the ayanamsa profile; the evidence tier
/// states that every value is runtime-computed and corpus-calibrated.

/// Reference moment at which a displayed element is evaluated.
enum ReferenceMoment { udaya, madhyahna }

/// One limb element running at a reference moment.
class PanchangElement {
  /// 'tithi', 'nakshatra', 'yoga' or 'karana'.
  final String limb;

  /// Sector index: tithi 0..29, nakshatra/yoga 0..26, karana 0..59.
  final int index;

  /// Canonical English name (exact fixture spellings).
  final String name;

  /// Reference moment this element was evaluated at.
  final ReferenceMoment referenceMoment;

  /// NPT wall clock (UTC fields) when the element began.
  final DateTime beginsAtNpt;

  /// NPT wall clock (UTC fields) when the element ends.
  final DateTime endsAtNpt;

  const PanchangElement({
    required this.limb,
    required this.index,
    required this.name,
    required this.referenceMoment,
    required this.beginsAtNpt,
    required this.endsAtNpt,
  });
}

/// The full panchang for one civil (AD) date in Nepal, NPT throughout.
class PanchangDay {
  /// The civil date of the NPT day (UTC fields; no offset applied).
  final DateTime dateNpt;

  /// Sunrise, NPT wall clock (Kathmandu anchor 27.7172 N / 85.324 E).
  final DateTime sunriseNpt;

  /// Tithi running at sunrise (udaya) - the Hamro Patro display convention.
  final PanchangElement tithiAtUdaya;

  /// Nakshatra running at sunrise (udaya).
  final PanchangElement nakshatraAtUdaya;

  /// Yoga running at sunrise (udaya).
  final PanchangElement yogaAtUdaya;

  /// Karana running at sunrise (udaya) - the Hamro Patro convention.
  final PanchangElement karanaAtUdaya;

  /// Tithi running at local noon (madhyahna) - BhaktiBharat convention.
  final PanchangElement tithiAtNoon;

  /// Nakshatra running at local noon (madhyahna).
  final PanchangElement nakshatraAtNoon;

  /// Yoga running at local noon; the BhaktiBharat yoga headline is the
  /// midnight element - the noon value is provided, midnight is not.
  final PanchangElement yogaAtNoon;

  /// True when the same tithi runs at two consecutive udayas (vriddhi).
  final bool tithiVriddhi;

  /// True when a tithi ends between two udayas without running at either
  /// (kshaya) - fires on both affected days.
  final bool tithiKshaya;

  /// True when a tithi ends within half an hour of this day's sunrise or
  /// the next day's sunrise: the day-label is convention-sensitive.
  final bool tithiBorderline;

  /// Engine and ayanamsa profile description for this value set.
  final String provenance;

  /// Evidence statement for every value in this day block.
  final String evidenceTier;

  const PanchangDay({
    required this.dateNpt,
    required this.sunriseNpt,
    required this.tithiAtUdaya,
    required this.nakshatraAtUdaya,
    required this.yogaAtUdaya,
    required this.karanaAtUdaya,
    required this.tithiAtNoon,
    required this.nakshatraAtNoon,
    required this.yogaAtNoon,
    required this.tithiVriddhi,
    required this.tithiKshaya,
    required this.tithiBorderline,
    required this.provenance,
    required this.evidenceTier,
  });
}

/// Computes the panchang for the civil date [year]-[month]-[day] (an NPT day),
/// defaulting to the BhaktiBharat ayanamsa profile (the corpus anchor with
/// the tightest calibration bands). Pass [sourceDelta] to render another
/// publisher's convention, e.g. [ayanamsaDeltaHamroPatro].
PanchangDay panchangFor({
  required int year,
  required int month,
  required int day,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  final dateNpt = DateTime.utc(year, month, day);

  // Sunrises: this day, the previous day and the next day (for flags).
  final sunriseJd = sunriseJdUt(year: year, month: month, day: day);
  final prevCivil = dateNpt.subtract(const Duration(days: 1));
  final nextCivil = dateNpt.add(const Duration(days: 1));
  final prevSunriseJdTt = jdTtFromJdUt(sunriseJdUt(
      year: prevCivil.year, month: prevCivil.month, day: prevCivil.day));
  final nextSunriseJdTt = jdTtFromJdUt(sunriseJdUt(
      year: nextCivil.year, month: nextCivil.month, day: nextCivil.day));
  final sunriseNpt = _nptWall(sunriseJd);

  // Reference instants (TT): udaya = this day's sunrise; noon = 12:00 NPT.
  final udayaJdTt = jdTtFromJdUt(sunriseJd);
  final noonJdTt = jdTtFromJdUt(jdFromDateTimeUtc(
      DateTime.utc(year, month, day, 12)
          .subtract(const Duration(milliseconds: nptOffsetMs))));

  PanchangElement at(String limb, double jdTt, ReferenceMoment ref) {
    final index = limbIndex(limb, jdTt, sourceDelta);
    final end = _nptWall(nextLimbBoundaryJdTt(limb, jdTt, sourceDelta));
    final begin = _nptWall(_previousLimbBoundaryJdTt(limb, jdTt, sourceDelta));
    return PanchangElement(
      limb: limb,
      index: index,
      name: limbName(limb, index),
      referenceMoment: ref,
      beginsAtNpt: begin,
      endsAtNpt: end,
    );
  }

  final tithi = at('tithi', udayaJdTt, ReferenceMoment.udaya);
  final nakshatra = at('nakshatra', udayaJdTt, ReferenceMoment.udaya);
  final yoga = at('yoga', udayaJdTt, ReferenceMoment.udaya);
  final karana = at('karana', udayaJdTt, ReferenceMoment.udaya);

  // Udaya-chain flags (tithi does not depend on the ayanamsa profile).
  final cur = limbIndex('tithi', udayaJdTt, sourceDelta);
  final prev = limbIndex('tithi', prevSunriseJdTt, sourceDelta);
  final next = limbIndex('tithi', nextSunriseJdTt, sourceDelta);
  final vriddhi = cur == next || cur == prev;
  final kshaya =
      (next - cur) % 30 == 2 || (cur - prev) % 30 == 2;

  // Borderline: a tithi boundary lands within half an hour of an udaya.
  final halfHour = const Duration(minutes: 30);
  final nextSunriseNpt = _nptWall(jdUtFromJdTt(nextSunriseJdTt));
  final borderline = tithi.endsAtNpt.difference(sunriseNpt).abs() < halfHour ||
      tithi.endsAtNpt.difference(nextSunriseNpt).abs() < halfHour;

  return PanchangDay(
    dateNpt: dateNpt,
    sunriseNpt: sunriseNpt,
    tithiAtUdaya: tithi,
    nakshatraAtUdaya: nakshatra,
    yogaAtUdaya: yoga,
    karanaAtUdaya: karana,
    tithiAtNoon: at('tithi', noonJdTt, ReferenceMoment.madhyahna),
    nakshatraAtNoon: at('nakshatra', noonJdTt, ReferenceMoment.madhyahna),
    yogaAtNoon: at('yoga', noonJdTt, ReferenceMoment.madhyahna),
    tithiVriddhi: vriddhi,
    tithiKshaya: kshaya,
    tithiBorderline: borderline,
    provenance: 'nMiti nepali_panchang engine: full 60-term Meeus Ch.47 moon, '
        'VSOP87D sun, Espenak-Meeus Delta T; ayanamsa profile delta '
        '${sourceDelta.toStringAsFixed(4)} deg (BhaktiBharat-anchored fit).',
    evidenceTier: 'runtime-computed; calibrated against the locked '
        'BhaktiBharat/Hamro Patro golden corpora (226 boundary receipts, '
        'see docs/methodology and the accuracy receipts)',
  );
}

/// Canonical name of [limb] at sector [index].
String limbName(String limb, int index) {
  switch (limb) {
    case 'tithi':
      return tithiName(index);
    case 'nakshatra':
      return nakshatraNames[index];
    case 'yoga':
      return yogaNames[index];
    case 'karana':
      return karanaName(index + 1);
    default:
      throw ArgumentError('unknown limb: $limb');
  }
}

/// NPT wall clock (UTC fields) for a TT Julian Day.
DateTime _nptWall(double jdTt) {
  return dateTimeUtcFromJd(jdUtFromJdTt(jdTt))
      .add(const Duration(milliseconds: nptOffsetMs));
}

/// TT Julian Day of the previous sector boundary of [limb] strictly before
/// [jdTtStart] (the begin instant of the sector running at [jdTtStart]).
double _previousLimbBoundaryJdTt(
    String limb, double jdTtStart, double sourceDelta) {
  final target = limbIndex(limb, jdTtStart, sourceDelta);
  var hi = jdTtStart;
  var lo = jdTtStart - 0.25;
  while (limbIndex(limb, lo, sourceDelta) == target) {
    hi = lo;
    lo -= 0.25;
    if (jdTtStart - lo > 4.0) {
      throw StateError(
          'boundary solver failed to bracket the previous $limb crossing');
    }
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (limbIndex(limb, mid, sourceDelta) == target) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}
