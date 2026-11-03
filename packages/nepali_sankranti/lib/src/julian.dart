/// Julian Day <-> UTC conversion helpers.
///
/// JD 2440587.5 is 1970-01-01T00:00:00Z, so conversions are exact for
/// any instant representable by [DateTime].

const double _unixEpochJd = 2440587.5;

/// Julian Day (with fraction) of a UTC instant.
double julianDay(DateTime utc) =>
    _unixEpochJd + utc.millisecondsSinceEpoch / 86400000.0;

/// UTC instant of a Julian Day.
DateTime utcFromJulianDay(double jd) => DateTime.fromMillisecondsSinceEpoch(
    ((jd - _unixEpochJd) * 86400000.0).round(),
    isUtc: true);

/// Julian centuries since J2000.0 (JD 2451545.0).
double julianCenturies(double jd) => (jd - 2451545.0) / 36525.0;
