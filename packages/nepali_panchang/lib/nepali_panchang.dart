/// Nepal-first lunar panchang engine for the nMiti Commons (R6a-1, HYA-403).
///
/// The engine computes tithi, nakshatra, yoga, karana and sunrise moments at
/// runtime from celestial mechanics - full 60-term Meeus Ch.47 moon series,
/// Ch.25 solar theory, a Delta-T table and per-source ayanamsa profiles - with no
/// precomputed data files, covering the entire BS 1975-2100+ range.
///
/// This scaffold wires the package into the pub workspace and CI. The
/// astronomy core (step 2), limbs and solvers (step 3) and ayanamsa profiles
/// (step 4) land in later steps; every step ships green before the next.
library;

/// Julian Day of a Gregorian calendar date (Meeus, Astronomical Algorithms,
/// chapter 7).
///
/// [day] may be fractional: 1.5 is the 1st at 12:00 TT, 4.81 is the 4th at
/// 19:26 TT. Valid for Gregorian dates only (nMiti's range is AD 1918-2044);
/// Julian-calendar dates before 1582-10-15 are out of scope. No Delta-T is
/// applied here: this is the raw civil-date to JD mapping the engine core
/// builds on.
double julianDayFromCivil(int year, int month, double day) {
  var y = year;
  var m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = y ~/ 100;
  final b = 2 - a + a ~/ 4;
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      day +
      b -
      1524.5;
}
