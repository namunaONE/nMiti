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
