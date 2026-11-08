import 'civil_time.dart';
import 'julian_day.dart';
import 'limbs.dart';
import 'masa.dart';
import 'moonrise.dart';
import 'moonset.dart';
import 'sunset.dart';

/// Chandra Darshan - R10.1 ritual layer 3, HYA-441.
///
/// Chandra Darshan is the first sighting of the young crescent Moon
/// after a new moon. The sighting window - the saait - runs from
/// sunset to moonset of the darshan evening. nepaljyotish (the Nepal
/// corpus) publishes exactly that pair for Kathmandu; drikpanchang
/// prints the same convention for New Delhi ('the moon ... sets about
/// one hour after sunset and can be sighted only after sunset' - rule
/// prose, not an algorithm).
///
/// Day rule (corpus-fitted; engine-equivalent precision run of
/// 2026-11-08 against 13 nepaljyotish windows, 6 BhaktiBharat
/// day-calls and 25 drikpanchang rows): the darshan day is the FIRST
/// civil evening at or after the local conjunction whose
/// moonset-minus-sunset lag reaches
/// [chandraDarshanMinMoonsetLagMinutes] = 39.0 minutes. The corpus
/// pins only a band, (37.80, 40.33] minutes: the binding rejected row
/// is New Delhi Jun 15 2026 (lag 37.80 - drikpanchang prints Jun 16),
/// with Kathmandu Jun 15 at 35.78; the binding accepted row is
/// Kathmandu Feb 7 2027 (lag 40.33 - nepaljyotish prints it). 39.0
/// sits at the band midpoint, 1.2 / 1.33 min inside the two binding
/// rows; every threshold inside the band reproduces every corpus
/// day-call identically.
///
/// Classical equivalent: an accepted evening carries the Moon at or
/// above ~8.4 deg geocentric altitude at sunset, a rejected one at or
/// below ~7.4 deg - the classical ~8 deg darshan-amsha lies inside
/// the empty band. The corpus cannot separate the two formulations:
/// the linger (39 min) is the served rule, the altitude is carried as
/// an honesty field.
///
/// The rule is the LINGER, not a tithi. A conjunction-day darshan is
/// real - May 17 2026 (Moon ~17 h old at saait begins, Shukla
/// Pratipada, lag 54 min) is printed by nepaljyotish, drikpanchang
/// ('Adhika Chandra Darshana') and BhaktiBharat alike - while
/// 'Dwitiya at sunset' is REFUTED: Nov 10 2026 is Shukla Dwitiya at
/// sunset (elongation 13.4 deg) and rejected by every source (lag
/// 26.5 min), while Feb 7 2027 is Pratipada at sunset and accepted.
/// Pure moonset-after-18:00, elongation, age or altitude thresholds
/// alone all fail corpus rows.
///
/// drikpanchang's Delhi corpus fits NO monotone rule (at least one
/// miss in every brute-forced family): their Feb 8 2027 row (engine:
/// Feb 7; Delhi Feb 7 lag 41.8) and their Oct 1 2027 row (engine:
/// Oct 2; Oct 1 lag 32.6) collide with the engine and are recorded as
/// agree:false in the fixture, decoded in
/// [chandraDarshanConventions]'drik_divergence', never absorbed -
/// 23 of their 25 rows agree. Hamro Patro publishes no Chandra
/// Darshan table - recorded absence, not negative evidence.

/// Minimum moonset-minus-sunset lag, minutes, for a civil evening to
/// be the darshan evening - the served day-rule constant. Corpus
/// band (37.80, 40.33] min; see the library doc comment.
const double chandraDarshanMinMoonsetLagMinutes = 39.0;

/// The classical darshan-amsha reference altitude, degrees: the
/// crescent becomes sightable around 8 deg of elongation from the
/// sun. Carried as the honesty field behind the served linger rule
/// (the corpus cannot separate the two formulations).
const double chandraDarshanAltitudeReferenceDeg = 8.0;

/// The named Chandra Darshan conventions, exposed for the site/API
/// display layer (HYA-441 honesty fields). Keys are stable
/// identifiers, never prose layout.
const Map<String, String> chandraDarshanConventions = {
  'identity':
      "Chandra Darshan = the first sighting of the young crescent Moon after a new moon; the sighting window (saait) runs from sunset to moonset of the darshan evening; one darshan per lunation, 12-13 per year.",
  'saait_window':
      "Saait = [sunset, moonset] of the darshan evening, local wall clock. nepaljyotish publishes exactly this pair for Kathmandu (13 windows, Apr 2026 - Apr 2027); drikpanchang prints the same convention for New Delhi.",
  'day_rule':
      "The darshan day is the first civil evening at or after the local conjunction whose moonset-minus-sunset lag reaches 39.0 minutes (corpus band 37.80-40.33: binding rejected New Delhi Jun 15 2026 at 37.80, binding accepted Kathmandu Feb 7 2027 at 40.33).",
  'linger_altitude_equivalence':
      "Equivalent within the corpus: accepted evenings carry the Moon at >= 8.4 deg geocentric altitude at sunset, rejected evenings <= 7.4 deg - the classical ~8 deg darshan-amsha. The corpus cannot separate the two; the 39-minute linger is the served rule, the altitude an honesty field.",
  'conj_day':
      "A conjunction-day darshan is real: May 17 2026 (Moon ~17 h old at saait begins, Shukla Pratipada, lag 54 min) is printed by nepaljyotish, drikpanchang (as 'Adhika Chandra Darshana') and BhaktiBharat - the rule is the linger, not the tithi.",
  'tithi_refuted':
      "'Dwitiya at sunset' is refuted: Nov 10 2026 is Shukla Dwitiya at sunset (elongation 13.4 deg) and is rejected by every source (lag 26.5 min); Feb 7 2027 is Pratipada at sunset and accepted (lag 40.3 min).",
  'drik_divergence':
      "drikpanchang's Delhi corpus fits no monotone rule (at least one miss in every brute-forced family). Two documented collisions with the engine: 2027-02-08 (engine: Feb 7) and 2027-10-01 (engine: Oct 2); recorded agree:false in the fixture, never absorbed; 23/25 rows agree.",
  'young_moon_note':
      "The saait values are local wall clocks; the publishers' tithi labels (Shukla Pratipada etc.) are their lunar-day labels, never the rule input.",
  'hamro_patro_absence':
      "Hamro Patro publishes no Chandra Darshan table - recorded absence, not negative evidence.",
  'location':
      "Computed for the given latitude/longitude (default: the nMiti Kathmandu anchor 27.7172 N / 85.324 E); the day rule anchors on the NPT civil day everywhere (IST = NPT minus 15 min).",
};

/// One Chandra Darshan: the saait window of the first sightable
/// crescent evening of a lunation, with the day-rule evidence
/// resolved into fields.
class ChandraDarshanWindow {
  /// The NPT civil date of the darshan evening (the date label the
  /// publishers print).
  final DateTime darshanDayNpt;

  /// The new-moon instant that opens this lunation, NPT wall clock
  /// (UTC fields) - the engine's own wrap-safe tithi-sector solver
  /// ([nextNewMoonJdTt]).
  final DateTime newMoonNpt;

  /// Saait begins = sunset of the darshan evening, NPT wall clock
  /// (UTC fields).
  final DateTime saaitBeginsNpt;

  /// Saait ends = moonset of the darshan evening, NPT wall clock
  /// (UTC fields).
  final DateTime saaitEndsNpt;

  /// Civil days from the conjunction's day to the darshan day (0 =
  /// a conjunction-day darshan; the corpus holds 0, 1 and 2).
  final int dayIndexAfterNewMoon;

  /// Age of the Moon at saait begins, hours from the conjunction
  /// instant.
  final double moonAgeHoursAtSaaitBegins;

  /// Elongation moon-minus-sun at saait begins, degrees [0, 360).
  final double elongationDegAtSaaitBegins;

  /// Geocentric altitude of the Moon's center at saait begins,
  /// degrees - the honesty field behind the ~8 deg darshan-amsha.
  final double moonAltitudeDegAtSaaitBegins;

  /// Moonset-minus-sunset lag of the darshan evening, minutes (>=
  /// [chandraDarshanMinMoonsetLagMinutes]).
  final double moonsetLagMinutes;

  /// Tithi at saait begins - the publishers' day label input, never
  /// the rule.
  final String tithiAtSaaitBegins;

  /// Engine and convention provenance (public truth-data policy).
  final String provenance;

  /// Evidence statement for every value in this window.
  final String evidenceTier;

  /// Wall-clock length of the saait (38-180 min across the corpus
  /// year).
  Duration get saaitDurationNpt => saaitEndsNpt.difference(saaitBeginsNpt);

  const ChandraDarshanWindow({
    required this.darshanDayNpt,
    required this.newMoonNpt,
    required this.saaitBeginsNpt,
    required this.saaitEndsNpt,
    required this.dayIndexAfterNewMoon,
    required this.moonAgeHoursAtSaaitBegins,
    required this.elongationDegAtSaaitBegins,
    required this.moonAltitudeDegAtSaaitBegins,
    required this.moonsetLagMinutes,
    required this.tithiAtSaaitBegins,
    required this.provenance,
    required this.evidenceTier,
  });
}

/// The Chandra Darshan of one lunation, given its new-moon instant
/// [newMoonNpt] (NPT wall clock, UTC fields), or null when no evening
/// of the scan qualifies (does not occur in the corpus; kept honest
/// rather than throwing).
///
/// The scan walks the civil days k = 0..4 from the conjunction's NPT
/// civil day. A candidate evening qualifies when the Moon sets inside
/// the civil day, sets strictly after the sun, and the
/// moonset-minus-sunset lag reaches
/// [chandraDarshanMinMoonsetLagMinutes]; the first qualifying evening
/// wins.
ChandraDarshanWindow? chandraDarshanForNewMoon({
  required DateTime newMoonNpt,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final nmJdTt = _jdTtFromNptWall(newMoonNpt);
  final conjDay =
      DateTime.utc(newMoonNpt.year, newMoonNpt.month, newMoonNpt.day);
  for (var k = 0; k <= 4; k++) {
    final day = conjDay.add(Duration(days: k));
    final ss = sunsetJdUt(
        year: day.year,
        month: day.month,
        day: day.day,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg);
    final ms = moonsetJdUt(
        year: day.year,
        month: day.month,
        day: day.day,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg);
    if (ms == null || ms <= ss) {
      // The Moon is not in the evening sky after sunset - the
      // conjunction-day case (the waning crescent sets before the
      // sun) or a day without a set.
      continue;
    }
    final lagMin = (ms - ss) * 1440.0;
    if (lagMin < chandraDarshanMinMoonsetLagMinutes) {
      continue;
    }
    final ssJdTt = jdTtFromJdUt(ss);
    return ChandraDarshanWindow(
      darshanDayNpt: DateTime.utc(day.year, day.month, day.day),
      newMoonNpt: newMoonNpt,
      saaitBeginsNpt: _nptWallFromJdUt(ss),
      saaitEndsNpt: _nptWallFromJdUt(ms),
      dayIndexAfterNewMoon: k,
      moonAgeHoursAtSaaitBegins: (ssJdTt - nmJdTt) * 24.0,
      elongationDegAtSaaitBegins: elongationDeg(ssJdTt),
      moonAltitudeDegAtSaaitBegins: moonGeocentricAltitudeDeg(
          jdUt: ss, latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg),
      moonsetLagMinutes: lagMin,
      tithiAtSaaitBegins: tithiName(limbIndex('tithi', ssJdTt, 0.0)),
      provenance: 'nMiti nepali_panchang chandra_darshan layer: saait = '
          'the engine sunset-moonset pair of the darshan evening (USNO '
          'solar equations + the Meeus Ch.47 moon); day rule: the first '
          'civil evening at/after the conjunction with a moonset-sunset '
          'lag of ${chandraDarshanMinMoonsetLagMinutes.toStringAsFixed(1)} '
          'min or more (corpus band 37.80-40.33 min, nepaljyotish / '
          'drikpanchang / BhaktiBharat corpus of 2026-11-08).',
      evidenceTier: 'runtime-computed; anchored to the 2026-11-08 receipt '
          'corpus - nepaljyotish 13 Kathmandu windows (2-min band), '
          'BhaktiBharat day-calls, drikpanchang Delhi rows (23/25 agree, '
          '2 documented divergences); CI gate '
          'test/chandra_darshan_test.dart.',
    );
  }
  return null;
}

/// The Chandra Darshan whose darshan evening is the NPT civil date
/// [year]-[month]-[day], or null when that date is not a darshan
/// evening - the date-label query behind the published tables.
///
/// The only conjunction whose darshan can fall on the asked date is
/// the last new moon at or before the end of that civil day (the
/// darshan day is at most 4 civil days after the conjunction day, and
/// no two new moons fall within 27 days of each other).
ChandraDarshanWindow? chandraDarshanOn({
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final limitTt = _jdTtOfNptDayEnd(DateTime.utc(year, month, day));
  final nm = _lastNewMoonJdTt(limitTt);
  final w = chandraDarshanForNewMoon(
      newMoonNpt: _nptWall(nm),
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg);
  if (w == null) {
    return null;
  }
  if (w.darshanDayNpt.year == year &&
      w.darshanDayNpt.month == month &&
      w.darshanDayNpt.day == day) {
    return w;
  }
  return null;
}

/// The first Chandra Darshan whose darshan day falls at or after
/// [afterNpt] (NPT wall clock, UTC fields) - the "next darshan"
/// query. A darshan already past at [afterNpt] is skipped: the
/// function answers "next", not "current".
ChandraDarshanWindow nextChandraDarshanAfter({
  required DateTime afterNpt,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final afterDay =
      DateTime.utc(afterNpt.year, afterNpt.month, afterNpt.day);
  // The lunation of afterDay may still hold its darshan ahead of
  // afterDay; start at its own new moon and advance in the JD domain
  // (the Bhadra-module hang lesson: never through the
  // millisecond-quantised wall clock).
  var nmJdTt = _lastNewMoonJdTt(_jdTtOfNptDayEnd(afterDay));
  while (true) {
    final w = chandraDarshanForNewMoon(
        newMoonNpt: _nptWall(nmJdTt),
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg);
    if (w != null && !w.darshanDayNpt.isBefore(afterDay)) {
      return w;
    }
    nmJdTt = nextNewMoonJdTt(nmJdTt);
  }
}

/// All Chandra Darshans whose darshan day falls in [start, end) -
/// NPT wall-clock DateTimes (UTC fields), chronological order. A
/// scan spanning N lunations yields exactly N windows.
List<ChandraDarshanWindow> chandraDarshanWindows({
  required DateTime start,
  required DateTime end,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  if (!start.isBefore(end)) {
    throw ArgumentError('start must be before end');
  }
  final startDay = DateTime.utc(start.year, start.month, start.day);
  final endDay = DateTime.utc(end.year, end.month, end.day);
  final out = <ChandraDarshanWindow>[];
  var nmJdTt = _lastNewMoonJdTt(_jdTtOfNptDayEnd(startDay));
  while (true) {
    final nmNpt = _nptWall(nmJdTt);
    final conjDay = DateTime.utc(nmNpt.year, nmNpt.month, nmNpt.day);
    if (!conjDay.isBefore(endDay)) {
      break;
    }
    final w = chandraDarshanForNewMoon(
        newMoonNpt: nmNpt,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg);
    if (w != null &&
        !w.darshanDayNpt.isBefore(startDay) &&
        w.darshanDayNpt.isBefore(endDay)) {
      out.add(w);
    }
    nmJdTt = nextNewMoonJdTt(nmJdTt);
  }
  return out;
}

/// TT Julian Day of the last new moon at or before [limitJdTt]. A
/// new moon occurs every 29.27-29.83 days, so the 35-day back-scan
/// always brackets one; the walk then steps forward until the next
/// new moon passes the limit.
double _lastNewMoonJdTt(double limitJdTt) {
  var t = nextNewMoonJdTt(limitJdTt - 35.0);
  while (true) {
    final next = nextNewMoonJdTt(t);
    if (next > limitJdTt) {
      return t;
    }
    t = next;
  }
}

/// NPT wall clock (UTC fields) for a UT Julian Day.
DateTime _nptWallFromJdUt(double jdUt) {
  return dateTimeUtcFromJd(jdUt)
      .add(const Duration(milliseconds: nptOffsetMs));
}

/// NPT wall clock (UTC fields) for a TT Julian Day - the same mapping
/// the masa and Bhadra modules use.
DateTime _nptWall(double jdTt) {
  return dateTimeUtcFromJd(jdUtFromJdTt(jdTt))
      .add(const Duration(milliseconds: nptOffsetMs));
}

/// TT Julian Day of an NPT wall-clock instant (UTC fields).
double _jdTtFromNptWall(DateTime nptWall) {
  return jdTtFromJdUt(jdFromDateTimeUtc(
      nptWall.subtract(const Duration(milliseconds: nptOffsetMs))));
}

/// TT Julian Day of the end (24:00 NPT) of the civil date [day]
/// (UTC fields - any time-of-day on that date maps to the same end).
double _jdTtOfNptDayEnd(DateTime day) {
  final next = day.add(const Duration(days: 1));
  return jdTtFromJdUt(julianDayFromCivil(
          next.year, next.month, next.day.toDouble()) -
      5.75 / 24.0);
}
