import 'civil_time.dart';
import 'julian_day.dart';
import 'moonrise.dart';

/// Moonset solver (HYA-441): the first setting of the Moon within an
/// NPT civil day - the setting twin of the moonrise solver (HYA-417).
///
/// Set condition - the same Meeus, Astronomical Algorithms (2nd ed.),
/// eq. 15.1 target as moonrise: the geocentric altitude of the Moon's
/// center reaches h0 = 0.7276 * pi - 34', the standard upper-limb
/// set with the 34' refraction folded into the target (pi = the
/// equatorial horizontal parallax, live per sample). The Moon is the
/// same 60-term Meeus Ch.47 series every other lunar layer uses, so
/// moonset, moonrise and every tithi boundary share one ephemeris.
///
/// The scan is the moonrise scan run on the DOWNWARD crossing:
/// 30-minute steps over the civil day [00:00, 24:00) NPT, then 40
/// bisection iterations. A Moon already below the horizon at 00:00 is
/// not this day's moonset - the next setting (after a mid-day rising)
/// is, and the first-downward-crossing scan picks that up naturally.
/// A set exactly on the 24:00 sample belongs to the day (the crossing
/// prevMargin > 0 && m <= 0 fires on the closing sample); a set
/// exactly at 00:00 belongs to the previous day's scan.
///
/// Served edge: the returned instant is the bisection upper bound,
/// the same convention as moonrise (within ~1e-14 d of the true
/// crossing, on the set side).
///
/// Receipts: the Chandra Darshan corpus
/// (test/fixtures/chandra_darshan_receipts_2026.json) gates the
/// moonset of every Kathmandu darshan evening - the saait END - to
/// 2 min against nepaljyotish's published windows, and the Delhi
/// moonsets to 8 min against drikpanchang (their set runs a constant
/// ~3-4 min early; both are publisher ephemeris conventions, the
/// same class as the documented sunrise display offsets).

/// Moonset of the NPT civil day [year]-[month]-[day] as a UT Julian
/// Day, or null when the Moon does not set inside the civil day
/// (roughly once a lunar month the set falls into a neighbouring
/// day - the mirror of the moonrise gap).
double? moonsetJdUt({
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  // 00:00 NPT = 18:15 UT of the previous UT day, i.e.
  // jdFromCivil(y, m, d) - 5.75/24 (NPT = UT + 5:45) - the same
  // anchor the moonrise solver uses.
  final dayStartUt =
      julianDayFromCivil(year, month, day.toDouble()) - 5.75 / 24.0;
  const step = 1.0 / 48.0; // 30 minutes
  double margin(double jdUt) =>
      moonGeocentricAltitudeDeg(
              jdUt: jdUt,
              latitudeDeg: latitudeDeg,
              longitudeDeg: longitudeDeg) -
          moonRiseTargetAltitudeDeg(jdUt);
  var prevJd = dayStartUt;
  var prevMargin = margin(dayStartUt);
  for (var i = 1; i <= 48; i++) {
    final jd = dayStartUt + i * step;
    final m = margin(jd);
    // Downward crossing: above the target at the previous sample, at
    // or below at this one (moonrise gates on prevMargin < 0 &&
    // m >= 0 - the mirror).
    if (prevMargin > 0.0 && m <= 0.0) {
      var lo = prevJd;
      var hi = jd;
      for (var k = 0; k < 40; k++) {
        final mid = (lo + hi) / 2;
        if (margin(mid) > 0.0) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return hi;
    }
    prevJd = jd;
    prevMargin = m;
  }
  return null;
}

/// Moonset of the NPT civil day as a wall-clock [DateTime] holding
/// NPT fields (the engine's civil convention - see parseWallClock),
/// or null when the Moon does not set that day.
DateTime? moonsetNpt({
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final jdUt = moonsetJdUt(
      year: year,
      month: month,
      day: day,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg);
  if (jdUt == null) {
    return null;
  }
  return dateTimeUtcFromJd(jdUt)
      .add(const Duration(milliseconds: nptOffsetMs));
}
