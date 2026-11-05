import 'dart:math' as math;

import 'civil_time.dart';
import 'julian_day.dart';
import 'moon.dart';
import 'sun.dart';

const double _radPerDeg = math.pi / 180;

/// Geocentric lunar eclipse solver - L6 grahan layer, step 1 (HYA-421).
///
/// Classical shadow-cone geometry in the style of Meeus, Astronomical
/// Algorithms (2nd ed.), ch. 54: the eclipse is measured by the
/// perpendicular distance from the Moon's center to the Earth's shadow
/// axis (the anti-solar line through the Earth's center). Sun and Moon
/// are both evaluated with the engine's geometric series -
/// [sunTrueLongitude] and [moonPosition], mean equinox of date - so the
/// rotation both frames share cancels and no separate coordinate
/// conversion is needed.
///
/// Shadow convention, decoded and exposed - never silently picked
/// (collision C1 of the HYA-421 research pass): the Earth's atmosphere
/// enlarges both shadow cones. The default [danjonShadowEnlargement]
/// (1/85) is the convention behind the NASA/GSFC eclipse bulletins that
/// the receipts in test/fixtures/nasa_lunar_2026.json are published
/// with. The classical Chauvenet alternative
/// [chauvenetShadowEnlargement] (1/50) is exposed as a parameter for
/// cross-checking.
///
/// The permanent CI gate test/eclipse_lunar_test.dart pins both lunar
/// eclipses of 2026 (Mar 3 total, Aug 28 partial) to the freshly-parsed
/// NASA tables: every contact within 3 min, magnitudes within
/// 0.01/0.03.

/// Shadow enlargement of the traditional Danjon rule: both shadow cones
/// are widened by 1/85 of the Earth's radius. The engine default,
/// matching the NASA/GSFC eclipse bulletins used as receipts.
const double danjonShadowEnlargement = 1.0 / 85.0;

/// Shadow enlargement of the Chauvenet rule (1/50): the classical
/// alternative to [danjonShadowEnlargement], exposed for cross-checking
/// and never silently substituted.
const double chauvenetShadowEnlargement = 1.0 / 50.0;

/// IAU equatorial Earth radius in km (the radius the shadow cones are
/// built from, before the atmospheric enlargement).
const double earthRadiusKm = 6378.14;

/// Mean Solar radius in km (NASA/GSFC eclipse bulletins).
const double sunRadiusKm = 696000.0;

/// Astronomical unit in km.
const double auKm = 149597870.7;

/// Classification of a lunar eclipse at greatest eclipse.
enum LunarEclipseType { penumbral, partial, total }

/// Circumstances of one lunar eclipse; all instants are UT Julian Days.
class LunarEclipseCircumstances {
  /// One of [LunarEclipseType.penumbral], [LunarEclipseType.partial] or
  /// [LunarEclipseType.total].
  final LunarEclipseType type;

  /// First and last contact with the penumbra; always present, otherwise
  /// there is no eclipse at all.
  final double jdUtPenumbralStart;
  final double jdUtPenumbralEnd;

  /// First and last contact with the umbra; null when the Moon never
  /// touches the umbra (a penumbral-only eclipse).
  final double? jdUtPartialStart;
  final double? jdUtPartialEnd;

  /// Immersion into and emersion from totality; null when the Moon is
  /// never completely inside the umbra.
  final double? jdUtTotalStart;
  final double? jdUtTotalEnd;

  /// Instant of greatest eclipse (minimal perpendicular distance from
  /// the Moon's center to the shadow axis).
  final double jdUtGreatest;

  /// Umbral magnitude at greatest eclipse: the fraction of the lunar
  /// diameter immersed in the umbra (> 1 for total eclipses).
  final double umbralMagnitude;

  /// Penumbral magnitude at greatest eclipse.
  final double penumbralMagnitude;

  const LunarEclipseCircumstances({
    required this.type,
    required this.jdUtPenumbralStart,
    required this.jdUtPenumbralEnd,
    required this.jdUtPartialStart,
    required this.jdUtPartialEnd,
    required this.jdUtTotalStart,
    required this.jdUtTotalEnd,
    required this.jdUtGreatest,
    required this.umbralMagnitude,
    required this.penumbralMagnitude,
  });
}

/// Shadow geometry at one TT instant.
class _ShadowGeometry {
  final double perpKm;
  final double umbraKm;
  final double penumbraKm;
  final double moonRadiusKm;

  const _ShadowGeometry({
    required this.perpKm,
    required this.umbraKm,
    required this.penumbraKm,
    required this.moonRadiusKm,
  });
}

_ShadowGeometry _shadowAt(double jdTt, double enlargement) {
  final moon = moonPosition(jdTt);
  final sunLon = sunTrueLongitude(jdTt);
  final sunDistanceKm = sunEarthDistanceAu(jdTt) * auKm;
  // The shadow axis: the anti-solar direction in the ecliptic of date.
  final axisX = -math.cos(sunLon * _radPerDeg);
  final axisY = -math.sin(sunLon * _radPerDeg);
  // Moon rectangular coordinates in the same frame.
  final cosBeta = math.cos(moon.latitudeDeg * _radPerDeg);
  final mx =
      moon.distanceKm * cosBeta * math.cos(moon.longitudeDeg * _radPerDeg);
  final my =
      moon.distanceKm * cosBeta * math.sin(moon.longitudeDeg * _radPerDeg);
  final mz = moon.distanceKm * math.sin(moon.latitudeDeg * _radPerDeg);
  // Perpendicular distance of the Moon's center from the shadow axis and
  // its axial distance behind the Earth.
  final axial = mx * axisX + my * axisY;
  final px = mx - axial * axisX;
  final py = my - axial * axisY;
  final perp = math.sqrt(px * px + py * py + mz * mz);
  // Enlarged Earth radius, then the linear cone radii at the Moon's axial
  // distance: the umbra narrows toward the Sun, the penumbra widens.
  final er = earthRadiusKm * (1.0 + enlargement);
  final umbra = er + axial * (er - sunRadiusKm) / sunDistanceKm;
  final penumbra = er + axial * (er + sunRadiusKm) / sunDistanceKm;
  // Moon radius from its parallax (Meeus ch. 54 builds the limb from the
  // same 0.272494 parallax ratio).
  final moonRadius =
      moon.distanceKm * math.sin(0.272494 * moon.parallaxDeg * _radPerDeg);
  return _ShadowGeometry(
      perpKm: perp,
      umbraKm: umbra,
      penumbraKm: penumbra,
      moonRadiusKm: moonRadius);
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

/// Next full moon (elongation 180 deg) strictly after [jdTtStart], TT.
double _nextFullMoon(double jdTtStart) {
  final s0 = _elongationSector(jdTtStart);
  var t = _nextSectorFlip(jdTtStart, s0);
  if (s0 == 1) {
    t = _nextSectorFlip(t, 0);
  }
  return t;
}

/// Instant of minimal perpendicular distance within the +-0.35-day window
/// around the full moon, by golden-section search.
double _minimizePerp(double tFullMoon, double enlargement) {
  var a = tFullMoon - 0.35;
  var b = tFullMoon + 0.35;
  for (var i = 0; i < 100; i++) {
    final c1 = b - (b - a) / 1.618;
    final c2 = a + (b - a) / 1.618;
    if (_shadowAt(c1, enlargement).perpKm <
        _shadowAt(c2, enlargement).perpKm) {
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
double _contact(double tInside, double enlargement, bool forward,
    double Function(_ShadowGeometry) f) {
  final step = forward ? 0.01 : -0.01;
  var lo = tInside;
  var hi = tInside + step;
  while (f(_shadowAt(hi, enlargement)) < 0.0) {
    lo = hi;
    hi += step;
    if ((hi - tInside).abs() > 0.6) {
      throw StateError('lunar eclipse contact solver ran away');
    }
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2.0;
    if (f(_shadowAt(mid, enlargement)) < 0.0) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}

LunarEclipseCircumstances? _circumstancesAtFullMoon(
    double tFullMoon, double enlargement) {
  final tGreatest = _minimizePerp(tFullMoon, enlargement);
  final g = _shadowAt(tGreatest, enlargement);
  if (g.perpKm >= g.penumbraKm + g.moonRadiusKm) {
    // The Moon's limb never touches the penumbra: no eclipse.
    return null;
  }
  final touchesUmbra = g.perpKm < g.umbraKm + g.moonRadiusKm;
  final total = g.perpKm < g.umbraKm - g.moonRadiusKm;
  double penumbraGap(_ShadowGeometry s) =>
      s.perpKm - (s.penumbraKm + s.moonRadiusKm);
  double umbraGap(_ShadowGeometry s) =>
      s.perpKm - (s.umbraKm + s.moonRadiusKm);
  double totalGap(_ShadowGeometry s) =>
      s.perpKm - (s.umbraKm - s.moonRadiusKm);
  return LunarEclipseCircumstances(
    type: total
        ? LunarEclipseType.total
        : (touchesUmbra
            ? LunarEclipseType.partial
            : LunarEclipseType.penumbral),
    jdUtPenumbralStart:
        jdUtFromJdTt(_contact(tGreatest, enlargement, false, penumbraGap)),
    jdUtPenumbralEnd:
        jdUtFromJdTt(_contact(tGreatest, enlargement, true, penumbraGap)),
    jdUtPartialStart: touchesUmbra
        ? jdUtFromJdTt(_contact(tGreatest, enlargement, false, umbraGap))
        : null,
    jdUtPartialEnd: touchesUmbra
        ? jdUtFromJdTt(_contact(tGreatest, enlargement, true, umbraGap))
        : null,
    jdUtTotalStart: total
        ? jdUtFromJdTt(_contact(tGreatest, enlargement, false, totalGap))
        : null,
    jdUtTotalEnd: total
        ? jdUtFromJdTt(_contact(tGreatest, enlargement, true, totalGap))
        : null,
    jdUtGreatest: jdUtFromJdTt(tGreatest),
    umbralMagnitude:
        (g.umbraKm + g.moonRadiusKm - g.perpKm) / (2.0 * g.moonRadiusKm),
    penumbralMagnitude:
        (g.penumbraKm + g.moonRadiusKm - g.perpKm) / (2.0 * g.moonRadiusKm),
  );
}

/// Lunar eclipse whose full moon falls in the window from one day before
/// [day] to 1.6 days after it, or null when there is none.
///
/// The window deliberately brackets the NASA receipt dates (whose UT date
/// is the date of greatest eclipse) and the day-before edge for eclipses
/// that begin before local midnight; mapping events to Nepali civil days
/// is the job of the grahan module (step 4), not of this solver.
LunarEclipseCircumstances? lunarEclipseNear(int year, int month, int day,
    {double shadowEnlargement = danjonShadowEnlargement}) {
  final jdUt = julianDayFromCivil(year, month, day.toDouble());
  final tNow = jdTtFromJdUt(jdUt);
  final tFullMoon = _nextFullMoon(jdTtFromJdUt(jdUt - 1.0));
  if (tFullMoon - tNow > 1.6) {
    // The next full moon is a month away: nothing near this date.
    return null;
  }
  return _circumstancesAtFullMoon(tFullMoon, shadowEnlargement);
}

/// All lunar eclipses of the Gregorian [year], in time order.
List<LunarEclipseCircumstances> lunarEclipsesInYear(int year,
    {double shadowEnlargement = danjonShadowEnlargement}) {
  final out = <LunarEclipseCircumstances>[];
  var t = jdTtFromJdUt(julianDayFromCivil(year, 1, 1.0));
  final end = jdTtFromJdUt(julianDayFromCivil(year + 1, 1, 1.0));
  while (true) {
    final tFullMoon = _nextFullMoon(t);
    if (tFullMoon >= end) {
      break;
    }
    final c = _circumstancesAtFullMoon(tFullMoon, shadowEnlargement);
    if (c != null) {
      out.add(c);
    }
    t = tFullMoon + 0.1;
  }
  return out;
}
