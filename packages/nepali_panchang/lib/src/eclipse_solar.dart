import 'dart:math' as math;

import 'civil_time.dart';
import 'eclipse_lunar.dart';
import 'julian_day.dart';
import 'moon.dart';
import 'sun.dart';

const double _radPerDeg = math.pi / 180;
const double _degPerRad = 180 / math.pi;

/// Topocentric solar eclipse solver - L6 grahan layer, step 2 (HYA-421).
///
/// Local circumstances by topocentric separation: at each instant the
/// geocentric equatorial positions of Sun and Moon (the same Meeus Ch.47
/// moon and VSOP87D sun every other limb shares, mean equinox of date,
/// nutation omitted for BOTH bodies so the rotation the frames share
/// cancels) are made topocentric by subtracting the observer's ECEF
/// vector on the reference ellipsoid (a = [earthRadiusKm], flattening
/// 1/298.26, sea level), rotated by Greenwich mean sidereal time plus
/// longitude. First and fourth contact solve sigma = S + M, the central
/// line solves sigma = |S - M|, with the semidiameters taken from the
/// topocentric distances. Magnitude is the covered fraction of the
/// solar diameter, obscuration the covered fraction of the solar disc
/// area (exact circle-circle overlap).
///
/// [sunApparentLongitude] is deliberately NOT used: it adds nutation for
/// the Sun alone, which would break the frame cancellation against the
/// geometric moon. The separation frame uses the true longitude plus the
/// aberration term only.
///
/// Visibility finding (decoded from the 2026-2027 Kathmandu receipts,
/// never silently assumed): the Moon's penumbra reaches past the
/// terminator, so a location can sit geometrically inside it with the Sun
/// below the horizon. 12 Aug 2026 and 6 Feb 2027 are real penumbral
/// grazes at Kathmandu that timeanddate lists as 'Not Visible in
/// Kathmandu'. Visibility is therefore gated on the Sun's altitude at
/// the contacts and at greatest, and such events are returned with
/// [SolarEclipseVisibility.belowHorizon] rather than suppressed, so the
/// grahan module (step 4) can show them with a not-visible flag per the
/// display policy. A new moon whose penumbra never reaches the location
/// at all (17 Feb 2026 at Kathmandu) returns null.
///
/// The minimum of the topocentric separation is found by a coarse
/// 0.01-day grid over the +-0.35-day window around the new moon,
/// refined by golden section over the best cell: near the new moon the
/// lunar parallax wobble (up to about +-40 arcmin over 24 h) exceeds the
/// synodic slope, so the topocentric minimum is NOT unimodal - the
/// plain golden-section search of the lunar solver is not safe here,
/// and the 2027-08-02 Kathmandu greatest moves by over a minute between
/// the two methods (the grid version matches the receipts).
///
/// Receipts: test/fixtures/solar_kathmandu_receipts.json, parsed
/// 2026-11-05 from timeanddate, time.now and heliora, pins the
/// 2 Aug 2027 partial (the first solar eclipse visible from Kathmandu
/// in the engine's live era) and the two below-horizon grazes.

/// Mean radius of the Moon in km (the NASA/GSFC eclipse bulletins'
/// value).
const double moonRadiusKm = 1737.4;

/// Flattening of the reference ellipsoid (1/298.26, the ellipsoid behind
/// the NASA/GSFC fundamental-plane geometry).
const double _earthFlattening = 1.0 / 298.26;

/// Visibility of a solar eclipse at the location, from the Sun's
/// altitude at the contacts and at greatest eclipse.
enum SolarEclipseVisibility {
  /// The Sun is above the astronomical horizon throughout the eclipse.
  aboveHorizon,

  /// The Sun crosses the horizon during the eclipse (a sunrise or
  /// sunset eclipse).
  partiallyAboveHorizon,

  /// The penumbra reaches the location but the Sun is below the horizon
  /// throughout - a geometrically real graze nobody can see.
  belowHorizon,
}

/// Circumstances of one solar eclipse at one location; all instants are
/// UT Julian Days.
class SolarEclipseCircumstances {
  /// First and last contact of the Moon's limb with the Sun's limb
  /// (topocentric separation sigma = S + M); always present, otherwise
  /// there is no graze at all.
  final double jdUtPartialStart;
  final double jdUtPartialEnd;

  /// Instant of greatest eclipse (minimal topocentric separation).
  final double jdUtGreatest;

  /// Second and third contact - immersion into and emersion from the
  /// central phase, sigma = |S - M|; null when the location never sees
  /// the central (total or annular) phase.
  final double? jdUtCentralStart;
  final double? jdUtCentralEnd;

  /// True when the central line passes the location at greatest eclipse:
  /// the Sun's disc is then fully covered (total) or fully ringed
  /// (annular).
  final bool centralAtGreatest;

  /// Fraction of the solar diameter covered at greatest eclipse.
  final double magnitude;

  /// Fraction of the solar disc area covered at greatest eclipse
  /// (exact circle-circle overlap).
  final double obscuration;

  /// Sun altitude above the astronomical horizon at the contacts and at
  /// greatest eclipse; the visibility gate is built from these.
  final double sunAltitudeDegAtStart;
  final double sunAltitudeDegAtGreatest;
  final double sunAltitudeDegAtEnd;

  /// Visibility classification at the location.
  final SolarEclipseVisibility visibility;

  const SolarEclipseCircumstances({
    required this.jdUtPartialStart,
    required this.jdUtPartialEnd,
    required this.jdUtGreatest,
    required this.jdUtCentralStart,
    required this.jdUtCentralEnd,
    required this.centralAtGreatest,
    required this.magnitude,
    required this.obscuration,
    required this.sunAltitudeDegAtStart,
    required this.sunAltitudeDegAtGreatest,
    required this.sunAltitudeDegAtEnd,
    required this.visibility,
  });
}

/// Topocentric geometry at one UT instant.
class _LocalGeometry {
  final double separationDeg;
  final double sunSemidiameterDeg;
  final double moonSemidiameterDeg;
  final double sunAltitudeDeg;

  const _LocalGeometry({
    required this.separationDeg,
    required this.sunSemidiameterDeg,
    required this.moonSemidiameterDeg,
    required this.sunAltitudeDeg,
  });
}

/// Mean obliquity of the ecliptic, Meeus eq. 22.2 (degrees).
double _meanObliquityDeg(double jdUt) {
  final t = (jdUt - 2451545.0) / 36525.0;
  return 23.439291111 -
      0.013004167 * t -
      0.000000164 * t * t +
      0.000000504 * t * t * t;
}

/// Greenwich mean sidereal time, Meeus eq. 12.4 (degrees).
double _gmstDeg(double jdUt) {
  final t = (jdUt - 2451545.0) / 36525.0;
  return 280.46061837 +
      360.98564736629 * (jdUt - 2451545.0) +
      0.000387933 * t * t -
      t * t * t / 38710000;
}

double _norm360(double deg) => deg % 360.0;

/// Sun longitude in the separation frame: the true (VSOP87D) longitude
/// plus the aberration term only. Nutation is omitted for both bodies
/// (see the library doc); [sunApparentLongitude] is not used.
double _sunLongitudeForSeparation(double jdTt) {
  return _norm360(sunTrueLongitude(jdTt) -
      20.4898 / 3600.0 / sunEarthDistanceAu(jdTt));
}

/// Observer ECEF position in km on the reference ellipsoid at sea
/// level, rotated into the equatorial frame by GMST + longitude.
List<double> _observerEcefKm(double jdUt, double latitudeDeg, double longitudeDeg) {
  final e2 = _earthFlattening * (2.0 - _earthFlattening);
  final phi = latitudeDeg * _radPerDeg;
  final n = earthRadiusKm / math.sqrt(1.0 - e2 * math.sin(phi) * math.sin(phi));
  final xy = n * math.cos(phi);
  final z = n * (1.0 - e2) * math.sin(phi);
  final theta = (_gmstDeg(jdUt) + longitudeDeg) * _radPerDeg;
  return [xy * math.cos(theta), xy * math.sin(theta), z];
}

double _lengthKm(List<double> v) =>
    math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);

/// Topocentric Sun-Moon geometry at [jdUt] for the observer.
_LocalGeometry _geometryAt(double jdUt, double latitudeDeg, double longitudeDeg) {
  final jdTt = jdTtFromJdUt(jdUt);
  final moon = moonPosition(jdTt);
  final eps = _meanObliquityDeg(jdUt) * _radPerDeg;
  final sunLon = _sunLongitudeForSeparation(jdTt) * _radPerDeg;
  final sunDistKm = sunEarthDistanceAu(jdTt) * auKm;
  final cosEps = math.cos(eps);
  final sinEps = math.sin(eps);
  // Equatorial rectangular coordinates, mean equinox of date: the Sun on
  // the ecliptic, the Moon with its latitude (Meeus eqs. 13.3/13.4).
  final sxg = sunDistKm * math.cos(sunLon);
  final syg = sunDistKm * math.sin(sunLon);
  final mb = moon.latitudeDeg * _radPerDeg;
  final ml = moon.longitudeDeg * _radPerDeg;
  final mxg = moon.distanceKm * math.cos(mb) * math.cos(ml);
  final myg = moon.distanceKm * math.cos(mb) * math.sin(ml);
  final mzg = moon.distanceKm * math.sin(mb);
  final sunEq = [sxg, syg * cosEps, syg * sinEps];
  final moonEq = [
    mxg,
    myg * cosEps - mzg * sinEps,
    myg * sinEps + mzg * cosEps,
  ];
  final o = _observerEcefKm(jdUt, latitudeDeg, longitudeDeg);
  final s = [sunEq[0] - o[0], sunEq[1] - o[1], sunEq[2] - o[2]];
  final m = [moonEq[0] - o[0], moonEq[1] - o[1], moonEq[2] - o[2]];
  final ds = _lengthKm(s);
  final dm = _lengthKm(m);
  final cosSep =
      (s[0] * m[0] + s[1] * m[1] + s[2] * m[2]) / (ds * dm);
  final sep =
      math.acos(math.max(-1.0, math.min(1.0, cosSep))) * _degPerRad;
  final sunSd = math.asin(sunRadiusKm / ds) * _degPerRad;
  final moonSd = math.asin(moonRadiusKm / dm) * _degPerRad;
  // Sun altitude from the same topocentric vector (the visibility gate).
  final raS = math.atan2(s[1], s[0]) * _degPerRad;
  final decS = math.asin(s[2] / ds) * _degPerRad;
  final h = (_gmstDeg(jdUt) + longitudeDeg - raS) * _radPerDeg;
  final phi = latitudeDeg * _radPerDeg;
  final dec = decS * _radPerDeg;
  final alt = math.asin(math.sin(phi) * math.sin(dec) +
          math.cos(phi) * math.cos(dec) * math.cos(h)) *
      _degPerRad;
  return _LocalGeometry(
      separationDeg: sep,
      sunSemidiameterDeg: sunSd,
      moonSemidiameterDeg: moonSd,
      sunAltitudeDeg: alt);
}

double _elongation(double jdTt) {
  return (moonPosition(jdTt).longitudeDeg - sunTrueLongitude(jdTt)) % 360.0;
}

/// Elongation half: 0 while waxing (elongation 0..180 deg), 1 while waning
/// (180..360 deg). Computing sectors from the normalized elongation makes
/// the phase solver wrap-safe.
int _elongationSector(double jdTt) => _elongation(jdTt) < 180.0 ? 0 : 1;

/// Instant the elongation first leaves sector [from] after [jdTtStart].
double _nextSectorFlip(double jdTtStart, int from) {
  var lo = jdTtStart;
  var hi = jdTtStart + 0.25;
  while (_elongationSector(hi) == from) {
    lo = hi;
    hi += 0.25;
    if (hi - jdTtStart > 32.0) {
      throw StateError('elongation sector solver failed to wrap');
    }
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2.0;
    if (_elongationSector(mid) == from) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}

/// Next new moon (elongation 0 deg) strictly after [jdTtStart], TT.
double _nextNewMoon(double jdTtStart) {
  final s0 = _elongationSector(jdTtStart);
  var t = _nextSectorFlip(jdTtStart, s0);
  if (s0 == 0) {
    t = _nextSectorFlip(t, 1);
  }
  return t;
}

/// Instant of minimal topocentric separation within the +-0.35-day
/// window around the new moon: a coarse 0.01-day grid scan finds the
/// global basin (the parallax wobble makes the function multimodal near
/// the conjunction), then golden-section refinement polishes the best
/// cell. See the library doc for why the lunar solver's plain golden
/// section is not safe here.
double _minSeparationInstant(
    double tNewMoonUt, double latitudeDeg, double longitudeDeg) {
  double sep(double jdUt) =>
      _geometryAt(jdUt, latitudeDeg, longitudeDeg).separationDeg;
  var best = tNewMoonUt - 0.35;
  var bestVal = sep(best);
  for (var k = 1; k <= 70; k++) {
    final t = tNewMoonUt - 0.35 + k * 0.01;
    final v = sep(t);
    if (v < bestVal) {
      bestVal = v;
      best = t;
    }
  }
  var a = best - 0.01;
  var b = best + 0.01;
  for (var i = 0; i < 80; i++) {
    final c1 = b - (b - a) / 1.618;
    final c2 = a + (b - a) / 1.618;
    if (sep(c1) < sep(c2)) {
      b = c2;
    } else {
      a = c1;
    }
  }
  return (a + b) / 2.0;
}

/// Contact instant where the signed gap function [f] first reaches zero,
/// stepping from [tInside] (where f < 0) in 0.01-day steps, then
/// bisecting. [forward] steps toward increasing time.
double _contact(double tInside, double latitudeDeg, double longitudeDeg,
    bool forward, double Function(_LocalGeometry) f) {
  final step = forward ? 0.01 : -0.01;
  var lo = tInside;
  var hi = tInside + step;
  while (f(_geometryAt(hi, latitudeDeg, longitudeDeg)) < 0.0) {
    lo = hi;
    hi += step;
    if ((hi - tInside).abs() > 0.6) {
      throw StateError('solar eclipse contact solver ran away');
    }
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2.0;
    if (f(_geometryAt(mid, latitudeDeg, longitudeDeg)) < 0.0) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}

double _clampUnit(double x) => math.max(-1.0, math.min(1.0, x));

/// Fraction of the solar disc area covered when the two limb circles are
/// [sepDeg] apart with semidiameters [sunSdDeg] and [moonSdDeg]: exact
/// circle-circle overlap divided by the solar disc area.
double _obscuration(double sepDeg, double sunSdDeg, double moonSdDeg) {
  final d = sepDeg * _radPerDeg;
  final rs = sunSdDeg * _radPerDeg;
  final rm = moonSdDeg * _radPerDeg;
  if (d >= rs + rm) {
    return 0.0;
  }
  double area;
  if (d <= (rs - rm).abs()) {
    // One disc lies entirely inside the other: the smaller area.
    final smaller = math.min(rs, rm);
    area = math.pi * smaller * smaller;
  } else {
    final t1 = _clampUnit((d * d + rm * rm - rs * rs) / (2.0 * d * rm));
    final t2 = _clampUnit((d * d + rs * rs - rm * rm) / (2.0 * d * rs));
    final k = math.sqrt(math.max(0.0,
        (-d + rm + rs) * (d + rm - rs) * (d - rm + rs) * (d + rm + rs)));
    area = rm * rm * math.acos(t1) + rs * rs * math.acos(t2) - 0.5 * k;
  }
  return area / (math.pi * rs * rs);
}

/// Visibility from the Sun's altitude at the contacts and at greatest.
SolarEclipseVisibility _visibilityOf(List<double> altitudes) {
  var above = 0;
  for (final a in altitudes) {
    if (a > 0.0) {
      above++;
    }
  }
  if (above == altitudes.length) {
    return SolarEclipseVisibility.aboveHorizon;
  }
  if (above == 0) {
    return SolarEclipseVisibility.belowHorizon;
  }
  return SolarEclipseVisibility.partiallyAboveHorizon;
}

SolarEclipseCircumstances? _circumstancesAtNewMoon(
    double tNewMoonUt, double latitudeDeg, double longitudeDeg) {
  final tGreatest =
      _minSeparationInstant(tNewMoonUt, latitudeDeg, longitudeDeg);
  final g = _geometryAt(tGreatest, latitudeDeg, longitudeDeg);
  if (g.separationDeg >= g.sunSemidiameterDeg + g.moonSemidiameterDeg) {
    // The Moon's limb never touches the Sun's from here: no graze at
    // all (e.g. 17 Feb 2026 at Kathmandu, 22.6 arcmin outside).
    return null;
  }
  final central =
      g.separationDeg < (g.sunSemidiameterDeg - g.moonSemidiameterDeg).abs();
  double partialGap(_LocalGeometry s) =>
      s.separationDeg - (s.sunSemidiameterDeg + s.moonSemidiameterDeg);
  final tStart =
      _contact(tGreatest, latitudeDeg, longitudeDeg, false, partialGap);
  final tEnd =
      _contact(tGreatest, latitudeDeg, longitudeDeg, true, partialGap);
  final atStart = _geometryAt(tStart, latitudeDeg, longitudeDeg);
  final atEnd = _geometryAt(tEnd, latitudeDeg, longitudeDeg);
  double? tCentralStart;
  double? tCentralEnd;
  if (central) {
    double centralGap(_LocalGeometry s) => s.separationDeg -
        (s.sunSemidiameterDeg - s.moonSemidiameterDeg).abs();
    tCentralStart =
        _contact(tGreatest, latitudeDeg, longitudeDeg, false, centralGap);
    tCentralEnd =
        _contact(tGreatest, latitudeDeg, longitudeDeg, true, centralGap);
  }
  return SolarEclipseCircumstances(
    jdUtPartialStart: tStart,
    jdUtPartialEnd: tEnd,
    jdUtGreatest: tGreatest,
    jdUtCentralStart: tCentralStart,
    jdUtCentralEnd: tCentralEnd,
    centralAtGreatest: central,
    magnitude: (g.sunSemidiameterDeg +
            g.moonSemidiameterDeg -
            g.separationDeg) /
        (2.0 * g.sunSemidiameterDeg),
    obscuration:
        _obscuration(g.separationDeg, g.sunSemidiameterDeg, g.moonSemidiameterDeg),
    sunAltitudeDegAtStart: atStart.sunAltitudeDeg,
    sunAltitudeDegAtGreatest: g.sunAltitudeDeg,
    sunAltitudeDegAtEnd: atEnd.sunAltitudeDeg,
    visibility: _visibilityOf(
        [atStart.sunAltitudeDeg, g.sunAltitudeDeg, atEnd.sunAltitudeDeg]),
  );
}

/// Solar eclipse whose new moon falls in the window from one day before
/// [day] to 1.6 days after it at the observer, or null when there is
/// no graze at all (including penumbral grazes that never reach the
/// location).
///
/// The window deliberately brackets the receipt dates (whose local date
/// is the date of greatest eclipse); mapping events to Nepali civil days
/// is the job of the grahan module (step 4), not of this solver.
/// Below-horizon grazes are NOT null: they are returned with
/// [SolarEclipseVisibility.belowHorizon].
SolarEclipseCircumstances? solarEclipseNear(int year, int month, int day,
    {double latitudeDeg = 27.7172, double longitudeDeg = 85.324}) {
  final jdUt = julianDayFromCivil(year, month, day.toDouble());
  final tNow = jdTtFromJdUt(jdUt);
  final tNewMoon = _nextNewMoon(jdTtFromJdUt(jdUt - 1.0));
  if (tNewMoon - tNow > 1.6) {
    // The next new moon is a month away: nothing near this date.
    return null;
  }
  return _circumstancesAtNewMoon(
      jdUtFromJdTt(tNewMoon), latitudeDeg, longitudeDeg);
}

/// All solar eclipse grazes at the observer during the Gregorian
/// [year], in time order, including below-horizon ones.
List<SolarEclipseCircumstances> solarEclipsesInYear(int year,
    {double latitudeDeg = 27.7172, double longitudeDeg = 85.324}) {
  final out = <SolarEclipseCircumstances>[];
  var t = jdTtFromJdUt(julianDayFromCivil(year, 1, 1.0));
  final end = jdTtFromJdUt(julianDayFromCivil(year + 1, 1, 1.0));
  while (true) {
    final tNewMoon = _nextNewMoon(t);
    if (tNewMoon >= end) {
      break;
    }
    final c = _circumstancesAtNewMoon(
        jdUtFromJdTt(tNewMoon), latitudeDeg, longitudeDeg);
    if (c != null) {
      out.add(c);
    }
    t = tNewMoon + 0.1;
  }
  return out;
}
