import 'dart:math' as math;

import 'elp2000/elp_table.dart';

/// Geometric geocentric position of the Moon, mean equinox of date.
///
/// Longitudes and latitudes are in degrees, the distance in kilometers. This
/// is the geometric position (no nutation, no aberration) evaluated from the
/// truncated ELP2000-82B series - Meeus, Astronomical Algorithms (2nd ed.),
/// example 47.a remains the permanent unit test anchor.
class MoonPosition {
  /// Ecliptic longitude in degrees, normalized to [0, 360).
  final double longitudeDeg;

  /// Ecliptic latitude in degrees.
  final double latitudeDeg;

  /// Earth-Moon center-to-center distance in kilometers.
  final double distanceKm;

  /// Equatorial horizontal parallax in degrees (Meeus eq. 47.7).
  final double parallaxDeg;

  const MoonPosition({
    required this.longitudeDeg,
    required this.latitudeDeg,
    required this.distanceKm,
    required this.parallaxDeg,
  });
}

const double _radPerDeg = math.pi / 180;

/// Arc seconds to radians (the longitude/latitude table sections are in
/// arcsec; the distance section is already in kilometers).
const double _radPerArcsec = math.pi / 648000;

/// Geometric geocentric position of the Moon for [jd] in Terrestrial Time.
///
/// ELP2000-82B (Chapront-Touze & Chapront 1983, Bureau des Longitudes /
/// IMCCE), truncated per the NASA Five Millennium Canon recipe: periodic
/// terms below 0.0005 arcsec in longitude/latitude and about 1 m in
/// distance are neglected (4,407 of 37,872 terms survive). The improved
/// mean arguments of Chapront et al. (2002) - the same L'/D/M/M'/F
/// polynomials the previous 60-term Meeus Ch.47 implementation used -
/// replace the raw 1983 Delaunay arguments. The coefficients live in the
/// GENERATED vendored table `elp2000/` (built by
/// tools/sweph/elp_build_table.py from the public IMCCE data; CI
/// regenerates and diffs it on every run - hand edits fail CI).
///
/// Frame - deliberately unchanged from the previous moon: this upgrade is a
/// FIT change, not a convention change. Geometric, mean ecliptic and
/// equinox of date; no nutation (it cancels in the tithi elongation
/// against the sun, which also omits it); no aberration; light-time
/// (~1.4 s of Moon motion) remains a NAMED systematic skip, stated in the
/// published error bars, never absorbed. [jd] must already be a TT Julian
/// Day - convert civil UTC with [deltaTSeconds].
MoonPosition moonPosition(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final terms = elpTerms;
  final counts = kElpSectionCounts;
  assert(
    terms.length ==
        6 * (counts[0] + counts[3] + counts[6]) +
            4 *
                (counts[1] +
                    counts[2] +
                    counts[4] +
                    counts[5] +
                    counts[7] +
                    counts[8]),
    'elp2000 table layout mismatch',
  );

  // Section sums per coordinate: r[0] longitude (arcsec), r[1] latitude
  // (arcsec), r[2] distance (km - the +pi/2 cosine shift and the a0/ath
  // scale factor are pre-folded into the table at generation time, so no
  // per-section special case is needed here beyond the unit summed).
  final r = List<double>.filled(3, 0.0);
  var off = 0;
  for (var iv = 0; iv < 3; iv++) {
    // Main problem: 6 doubles per term - the sine argument as a
    // polynomial in t (coefficients for t^0..t^4, radians), then the
    // amplitude.
    var end = off + counts[iv * 3] * 6;
    for (var i = off; i < end; i += 6) {
      r[iv] += terms[i + 5] *
          math.sin(terms[i] +
              (terms[i + 1] +
                  (terms[i + 2] +
                      (terms[i + 3] + terms[i + 4] * t) * t) *
                  t) *
              t);
    }
    off = end;
    // Figure/tide then planetary terms: 4 doubles per term - argument
    // constant (radians), argument t-rate (radians/cy), amplitude, power
    // of t (the amplitude scales by t^power).
    for (var g = 1; g <= 2; g++) {
      end = off + counts[iv * 3 + g] * 4;
      for (var i = off; i < end; i += 4) {
        final amp = terms[i + 2];
        final tp = terms[i + 3];
        r[iv] += (tp == 0 ? amp : (tp == 1 ? amp * t : amp * t * t)) *
            math.sin(terms[i] + terms[i + 1] * t);
      }
      off = end;
    }
  }

  final w = kElpMeanLongitudeRad;
  final lonRad = r[0] * _radPerArcsec +
      w[0] + (w[1] + (w[2] + (w[3] + w[4] * t) * t) * t) * t;
  final distance = r[2];
  return MoonPosition(
    longitudeDeg: _norm360(lonRad * _radPerDeg),
    latitudeDeg: r[1] * _radPerArcsec * _radPerDeg,
    distanceKm: distance,
    parallaxDeg: math.asin(6378.14 / distance) / _radPerDeg,
  );
}

double _norm360(double deg) => deg % 360.0;
