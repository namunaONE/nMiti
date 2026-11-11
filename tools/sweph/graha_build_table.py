#!/usr/bin/env python3
"""Generate the vendored VSOP87D planetary table for the nMiti graha engine.

HYA-450 Wave 1 (PR-A): builds the truncated VSOP87D series (Bretagnon
& Francou planetary theory, version D: heliocentric, geometric,
dynamical ecliptic and equinox of the date) for Mercury through Saturn
PLUS the Earth leg the geocentric subtraction needs, and emits it as
deterministic Dart source under packages/nepali_panchang/lib/src/graha/:

  graha_table.dart        - layout docs, section counts, the flat list
  graha_terms_partNN.dart - kGrahaTermsPartNN chunks of the flat list

The Earth sections live in this table because the graha channels need
Earth's heliocentric B and R (the legacy vsop87d_earth.dart carries
only the L series, enough for the solar channel it serves - the two
tables share the same source theory and the same truncation spirit,
but the graha engine must not lean on an L-only Earth). The table is
DATA: generated, never hand-edited. Two guards keep it honest (see
tools/sweph/README.md):

- .github/workflows/graha-table-gen.yml regenerates and COMMITS the
  table when the generator changes, so the megabyte-scale coefficient
  lists never have to travel through a review tool that may truncate
  or mangle it;
- the ci.yml "graha VSOP87D vendored table freshness gate" (lands with
  the engine module in this same branch) regenerates the table from
  the build/vsop87 download on every CI run and fails on byte drift.

Truncation: terms with |A| < 1e-8 rad (AU in R) are neglected. The
dropped-tail bound (summed dropped |A| per variable) is computed at
generation time, printed as a CI notice and asserted against a
budget, so an upstream data change cannot silently widen the
truncation error.

Self-verification before writing (fail-loud, no Swiss, no Horizons):

- every term row parses to tag + 18 tokens (the Fortran i3 argument
  fields can run together, e.g. "8-13"; merged tokens are re-split,
  and any unexpected shape fails loudly);
- A = sqrt(S^2 + K^2) within 1e-10 (the file writes all three at 11
  decimals; the measured worst rounding deviation of the triple is
  ~1.0e-11 - e.g. Mercury row A=9.43e-9 - so the 1e-10 band tolerates
  the format's own rounding while still catching real parse slips,
  which shift A by orders of magnitude);
- the 4-digit row tag is 4 + planet + variable + power and must match
  the series header, and per-series term numbers run 1..N;
- Venus L0 term 1 is the published mean-longitude constant 3.17614669689
  rad (measured live within 3e-8); the 1e-4 band catches format and
  ordering bugs without false-tripping on upstream re-issues;
- the emitted flat table is re-evaluated by a mirror of the Dart reader
  and compared against the reference series evaluation at three
  epochs - catches layout/folding bugs;
- every formatted number round-trips within %.12g precision.

License: VSOP87 is public research data (Bureau des Longitudes /
IMCCE). Only numeric facts computed from it are vendored; the theory is
cited academic work (Bretagnon & Francou, Astron. Astrophys. 202, 309
(1988)) and no text or code from the distribution is copied. Stdlib
only.
"""
import argparse
import math
import os
import re
import sys
import urllib.request

PLANETS = [
    # (name, VSOP87D file suffix, VSOP87 planet number)
    ("mercury", "mer", 1),
    ("venus", "ven", 2),
    ("earth", "ear", 3),
    ("mars", "mar", 4),
    ("jupiter", "jup", 5),
    ("saturn", "sat", 6),
]

HEADER_PLANET_NUM = {
    "MERCURY": 1, "VENUS": 2, "EARTH": 3, "MARS": 4, "JUPITER": 5,
    "SATURN": 6,
}

IMCCE_URL = "https://ftp.imcce.fr/pub/ephem/planets/vsop87/VSOP87D.%s"
MIRROR_URL = ("https://raw.githubusercontent.com/ctdk/vsop87/master/"
              "VSOP87D.%s")

# Truncation floor: terms with |A| >= TRUNC_RAD survive (radians for
# L/B, AU for R).
TRUNC_RAD = 1e-8
# Budget on the summed dropped amplitude per (planet, variable). This
# is the WORST-CASE bound (every dropped term aligned in phase); the
# realistic error is the far smaller root-sum-square of the same
# dropped terms. Calibrated against the measured data (e.g. Mars L0:
# last kept amplitude ~4e-8 with ~1000 smaller terms behind it, so the
# aligned bound is order 1e-4-1e-3 rad) - the assert is a tripwire
# against upstream data changes, and the ACTUAL measured tails print as
# CI notices on every run so the floor stays visible.
TAIL_BUDGET = {1: 1e-3, 2: 1e-3, 3: 1e-4}  # rad, rad, AU

A_GUARD_TOL = 1e-10             # |sqrt(S^2+K^2) - A|; measured worst
                                # 11-decimal rounding deviation ~1.0e-11
FLAT_MIRROR_TOL = 1e-7          # rad (AU in R); structure bugs blow up
VENUS_L0_ANCHOR = 3.17614669689  # published lambda(2) mean longitude, rad
VENUS_L0_TOL = 1e-4

CHECK_EPOCHS = [2448724.5, 2451545.0, 2461000.0]

PART_BYTES_TARGET = 32000
NUMS_PER_LINE = 8

HDR = re.compile(r"^\s*VSOP87\s+VERSION\s+D4\s+(\S+)\s+VARIABLE\s+(\d)"
                r"\s+\(LBR\)\s+\*T\*\*(\d)\s+(\d+)\s+TERMS")
ROW = re.compile(r"^\s*4\d{3}\s")
INT_TOKEN = re.compile(r"^[\d-]+$")


def download_vsop87(data_dir):
    os.makedirs(data_dir, exist_ok=True)
    for _, code, _ in PLANETS:
        dest = os.path.join(data_dir, "VSOP87D." + code)
        if os.path.exists(dest):
            continue
        err = None
        for url in (IMCCE_URL % code, MIRROR_URL % code):
            try:
                print("downloading %s" % url)
                with urllib.request.urlopen(url, timeout=180) as resp:
                    blob = resp.read()
                with open(dest, "wb") as f:
                    f.write(blob)
                with open(dest) as f:
                    if not f.readline().lstrip().startswith("VSOP87"):
                        raise ValueError("content sanity check failed")
                err = None
                break
            except Exception as exc:  # noqa: BLE001 - report, try next
                err = exc
                if os.path.exists(dest):
                    os.remove(dest)
        if err is not None:
            raise SystemExit("could not fetch VSOP87D.%s: %s"
                             % (code, err))


def split_jam(tok):
    """The 12 i3 argument fields can run together when adjacent fields
    both fill their width ("8-13" is 8 and -13). Re-split merged integer
    tokens; float fields always carry a decimal point and never merge."""
    if "-" in tok and INT_TOKEN.match(tok):
        return re.findall(r"-?\d+", tok)
    return [tok]


def parse_file(path, planet_num, planet_name):
    """Parse one VSOP87D file into {(var, alpha): [(A, B, C), ...]}."""
    series = {}
    cur = None
    with open(path) as f:
        for lineno, line in enumerate(f, 1):
            m = HDR.match(line)
            if m:
                if HEADER_PLANET_NUM.get(m.group(1)) != planet_num:
                    raise SystemExit(
                        "%s:%d: header planet %r does not match planet "
                        "number %d" % (path, lineno, m.group(1), planet_num))
                var, alpha, nterms = (int(m.group(2)), int(m.group(3)),
                                      int(m.group(4)))
                if (var, alpha) in series:
                    raise SystemExit("%s:%d: duplicate VARIABLE %d "
                                     "*T**%d header" % (path, lineno,
                                                        var, alpha))
                cur = {"var": var, "alpha": alpha, "nterms": nterms,
                       "terms": []}
                series[(var, alpha)] = cur
                continue
            if cur is None or not ROW.match(line):
                continue
            toks = line.split()
            rest = []
            for t in toks[1:]:
                rest.extend(split_jam(t))
            if len(rest) != 18:
                raise SystemExit("%s:%d: row has %d tokens, expected 18: "
                                 "%r" % (path, lineno, len(rest), line))
            tag = toks[0]
            if (int(tag[0]) != 4 or int(tag[1]) != planet_num
                    or int(tag[2]) != cur["var"]
                    or int(tag[3]) != cur["alpha"]):
                raise SystemExit("%s:%d: row tag %r does not match series "
                                 "VARIABLE %d *T**%d of planet %d"
                                 % (path, lineno, tag, cur["var"],
                                    cur["alpha"], planet_num))
            n = int(rest[0])
            try:
                avals = [int(x) for x in rest[1:13]]
            except ValueError:
                raise SystemExit("%s:%d: non-integer argument fields: %r"
                                 % (path, lineno, line))
            S, K, A, B, C = (float(x) for x in rest[13:18])
            if abs(math.hypot(S, K) - A) > A_GUARD_TOL:
                raise SystemExit("%s:%d: A guard failed: S=%r K=%r A=%r"
                                 % (path, lineno, S, K, A))
            cur["terms"].append((n, avals, A, B, C))
    if not series:
        raise SystemExit("%s: no VSOP87 series headers found" % path)
    for (var, alpha), s in series.items():
        if len(s["terms"]) != s["nterms"]:
            raise SystemExit("%s VARIABLE %d *T**%d: %d terms, header "
                             "says %d" % (path, var, alpha,
                                         len(s["terms"]), s["nterms"]))
        for i, t in enumerate(s["terms"], 1):
            if t[0] != i:
                raise SystemExit("%s VARIABLE %d *T**%d: term numbers not "
                                 "sequential at %d" % (path, var, alpha, i))
    return series


def check_anchors(parsed):
    terms = parsed["ven"][(1, 0)]["terms"]
    n, _avals, A, B, C = terms[0]
    if n != 1 or B != 0.0 or C != 0.0:
        raise SystemExit("venus L0 term 1 is not the constant term")
    if abs(A - VENUS_L0_ANCHOR) > VENUS_L0_TOL:
        raise SystemExit("venus L0 anchor %.11f vs published %.11f "
                         "(band %.1e)" % (A, VENUS_L0_ANCHOR, VENUS_L0_TOL))
    return A


def build_flat(parsed):
    """Flatten into 108 sections (6 bodies x 3 variables x 6 powers),
    each term 3 doubles A, B, C; sections with no surviving terms keep
    count 0 so the Dart reader can derive variable and power from the
    section index."""
    counts = []
    flat = []
    tails = {}
    raws = 0
    for _, code, _ in PLANETS:
        series = parsed[code]
        for var in (1, 2, 3):
            tail_var = 0.0
            for alpha in range(6):
                terms = series.get((var, alpha), {}).get("terms", [])
                raws += len(terms)
                kept = [t for t in terms if abs(t[2]) >= TRUNC_RAD]
                for t in terms:
                    if abs(t[2]) < TRUNC_RAD:
                        tail_var += abs(t[2])
                counts.append(len(kept))
                for t in kept:
                    flat.extend([t[2], t[3], t[4]])  # A, B, C
            tails[(code, var)] = tail_var
    return counts, flat, tails, raws


def tau_of(jd):
    # VSOP87 native time unit: thousands of Julian years from J2000.
    return (jd - 2451545.0) / 365250.0


def eval_series(series, var, jd):
    """Reference evaluation of the truncated series (per variable)."""
    tau = tau_of(jd)
    acc = 0.0
    for alpha in range(6):
        terms = series.get((var, alpha), {}).get("terms", [])
        t_alpha = tau ** alpha
        for _n, _a, A, B, C in terms:
            if abs(A) >= TRUNC_RAD:
                acc += t_alpha * A * math.cos(B + C * tau)
    return acc


def eval_flat(counts, flat, jd):
    """Mirror of the Dart reader: walk the sections, term = A, B, C."""
    tau = tau_of(jd)
    out = []
    i = 0
    for ci in range(len(counts)):
        var = (ci % 18) // 6
        alpha = ci % 6
        t_alpha = tau ** alpha
        acc = 0.0
        for _ in range(counts[ci]):
            A, B, C = flat[i], flat[i + 1], flat[i + 2]
            i += 3
            acc += t_alpha * A * math.cos(B + C * tau)
        out.append(acc)
    if i != len(flat):
        raise SystemExit("mirror walk consumed %d of %d doubles"
                         % (i, len(flat)))
    return out


def verify(parsed, counts, flat):
    for jd in CHECK_EPOCHS:
        mirror = eval_flat(counts, flat, jd)
        for pi, (_, code, _) in enumerate(PLANETS):
            series = parsed[code]
            for var in (1, 2, 3):
                ref = eval_series(series, var, jd)
                got = mirror[pi * 3 + (var - 1)]
                if abs(ref - got) > FLAT_MIRROR_TOL:
                    raise SystemExit(
                        "flat mirror disagrees: %s var %d JD %.1f: "
                        "%.12e vs %.12e" % (code, var, jd, got, ref))
    for v in flat:
        s = fmt(v)
        back = float(s)
        if abs(back - v) > 1e-11 * max(1.0, abs(v)):
            raise SystemExit("format round-trip failure: %r -> %s"
                             % (v, s))


def fmt(v):
    """Deterministic %.12g double literal (ELP table convention)."""
    s = "%.12g" % (v,)
    if "." not in s and "e" not in s and "E" not in s:
        s += ".0"  # keep every entry an explicit double literal
    return s


def dart_body(num_strs):
    lines = []
    for lo in range(0, len(num_strs), NUMS_PER_LINE):
        hi = min(lo + NUMS_PER_LINE, len(num_strs))
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


PART_HEADER = """// GENERATED FILE - tools/sweph/graha_build_table.py - DO NOT EDIT.
// Vendored VSOP87D planetary series, chunk %d of %d.
// Layout, provenance and license: see graha_table.dart.

const List<double> kGrahaTermsPart%02d = <double>[
%s
];
"""


def tail_summary(tails):
    worst = {}
    for (code, var), tail in tails.items():
        prev = worst.get(var, ("", 0.0))
        if tail > prev[1]:
            worst[var] = (code, tail)
    names = {1: "L", 2: "B", 3: "R"}
    units = {1: "rad", 2: "rad", 3: "AU"}
    return "; ".join("%s %.2e %s (%s)" % (names[v], worst[v][1],
                                          units[v], worst[v][0])
                     for v in (1, 2, 3))


def write_files(out_dir, counts, flat, tails, anchor):
    os.makedirs(out_dir, exist_ok=True)
    num_strs = [fmt(v) for v in flat]
    parts = chunk_parts(num_strs)

    names = []
    for idx, part in enumerate(parts, 1):
        name = "graha_terms_part%02d.dart" % idx
        names.append(name)
        with open(os.path.join(out_dir, name), "w") as f:
            f.write(PART_HEADER % (idx, len(parts), idx,
                                   dart_body(part)))

    total_terms = sum(counts)
    doubles = 3 * total_terms
    assert doubles == len(flat)

    spread = "\n".join("  ...kGrahaTermsPart%02d," % i
                        for i in range(1, len(parts) + 1))
    imports = "\n".join("import '%s';" % n for n in names)
    counts_txt = ", ".join(str(c) for c in counts)

    table = """// GENERATED FILE - tools/sweph/graha_build_table.py - DO NOT EDIT.
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
// Worst dropped-tail bounds at generation: %(tail_line)s
// (aligned worst case; the realistic error is the much smaller
// root-sum-square of the same dropped terms).
//
// Regenerate:
//   python3 tools/sweph/graha_build_table.py --data-dir build/vsop87 \\
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
// the native VSOP87 time unit). Total: %(doubles)d doubles
// (%(terms)d terms).

%(imports)s

/// Term counts of the 108 sections - body x variable (1=L, 2=B,
/// 3=R) x power (T^0..T^5), in flat [kGrahaTerms] order.
const List<int> kGrahaSectionCounts = <int>[%(counts_txt)s];

/// The flat coefficient table - see the file header for the layout.
const List<double> kGrahaTerms = <double>[
%(spread)s
];
""" % {"tail_line": tail_summary(tails), "doubles": doubles,
       "terms": total_terms, "imports": imports,
       "counts_txt": counts_txt, "spread": spread}

    with open(os.path.join(out_dir, "graha_table.dart"), "w") as f:
        f.write(table)

    return {"terms": total_terms, "doubles": doubles,
            "parts": len(parts)}


def main():
    ap = argparse.ArgumentParser(
        description="Generate the vendored VSOP87D graha Dart table.")
    ap.add_argument("--data-dir", default="build/vsop87",
                    help="VSOP87D downloads (auto-fetched if missing)")
    ap.add_argument("--out-dir",
                    default="packages/nepali_panchang/lib/src/graha",
                    help="output directory for the Dart files")
    args = ap.parse_args()

    download_vsop87(args.data_dir)
    parsed = {}
    for name, code, num in PLANETS:
        parsed[code] = parse_file(
            os.path.join(args.data_dir, "VSOP87D." + code), num, name)
    anchor = check_anchors(parsed)
    counts, flat, tails, raws = build_flat(parsed)
    for (code, var), tail in sorted(tails.items()):
        if tail > TAIL_BUDGET[var]:
            raise SystemExit(
                "dropped tail %s var %d = %.3e exceeds budget %.1e - "
                "truncation error budget needs a conscious re-look"
                % (code, var, tail, TAIL_BUDGET[var]))
    verify(parsed, counts, flat)
    info = write_files(args.out_dir, counts, flat, tails, anchor)
    info["raws"] = raws

    print("::notice::graha VSOP87D table generated: %(terms)d terms "
          "(of %(raws)d raw), %(doubles)d doubles, %(parts)d parts" % info)
    print("::notice::venus L0 anchor A = %.11f rad "
          "(published 3.17614669689)" % anchor)
    print("::notice::worst dropped-tail bounds: %s"
          % tail_summary(tails))
    print("::notice::wrote %s" % args.out_dir)


if __name__ == "__main__":
    main()
