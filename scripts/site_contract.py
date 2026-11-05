"""Site output contract - the single source of truth shared by CI gates.

Both gates call check():
  - ci.yml runs it PRE-MERGE against the local build output
    (--dir build/site), so a broken site cannot reach main. Incident
    2026-11-03: the post-deploy smoke ran only after merge, its first
    execution failed on main, and the fix had to be shipped separately.
  - the pages.yml post-deploy smoke runs it against the live site
    (via --base, or by importing check() and passing a fetcher).

This is an INDEPENDENT implementation (Python, straight from the
canonical CSVs), not the Dart engine that built the site. It verifies:
  - static markers on every page/widget/CSV artifact (client-guard
    anchors, honesty-page anchors, canonical CSV headers and rows);
  - today.json against a from-scratch Python recompute;
  - sankranti.json against a from-scratch Python recompute;
  - the L1 core CSV structure (1,308 rows spanning BS 1975-2083);
  - every SHA-256 digest the /data page publishes, recomputed
    independently here from the served bytes (a page can never list
    a checksum that does not match its own download).

Usage:
  python3 scripts/site_contract.py --dir build/site            (local build)
  python3 scripts/site_contract.py --base URL [--cachebust N]   (live site)
"""

import argparse
import datetime
import hashlib
import json
import sys
import time
import urllib.request
import zoneinfo

# Required substrings per artifact. Case-sensitive on purpose: HTML ids
# and JavaScript identifiers are case-sensitive, so a case drift is a real
# regression. Note the sankranti CSV marker: bs_year is the FIRST column,
# so the last row (BS 2100 Chaitra) begins a line - the marker is the full
# row prefix "2100,12,Chaitra", not ",2100," (which never occurs anywhere
# in the file and failed the first post-deploy smoke run - incident
# 2026-11-03).
MARKERS = {
    "index.html": ['id="ans-en"', 'id="cal-grid"'],
    "accuracy.html": ['id="evidence-tiers"', "2096", "errata"],
    "methodology.html": ['id="layers"', "anchor chain"],
    "data.html": [
        'id="data-dictionary"',
        'id="checksums"',
        'id="license"',
        "data/calendar_bs_core_1975_2083.csv",
        "data/sankranti_moments_1975_2083.csv",
        "data/sankranti_moments_1975_2100.csv",
    ],
    "docs.html": [
        'id="docs-toc"',
        'id="data-dictionary"',
        'id="methodology"',
        'id="changelog"',
        'id="errata"',
        'id="provenance"',
        "83e8c16794ba4aa3da4dee472efe18ac2fb8e94e",
        "fc1aae6",
        "23.87508",
        "sankranti_npt",
        "projection-defect",
    ],
    "sankranti.html": ['id="sankranti-now"', "pre_2036_exception", "projection_defect"],
    "panchang.html": ['id="panchang-tithi"', 'id="panchang-sunrise"', 'id="panchang-meta"', "udaya", "madhyahna"],
    "embed/v1/widget.js": ["data-nmiti", "NPT_MS", "attachShadow"],
    "embed/example.html": ["embed/v1/widget.js", 'data-nmiti="today"'],
    "data/calendar_bs_core_1975_2083.csv": ["bs_year,baisakh1,weekday", "2083,2026-04-14"],
    "data/calendar_bs_tail_2084_2100.csv": ["2096", "projection-defect"],
    "data/sankranti_moments_1975_2083.csv": [
        "bs_year,month_no,month,rashi,sankranti_npt",
        "2083,12,Chaitra",
    ],
    "data/sankranti_moments_1975_2100.csv": [
        "bs_year,month_no,month_en",
        "era_law",
        "2100,12,Chaitra",
    ],
}


def _core_rows(text):
    rows = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        cols = line.split(",")
        if cols[0] == "bs_year":
            continue
        rows[int(cols[0])] = (
            datetime.date.fromisoformat(cols[1]),
            [int(x) for x in cols[3:15]],
        )
    return rows


def _sk_rows(text):
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        cols = line.split(",")
        if cols[0] == "bs_year":
            continue
        rows.append((cols[5], int(cols[0]), int(cols[1])))
    return rows


def check(read_text):
    """Run the full contract. read_text(rel_path) -> str.

    Returns a list of human-readable failure strings (empty = pass).
    """
    cache = {}

    def text(rel):
        if rel not in cache:
            cache[rel] = read_text(rel)
        return cache[rel]

    failures = []

    for rel, markers in MARKERS.items():
        body = text(rel)
        for marker in markers:
            if marker not in body:
                failures.append(rel + " missing marker '" + marker + "'")

    # L1 core CSV structure: 1,308 ingress rows spanning BS 1975-2083,
    # 12 rows per year, first and last rows exactly where they must be.
    l1_rows = []
    for line in text("data/sankranti_moments_1975_2083.csv").splitlines():
        s = line.strip()
        if not s or s.startswith("#") or s.startswith("bs_year,"):
            continue
        cols = s.split(",")
        l1_rows.append((int(cols[0]), int(cols[1])))
    if len(l1_rows) != 1308:
        failures.append(
            "L1 core CSV has " + str(len(l1_rows)) + " rows, expected 1308"
        )
    else:
        years = [r[0] for r in l1_rows]
        if years[0] != 1975 or years[-1] != 2083 or l1_rows[-1] != (2083, 12):
            failures.append(
                "L1 core CSV span is BS "
                + str(years[0])
                + "-"
                + str(years[-1])
                + " (last row month "
                + str(l1_rows[-1][1])
                + "), expected 1975-2083 ending 2083-12"
            )
        per_year = {}
        for y, _m in l1_rows:
            per_year[y] = per_year.get(y, 0) + 1
        bad_years = [y for y in per_year if per_year[y] != 12]
        if bad_years:
            failures.append(
                "L1 core CSV years without exactly 12 rows: "
                + str(sorted(bad_years)[:5])
            )

    # SHA-256 re-verification: recompute the digest of every served CSV
    # from the bytes this contract just fetched and require the digest
    # the /data page displays to match. The page build computes these
    # from the exact bytes it serves, so any drift fails here loudly.
    data_html = text("data.html")
    for rel in [
        "data/calendar_bs_core_1975_2083.csv",
        "data/calendar_bs_tail_2084_2100.csv",
        "data/sankranti_moments_1975_2083.csv",
        "data/sankranti_moments_1975_2100.csv",
    ]:
        digest = hashlib.sha256(text(rel).encode("utf-8")).hexdigest()
        if digest not in data_html:
            failures.append(
                "data.html missing recomputed SHA-256 " + digest + " for " + rel
            )

    # today.json: independently recomputed from the canonical core CSV.
    rows = _core_rows(text("data/calendar_bs_core_1975_2083.csv"))
    today = datetime.datetime.now(zoneinfo.ZoneInfo("Asia/Kathmandu")).date()
    by = max(y for y in rows if rows[y][0] <= today)
    b1, months = rows[by]
    if today >= b1 + datetime.timedelta(days=sum(months)):
        failures.append("today falls outside the core table")
        return failures
    doy = (today - b1).days + 1
    m, d = 1, doy
    for length in months:
        if d <= length:
            break
        d -= length
        m += 1
    expected = (by, m, d)
    deployed = json.loads(text("api/v1/today.json"))
    got = (deployed["bs"]["year"], deployed["bs"]["month"], deployed["bs"]["day"])
    if got != expected:
        failures.append(
            "today.json " + str(got) + " != independently computed " + str(expected)
        )

    # sankranti.json: independently recomputed from the canonical CSV.
    sk_rows = _sk_rows(text("data/sankranti_moments_1975_2100.csv"))
    now_utc = datetime.datetime.now(datetime.timezone.utc)
    cur = None
    nxt = None
    for r in sk_rows:
        t = datetime.datetime.fromisoformat(r[0].replace("Z", "+00:00"))
        if t <= now_utc:
            cur = r
        elif nxt is None:
            nxt = r
    sk = json.loads(text("api/v1/sankranti.json"))
    if sk["current_rasi"]["index"] != cur[2] or sk["current_rasi"]["bs_year"] != cur[1]:
        failures.append(
            "sankranti.json current rasi BS "
            + str(sk["current_rasi"]["bs_year"])
            + "-"
            + str(sk["current_rasi"]["index"])
            + " != independently computed BS "
            + str(cur[1])
            + "-"
            + str(cur[2])
        )
    if sk["next"]["instant_utc"] != nxt[0]:
        failures.append(
            "sankranti.json next instant " + sk["next"]["instant_utc"] + " != CSV " + nxt[0]
        )
    exp_mu = (
        datetime.datetime.fromisoformat(nxt[0].replace("Z", "+00:00")) - now_utc
    ).total_seconds() / 60
    if abs(sk["next"]["minutes_until"] - exp_mu) > 60:
        failures.append(
            "sankranti.json minutes_until "
            + str(sk["next"]["minutes_until"])
            + " vs expected ~"
            + str(int(exp_mu))
        )

    return failures


def _main():
    parser = argparse.ArgumentParser(description="nMiti site output contract")
    parser.add_argument("--dir", help="check a local build output directory")
    parser.add_argument("--base", help="check a deployed base URL")
    parser.add_argument(
        "--cachebust", default="", help="cachebust query value for --base fetches"
    )
    args = parser.parse_args()

    if bool(args.dir) == bool(args.base):
        print("site_contract: pass exactly one of --dir or --base")
        sys.exit(2)

    if args.dir:
        root = args.dir.rstrip("/")

        def read_text(rel):
            with open(root + "/" + rel, encoding="utf-8") as f:
                return f.read()

    else:
        base = args.base.rstrip("/") + "/"

        def read_text(rel):
            u = base + rel
            if args.cachebust:
                u += "?cachebust=" + args.cachebust
            last = None
            for attempt in range(3):
                try:
                    with urllib.request.urlopen(u, timeout=60) as r:
                        return r.read().decode("utf-8")
                except Exception as e:
                    print("fetch attempt " + str(attempt + 1) + " of " + u + " failed: " + str(e))
                    last = e
                    if attempt < 2:
                        time.sleep(30)
            raise last

    try:
        failures = check(read_text)
    except Exception as e:
        print("SMOKE FAIL: contract could not be evaluated: " + str(e))
        sys.exit(1)
    for failure in failures:
        print("SMOKE FAIL: " + failure)
    if failures:
        sys.exit(1)
    print("site contract OK: " + (args.dir or args.base))


if __name__ == "__main__":
    _main()
