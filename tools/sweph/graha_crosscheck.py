#!/usr/bin/env python3
"""HYA-450: Swiss-truth cross-check of the nMiti graha engine (Wave 1).

Reads the graha rows that dump_limb_instants writes into
limb_instants.json (Mercury, Venus, Mars, Jupiter, Saturn and the mean
node Rahu, one 12:00 UT instant per day, engine sidereal longitudes on
the BASE ayanamsa profile) and re-solves each instant with pyswisseph
(Moshier file-free mode, Lahiri sidereal mode, apparent positions),
then scores the engine-vs-Swiss gap per body.

Receipts-first, like tools/sweph/sweph_crosscheck.py: the bands are
calibrated to measured evidence (hard 120 arcsec, mean 60 arcsec, all
bodies). The dump scores the BASE-ayanamsa channel, which sits the
measured +28.607 arcsec base-vs-Swiss-Lahiri convention gap (R10
ayanamsa receipts) off the Swiss reference before any engine error,
plus the VSOP87D truncation tails and the post-fix graha receipts
class (sub-arcsec vs JPL DE441; the first-CI mercury 6.259 arcsec
class was the double EMB -> Earth moon correction on the vendored
earth series, fixed in HYA-450) - the original 30 arcsec
mean band could not clear the convention gap alone. Tighten only on
measured evidence, never before.

License boundary: pyswisseph is AGPL-3 and is invoked only by this CI
harness - no shipped package links against it, and the only outputs
are numeric facts. See tools/sweph/README.md.
"""

import argparse
import json
import sys

import swisseph as swe

HARD_BAND_ARCSEC = 120.0
# Mean band must clear the measured +28.607 arcsec base-vs-Swiss-Lahiri
# convention gap (R10 ayanamsa receipts) plus the VSOP87D engine class.
MEAN_BAND_ARCSEC = 60.0

PLANET_TARGETS = {
    "mercury": swe.MERCURY,
    "venus": swe.VENUS,
    "mars": swe.MARS,
    "jupiter": swe.JUPITER,
    "saturn": swe.SATURN,
}

FLG = swe.FLG_MOSEPH | swe.FLG_SPEED


def wrap_delta_arcsec(a_deg, b_deg):
    d = (a_deg - b_deg) % 360.0
    if d > 180.0:
        d -= 360.0
    return abs(d) * 3600.0


def swiss_sidereal_deg(jd_ut, target):
    res = swe.calc_ut(jd_ut, target, FLG)
    first = res[0]
    lon = float(first[0]) if isinstance(first, (tuple, list)) else float(first)
    return lon - swe.get_ayanamsa_ut(jd_ut)


def annotate(level, msg):
    print("::%s::%s" % (level, msg.replace("%", "%25")))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--instants", required=True)
    ap.add_argument("--summary", required=True)
    args = ap.parse_args()

    with open(args.instants) as f:
        doc = json.load(f)
    rows = doc.get("grahas")
    if not rows:
        annotate("error", "graha_crosscheck: no 'grahas' rows in the "
                 "instants dump - run the extended dump_limb_instants")
        return 1

    swe.set_sid_mode(swe.SIDM_LAHIRI, 0, 0)

    bodies = list(PLANET_TARGETS.keys()) + ["rahu_mean_node"]
    stats = {b: [] for b in bodies}
    for row in rows:
        jd_ut = row["jd_ut"]
        sid = row["sidereal_deg"]
        for name, target in PLANET_TARGETS.items():
            ref = swiss_sidereal_deg(jd_ut, target)
            stats[name].append(wrap_delta_arcsec(sid[name], ref))
        node_ref = swiss_sidereal_deg(jd_ut, swe.MEAN_NODE)
        stats["rahu_mean_node"].append(
            wrap_delta_arcsec(row["rahu_mean_node_deg"], node_ref))

    lines = [
        "## HYA-450 graha Swiss-truth scoreboard",
        "",
        ("| body | n | max abs delta (arcsec) | mean abs delta (arcsec) "
         "| band hard/mean (arcsec) | verdict |"),
        "|---|---|---|---|---|---|",
    ]
    failures = 0
    for body in bodies:
        vals = stats[body]
        if not vals:
            continue
        mx = max(vals)
        mean = sum(vals) / len(vals)
        ok = mx <= HARD_BAND_ARCSEC and mean <= MEAN_BAND_ARCSEC
        verdict = "PASS" if ok else "FAIL"
        if not ok:
            failures += 1
        annotate("notice" if ok else "error",
                 "graha %s: n=%d max=%.2f arcsec mean=%.2f arcsec "
                 "band %.0f/%.0f %s"
                 % (body, len(vals), mx, mean,
                    HARD_BAND_ARCSEC, MEAN_BAND_ARCSEC, verdict))
        lines.append("| %s | %d | %.2f | %.2f | %.0f/%.0f | %s |"
                     % (body, len(vals), mx, mean,
                        HARD_BAND_ARCSEC, MEAN_BAND_ARCSEC, verdict))

    with open(args.summary, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("graha crosscheck: %d rows, %d bodies, %d band failures"
          % (len(rows), len(bodies), failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
