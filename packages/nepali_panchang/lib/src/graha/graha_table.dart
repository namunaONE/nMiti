// GENERATED FILE - tools/sweph/graha_build_table.py - DO NOT EDIT.
//
// Vendored VSOP87D planetary theory for the nMiti graha engine:
// Mercury, Venus, Earth, Mars, Jupiter, Saturn - the Earth sections
// feed the geocentric subtraction (the legacy vsop87d_earth.dart is
// the solar channel's table and carries only the L series). Bretagnon
// & Francou VSOP87 version D: heliocentric, geometric, dynamical
// ecliptic and equinox of the date - light-time and aberration are
// applied by the engine (graha.dart), not by this table.
//
// Source data: VSOP87D distribution, Bureau des Longitudes / IMCCE -
// https://ftp.imcce.fr/pub/ephem/planets/vsop87/ - public research
// data; only numeric facts computed from it are vendored, no text or
// code from the distribution is copied. Theory: Bretagnon & Francou,
// Astron. Astrophys. 202, 309 (1988).
//
// Truncation: terms with |A| < 1e-8 rad (AU in R) are neglected.
// Worst dropped-tail bounds at generation: L 4.61e-06 rad (sat); B 1.81e-06 rad (sat); R 3.32e-06 AU (jup)
// (aligned worst case; the realistic error is the much smaller
// root-sum-square of the same dropped terms).
//
// Regenerate:
//   python3 tools/sweph/graha_build_table.py --data-dir build/vsop87 \
//     --out-dir packages/nepali_panchang/lib/src/graha
// CI regenerates and diffs this directory on every run (ci.yml
// "graha VSOP87D vendored table freshness gate") - hand edits fail CI.
//
// LAYOUT: [kGrahaSectionCounts] lists the term count of 108 sections
// in the order: for each body in Mercury, Venus, Earth, Mars,
// Jupiter, Saturn; for each variable 1=L, 2=B, 3=R; for each power
// T^0..T^5. Within a section the terms keep the source file order.
// [kGrahaTerms] is the flat list: each term is 3 doubles A, B, C
// (radians; AU in the R sections), and the value of a variable is the
// sum over its six sections of
//   tau^power * sum( A * cos(B + C * tau) )
// with tau = (JD - 2451545.0) / 365250.0 (thousands of Julian years,
// the native VSOP87 time unit). Total: 27000 doubles
// (9000 terms).

import 'graha_terms_part01.dart';
import 'graha_terms_part02.dart';
import 'graha_terms_part03.dart';
import 'graha_terms_part04.dart';
import 'graha_terms_part05.dart';
import 'graha_terms_part06.dart';
import 'graha_terms_part07.dart';
import 'graha_terms_part08.dart';
import 'graha_terms_part09.dart';
import 'graha_terms_part10.dart';
import 'graha_terms_part11.dart';
import 'graha_terms_part12.dart';

/// Term counts of the 108 sections - body x variable (1=L, 2=B,
/// 3=R) x power (T^0..T^5), in flat [kGrahaTerms] order.
const List<int> kGrahaSectionCounts = <int>[236, 96, 15, 8, 5, 0, 155, 33, 11, 7, 2, 0, 115, 30, 10, 6, 0, 0, 151, 53, 16, 4, 3, 0, 79, 27, 5, 4, 1, 0, 89, 18, 4, 1, 0, 0, 221, 87, 28, 5, 2, 0, 54, 10, 1, 0, 0, 0, 152, 49, 9, 2, 1, 0, 430, 208, 83, 20, 6, 0, 143, 67, 16, 4, 2, 0, 344, 170, 63, 8, 4, 0, 384, 180, 97, 46, 19, 4, 108, 71, 40, 11, 6, 1, 490, 245, 128, 67, 24, 9, 556, 297, 135, 63, 27, 12, 217, 110, 51, 25, 12, 2, 1089, 583, 298, 137, 58, 25];

/// The flat coefficient table - see the file header for the layout.
const List<double> kGrahaTerms = <double>[
  ...kGrahaTermsPart01,
  ...kGrahaTermsPart02,
  ...kGrahaTermsPart03,
  ...kGrahaTermsPart04,
  ...kGrahaTermsPart05,
  ...kGrahaTermsPart06,
  ...kGrahaTermsPart07,
  ...kGrahaTermsPart08,
  ...kGrahaTermsPart09,
  ...kGrahaTermsPart10,
  ...kGrahaTermsPart11,
  ...kGrahaTermsPart12,
];
