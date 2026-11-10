#!/usr/bin/env python3
"""ELP2000-82B truncation spike: what would a NASA-canon-class moon cost,
and what would it buy (HYA-369 follow-up, engine-perfection research
move #2)?

Downloads the ELP2000-82B semi-analytical lunar theory (Chapront-Touze &
Chapront 1983, A&A 124, 50; distributed by IMCCE/Bureau des Longitudes) at
CI time, truncates it per the NASA Five Millennium Canon recipe (neglect
periodic terms smaller than 0.0005 arcsec in longitude and latitude, and
smaller than about 1 m in distance - one `prec` knob in the original
evaluator), and measures at the engine's own limb-boundary instants:

 1. the survivor term counts per file and the total - the Dart port
    size, plus an evaluation timing benchmark;
 2. the moon longitude accuracy of the truncated theory against Swiss
    Ephemeris (geometric, mean equinox of date - the exact frame of the
    engine's Meeus Ch.47 moon), in both argument variants:
    (a) raw ELP82B (1983 mean elements, DE200 fit corrections) and
    (b) NASA-canonical: the improved mean arguments L', D, M, M', F of
        Chapront-Chapront-Touze-Francou (2002) - the same polynomials
        the engine's moon.dart already uses;
 3. the current engine moon's truncation-error curve vs the same Swiss
    geometric truth - the error the upgrade would remove;
 4. the PREDICTED post-upgrade tithi/karana bands: the moon substitution
    shifts every boundary by (lambda_elp - lambda_engine)/rate, applied
    to the per-boundary Swiss deltas from the sweph_crosscheck receipts
    - plus two floors: a perfect geometric moon (Swiss geometric
    substituted) and a perfect apparent moon (Swiss apparent
    substituted, which also removes the named-skipped light-time) - the
    decomposition ladder that makes the go/no-go call.

The evaluator is a faithful port of the reference Fortran subroutine
elp82b_1 (IMCCE, 1996): the same mean elements, the same DE200/LE200 fit
correction machinery (delnu/dele/delg/delnp/delep applied per main-
problem term), the same record formats (4i3,2x,f13.5,6(2x,f10.2) for the
main problem, 5i3,1x,f9.5,1x,f9.5 for the figure/tide/relativity files,
11i3,1x,f9.5,1x,f9.5 for the planetary files), stopping before the
subroutine's final precession rotation so the output is the spherical
position in the mean dynamical ecliptic of date - the engine's frame.
TT and TDB differ by ~1.6 ms (~0.0003 arcsec of moon motion), far below
the NASA truncation class, and are not distinguished.

LICENSE BOUNDARY: ELP2000-82B is public research data from the Bureau des
Longitudes/IMCCE. This spike downloads it at CI time and emits only
numeric facts (counts, deltas, timings); nothing from it ships in any
artifact and the MIT engine is untouched by this step. A future engine
upgrade PR would vendor the truncated public-domain coefficient table
with full citation - a separate decision with its own review.
"""

import argparse
import json
import math
import os
import sys
import time
import traceback
import urllib.request

try:
    import swisseph as swe
except ImportError:
    print("pyswisseph is required: python3 -m pip install pyswisseph",
          file=sys.stderr)
    raise

ELP_BASE = "https://ftp.imcce.fr/pub/ephem/moon/elp82b/"
# NASA Five Millennium Canon truncation recipe: neglect periodic terms
# with coefficients smaller than 0.0005 arcsec in longitude and latitude.
# In the original evaluator the same `prec` knob gives 0.0005 arcsec ->
# prec*ath = 0.93 m in distance (the canon quotes "smaller than 1 m").
NASA_TRUNC_ARCSEC = 0.0005
RAD = 648000.0 / math.pi  # arcsec per radian
DEG = math.pi / 180.0
HALF_PI = math.pi / 2.0
# Record counts from the IMCCE README (each file carries one header
# line; the parser asserts the data-line counts against these with a
# small tolerance - the README counts header lines inconsistently).
ELP_EXPECTED_DATA = {1: 1023, 2: 918, 3: 704, 4: 347, 5: 316, 6: 237,
                     7: 14, 8: 11, 9: 8, 10: 14328, 11: 5233, 12: 6631,
                     13: 4384, 14: 833, 15: 1715, 16: 170, 17: 150,
                     18: 114, 19: 226, 20: 188, 21: 169, 22: 3, 23: 2,
                     24: 2, 25: 6, 26: 4, 27: 5, 28: 20, 29: 12, 30: 14,
                     31: 11, 32: 4, 33: 10, 34: 28, 35: 13, 36: 19}


def annotate(msg, kind="notice"):
    """GitHub Actions annotation; the run page renders the annotations
    table server-side without log access. No-op outside Actions."""
    if os.environ.get("GITHUB_ACTIONS") != "true":
        return
    one_line = " ".join(str(msg).split())
    if len(one_line) > 900:
        one_line = one_line[:900] + "... (truncated)"
    print("::%s::%s" % (kind, one_line.replace("%", "%25")))


def annotate_error(msg):
    annotate(msg, "error")


def download_elp(data_dir):
    """Fetch the 36 ELP2000-82B data files from IMCCE (about 3 MB)."""
    os.makedirs(data_dir, exist_ok=True)
    for n in range(1, 37):
        name = "ELP%d" % n
        path = os.path.join(data_dir, name)
        if os.path.exists(path) and os.path.getsize(path) > 0:
            continue
        with urllib.request.urlopen(ELP_BASE + name, timeout=120) as resp:
            data = resp.read()
        with open(path, "wb") as f:
            f.write(data)
    total = sum(os.path.getsize(os.path.join(data_dir, "ELP%d" % n))
                for n in range(1, 37))
    print("ELP82B data ready: 36 files, %.1f KB total" % (total / 1024.0))


def _ints(line, count):
    return [int(line[3 * i:3 * i + 3]) for i in range(count)]


def _num(line, start, width):
    return float(line[start:start + width])


class ElpTheory:
    """The truncated ELP2000-82B series in one argument variant.

    Faithful port of the reference Fortran subroutine elp82b_1 (IMCCE
    1996): mean elements, DE200/LE200 fit corrections and record
    formats are transcribed exactly; the truncation threshold follows
    the NASA Five Millennium Canon recipe. The spherical output is the
    mean dynamical ecliptic of date (the frame before the Fortran's
    final J2000 rotation).
    """

    def __init__(self, data_dir, arcsec_trunc, use_2002_arguments):
        self.use_2002 = use_2002_arguments
        trunc = arcsec_trunc - 1.0e-12
        self.pre = [0.0, trunc, trunc, trunc / RAD * 384747.9806743165]
        # --- elp82b_1 initialisation block (arcsec/cy^k -> radians) ---
        self.ath = 384747.9806743165
        self.a0 = 384747.9806448954
        am = 0.074801329518
        alfa = 0.002571881335
        dtasm = 2.0 * alfa / (3.0 * am)
        w = [[0.0] * 6 for _ in range(4)]  # w[i][k], i = 1..3, k = 1..5
        w[1][1] = (218 + 18 / 60 + 59.95571 / 3600) * DEG
        w[2][1] = (83 + 21 / 60 + 11.67475 / 3600) * DEG
        w[3][1] = (125 + 2 / 60 + 40.39816 / 3600) * DEG
        eart = [(100 + 27 / 60 + 59.22059 / 3600) * DEG,
                129597742.2758 / RAD, -0.0202 / RAD, 0.9e-5 / RAD,
                0.15e-6 / RAD]
        peri = [(102 + 56 / 60 + 14.42753 / 3600) * DEG,
                1161.2283 / RAD, 0.5327 / RAD, -0.138e-3 / RAD, 0.0]
        w[1][2] = 1732559343.73604 / RAD
        w[2][2] = 14643420.2632 / RAD
        w[3][2] = -6967919.3622 / RAD
        w[1][3] = -5.8883 / RAD
        w[2][3] = -38.2776 / RAD
        w[3][3] = 6.3622 / RAD
        w[1][4] = 0.6604e-2 / RAD
        w[2][4] = -0.45047e-1 / RAD
        w[3][4] = 0.7625e-2 / RAD
        w[1][5] = -0.3169e-4 / RAD
        w[2][5] = 0.21301e-3 / RAD
        w[3][5] = -0.3586e-4 / RAD
        preces = 5029.0966 / RAD
        # Planetary mean longitudes (Mercury..Neptune): const + rate.
        p = [[0.0, 0.0, 0.0] for _ in range(9)]
        p[1][1] = (252 + 15 / 60 + 3.25986 / 3600) * DEG
        p[1][2] = 538101628.68898 / RAD
        p[2][1] = (181 + 58 / 60 + 47.28305 / 3600) * DEG
        p[2][2] = 210664136.43355 / RAD
        p[3][1] = eart[0]
        p[3][2] = eart[1]
        p[4][1] = (355 + 25 / 60 + 59.78866 / 3600) * DEG
        p[4][2] = 68905077.59284 / RAD
        p[5][1] = (34 + 21 / 60 + 5.34212 / 3600) * DEG
        p[5][2] = 10925660.42861 / RAD
        p[6][1] = (50 + 4 / 60 + 38.89694 / 3600) * DEG
        p[6][2] = 4399609.65932 / RAD
        p[7][1] = (314 + 3 / 60 + 18.01841 / 3600) * DEG
        p[7][2] = 1542481.19393 / RAD
        p[8][1] = (304 + 20 / 60 + 55.19575 / 3600) * DEG
        p[8][2] = 786550.32074 / RAD
        # Corrections of the constants (the fit to DE200/LE200).
        delnu = 0.55604 / RAD / w[1][2]
        dele = 0.01789 / RAD
        delg = -0.08066 / RAD
        delnp = -0.06424 / RAD / w[1][2]
        delep = -0.12879 / RAD
        # Delaunay arguments del[i][k] (radians, k = 1..5).
        d = [[0.0] * 6 for _ in range(5)]
        for k in range(1, 6):
            d[1][k] = w[1][k] - eart[k - 1]
            d[2][k] = eart[k - 1] - peri[k - 1]
            d[3][k] = w[1][k] - w[2][k]
            d[4][k] = w[1][k] - w[3][k]
        d[1][1] += math.pi
        zeta = [0.0, w[1][1], w[1][2] + preces]

        if use_2002_arguments:
            # NASA-canonical: the improved mean arguments of
            # Chapront-Chapront-Touze-Francou (2002) - identical to the
            # polynomials in the engine's moon.dart (Meeus Ch.47).
            # Powers beyond the published expressions are zero (the raw
            # t^5 argument terms are ~1e-13 deg at the 2026 epoch).
            lp = [218.3164477, 481267.88123421, -0.0015786,
                  1.0 / 538841, -1.0 / 65194000]
            dd = [297.8501921, 445267.1114034, -0.0018819,
                  1.0 / 545868, -1.0 / 113065000]
            mm = [357.5291092, 35999.0502909, -0.0001536,
                  1.0 / 24490000, 0.0]
            mp = [134.9633964, 477198.8675055, 0.0087414,
                  1.0 / 69699, -1.0 / 14712000]
            ff = [93.2720950, 483202.0175233, -0.0036539,
                  -1.0 / 3526000, 1.0 / 863310000]
            lp, dd, mm, mp, ff = ([v * DEG for v in row]
                                 for row in (lp, dd, mm, mp, ff))
            w[1] = [0.0, lp[0], lp[1], lp[2], lp[3], lp[4]]
            for k in range(1, 6):
                idx = k - 1
                d[1][k] = dd[idx]
                d[2][k] = mm[idx]
                d[3][k] = mp[idx]
                d[4][k] = ff[idx]
            d[1][1] += math.pi  # the ELP D convention: D + 180 deg
            zeta = [0.0, lp[0], lp[1] + preces]
            # Earth mean longitude L = L' - D for the planetary args.
            p[3][1] = lp[0] - dd[0]
            p[3][2] = lp[1] - dd[1]

        self.w1 = w[1]
        self.p = p
        self.d = d
        self.zeta = zeta
        self._fit = (delnu, dele, delg, delnp, delep, am, dtasm)

        # Survivors per coordinate.
        self.main = [[], [], [], []]   # (arg c1..c5, amplitude)
        self.fig = [[], [], [], []]    # (a1, a2, amplitude, tpow)
        self.planet = [[], [], [], []]  # (b1, b2-b1, amplitude, tpow)
        self.counts = {}
        self._parse(data_dir)

    # ---- parsing ----------------------------------------------------

    def _parse(self, data_dir):
        (fit_delnu, fit_dele, fit_delg, fit_delnp, fit_delep,
         am, dtasm) = self._fit
        for n in range(1, 37):
            with open(os.path.join(data_dir, "ELP%d" % n), "rb") as f:
                raw = f.read().decode("ascii")
            lines = [ln for ln in raw.split("\n") if ln.strip()]
            data_lines = lines[1:]  # line 0 is the file header
            expected = ELP_EXPECTED_DATA[n]
            if abs(len(data_lines) - expected) > 2:
                raise RuntimeError(
                    "ELP%d: %d data lines, README says about %d"
                    % (n, len(data_lines), expected))
            iv = ((n - 1) % 3) + 1  # 1 longitude, 2 latitude, 3 distance
            kept = 0
            for ln in data_lines:
                if 1 <= n <= 3:
                    # format 1001: 4i3,2x,f13.5,6(2x,f10.2)
                    ilu = _ints(ln, 4)
                    c1 = _num(ln, 14, 13)
                    coef = [c1]
                    for j in range(6):
                        coef.append(_num(ln, 29 + 10 * j, 10))
                    if abs(c1) < self.pre[iv]:
                        continue
                    if n == 3:
                        coef[0] = c1 - 2.0 * c1 * fit_delnu / 3.0
                    tgv = coef[1] + dtasm * coef[5]
                    xc = (coef[0] + tgv * (fit_delnp - am * fit_delnu) +
                          coef[2] * fit_delg + coef[3] * fit_dele +
                          coef[4] * fit_delep)
                    arg = [0.0] * 5
                    for k in range(1, 6):
                        s = 0.0
                        for i in range(1, 5):
                            s += ilu[i - 1] * self.d[i][k]
                        arg[k - 1] = s
                    self.main[iv].append((arg, xc))
                elif 4 <= n <= 9 or 22 <= n <= 36:
                    # format 1002: 5i3,1x,f9.5,1x,f9.5
                    vals = _ints(ln, 5)
                    iz, ilu = vals[0], vals[1:]
                    pha = _num(ln, 16, 9) * DEG
                    x = _num(ln, 26, 9)
                    if x < self.pre[iv]:
                        continue
                    tpow = 0
                    if 7 <= n <= 9 or 25 <= n <= 27:
                        tpow = 1
                    elif 34 <= n <= 36:
                        tpow = 2
                    a1 = pha + iz * self.zeta[1]
                    a2 = iz * self.zeta[2]
                    for i in range(1, 5):
                        a1 += ilu[i - 1] * self.d[i][1]
                        a2 += ilu[i - 1] * self.d[i][2]
                    self.fig[iv].append((a1, a2, x, tpow))
                else:
                    # format 1003: 11i3,1x,f9.5,1x,f9.5 (ELP10..21)
                    ipla = _ints(ln, 11)
                    pha = _num(ln, 34, 9) * DEG
                    x = _num(ln, 44, 9)
                    if x < self.pre[iv]:
                        continue
                    tpow = 1 if (13 <= n <= 15 or 19 <= n <= 21) else 0
                    table1 = n < 16
                    b1 = pha
                    b2 = pha
                    if table1:
                        for i in range(1, 9):
                            b1 += ipla[i - 1] * self.p[i][1]
                            b2 += ipla[i - 1] * self.p[i][2]
                        b1 += (ipla[8] * self.d[1][1] +
                               ipla[9] * self.d[3][1] +
                               ipla[10] * self.d[4][1])
                        b2 += (ipla[8] * self.d[1][2] +
                               ipla[9] * self.d[3][2] +
                               ipla[10] * self.d[4][2])
                    else:
                        for i in range(1, 8):
                            b1 += ipla[i - 1] * self.p[i][1]
                            b2 += ipla[i - 1] * self.p[i][2]
                        for i in range(1, 5):
                            b1 += ipla[i + 6] * self.d[i][1]
                            b2 += ipla[i + 6] * self.d[i][2]
                    self.planet[iv].append((b1, b2 - b1, x, tpow))
                kept += 1
            self.counts[n] = (kept, len(data_lines))

    # ---- evaluation -------------------------------------------------

    def survivor_terms(self):
        return sum(len(g[iv]) for g in (self.main, self.fig, self.planet)
                   for iv in (1, 2, 3))

    def spherical(self, jd_tt):
        """Spherical position in the mean dynamical ecliptic of date:
        (longitude_deg, latitude_deg, distance_km) - the frame of the
        engine's Meeus Ch.47 moon (geometric, no nutation)."""
        t = (jd_tt - 2451545.0) / 36525.0
        sin = math.sin
        r1 = r2 = r3 = 0.0
        for arg, x in self.main[1]:
            r1 += x * sin(arg[0] + (arg[1] + (arg[2] + (arg[3] + arg[4] * t) * t) * t) * t)
        for arg, x in self.main[2]:
            r2 += x * sin(arg[0] + (arg[1] + (arg[2] + (arg[3] + arg[4] * t) * t) * t) * t)
        for arg, x in self.main[3]:
            r3 += x * sin(arg[0] + (arg[1] + (arg[2] + (arg[3] + arg[4] * t) * t) * t) * t + HALF_PI)
        for a1, a2, x, tp in self.fig[1]:
            r1 += (x if tp == 0 else (x * t if tp == 1 else x * t * t)) * sin(a1 + a2 * t)
        for a1, a2, x, tp in self.fig[2]:
            r2 += (x if tp == 0 else (x * t if tp == 1 else x * t * t)) * sin(a1 + a2 * t)
        for a1, a2, x, tp in self.fig[3]:
            r3 += (x if tp == 0 else (x * t if tp == 1 else x * t * t)) * sin(a1 + a2 * t)
        for b1, db, x, tp in self.planet[1]:
            r1 += (x if tp == 0 else x * t) * sin(b1 + db * t)
        for b1, db, x, tp in self.planet[2]:
            r2 += (x if tp == 0 else x * t) * sin(b1 + db * t)
        for b1, db, x, tp in self.planet[3]:
            r3 += (x if tp == 0 else x * t) * sin(b1 + db * t)
        w1 = self.w1
        lon = r1 / RAD + w1[1] + (w1[2] + (w1[3] + (w1[4] + w1[5] * t) * t) * t) * t
        lon %= 2.0 * math.pi
        return math.degrees(lon), math.degrees(r2 / RAD), \
            r3 * (self.a0 / self.ath)


def stats(values):
    v = sorted(values)
    n = len(v)
    return {
        "n": n,
        "mean_s": round(sum(v) / n, 2) if n else None,
        "max_s": round(v[-1], 2) if n else None,
    }


def norm360(x):
    return x % 360.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--instants", required=True,
                    help="limb_instants.json from dump_limb_instants")
    ap.add_argument("--receipts", required=True,
                    help="sweph_receipts.json from sweph_crosscheck (the "
                         "per-boundary Swiss deltas this spike builds on)")
    ap.add_argument("--data-dir", default="build/elp82b",
                    help="directory for the downloaded ELP82B files")
    ap.add_argument("--out", default=None, help="output receipts JSON path")
    ap.add_argument("--summary", default=None, help="markdown summary path")
    ap.add_argument("--trim-days", type=float, default=1.0,
                    help="interior trim, mirroring sweph_crosscheck")
    args = ap.parse_args()

    with open(args.instants) as f:
        dump = json.load(f)
    with open(args.receipts) as f:
        receipts = json.load(f)
    window = dump["window"]
    receipt_by_key = {}
    for row in receipts.get("boundaries", []):
        if row.get("limb") in ("tithi", "karana"):
            receipt_by_key[(row["limb"], row["utc"])] = row

    jd_start = julian_day_of(window["start"])
    jd_end = julian_day_of(window["end"])
    lo_limit = jd_start + args.trim_days
    hi_limit = jd_end - args.trim_days

    download_elp(args.data_dir)
    t0 = time.perf_counter()
    theory_raw = ElpTheory(args.data_dir, NASA_TRUNC_ARCSEC, False)
    theory_2002 = ElpTheory(args.data_dir, NASA_TRUNC_ARCSEC, True)
    parse_s = time.perf_counter() - t0

    total_kept = theory_2002.survivor_terms()
    lon_kept = sum(len(theory_2002.main[1]) + len(theory_2002.fig[1]) +
                   len(theory_2002.planet[1]) for _ in (0,))
    lat_kept = len(theory_2002.main[2]) + len(theory_2002.fig[2]) + \
        len(theory_2002.planet[2])
    dist_kept = len(theory_2002.main[3]) + len(theory_2002.fig[3]) + \
        len(theory_2002.planet[3])
    full_terms = sum(total for _kept, total in theory_2002.counts.values())
    print("ELP terms kept at %.4f arcsec: %d of %d "
          "(longitude %d, latitude %d, distance %d); parse %.2fs"
          % (NASA_TRUNC_ARCSEC, total_kept, full_terms,
             lon_kept, lat_kept, dist_kept, parse_s))

    # Evaluation timing (the Dart cost extrapolation input).
    bench_jd = 2461352.5
    t0 = time.perf_counter()
    reps = 25
    for _ in range(reps):
        theory_2002.spherical(bench_jd)
    eval_ms = (time.perf_counter() - t0) * 1000.0 / reps
    print("ELP evaluation: %.2f ms per spherical() in CPython "
          "(%d terms)" % (eval_ms, total_kept))

    # Swiss helpers. Apparent (the scoreboard truth convention) is
    # calc_ut on UT; geometric mean-of-date (the moon-vs-moon
    # comparison frame) is calc on the engine's TT instant with
    # NONUT | NOABERR | TRUEPOS.
    app_flags = swe.FLG_MOSEPH
    if not hasattr(swe, "FLG_TRUEPOS"):
        raise RuntimeError(
            "pyswisseph lacks FLG_TRUEPOS; cannot build the geometric "
            "mean-of-date comparison frame")
    geo_flags = (swe.FLG_MOSEPH | swe.FLG_NONUT | swe.FLG_NOABERR |
                 swe.FLG_TRUEPOS)

    def sw_app_moon(jd_tt):
        xx, _ = swe.calc(jd_tt, swe.MOON, app_flags)
        return xx[0]

    def sw_geo_moon(jd_tt):
        xx, _ = swe.calc(jd_tt, swe.MOON, geo_flags)
        return xx[0]

    def sw_elong_rate(jd_ut):
        h = 0.25

        def elong(ut):
            m, _ = swe.calc_ut(ut, swe.MOON, app_flags)
            s, _ = swe.calc_ut(ut, swe.SUN, app_flags)
            return norm360(m[0] - s[0])

        e2 = elong(jd_ut + h)
        e1 = elong(jd_ut - h)
        return (((e2 - e1 + 540.0) % 360.0) - 180.0) / (2.0 * h)

    moon_rows = []
    moon_acc = {}
    per_limb = {}
    for limb in ("tithi", "karana"):
        rows = dump["boundaries"].get(limb, [])
        cur, pred_raw, pred_2002 = [], [], []
        floor_geo, floor_app = [], []
        eng_err, elp_raw_err, elp_2002_err, app_minus_geo = [], [], [], []
        for r in rows:
            jd_ut = r["jd_ut"]
            if jd_ut < lo_limit or jd_ut > hi_limit:
                continue
            if "moon_deg" not in r:
                raise RuntimeError(
                    "%s boundary at %s: dump lacks moon_deg - regenerate "
                    "with the updated dump_limb_instants"
                    % (limb, r.get("utc", "?")))
            key = (limb, r["utc"])
            if key not in receipt_by_key:
                raise RuntimeError(
                    "%s boundary at %s: no sweph_crosscheck receipt row"
                    % (limb, r["utc"]))
            delta_s = receipt_by_key[key]["delta_s"]
            jd_tt = r["jd_tt"]
            moon_eng = r["moon_deg"]
            moon_sw_geo = sw_geo_moon(jd_tt)
            moon_sw_app = sw_app_moon(jd_tt)
            lon_raw, _lat_raw, _dist = theory_raw.spherical(jd_tt)
            lon_2002, _lat_2002, _dist2 = theory_2002.spherical(jd_tt)
            rate = sw_elong_rate(jd_ut)

            def shifted(d_moon, _rate=rate, _delta=delta_s):
                # The moon substitution moves the boundary by
                # -d_moon/rate days; the Swiss delta shifts with it.
                return _delta + d_moon / _rate * 86400.0

            cur.append(delta_s)
            pred_raw.append(shifted(lon_raw - moon_eng))
            pred_2002.append(shifted(lon_2002 - moon_eng))
            floor_geo.append(shifted(moon_sw_geo - moon_eng))
            floor_app.append(shifted(moon_sw_app - moon_eng))
            eng_err.append((moon_eng - moon_sw_geo) * 3600.0)
            elp_raw_err.append((lon_raw - moon_sw_geo) * 3600.0)
            elp_2002_err.append((lon_2002 - moon_sw_geo) * 3600.0)
            app_minus_geo.append((moon_sw_app - moon_sw_geo) * 3600.0)
            if limb == "tithi":
                moon_rows.append({
                    "utc": r["utc"], "jd_tt": jd_tt,
                    "moon_engine_deg": moon_eng,
                    "moon_elp2002_deg": lon_2002,
                    "moon_elp_raw_deg": lon_raw,
                    "moon_swiss_geometric_deg": moon_sw_geo,
                    "moon_swiss_apparent_deg": moon_sw_app,
                    "engine_minus_swiss_geo_arcsec":
                        round((moon_eng - moon_sw_geo) * 3600.0, 4),
                    "elp2002_minus_swiss_geo_arcsec":
                        round((lon_2002 - moon_sw_geo) * 3600.0, 4),
                    "swiss_app_minus_geo_arcsec":
                        round((moon_sw_app - moon_sw_geo) * 3600.0, 4),
                    "elong_rate_deg_per_day": round(rate, 6),
                    "delta_s_current": round(delta_s, 2),
                    "delta_s_pred_elp2002": round(pred_2002[-1], 2),
                    "delta_s_floor_geo": round(floor_geo[-1], 2),
                    "delta_s_floor_app": round(floor_app[-1], 2),
                })

        def signed(vals):
            return round(sum(vals) / len(vals), 2) if vals else None

        per_limb[limb] = {
            "n": len(cur),
            "current": {**stats([abs(v) for v in cur]),
                        "signed_mean_s": signed(cur)},
            "pred_elp_raw": {**stats([abs(v) for v in pred_raw]),
                             "signed_mean_s": signed(pred_raw)},
            "pred_elp_2002": {**stats([abs(v) for v in pred_2002]),
                              "signed_mean_s": signed(pred_2002)},
            "floor_perfect_geometric": {
                **stats([abs(v) for v in floor_geo]),
                "signed_mean_s": signed(floor_geo)},
            "floor_perfect_apparent": {
                **stats([abs(v) for v in floor_app]),
                "signed_mean_s": signed(floor_app)},
        }
        moon_acc = {
            "engine_meeus_vs_swiss_geo_arcsec": {
                **stats([abs(v) for v in eng_err]),
                "signed_mean": signed(eng_err)},
            "elp_raw_vs_swiss_geo_arcsec": {
                **stats([abs(v) for v in elp_raw_err]),
                "signed_mean": signed(elp_raw_err)},
            "elp_2002_vs_swiss_geo_arcsec": {
                **stats([abs(v) for v in elp_2002_err]),
                "signed_mean": signed(elp_2002_err)},
            "swiss_app_minus_geo_arcsec": {
                **stats([abs(v) for v in app_minus_geo]),
                "signed_mean": signed(app_minus_geo)},
        }
        print("ELP spike %-6s n=%-3d current %.1f|%.0fs -> elp2002 "
              "%.1f|%.0fs | floor(geo moon) %.1f|%.0fs | floor(app moon) "
              "%.1f|%.0fs"
              % (limb, len(cur),
                 per_limb[limb]["current"]["mean_s"],
                 per_limb[limb]["current"]["max_s"],
                 per_limb[limb]["pred_elp_2002"]["mean_s"],
                 per_limb[limb]["pred_elp_2002"]["max_s"],
                 per_limb[limb]["floor_perfect_geometric"]["mean_s"],
                 per_limb[limb]["floor_perfect_geometric"]["max_s"],
                 per_limb[limb]["floor_perfect_apparent"]["mean_s"],
                 per_limb[limb]["floor_perfect_apparent"]["max_s"]))

    # ---- annotations (own CI step: its own annotation budget) ------
    annotate("ELP terms kept at NASA %.4f arcsec/~1m recipe: %d of %d "
             "(lon %d, lat %d, dist %d); eval %.2f ms CPython"
             % (NASA_TRUNC_ARCSEC, total_kept, full_terms, lon_kept,
                lat_kept, dist_kept, eval_ms))
    annotate("ELP moon accuracy vs Swiss geometric (arcsec): "
             "2002-args mean=%.3f max=%.3f signed=%+.3f; "
             "raw-82B-args mean=%.3f max=%.3f signed=%+.3f"
             % (moon_acc["elp_2002_vs_swiss_geo_arcsec"]["mean_s"],
                moon_acc["elp_2002_vs_swiss_geo_arcsec"]["max_s"],
                moon_acc["elp_2002_vs_swiss_geo_arcsec"]["signed_mean"],
                moon_acc["elp_raw_vs_swiss_geo_arcsec"]["mean_s"],
                moon_acc["elp_raw_vs_swiss_geo_arcsec"]["max_s"],
                moon_acc["elp_raw_vs_swiss_geo_arcsec"]["signed_mean"]))
    annotate("Engine Meeus moon vs Swiss geometric (arcsec): "
             "mean=%.3f max=%.3f signed=%+.3f | Swiss apparent-geometric "
             "(light-time+aberration+nutation): mean=%.3f signed=%+.3f"
             % (moon_acc["engine_meeus_vs_swiss_geo_arcsec"]["mean_s"],
                moon_acc["engine_meeus_vs_swiss_geo_arcsec"]["max_s"],
                moon_acc["engine_meeus_vs_swiss_geo_arcsec"]["signed_mean"],
                moon_acc["swiss_app_minus_geo_arcsec"]["mean_s"],
                moon_acc["swiss_app_minus_geo_arcsec"]["signed_mean"]))
    for limb in ("tithi", "karana"):
        cur = per_limb[limb]["current"]
        p02 = per_limb[limb]["pred_elp_2002"]
        praw = per_limb[limb]["pred_elp_raw"]
        fgeo = per_limb[limb]["floor_perfect_geometric"]
        fapp = per_limb[limb]["floor_perfect_apparent"]
        annotate("ELP spike %s predicted band (s): current %.1f|%.0f "
                 "signed %+.1f -> ELP2002 %.1f|%.0f signed %+.1f | "
                 "raw82B %.1f|%.0f | floor geo-moon %.1f|%.0f | "
                 "floor app-moon %.1f|%.0f"
                 % (limb, cur["mean_s"], cur["max_s"],
                    cur["signed_mean_s"],
                    p02["mean_s"], p02["max_s"], p02["signed_mean_s"],
                    praw["mean_s"], praw["max_s"],
                    fgeo["mean_s"], fgeo["max_s"],
                    fapp["mean_s"], fapp["max_s"]))

    if args.out:
        out = {
            "recipe": "NASA Five Millennium Canon: neglect < %.4f arcsec "
                      "longitude/latitude, < ~1 m distance" %
                      NASA_TRUNC_ARCSEC,
            "terms": {
                "kept": total_kept,
                "full": full_terms,
                "longitude": lon_kept,
                "latitude": lat_kept,
                "distance": dist_kept,
                "per_file": {"ELP%d" % n: {"kept": k, "total": t}
                             for n, (k, t) in sorted(
                                 theory_2002.counts.items())},
            },
            "eval_ms_cpython": round(eval_ms, 3),
            "moon_accuracy_arcsec": moon_acc,
            "bands": per_limb,
            "tithi_boundaries": moon_rows,
        }
        with open(args.out, "w") as f:
            json.dump(out, f, indent=2)
        print("receipts written: %s" % args.out)

    if args.summary:
        lines = [
            "## ELP2000-82B truncation spike (HYA-369 follow-up)",
            "",
            "NASA Five Millennium Canon recipe (neglect < %.4f arcsec, "
            "~1 m): **%d of %d terms kept** (longitude %d, latitude %d, "
            "distance %d); %.2f ms per evaluation in CPython."
            % (NASA_TRUNC_ARCSEC, total_kept, full_terms, lon_kept,
               lat_kept, dist_kept, eval_ms),
            "",
            "Moon longitude vs Swiss geometric, mean-of-date frame "
            "(arcsec):",
            "",
            "| moon | mean abs | max abs | signed mean |",
            "|---|---|---|---|",
        ]
        for label, key in (
                ("engine Meeus Ch.47", "engine_meeus_vs_swiss_geo_arcsec"),
                ("ELP82B raw args", "elp_raw_vs_swiss_geo_arcsec"),
                ("ELP82B 2002 args (NASA)", "elp_2002_vs_swiss_geo_arcsec"),
                ("Swiss apparent - geometric",
                 "swiss_app_minus_geo_arcsec")):
            m = moon_acc[key]
            lines.append("| %s | %.3f | %.3f | %+.3f |"
                         % (label, m["mean_s"], m["max_s"],
                            m["signed_mean"]))
        lines += [
            "",
            "Predicted tithi/karana bands (Swiss minus engine, seconds; "
            "mean|max (signed)):",
            "",
            "| channel | n | current | +ELP2002 | +ELP raw | floor: "
            "perfect geo moon | floor: perfect app moon |",
            "|---|---|---|---|---|---|---|",
        ]
        for limb in ("tithi", "karana"):
            b = per_limb[limb]

            def cell(v):
                return "%.1f|%.0f (%+.1f)" % (v["mean_s"], v["max_s"],
                                               v["signed_mean_s"])

            lines.append("| %s | %d | %s | %s | %s | %s | %s |"
                         % (limb, b["n"], cell(b["current"]),
                            cell(b["pred_elp_2002"]),
                            cell(b["pred_elp_raw"]),
                            cell(b["floor_perfect_geometric"]),
                            cell(b["floor_perfect_apparent"])))
        with open(args.summary, "w") as f:
            f.write("\n".join(lines) + "\n")
        print("summary written: %s" % args.summary)


def julian_day_of(iso_date):
    y, m, d = (int(x) for x in iso_date.split("-"))
    if m <= 2:
        y -= 1
        m += 12
    a = y // 100
    b = 2 - a + a // 4
    return math.floor(365.25 * (y + 4716)) + \
        math.floor(30.6001 * (m + 1)) + d + b - 1524.5


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except BaseException:
        annotate_error("elp_spike crashed: " + traceback.format_exc())
        raise
