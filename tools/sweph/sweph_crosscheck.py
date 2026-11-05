#!/usr/bin/env python3
"""Swiss-truth cross-check of the nMiti lunar engine (HYA-369 prep,
moonrise parity added by HYA-417).

Reads the Dart engine's limb-boundary dump (nmiti_cli:dump_limb_instants)
and re-solves every boundary with Swiss Ephemeris via pyswisseph, scoring
the reconstruction gap per limb (HYA-369 deliverable 1), flagging
knife-edge boundaries (within 30 minutes of a Kathmandu sunrise - the days
two honest panchangs can print different tithis), and measuring the Delta-T
model residual (Swiss internal vs our Espenak-Meeus polynomial). Enforces
provisional bands and writes a receipts JSON.

HYA-417: the dump also carries the per-day moonrise (first rise within
the NPT civil day, Meeus eq. 15.1 target 0.7276*pi - 34' on geocentric
altitude, live parallax). The harness mirrors the IDENTICAL convention
on Swiss Ephemeris - geocentric equatorial position, the same target,
30-min stepped scan then bisection - so the moonrise score is pure
ephemeris + algorithm parity: no rise/set convention gap enters.

Ephemeris mode: FLG_MOSEPH (Moshier) - file-free, deterministic in CI,
sub-arcsecond on the Moon. Sidereal mode: Swiss Lahiri (SIDM_LAHIRI); the
engine's fitted base ayanamsa is deliberately NOT substituted, so the
nakshatra/yoga deltas include the ayanamsa convention gap - that is the
informative number for HYA-369.

LICENSE BOUNDARY (AGPL): this harness imports pyswisseph (AGPL-3) at
runtime. It is a verification tool only: no nMiti package imports or links
against it, nothing from it ships in any artifact, and its only outputs are
numeric facts (deltas and counts), which are not copyrightable. The Dart
engine stays MIT and dependency-free. For distribution-safety, treat this
file as being under the same terms as pyswisseph. See README.md.
"""

import argparse
import datetime as _dt
import json
import math
import sys

try:
    import swisseph as swe
except ImportError:
    print("pyswisseph is required: python3 -m pip install pyswisseph",
          file=sys.stderr)
    raise

# Provisional bands (seconds), tightened as receipts accumulate - exactly
# like the publisher corpus bands and the tithi_engine oracle bands before
# them. Tithi/karana are pure ephemeris parity (no ayanamsa); nakshatra/
# yoga are wider because they include the ayanamsa convention gap.
HARD_BAND_S = {"tithi": 300, "karana": 300, "nakshatra": 600, "yoga": 600}
MEAN_BAND_S = {"tithi": 150, "karana": 150, "nakshatra": 300, "yoga": 300}
# Moonrise parity band (HYA-417): same target convention on both sides,
# so this is pure ephemeris + algorithm parity like tithi.
MOONRISE_HARD_BAND_S = 300
MOONRISE_MEAN_BAND_S = 150
KNIFE_EDGE_MIN = 30.0
SEED_DAYS = 0.05  # seed the Swiss solver ~72 min before our boundary
KATHMANDU_LAT = 27.7172
KATHMANDU_LON = 85.324
AU_KM = 149597870.7
EARTH_EQ_RADIUS_KM = 6378.1366


def norm360(x):
    return x % 360.0


class Sweph:
    """Thin deterministic wrapper: Moshier ephemeris, Lahiri sidereal."""

    def __init__(self):
        swe.set_sid_mode(swe.SIDM_LAHIRI, 0, 0)
        self.flags = swe.FLG_MOSEPH | swe.FLG_SPEED
        self.eq_flags = swe.FLG_MOSEPH | swe.FLG_EQUATORIAL

    def lon(self, body, jd_ut):
        xx, ret = swe.calc_ut(jd_ut, body, self.flags)
        if ret is None or (isinstance(ret, int) and ret < 0):
            raise RuntimeError("swe.calc_ut failed at jd_ut=%r" % jd_ut)
        return xx[0]

    def elongation(self, jd_ut):
        return norm360(self.lon(swe.MOON, jd_ut) - self.lon(swe.SUN, jd_ut))

    def nakshatra_angle(self, jd_ut):
        ay = swe.get_ayanamsa_ut(jd_ut)
        return norm360(self.lon(swe.MOON, jd_ut) - ay)

    def yoga_angle(self, jd_ut):
        ay = swe.get_ayanamsa_ut(jd_ut)
        moon = norm360(self.lon(swe.MOON, jd_ut) - ay)
        sun = norm360(self.lon(swe.SUN, jd_ut) - ay)
        return norm360(moon + sun)

    def moon_margin(self, jd_ut):
        """Geocentric center altitude minus the Meeus 15.1 rise target,
        the exact quantity the Dart solver bisects to zero."""
        xx, _ = swe.calc_ut(jd_ut, swe.MOON, self.eq_flags)
        ra, dec, dist_au = xx[0], xx[1], xx[2]
        dist_km = dist_au * AU_KM
        parallax_deg = math.degrees(
            math.asin(EARTH_EQ_RADIUS_KM / dist_km))
        target = 0.7276 * parallax_deg - 34.0 / 60.0
        gmst_deg = swe.sidtime(jd_ut) * 15.0
        hour_angle = math.radians(norm360(gmst_deg + KATHMANDU_LON - ra))
        lat = math.radians(KATHMANDU_LAT)
        dec_r = math.radians(dec)
        alt = math.degrees(math.asin(
            math.sin(lat) * math.sin(dec_r) +
            math.cos(lat) * math.cos(dec_r) * math.cos(hour_angle)))
        return alt - target


ANGLE_FNS = {
    "tithi": lambda s: s.elongation,
    "karana": lambda s: s.elongation,
    "nakshatra": lambda s: s.nakshatra_angle,
    "yoga": lambda s: s.yoga_angle,
}


def next_boundary(angle_fn, span_deg, jd_seed):
    """First limb boundary strictly after jd_seed (mirrors the Dart
    solver: sector-index stepping, then bisection - wrap-safe)."""
    target = math.floor(norm360(angle_fn(jd_seed)) / span_deg)
    lo, hi = jd_seed, jd_seed + 0.05
    while math.floor(norm360(angle_fn(hi)) / span_deg) == target:
        lo = hi
        hi += 0.05
        if hi - jd_seed > 4.0:
            raise RuntimeError("boundary solver failed to bracket")
    for _ in range(45):
        mid = (lo + hi) / 2.0
        if math.floor(norm360(angle_fn(mid)) / span_deg) == target:
            lo = mid
        else:
            hi = mid
    return hi


def sw_moonrise(sw, jd_ut_ref):
    """First upward crossing of the Meeus 15.1 target after
    jd_ut_ref - 30 min, mirroring the Dart scan-and-bisect solver."""
    t0 = jd_ut_ref - 0.02
    step = 1.0 / 48.0  # 30 minutes, same as the Dart scan
    prev = t0
    prev_f = sw.moon_margin(t0)
    for i in range(1, 97):
        t = t0 + i * step
        f = sw.moon_margin(t)
        if prev_f < 0.0 <= f:
            lo, hi = prev, t
            for _ in range(45):
                mid = (lo + hi) / 2.0
                if sw.moon_margin(mid) < 0.0:
                    lo = mid
                else:
                    hi = mid
            return hi
        prev, prev_f = t, f
    return None


def stats(values):
    v = sorted(values)
    n = len(v)
    return {
        "n": n,
        "min_s": round(v[0], 2) if n else None,
        "mean_s": round(sum(v) / n, 2) if n else None,
        "max_s": round(v[-1], 2) if n else None,
        "p95_s": round(v[int(0.95 * (n - 1))], 2) if n else None,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--instants", required=True,
                   help="limb_instants.json from dump_limb_instants")
    ap.add_argument("--receipts", default=None,
                   help="output receipts JSON path")
    ap.add_argument("--trim-days", type=float, default=1.0,
                   help="interior trim: skip boundaries this close to the "
                        "window edges (solver warm-up)")
    args = ap.parse_args()

    with open(args.instants) as f:
        dump = json.load(f)
    window = dump["window"]
    spans = dump["limb_spans_deg"]
    boundaries = dump.get("boundaries", {})
    sunrises = sorted(r["jd_ut"] for r in dump.get("sunrises", []))

    jd_start = julian_day_of(window["start"])
    jd_end = julian_day_of(window["end"])
    lo_limit = jd_start + args.trim_days
    hi_limit = jd_end - args.trim_days

    sw = Sweph()
    per_limb = {}
    all_rows = []
    knife_edges = []
    dt_residuals = []
    failures = []

    for limb in ("tithi", "karana", "nakshatra", "yoga"):
        rows = boundaries.get(limb, [])
        if not rows:
            failures.append("no %s boundaries in dump" % limb)
            continue
        angle_fn = ANGLE_FNS[limb](sw)
        span = float(spans[limb])
        deltas = []
        for r in rows:
            jd_ut = r["jd_ut"]
            if jd_ut < lo_limit or jd_ut > hi_limit:
                continue
            sw_jd = next_boundary(angle_fn, span, jd_ut - SEED_DAYS)
            delta_s = (sw_jd - jd_ut) * 86400.0
            deltas.append(delta_s)
            # Delta-T residual: Swiss internal model vs our polynomial.
            sw_dt = swe.deltat(jd_ut)
            dt_residuals.append(sw_dt - r["delta_t_s"])
            # Knife-edge: distance to the nearest sunrise.
            knife_min = None
            if sunrises:
                nearest = min(sunrises, key=lambda s: abs(s - jd_ut))
                knife_min = (jd_ut - nearest) * 1440.0
                knife = abs(knife_min) <= KNIFE_EDGE_MIN
            else:
                knife = False
            row = {
                "limb": limb,
                "utc": r["utc"],
                "jd_ut": jd_ut,
                "swiss_jd_ut": sw_jd,
                "delta_s": round(delta_s, 2),
            }
            if knife_min is not None:
                row["sunrise_delta_min"] = round(knife_min, 1)
                row["knife_edge"] = knife
                if knife:
                    knife_edges.append(row)
            all_rows.append(row)

        abs_deltas = [abs(d) for d in deltas]
        st = stats(abs_deltas)
        signed = sum(deltas) / len(deltas) if deltas else 0.0
        hard = HARD_BAND_S[limb]
        mean_band = MEAN_BAND_S[limb]
        ok = st["max_s"] <= hard and st["mean_s"] <= mean_band
        if not ok:
            failures.append(
                "%s: max=%.0fs (band %ds), mean=%.0fs (band %ds)"
                % (limb, st["max_s"], hard, st["mean_s"], mean_band))
        per_limb[limb] = {
            **st,
            "signed_mean_s": round(signed, 2),
            "hard_band_s": hard,
            "mean_band_s": mean_band,
            "pass": ok,
        }
        print("SWEPH cross-check scoreboard: %-10s n=%-3d "
              "mean|d|=%7.1fs max=%6.0fs signed_mean=%+7.1fs "
              "band %d/%d %s"
              % (limb, st["n"], st["mean_s"], st["max_s"], signed,
                 hard, mean_band, "PASS" if ok else "FAIL"))

    # HYA-417: moonrise parity - same Meeus 15.1 target on both sides.
    moonrise_rows = dump.get("moonrises", [])
    moonrise_out = None
    if not moonrise_rows:
        failures.append("no moonrises in dump")
    else:
        deltas = []
        rows_out = []
        for r in moonrise_rows:
            jd_ut = r["jd_ut"]
            if jd_ut < lo_limit or jd_ut > hi_limit:
                continue
            sw_jd = sw_moonrise(sw, jd_ut)
            if sw_jd is None:
                failures.append(
                    "moonrise on %s: Swiss mirror found no rise" % r["date"])
                continue
            delta_s = (sw_jd - jd_ut) * 86400.0
            deltas.append(delta_s)
            rows_out.append({
                "date": r["date"],
                "utc": r["utc"],
                "jd_ut": jd_ut,
                "swiss_jd_ut": sw_jd,
                "delta_s": round(delta_s, 2),
            })
        st = stats([abs(d) for d in deltas])
        signed = sum(deltas) / len(deltas) if deltas else 0.0
        ok = st["max_s"] <= MOONRISE_HARD_BAND_S and \
            st["mean_s"] <= MOONRISE_MEAN_BAND_S
        if not ok:
            failures.append(
                "moonrise: max=%.0fs (band %ds), mean=%.0fs (band %ds)"
                % (st["max_s"], MOONRISE_HARD_BAND_S,
                   st["mean_s"], MOONRISE_MEAN_BAND_S))
        moonrise_out = {
            **st,
            "signed_mean_s": round(signed, 2),
            "hard_band_s": MOONRISE_HARD_BAND_S,
            "mean_band_s": MOONRISE_MEAN_BAND_S,
            "days_without_rise": dump.get("moonrise_days_without_rise"),
            "pass": ok,
        }
        print("SWEPH cross-check scoreboard: %-10s n=%-3d "
              "mean|d|=%7.1fs max=%6.0fs signed_mean=%+7.1fs "
              "band %d/%d %s"
              % ("moonrise", st["n"], st["mean_s"], st["max_s"], signed,
                 MOONRISE_HARD_BAND_S, MOONRISE_MEAN_BAND_S,
                 "PASS" if ok else "FAIL"))
        all_rows.extend(rows_out)

    dt_st = stats([abs(d) for d in dt_residuals])
    dt_signed = sum(dt_residuals) / len(dt_residuals) if dt_residuals else 0.0
    print("delta T residual (Swiss - Espenak-Meeus): mean=%+.2fs "
          "max|d|=%.2fs (n=%d)"
          % (dt_signed, dt_st["max_s"] or 0.0, dt_st["n"]))

    if knife_edges:
        print("knife-edge boundaries (<= %.0f min from a sunrise): %d"
              % (KNIFE_EDGE_MIN, len(knife_edges)))
        for k in knife_edges:
            print("  %-24s %-10s sunrise_delta=%+6.1f min "
                  "swiss_delta=%+7.1fs"
                  % (k["utc"], k["limb"], k["sunrise_delta_min"],
                     k["delta_s"]))
    else:
        print("knife-edge boundaries (<= %.0f min from a sunrise): 0"
              % KNIFE_EDGE_MIN)

    if args.receipts:
        receipts = {
            "generated_at_utc":
                _dt.datetime.now(_dt.timezone.utc).isoformat(),
            "window": window,
            "ephemeris": "Swiss Ephemeris, Moshier file-free mode (FLG_MOSEPH)",
            "sidereal_mode": "SIDM_LAHIRI",
            "engine_ayanamsa_profile": dump.get("ayanamsa_profile"),
            "knife_edge_def_min": KNIFE_EDGE_MIN,
            "limbs": per_limb,
            "moonrise": moonrise_out,
            "delta_t_residual": {
                **dt_st,
                "signed_mean_s": round(dt_signed, 2),
            },
            "boundaries": all_rows,
            "knife_edges": knife_edges,
        }
        with open(args.receipts, "w") as f:
            json.dump(receipts, f, indent=2)
        print("receipts written: %s" % args.receipts)

    if failures:
        for msg in failures:
            print("FAIL: " + msg, file=sys.stderr)
        sys.exit(1)
    print("SWEPH cross-check: all provisional bands hold.")


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
    main()
