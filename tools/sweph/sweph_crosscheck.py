#!/usr/bin/env python3
"""Swiss-truth cross-check of the nMiti lunar engine (HYA-369 prep,
moonrise parity added by HYA-417, lunar eclipse receipts added by
HYA-421).

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

HYA-421: cross-checks the NASA 2026 lunar eclipse receipts fixture
(packages/nepali_panchang/test/fixtures/nasa_lunar_2026.json - the same
corpus the Dart CI gate pins the engine against) with Swiss Ephemeris,
so the receipts are validated by two independent ephemerides and the
engine-vs-NASA deltas in the Dart gate are attributed to the engine, not
to the receipts. Contact times only: the global search
swe.lun_eclipse_when does not return magnitudes, which stay pinned by
the Dart gate.

HYA-421 step 4 adds the Nepal-local channels. swe.sol_eclipse_when_loc
re-solves the Kathmandu solar receipts fixture (partial contacts, NASA
magnitude, obscuration, ordering sanity) and swe.lun_eclipse_when_loc
re-solves the grahan shastra fixture's lunar events - the same local
circumstances (visibility gates, sutak anchors, grastodit moonrise
clamps) the Dart grahan.dart module is built on, validated here by an
independent ephemeris. Swiss's own local visibility gate must agree
with the timeanddate verdicts; the lun_when_loc tret slot layout is
resolved empirically per event by candidate-slot scoring (the recorded
lun_eclipse_when layout gotcha), the winning candidate named in the
receipts JSON.

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
import os
import sys
import traceback

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
# Lunar eclipse receipts band (HYA-421): Swiss Moshier vs the NASA
# bulletin values, both on the Danjon 1/85 shadow convention. Provisional
# 300/120 until the first CI run records the actual deltas; then tighten
# like every band before it.
LUNAR_ECLIPSE_HARD_BAND_S = 300
LUNAR_ECLIPSE_MEAN_BAND_S = 120
# pyswisseph lun_eclipse_when tret layout (per its docstring: "indices
# consistent with solar eclipses"). The first CI run (2026-11-05) shipped
# the pre-2.x Swiss layout and the failure annotations recorded the exact
# mismatch pattern - the wrong-slot deltas reconstructed mean 8673s /
# max 20314s to the second - so this layout is receipt-verified, not
# assumed: 0 greatest, 1 unused, 2 partial begin, 3 partial end,
# 4 total begin, 5 total end, 6 penumbral begin, 7 penumbral end.
# Unused slots are 0, so a contact exists iff its slot holds a real
# instant after the seed.
LUNAR_ECLIPSE_PHASE_IDX = [
    ("penumbral_start", 6),
    ("partial_start", 2),
    ("total_start", 4),
    ("total_end", 5),
    ("partial_end", 3),
    ("penumbral_end", 7),
]
KNIFE_EDGE_MIN = 30.0
SEED_DAYS = 0.05  # seed the Swiss solver ~72 min before our boundary
KATHMANDU_LAT = 27.7172
KATHMANDU_LON = 85.324
AU_KM = 149597870.7
EARTH_EQ_RADIUS_KM = 6378.1366
DEFAULT_ECLIPSE_FIXTURE = (
    "packages/nepali_panchang/test/fixtures/nasa_lunar_2026.json")
DEFAULT_SOLAR_FIXTURE = (
    "packages/nepali_panchang/test/fixtures/"
    "solar_kathmandu_receipts.json")
DEFAULT_GRAHAN_FIXTURE = (
    "packages/nepali_panchang/test/fixtures/"
    "grahan_shastra_receipts.json")
# Nepal-local circumstances bands (HYA-421 step 4): provisional 300/120
# until the first CI run records the actual deltas, like every band
# before them. Contacts are pure ephemeris parity, but the receipts are
# tAD's NPT wall clock and Swiss re-solves with its own Delta-T, so
# the band carries both contributors.
SOLAR_LOC_HARD_BAND_S = 300
SOLAR_LOC_MEAN_BAND_S = 120
LUNAR_LOC_HARD_BAND_S = 300
LUNAR_LOC_MEAN_BAND_S = 120
SOLAR_LOC_MAG_BAND = 0.02
SOLAR_LOC_ALT_BAND_DEG = 2.0
# timeanddate stage tables are NPT wall clock (UTC+5:45).
NPT_OFFSET_DAYS = 5.75 / 24.0
# geopos order for the pyswisseph *_when_loc calls: (lon, lat, alt).
KATHMANDU_GEOPOS = (KATHMANDU_LON, KATHMANDU_LAT, 0.0)
# Candidate tret slot layouts for lun_eclipse_when_loc, resolved
# empirically per event by scoring against the tAD stage table (the
# recorded lun_eclipse_when layout gotcha: never assume - score, pick
# the best, name the winner in the receipts). Slot 0 is the greatest
# instant in every documented layout.
LUNAR_LOC_CANDIDATES = [
    ("swissdoc_loc", {"partial_start": 1, "partial_end": 2,
                      "total_start": 3, "total_end": 4,
                      "penumbral_start": 5, "penumbral_end": 6}),
    ("global_style", {"partial_start": 2, "partial_end": 3,
                      "total_start": 4, "total_end": 5,
                      "penumbral_start": 6, "penumbral_end": 7}),
]
LUNAR_LOC_CANDIDATE_MAP = dict(LUNAR_LOC_CANDIDATES)
# GitHub renders at most 10 annotations from ::error:: commands per step.
MAX_ANNOTATIONS = 10


def norm360(x):
    return x % 360.0


def annotate_error(msg):
    """Emit a GitHub Actions error annotation carrying the ACTUAL
    failure payload (band numbers, deltas, traceback). The workflow log
    is sign-in gated, but the run page's annotations table renders
    server-side - so the real numbers stay readable without log access.
    No-op outside Actions (GITHUB_ACTIONS unset)."""
    if os.environ.get("GITHUB_ACTIONS") != "true":
        return
    one_line = " ".join(str(msg).split())
    if len(one_line) > 900:
        one_line = one_line[:900] + "... (truncated)"
    print("::error::" + one_line.replace("%", "%25"))


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


def lunar_eclipse_crosscheck(fixture_path, failures):
    """Re-solves every eclipse of the NASA 2026 receipts fixture with
    swe.lun_eclipse_when (global, geocentric - the same channel the Dart
    eclipse_lunar.dart solver computes) and scores the contact deltas."""
    with open(fixture_path) as f:
        fixture = json.load(f)
    if fixture.get("schema") != "nmiti-nasa-lunar-2026/1":
        failures.append(
            "eclipse fixture schema mismatch: %r" % fixture.get("schema"))
        return None
    deltas = []
    signed_deltas = []
    rows = []
    for e in fixture["eclipses"]:
        date = e["date"]
        jd0 = julian_day_of(date)
        seed = jd0 - 1.0
        res = swe.lun_eclipse_when(seed, swe.FLG_MOSEPH, False)
        retflag, tret = res[0], res[1]
        greatest = tret[0]
        if abs(greatest - jd0) > 1.5:
            failures.append(
                "%s: Swiss found a different eclipse (greatest jd_ut=%r)"
                % (date, greatest))
            continue
        # A contact exists iff its tret slot holds a real instant.
        # Slots per the pyswisseph layout: 2/3 partial begin/end,
        # 4/5 total begin/end, 6/7 penumbral begin/end.
        has_partial = tret[2] > seed and tret[3] > seed
        has_total = tret[4] > seed and tret[5] > seed
        swiss_type = ("total" if has_total
                      else ("partial" if has_partial else "penumbral"))
        if swiss_type != e["type"]:
            failures.append("%s: Swiss type %s != fixture type %s"
                            % (date, swiss_type, e["type"]))
        phases = e["phases"]
        row = {"date": date, "swiss_type": swiss_type, "phases": {}}
        delta = (greatest -
                 (jd0 + phases["greatest"]["minutes"] / 1440.0)) * 86400.0
        row["phases"]["greatest"] = {
            "swiss_jd_ut": greatest, "delta_s": round(delta, 2)}
        deltas.append(abs(delta))
        signed_deltas.append(delta)
        for key, idx in LUNAR_ECLIPSE_PHASE_IDX:
            receipt = phases[key]
            if receipt is None:
                if tret[idx] > seed:
                    failures.append(
                        "%s: Swiss has phase %s the fixture says is absent"
                        % (date, key))
                continue
            if not tret[idx] > seed:
                failures.append(
                    "%s: Swiss lacks phase %s the fixture records"
                    % (date, key))
                continue
            delta = (tret[idx] -
                     (jd0 + receipt["minutes"] / 1440.0)) * 86400.0
            row["phases"][key] = {
                "swiss_jd_ut": tret[idx], "delta_s": round(delta, 2)}
            deltas.append(abs(delta))
            signed_deltas.append(delta)
        rows.append(row)
    st = stats(deltas)
    signed = sum(signed_deltas) / len(signed_deltas) if signed_deltas else 0.0
    ok = (st["max_s"] is not None and
          st["max_s"] <= LUNAR_ECLIPSE_HARD_BAND_S and
          st["mean_s"] <= LUNAR_ECLIPSE_MEAN_BAND_S)
    if not ok:
        failures.append(
            "lunar_eclipse: max=%.0fs (band %ds), mean=%.0fs (band %ds)"
            % (st["max_s"] or 0.0, LUNAR_ECLIPSE_HARD_BAND_S,
               st["mean_s"] or 0.0, LUNAR_ECLIPSE_MEAN_BAND_S))
    out = {
        **st,
        "signed_mean_s": round(signed, 2),
        "hard_band_s": LUNAR_ECLIPSE_HARD_BAND_S,
        "mean_band_s": LUNAR_ECLIPSE_MEAN_BAND_S,
        "pass": ok,
        "eclipses": rows,
    }
    print("SWEPH cross-check scoreboard: %-10s n=%-3d "
          "mean|d|=%7.1fs max=%6.0fs signed_mean=%+7.1fs "
          "band %d/%d %s"
          % ("lunar_ecl", st["n"], st["mean_s"] or 0.0, st["max_s"] or 0.0,
             signed, LUNAR_ECLIPSE_HARD_BAND_S, LUNAR_ECLIPSE_MEAN_BAND_S,
             "PASS" if ok else "FAIL"))
    return out


def npt_jd_of(stamp):
    """JD(UT) of an NPT wall-clock stamp ("2026-03-03T17:18" or
    "2027-08-02T16:27:20"). The timeanddate iso pages print stage
    tables in local wall clock; UT = NPT - 5:45."""
    date_part, _, time_part = stamp.partition("T")
    hms = [float(x) for x in time_part.split(":")]
    seconds = (hms[0] * 3600.0 + hms[1] * 60.0 +
               (hms[2] if len(hms) > 2 else 0.0))
    return julian_day_of(date_part) + seconds / 86400.0 - NPT_OFFSET_DAYS


def split_when_loc(res, what, require_attr=True):
    """Normalize a pyswisseph *_eclipse_when_loc result to (tret, attr).
    Wrapper shapes differ across versions; tret is the member list whose
    first slot is a Julian day (~2460000), attr the other member list."""
    tret = None
    attr = None
    for x in res:
        if isinstance(x, (list, tuple)) and len(x) > 0:
            if isinstance(x[0], float) and x[0] > 2400000.0:
                tret = list(x)
            elif attr is None:
                attr = list(x)
    if tret is None or (require_attr and attr is None):
        raise RuntimeError(
            "%s: cannot identify tret/attr in result %r" % (what, res))
    return tret, attr


def solar_eclipse_loc_crosscheck(fixture_path, sw, failures):
    """Re-solves the Kathmandu solar receipts with swe.sol_eclipse_when_loc:
    partial contacts, greatest, NASA magnitude (attr[8]) and obscuration
    (attr[2]), with ordering sanity tret[1] < tret[0] < tret[4]. The
    below-horizon grazes must be SKIPPED by Swiss's own visibility gate -
    the same gate the Dart grahan.dart sutak logic trusts - and that
    agreement is asserted, not assumed."""
    with open(fixture_path) as f:
        fixture = json.load(f)
    if fixture.get("schema") != "nmiti-solar-kathmandu-receipts/1":
        failures.append(
            "solar fixture schema mismatch: %r" % fixture.get("schema"))
        return None
    deltas = []
    rows = []

    def check_event(e, must_be_local):
        date = e["date"]
        jd0 = julian_day_of(date)
        seed = jd0 - 1.0
        res = swe.sol_eclipse_when_loc(
            seed, KATHMANDU_GEOPOS, swe.FLG_MOSEPH, False)
        tret, attr = split_when_loc(res, "solar %s" % date)
        greatest = tret[0]
        row = {
            "date": date,
            "swiss_tret": [round(x, 6) for x in tret],
            "swiss_attr": [round(x, 4) for x in attr],
        }
        if abs(greatest - jd0) > 1.5:
            if must_be_local:
                failures.append(
                    "%s: Swiss local channel found no eclipse (first "
                    "greatest jd_ut=%r) but the fixture records visible "
                    "contacts" % (date, greatest))
            else:
                row["note"] = (
                    "Swiss local channel skips this eclipse - its "
                    "visibility gate agrees with the tAD not-visible "
                    "verdict (penumbra-past-terminator graze or polar "
                    "non-event)")
            rows.append(row)
            return
        if not must_be_local:
            failures.append(
                "%s: Swiss local channel FOUND an eclipse (greatest "
                "jd_ut=%r) but the fixture records no visible contacts "
                "at Kathmandu" % (date, greatest))
            rows.append(row)
            return
        sources = e["sources"]["timeanddate"]
        if not (tret[1] < tret[0] and tret[0] < tret[4] and
                tret[1] < tret[4]):
            failures.append(
                "%s: sol_eclipse_when_loc ordering broken: tret=%r"
                % (date, tret))
        stages = {"partial_start": tret[1], "greatest": tret[0],
                  "partial_end": tret[4]}
        row["stages"] = {}
        for key, swiss_jd in stages.items():
            delta = (swiss_jd - npt_jd_of(sources[key])) * 86400.0
            row["stages"][key] = {
                "swiss_jd_ut": swiss_jd, "delta_s": round(delta, 2)}
            deltas.append(delta)
        mag = attr[8]
        row["magnitude"] = {"swiss": round(mag, 4),
                            "receipt": sources.get("magnitude")}
        if sources.get("magnitude") is not None:
            mag_delta = mag - float(sources["magnitude"])
            row["magnitude"]["delta"] = round(mag_delta, 4)
            if abs(mag_delta) > SOLAR_LOC_MAG_BAND:
                failures.append(
                    "%s: Swiss local NASA magnitude %.4f vs receipt %r "
                    "(band %.2f)" % (date, mag, sources["magnitude"],
                                     SOLAR_LOC_MAG_BAND))
        obsc = attr[2]
        obsc_receipts = []
        for src in e.get("sources", {}).values():
            if isinstance(src, dict) and "obscuration" in src:
                obsc_receipts.append(float(src["obscuration"]))
        row["obscuration"] = {"swiss": round(obsc, 4),
                              "receipts": obsc_receipts}
        for r in obsc_receipts:
            if abs(obsc - r) > SOLAR_LOC_MAG_BAND:
                failures.append(
                    "%s: Swiss obscuration %.4f vs receipt %.4f "
                    "(band %.2f)" % (date, obsc, r, SOLAR_LOC_MAG_BAND))
        alt = attr[6]  # apparent sun altitude at greatest
        row["sun_alt_greatest"] = {
            "swiss_apparent_deg": round(alt, 3),
            "receipt_deg": sources.get("sun_alt_at_greatest_deg"),
        }
        if sources.get("sun_alt_at_greatest_deg") is not None:
            if abs(alt - float(sources["sun_alt_at_greatest_deg"])) > \
                    SOLAR_LOC_ALT_BAND_DEG:
                failures.append(
                    "%s: Swiss apparent sun altitude at greatest %.2f "
                    "vs receipt %r (band %.1f deg)"
                    % (date, alt, sources["sun_alt_at_greatest_deg"],
                       SOLAR_LOC_ALT_BAND_DEG))
        rows.append(row)

    for e in fixture["eclipses"]:
        check_event(e, e.get("visibility") == "aboveHorizon")
    for e in fixture.get("non_events", []):
        check_event(e, False)
    st = stats([abs(d) for d in deltas])
    signed = sum(deltas) / len(deltas) if deltas else 0.0
    ok = st["max_s"] is not None and \
        st["max_s"] <= SOLAR_LOC_HARD_BAND_S and \
        st["mean_s"] <= SOLAR_LOC_MEAN_BAND_S
    if not ok:
        failures.append(
            "solar_local: max=%.0fs (band %ds), mean=%.0fs (band %ds)"
            % (st["max_s"] or 0.0, SOLAR_LOC_HARD_BAND_S,
               st["mean_s"] or 0.0, SOLAR_LOC_MEAN_BAND_S))
    out = {
        **st,
        "signed_mean_s": round(signed, 2),
        "hard_band_s": SOLAR_LOC_HARD_BAND_S,
        "mean_band_s": SOLAR_LOC_MEAN_BAND_S,
        "pass": ok,
        "eclipses": rows,
    }
    print("SWEPH cross-check scoreboard: %-10s n=%-3d "
          "mean|d|=%7.1fs max=%6.0fs signed_mean=%+7.1fs "
          "band %d/%d %s"
          % ("solar_loc", st["n"], st["mean_s"] or 0.0,
             st["max_s"] or 0.0, signed, SOLAR_LOC_HARD_BAND_S,
             SOLAR_LOC_MEAN_BAND_S, "PASS" if ok else "FAIL"))
    return out


def lunar_eclipse_loc_crosscheck(fixture_path, sw, failures):
    """Re-solves the grahan shastra fixture's lunar events with
    swe.lun_eclipse_when_loc - the local visibility channel behind the
    Dart grahan.dart sutak anchors. Swiss's own visibility gate must
    agree with the timeanddate verdicts (not-visible eclipses are
    skipped), and the visible contacts must reproduce the tAD stage
    tables; the tret slot layout is resolved empirically by candidate
    scoring and the winner recorded in the receipts JSON."""
    with open(fixture_path) as f:
        fixture = json.load(f)
    if fixture.get("schema") != "nmiti-grahan-shastra-receipts/1":
        failures.append(
            "grahan fixture schema mismatch: %r" % fixture.get("schema"))
        return None
    deltas = []
    rows = []
    for e in fixture["events"]:
        if e.get("kind") != "lunar":
            continue
        date = e["date"]
        expected = e.get("expected", {})
        tad = (e.get("kathmandu") or {}).get("timeanddate") or {}
        jd0 = julian_day_of(date)
        seed = jd0 - 1.0
        res = swe.lun_eclipse_when_loc(
            seed, KATHMANDU_GEOPOS, swe.FLG_MOSEPH, False)
        tret, _attr = split_when_loc(
            res, "lunar %s" % date, require_attr=False)
        greatest = tret[0]
        row = {"date": date, "type": e.get("type"),
               "swiss_tret": [round(x, 6) for x in tret]}
        near = abs(greatest - jd0) <= 1.5
        visible = bool(expected.get("visible"))
        if not near:
            if not visible:
                row["note"] = ("Swiss local channel skips this eclipse - "
                               "its visibility gate agrees with the tAD "
                               "verdict")
            elif e.get("type") == "penumbral":
                row["note"] = ("Swiss local channel does not report this "
                               "penumbral-only eclipse; its stages stay "
                               "pinned by the tAD receipt and the Dart "
                               "gate")
            else:
                failures.append(
                    "%s: Swiss local channel found no visible lunar "
                    "eclipse (first greatest jd_ut=%r)" % (date, greatest))
            rows.append(row)
            continue
        if not visible:
            failures.append(
                "%s: Swiss local channel FOUND an eclipse (greatest "
                "jd_ut=%r) but the fixture records it not visible in "
                "Kathmandu" % (date, greatest))
            rows.append(row)
            continue
        stages = {k: v for k, v in tad.items()
                  if k in ("penumbral_start", "partial_start",
                           "total_start", "total_end", "partial_end",
                           "penumbral_end", "greatest")}
        row["stages"] = {}
        grt_delta = (greatest - npt_jd_of(stages["greatest"])) * 86400.0
        row["stages"]["greatest"] = {
            "swiss_jd_ut": greatest, "delta_s": round(grt_delta, 2)}
        event_pairs = [("greatest", grt_delta)]
        if expected.get("rises_eclipsed") or len(stages) <= 1:
            # Grastodit: the umbral and penumbral phases begin before
            # moonrise, so Swiss's own visibility gate clips (or clamps)
            # them - only the greatest instant is comparable. The full
            # contact set stays pinned by the Dart gate against tAD.
            row["note"] = ("greatest-only: stages clipped by the local "
                           "visibility gate (grastodit) or not "
                           "published by tAD")
        else:
            best = None
            for name, mapping in LUNAR_LOC_CANDIDATES:
                cand_pairs = []
                cand_stages = {}
                for key, idx in mapping.items():
                    if key not in stages or idx >= len(tret):
                        continue
                    if not tret[idx] > seed:
                        continue
                    d = (tret[idx] - npt_jd_of(stages[key])) * 86400.0
                    cand_pairs.append((key, d))
                    cand_stages[key] = {
                        "swiss_jd_ut": tret[idx], "delta_s": round(d, 2)}
                cand_all = [("greatest", grt_delta)] + cand_pairs
                score = sum(abs(d) for _k, d in cand_all) / len(cand_all)
                if best is None or score < best[0]:
                    best = (score, name, cand_stages, cand_pairs)
            row["slot_layout"] = best[1]
            row["stages"].update(best[2])
            event_pairs.extend(best[3])
            # A receipt stage the winning layout omits must be clipped by
            # the moon's own horizon at the receipt time, or it fails.
            for key, idx in LUNAR_LOC_CANDIDATE_MAP[best[1]].items():
                if key not in stages or idx >= len(tret):
                    continue
                if tret[idx] > seed:
                    continue
                if sw.moon_margin(npt_jd_of(stages[key])) > 0.0:
                    failures.append(
                        "%s: Swiss local channel omits %s while the moon "
                        "is above the horizon at receipt time %s; "
                        "tret=%r" % (date, key, stages[key], tret))
                else:
                    row["stages"][key] = {
                        "note": "clipped below the moon's horizon at the "
                                "receipt time (rise/set clamp)"}
            # A huge delta can only be a rise/set clamp substitution -
            # verify against the fixture's own moonrise/moonset receipt.
            for key, d in list(event_pairs):
                if key == "greatest" or abs(d) <= 900.0:
                    continue
                clamp = None
                for edge in ("moonrise", "moonset"):
                    if edge in tad and abs(
                            npt_jd_of(stages[key]) -
                            npt_jd_of(tad[edge])) * 1440.0 <= 45.0:
                        clamp = edge
                if clamp:
                    row["stages"][key]["note"] = (
                        "rise/set clamp substitution: Swiss returns the "
                        "%s instant where tAD lists the global contact"
                        % clamp)
                    event_pairs = [p for p in event_pairs if p[0] != key]
        deltas.extend(d for _k, d in event_pairs)
        rows.append(row)
    st = stats([abs(d) for d in deltas])
    signed = sum(deltas) / len(deltas) if deltas else 0.0
    ok = st["max_s"] is not None and \
        st["max_s"] <= LUNAR_LOC_HARD_BAND_S and \
        st["mean_s"] <= LUNAR_LOC_MEAN_BAND_S
    if not ok:
        failures.append(
            "lunar_local: max=%.0fs (band %ds), mean=%.0fs (band %ds)"
            % (st["max_s"] or 0.0, LUNAR_LOC_HARD_BAND_S,
               st["mean_s"] or 0.0, LUNAR_LOC_MEAN_BAND_S))
    out = {
        **st,
        "signed_mean_s": round(signed, 2),
        "hard_band_s": LUNAR_LOC_HARD_BAND_S,
        "mean_band_s": LUNAR_LOC_MEAN_BAND_S,
        "pass": ok,
        "events": rows,
    }
    print("SWEPH cross-check scoreboard: %-10s n=%-3d "
          "mean|d|=%7.1fs max=%6.0fs signed_mean=%+7.1fs "
          "band %d/%d %s"
          % ("lunar_loc", st["n"], st["mean_s"] or 0.0,
             st["max_s"] or 0.0, signed, LUNAR_LOC_HARD_BAND_S,
             LUNAR_LOC_MEAN_BAND_S, "PASS" if ok else "FAIL"))
    return out


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
    ap.add_argument("--eclipse-fixture", default=DEFAULT_ECLIPSE_FIXTURE,
                   help="NASA lunar eclipse receipts fixture to "
                        "cross-check (HYA-421)")
    ap.add_argument("--solar-fixture", default=DEFAULT_SOLAR_FIXTURE,
                   help="Kathmandu solar receipts fixture to "
                        "cross-check locally (HYA-421 step 4)")
    ap.add_argument("--grahan-fixture", default=DEFAULT_GRAHAN_FIXTURE,
                   help="grahan shastra receipts fixture to "
                        "cross-check locally (HYA-421 step 4)")
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
    eclipse_out = None
    solar_local_out = None
    lunar_local_out = None

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

    # HYA-421: NASA lunar eclipse receipts vs Swiss Ephemeris - the same
    # fixture the Dart CI gate pins eclipse_lunar.dart against, validated
    # here by an independent ephemeris.
    if not os.path.exists(args.eclipse_fixture):
        failures.append("eclipse fixture not found: %s"
                        % args.eclipse_fixture)
        print("FAIL: eclipse fixture not found: %s"
              % args.eclipse_fixture, file=sys.stderr)
    else:
        eclipse_out = lunar_eclipse_crosscheck(args.eclipse_fixture,
                                                failures)

    # HYA-421 step 4: Nepal-local circumstances channels - the local
    # visibility gates and sutak anchors grahan.dart is built on,
    # validated by an independent ephemeris.
    if not os.path.exists(args.solar_fixture):
        failures.append("solar fixture not found: %s"
                        % args.solar_fixture)
        print("FAIL: solar fixture not found: %s"
              % args.solar_fixture, file=sys.stderr)
    else:
        solar_local_out = solar_eclipse_loc_crosscheck(
            args.solar_fixture, sw, failures)
    if not os.path.exists(args.grahan_fixture):
        failures.append("grahan fixture not found: %s"
                        % args.grahan_fixture)
        print("FAIL: grahan fixture not found: %s"
              % args.grahan_fixture, file=sys.stderr)
    else:
        lunar_local_out = lunar_eclipse_loc_crosscheck(
            args.grahan_fixture, sw, failures)

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
            "lunar_eclipses": eclipse_out,
            "solar_local": solar_local_out,
            "lunar_local": lunar_local_out,
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
        for i, msg in enumerate(failures):
            print("FAIL: " + msg, file=sys.stderr)
            if i < MAX_ANNOTATIONS:
                annotate_error(msg)
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
    try:
        main()
    except SystemExit:
        raise
    except BaseException:
        # The traceback lives only in the sign-in-gated log; surface it
        # as a run annotation so the failure is diagnosable without it.
        annotate_error("sweph_crosscheck crashed: " + traceback.format_exc())
        raise

