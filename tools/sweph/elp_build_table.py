#!/usr/bin/env python3
"""Generate the vendored ELP2000-82B coefficient table for the nMiti moon.

HYA-369 engine upgrade. Builds the NASA-canonical truncated ELP2000-82B
series - the exact theory the CI spike (elp_spike.py) measured - and
emits it as deterministic Dart source under
packages/nepali_panchang/lib/src/elp2000/:

  elp_table.dart        - layout docs, section counts, the mean
                          longitude polynomial, the composed flat list
  elp_terms_partNN.dart - kElpTermsPartNN chunks of the flat list

The table is DATA: generated, never hand-edited. Two guards keep it
honest (see tools/sweph/README.md):

- .github/workflows/elp-table-gen.yml regenerates and COMMITS the
  table when the generator changes, so the ~300 KB of coefficients
  never travels through a review tool;
- the ci.yml "elp2000 vendored table freshness gate" regenerates it
  from the build/elp82b download on every CI run and fails on any
  byte drift.

Self-verification before writing (fail-loud, no Swiss needed):

- the 47.a anchor: the 2002-arguments value at JD 2448724.5 must sit
  where the spike measured it (~133.162133 deg, i.e. the known ~2.2
  arcsec offset below Swiss geometric) - catches frame/regression
  bugs at generation time;
- the emitted flat table is re-evaluated by a mirror of the Dart
  reader and compared against the reference evaluator at three
  epochs - catches layout/folding bugs;
- every formatted number round-trips within %.12g precision.

License: ELP2000-82B is public research data (Bureau des Longitudes /
IMCCE). Only numeric facts computed from it are vendored; the theory
is cited academic work and no text or code from the distribution is
copied. Stdlib only; reuses the spike's parser so the two cannot drift.
"""
import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from elp_spike import (  # noqa: E402
    NASA_TRUNC_ARCSEC,
    RAD,
    ElpTheory,
    download_elp,
)

HALF_PI = math.pi / 2.0

# Example 47.a epoch (1992 April 12.0 TD): the spike measured the
# 2002-arguments longitude at Swiss-geometric minus 2.17 arcsec
# (~133.162133 deg). Generous band: catches the frame/rate bugs this
# anchor exists for (those shift by tens of arcsec), never false-trips.
ANCHOR_JD = 2448724.5
ANCHOR_LON_DEG = 133.162133
ANCHOR_LON_TOL_DEG = 0.005

# Flat-table vs reference evaluator agreement (identical summation
# order; the only difference is %.12g coefficient rounding).
FLAT_LON_LAT_TOL_DEG = 1e-7
FLAT_DIST_TOL_KM = 1e-3

CHECK_EPOCHS = [2448724.5, 2451545.0, 2461000.0]

PART_BYTES_TARGET = 32000
NUMS_PER_LINE = 8


def build_flat(theory):
    """Flatten the theory into the generated Dart layout.

    Section order: (main, fig, planet) x (lon, lat, dist); main terms
    are 6 doubles (argument powers a1..a5 in radians, amplitude in
    arcsec), fig/planet terms are 4 doubles (argument constant and
    t-rate in radians, amplitude, power of t). At generation time the
    distance section gets its +pi/2 cosine shift folded into a1 and
    every distance amplitude pre-multiplied by a0/ath, so the Dart
    reader needs no per-section special cases beyond the unit it sums.
    """
    counts = []
    flat = []
    a0_over_ath = theory.a0 / theory.ath
    for iv in (1, 2, 3):
        for group in ("main", "fig", "planet"):
            entries = getattr(theory, group)[iv]
            counts.append(len(entries))
            for entry in entries:
                if group == "main":
                    arg, x = entry
                    a1 = arg[0]
                    if iv == 3:
                        a1 += HALF_PI
                        x = x * a0_over_ath
                    flat.extend([a1, arg[1], arg[2], arg[3], arg[4], x])
                else:
                    a1, a2, x, tp = entry
                    if iv == 3:
                        x = x * a0_over_ath
                    flat.extend([a1, a2, x, float(tp)])
    return counts, flat


def eval_flat(counts, flat, w1, jd):
    """Mirror of the Dart reader: evaluate the flat table directly."""
    t = (jd - 2451545.0) / 36525.0
    r = [0.0, 0.0, 0.0]
    i = 0
    for iv in range(3):
        for _ in range(counts[iv * 3]):
            a1, a2, a3, a4, a5, x = flat[i:i + 6]
            i += 6
            r[iv] += x * math.sin(
                a1 + (a2 + (a3 + (a4 + a5 * t) * t) * t) * t)
        for g in (1, 2):
            for _ in range(counts[iv * 3 + g]):
                a1, a2, x, tp = flat[i:i + 4]
                i += 4
                if tp == 0.0:
                    f = x
                elif tp == 1.0:
                    f = x * t
                else:
                    f = x * t * t
                r[iv] += f * math.sin(a1 + a2 * t)
    w = w1
    lon = (r[0] / RAD + w[1] + (w[2] + (w[3] + (w[4] + w[5] * t) * t) * t) * t
           ) % (2.0 * math.pi)
    lat = math.degrees(r[1] / RAD)
    return math.degrees(lon), lat, r[2]


def fmt(v):
    """Deterministic %.12g double literal (relative error ~5e-13 -
    ~6e-7 arcsec on the largest amplitude, negligible vs the 0.0005
    arcsec truncation threshold)."""
    s = "%.12g" % (v,)
    if "." not in s and "e" not in s and "E" not in s:
        s += ".0"  # keep every entry an explicit double literal
    return s


def verify(theory, counts, flat, w1):
    lon, lat, dist = theory.spherical(ANCHOR_JD)
    if abs(lon - ANCHOR_LON_DEG) > ANCHOR_LON_TOL_DEG:
        raise SystemExit(
            "47.a anchor regression: lon %.6f deg, expected %.6f +/- %.4f"
            % (lon, ANCHOR_LON_DEG, ANCHOR_LON_TOL_DEG))
    if not 350000.0 < dist < 410000.0 or abs(lat) > 6.0:
        raise SystemExit(
            "47.a anchor out of range: lat %.6f deg dist %.3f km"
            % (lat, dist))
    for jd in CHECK_EPOCHS:
        ref = theory.spherical(jd)
        got = eval_flat(counts, flat, w1, jd)
        for name, a, b, tol in (("lon", ref[0], got[0], FLAT_LON_LAT_TOL_DEG),
                               ("lat", ref[1], got[1], FLAT_LON_LAT_TOL_DEG),
                               ("dist", ref[2], got[2], FLAT_DIST_TOL_KM)):
            if abs(a - b) > tol:
                raise SystemExit(
                    "flat-table mirror disagrees at JD %.1f: %s %.9f vs %.9f"
                    % (jd, name, b, a))
    for v in flat:
        s = fmt(v)
        back = float(s)
        if abs(back - v) > 1e-11 * max(1.0, abs(v)):
            raise SystemExit("format round-trip failure: %r -> %s" % (v, s))
    return lon, lat, dist


def dart_body(num_strs, start, end):
    lines = []
    for lo in range(start, end, NUMS_PER_LINE):
        hi = min(lo + NUMS_PER_LINE, end)
        lines.append("  " + ", ".join(num_strs[lo:hi]) + ",")
    return "\n".join(lines)


def chunk_parts(num_strs):
    """Split the formatted numbers into parts under the byte target."""
    parts = []
    cur = []
    size = 0
    for s in num_strs:
        if size and size + len(s) > PART_BYTES_TARGET:
            parts.append(cur)
            cur = []
            size = 0
        cur.append(s)
        size += len(s) + 2
    if cur:
        parts.append(cur)
    return parts


PART_HEADER = """// GENERATED FILE - tools/sweph/elp_build_table.py - DO NOT EDIT.
// Vendored ELP2000-82B truncated lunar theory, chunk %d of %d.
// Layout, provenance and license: see elp_table.dart.

const List<double> kElpTermsPart%02d = <double>[
%s
];
"""


def write_files(out_dir, theory, counts, flat, w1, anchor):
    os.makedirs(out_dir, exist_ok=True)
    num_strs = [fmt(v) for v in flat]
    parts = chunk_parts(num_strs)

    names = []
    for idx, part in enumerate(parts, 1):
        name = "elp_terms_part%02d.dart" % idx
        names.append(name)
        body = dart_body(part, 0, len(part))
        with open(os.path.join(out_dir, name), "w") as f:
            f.write(PART_HEADER % (idx, len(parts), idx, body))

    main_counts = counts[0] + counts[3] + counts[6]
    other_counts = sum(counts[i] for i in (1, 2, 4, 5, 7, 8))
    total_terms = sum(counts)
    doubles = 6 * main_counts + 4 * other_counts
    assert doubles == len(flat)

    spread = "\n".join(
        "...kElpTermsPart%02d," % i for i in range(1, len(parts) + 1))
    imports = "\n".join("import '%s';" % n for n in names)
    counts_txt = ", ".join(str(c) for c in counts)
    w1_txt = ", ".join(fmt(v) for v in w1[1:6])

    table = """// GENERATED FILE - tools/sweph/elp_build_table.py - DO NOT EDIT.
//
// Vendored ELP2000-82B lunar theory for the nMiti engine moon, NASA
// Five Millennium Canon truncation: periodic terms below 0.0005 arcsec
// in longitude/latitude (~1 m in distance) are neglected - %(terms)d of
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
//   python3 tools/sweph/elp_build_table.py --data-dir build/elp82b \\
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
// Total: %(doubles)d doubles (%(terms)d terms).

%(imports)s

/// Terms per section, in the flat [elpTerms] order: main-lon, fig-lon,
/// planet-lon, main-lat, fig-lat, planet-lat, main-dist, fig-dist,
/// planet-dist.
const List<int> kElpSectionCounts = <int>[%(counts)s];

/// Equinox-of-date mean longitude L' polynomial coefficients (t^0..t^4),
/// radians (Chapront et al. 2002).
const List<double> kElpMeanLongitudeRad = <double>[%(w1)s];

/// The flat coefficient table - see the file header for the layout.
const List<double> elpTerms = <double>[
%(spread)s
];
""" % {"terms": total_terms, "doubles": doubles, "imports": imports,
       "counts": counts_txt, "w1": w1_txt, "spread": spread}

    with open(os.path.join(out_dir, "elp_table.dart"), "w") as f:
        f.write(table)

    return {
        "terms": total_terms,
        "doubles": doubles,
        "parts": len(parts),
        "counts": counts,
        "anchor_lon_deg": anchor[0],
        "anchor_lat_deg": anchor[1],
        "anchor_dist_km": anchor[2],
    }


def main():
    ap = argparse.ArgumentParser(
        description="Generate the vendored ELP2000-82B Dart table.")
    ap.add_argument("--data-dir", default="build/elp82b",
                    help="ELP82B distribution (auto-downloaded if missing)")
    ap.add_argument("--out-dir",
                    default="packages/nepali_panchang/lib/src/elp2000",
                    help="output directory for the Dart files")
    args = ap.parse_args()

    if not os.path.exists(os.path.join(args.data_dir, "ELP1")):
        print("ELP82B data not found in %s - downloading" % args.data_dir)
        download_elp(args.data_dir)

    # The shipped variant: NASA-canonical truncation with the improved
    # Chapront 2002 mean arguments (the spike's go-decision variant).
    theory = ElpTheory(args.data_dir, NASA_TRUNC_ARCSEC, True)
    counts, flat = build_flat(theory)
    anchor = verify(theory, counts, flat, theory.w1)
    info = write_files(args.out_dir, theory, counts, flat, theory.w1,
                       anchor)

    # Anchor values as CI-visible notices: the Dart unit test
    # (moon_47a_test.dart) pins these, and the gate step below regenerates
    # this table on every run - the notices let a reviewer read the
    # current anchor values straight off the run page.
    print("::notice::elp2000 table generated: %(terms)d terms, "
          "%(doubles)d doubles, %(parts)d parts" % info)
    print("::notice::anchor JD 2448724.5 (Meeus 47.a): lon %.6f deg, "
          "lat %.6f deg, dist %.3f km" % anchor)
    print("::notice::wrote %s" % args.out_dir)


if __name__ == "__main__":
    main()
