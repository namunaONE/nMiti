import 'dart:math' as math;

/// Geometric geocentric position of the Moon, mean equinox of date.
///
/// Longitudes and latitudes are in degrees, the distance in kilometers. This
/// is the geometric position (no nutation, no aberration) of Meeus,
/// Astronomical Algorithms (2nd ed.), chapter 47 - example 47.a is the
/// permanent unit test.
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

/// Table 47.A (Meeus p. 339-340): [D, M, M', F, Sigma-l, Sigma-r].
///
/// Sigma-l is in units of 1e-6 degree, Sigma-r in units of 1e-3 km.
const List<List<int>> _table47a = [
  [0, 0, 1, 0, 6288774, -20905355],
  [2, 0, -1, 0, 1274027, -3699111],
  [2, 0, 0, 0, 658314, -2955968],
  [0, 0, 2, 0, 213618, -569925],
  [0, 1, 0, 0, -185116, 48888],
  [0, 0, 0, 2, -114332, -3149],
  [2, 0, -2, 0, 58793, 246158],
  [2, -1, -1, 0, 57066, -152138],
  [2, 0, 1, 0, 53322, -170733],
  [2, -1, 0, 0, 45758, -204586],
  [0, 1, -1, 0, -40923, -129620],
  [1, 0, 0, 0, -34720, 108743],
  [0, 1, 1, 0, -30383, 104755],
  [2, 0, 0, -2, 15327, 10321],
  [0, 0, 1, 2, -12528, 0],
  [0, 0, 1, -2, 10980, 79661],
  [4, 0, -1, 0, 10675, -34782],
  [0, 0, 3, 0, 10034, -23210],
  [4, 0, -2, 0, 8548, -21636],
  [2, 1, -1, 0, -7888, 24208],
  [2, 1, 0, 0, -6766, 30824],
  [1, 0, -1, 0, -5163, -8379],
  [1, 1, 0, 0, 4987, -16675],
  [2, -1, 1, 0, 4036, -12831],
  [2, 0, 2, 0, 3994, -10445],
  [4, 0, 0, 0, 3861, -11650],
  [2, 0, -3, 0, 3665, 14403],
  [0, 1, -2, 0, -2689, -7003],
  [2, 0, -1, 2, -2602, 0],
  [2, -1, -2, 0, 2390, 10056],
  [1, 0, 1, 0, -2348, 6322],
  [2, -2, 0, 0, 2236, -9884],
  [0, 1, 2, 0, -2120, 5751],
  [0, 2, 0, 0, -2069, 0],
  [2, -2, -1, 0, 2048, -4950],
  [2, 0, 1, -2, -1773, 4130],
  [2, 0, 0, 2, -1595, 0],
  [4, -1, -1, 0, 1215, -3958],
  [0, 0, 2, 2, -1110, 0],
  [3, 0, -1, 0, -892, 3258],
  [2, 1, 1, 0, -810, 2616],
  [4, -1, -2, 0, 759, -1897],
  [0, 2, -1, 0, -713, -2117],
  [2, 2, -1, 0, -700, 2354],
  [2, 1, -2, 0, 691, 0],
  [2, -1, 0, -2, 596, 0],
  [4, 0, 1, 0, 549, -1423],
  [0, 0, 4, 0, 537, -1117],
  [4, -1, 0, 0, 520, -1571],
  [1, 0, -2, 0, -487, -1739],
  [2, 1, 0, -2, -399, 0],
  [0, 0, 2, -2, -381, -4421],
  [1, 1, 1, 0, 351, 0],
  [3, 0, -2, 0, -340, 0],
  [4, 0, -3, 0, 330, 0],
  [2, -1, 2, 0, 327, 0],
  [0, 2, 1, 0, -323, 1165],
  [1, 1, -1, 0, 299, 0],
  [2, 0, 3, 0, 294, 0],
  [2, 0, -1, -2, 0, 8752],
];

/// Table 47.B (Meeus p. 341): [D, M, M', F, Sigma-b].
///
/// Sigma-b is in units of 1e-6 degree.
const List<List<int>> _table47b = [
  [0, 0, 0, 1, 5128122],
  [0, 0, 1, 1, 280602],
  [0, 0, 1, -1, 277693],
  [2, 0, 0, -1, 173237],
  [2, 0, -1, 1, 55413],
  [2, 0, -1, -1, 46271],
  [2, 0, 0, 1, 32573],
  [0, 0, 2, 1, 17198],
  [2, 0, 1, -1, 9266],
  [0, 0, 2, -1, 8822],
  [2, -1, 0, -1, 8216],
  [2, 0, -2, -1, 4324],
  [2, 0, 1, 1, 4200],
  [2, 1, 0, -1, -3359],
  [2, -1, -1, 1, 2463],
  [2, -1, 0, 1, 2211],
  [2, -1, -1, -1, 2065],
  [0, 1, -1, -1, -1870],
  [4, 0, -1, -1, 1828],
  [0, 1, 0, 1, -1794],
  [0, 0, 0, 3, -1749],
  [0, 1, -1, 1, -1565],
  [1, 0, 0, 1, -1491],
  [0, 1, 1, 1, -1475],
  [0, 1, 1, -1, -1410],
  [0, 1, 0, -1, -1344],
  [1, 0, 0, -1, -1335],
  [0, 0, 3, 1, 1107],
  [4, 0, 0, -1, 1021],
  [4, 0, -1, 1, 833],
  [0, 0, 1, -3, 777],
  [4, 0, -2, 1, 671],
  [2, 0, 0, -3, 607],
  [2, 0, 2, -1, 596],
  [2, -1, 1, -1, 491],
  [2, 0, -2, 1, -451],
  [0, 0, 3, -1, 439],
  [2, 0, 2, 1, 422],
  [2, 0, -3, -1, 421],
  [2, 1, -1, 1, -366],
  [2, 1, 0, 1, -351],
  [4, 0, 0, 1, 331],
  [2, -1, 1, 1, 315],
  [2, -2, 0, -1, 302],
  [0, 0, 1, 3, -283],
  [2, 1, 1, -1, -229],
  [1, 1, 0, -1, 223],
  [1, 1, 0, 1, 223],
  [0, 1, -2, -1, -220],
  [2, 1, -1, -1, -220],
  [1, 0, 1, 1, -185],
  [2, -1, -2, -1, 181],
  [0, 1, 2, 1, -177],
  [4, 0, -2, -1, 176],
  [4, -1, -1, -1, 166],
  [1, 0, 1, -1, -164],
  [4, 0, 1, -1, 132],
  [1, 0, -1, -1, -119],
  [4, -1, 0, -1, 115],
  [2, -2, 0, 1, 107],
];

const double _radPerDeg = math.pi / 180;

/// Geometric geocentric position of the Moon for [jd] in Terrestrial Time.
///
/// Full 60-term ELP-2000/82 series of Meeus, Astronomical Algorithms (2nd
/// ed.), chapter 47, with the eccentricity factor E on the terms in M, the
/// additive A1/A2/A3 corrections and the constant 385000.56 km term. [jd]
/// must already be a TT Julian Day - convert civil UTC with
/// [deltaTSeconds].
MoonPosition moonPosition(double jd) {
  final t = (jd - 2451545.0) / 36525.0;
  final t2 = t * t;
  final t3 = t2 * t;
  final t4 = t2 * t2;
  final lp = 218.3164477 +
      481267.88123421 * t -
      0.0015786 * t2 +
      t3 / 538841 -
      t4 / 65194000;
  final d = 297.8501921 +
      445267.1114034 * t -
      0.0018819 * t2 +
      t3 / 545868 -
      t4 / 113065000;
  final m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000;
  final mp = 134.9633964 +
      477198.8675055 * t +
      0.0087414 * t2 +
      t3 / 69699 -
      t4 / 14712000;
  final f = 93.2720950 +
      483202.0175233 * t -
      0.0036539 * t2 -
      t3 / 3526000 +
      t4 / 863310000;
  final e = 1 - 0.002516 * t - 0.0000074 * t2;
  var sigmaL = 0.0;
  var sigmaR = 0.0;
  for (final row in _table47a) {
    final arg = (row[0] * d + row[1] * m + row[2] * mp + row[3] * f) * _radPerDeg;
    sigmaL += _ecc(row[1], row[4].toDouble(), e) * math.sin(arg);
    sigmaR += _ecc(row[1], row[5].toDouble(), e) * math.cos(arg);
  }
  var sigmaB = 0.0;
  for (final row in _table47b) {
    final arg = (row[0] * d + row[1] * m + row[2] * mp + row[3] * f) * _radPerDeg;
    sigmaB += _ecc(row[1], row[4].toDouble(), e) * math.sin(arg);
  }
  final a1 = 119.75 + 131.849 * t;
  final a2 = 53.09 + 479264.290 * t;
  final a3 = 313.45 + 481266.484 * t;
  sigmaL += 3958 * math.sin(a1 * _radPerDeg) +
      1962 * math.sin((lp - f) * _radPerDeg) +
      318 * math.sin(a2 * _radPerDeg);
  sigmaB += -2235 * math.sin(lp * _radPerDeg) +
      382 * math.sin(a3 * _radPerDeg) +
      175 * math.sin((a1 - f) * _radPerDeg) +
      175 * math.sin((a1 + f) * _radPerDeg) +
      127 * math.sin((lp - mp) * _radPerDeg) -
      115 * math.sin((lp + mp) * _radPerDeg);
  final distance = 385000.56 + sigmaR / 1000;
  return MoonPosition(
    longitudeDeg: _norm360(lp + sigmaL / 1e6),
    latitudeDeg: sigmaB / 1e6,
    distanceKm: distance,
    parallaxDeg: math.asin(6378.14 / distance) / _radPerDeg,
  );
}

/// Applies the eccentricity factor E to a table coefficient: times E for
/// |M| = 1, times E squared for |M| = 2 (Meeus p. 342).
double _ecc(int m, double coeff, double e) {
  switch (m.abs()) {
    case 1:
      return coeff * e;
    case 2:
      return coeff * e * e;
    default:
      return coeff;
  }
}

double _norm360(double deg) => deg % 360.0;
