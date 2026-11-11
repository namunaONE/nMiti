// GENERATED FILE - tools/sweph/elp_build_table.py - DO NOT EDIT.
//
// Vendored ELP2000-82B lunar theory for the nMiti engine moon, NASA
// Five Millennium Canon truncation: periodic terms below 0.0005 arcsec
// in longitude/latitude (~1 m in distance) are neglected - 4407 of
// 37,872 terms survive. The improved mean arguments of Chapront,
// Chapront-Touze, Francou & Laskar (2002) replace the raw 1983
// Delaunay arguments (the same L'/D/M/M'/F polynomials as the previous
// Meeus Ch.47 implementation, so the frame is unchanged: geometric,
// mean ecliptic and equinox of date).
//
// Source data: ELP2000-82B distribution, Chapront-Touze & Chapront
// (1983), Bureau des Longitudes / IMCCE -
// https://ftp.imcce.fr/pub/ephem/moon/elp82b/ - public research data;
// only numeric facts computed from it are vendored, no text or code
// from the distribution is copied. Theory papers: Chapront-Touze &
// Chapront, Astron. Astrophys. 190, 342 (1988); Chapront et al.,
// Astron. Astrophys. 387, 700 (2002). Truncation recipe: Espenak &
// Meeus, Five Millennium Canon of Lunar Eclipses (NASA/TP-2004-212762).
//
// Regenerate:
//   python3 tools/sweph/elp_build_table.py --data-dir build/elp82b \
//     --out-dir packages/nepali_panchang/lib/src/elp2000
// CI regenerates and diffs this directory on every run (ci.yml
// "elp2000 vendored table freshness gate") - hand edits fail CI.
//
// LAYOUT of [elpTerms]: sections in the order main-lon, fig-lon,
// planet-lon, main-lat, fig-lat, planet-lat, main-dist, fig-dist,
// planet-dist; [kElpSectionCounts] lists the term count of each.
// Main-problem terms are 6 doubles: the sine argument as a polynomial
// in t (powers t^0..t^4, radians), then the amplitude (arcsec; km in
// the distance section, where the +pi/2 cosine shift is pre-folded
// into the t^0 argument coefficient). Figure/tide and planetary terms
// are 4 doubles: argument constant (rad), argument t-rate (rad/cy),
// amplitude (same unit as the section), power of t (0, 1 or 2 - the
// amplitude scales by t^power). Distance amplitudes are pre-multiplied
// by a0/ath. [kElpMeanLongitudeRad] is the equinox-of-date mean
// longitude L' polynomial in radians (t^0..t^4 coefficients).
// Total: 19968 doubles (4407 terms).

import 'elp_terms_part01.dart';
import 'elp_terms_part02.dart';
import 'elp_terms_part03.dart';
import 'elp_terms_part04.dart';
import 'elp_terms_part05.dart';
import 'elp_terms_part06.dart';
import 'elp_terms_part07.dart';
import 'elp_terms_part08.dart';
import 'elp_terms_part09.dart';

/// Terms per section, in the flat [elpTerms] order: main-lon, fig-lon,
/// planet-lon, main-lat, fig-lat, planet-lat, main-dist, fig-dist,
/// planet-dist.
const List<int> kElpSectionCounts = <int>[452, 87, 1565, 401, 65, 674, 317, 49, 797];

/// Equinox-of-date mean longitude L' polynomial coefficients (t^0..t^4),
/// radians (Chapront et al. 2002).
const List<double> kElpMeanLongitudeRad = <double>[3.81034082362, 8399.70911163, -2.7551767572e-05, 3.23904315372e-08, -2.67713171763e-10];

/// The flat coefficient table - see the file header for the layout.
const List<double> elpTerms = <double>[
...kElpTermsPart01,
...kElpTermsPart02,
...kElpTermsPart03,
...kElpTermsPart04,
...kElpTermsPart05,
...kElpTermsPart06,
...kElpTermsPart07,
...kElpTermsPart08,
...kElpTermsPart09,
];
