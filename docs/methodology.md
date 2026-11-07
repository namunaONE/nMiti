# Methodology — how nMiti data is built and verified

## Principles

1. **Honest accuracy.** Claims are made per evidence class, never as a global slogan. A row says what it is; nothing pretends to be more verified than it is.
2. **Fail closed.** If an invariant fails, the build refuses to emit. A missing row ships as `null` (loud failure), never a guess.
3. **Projections are labeled.** Beyond the verified core, data is projection-astronomical with declared uncertainty, or absent. Folklore projections are never shipped as fact.
4. **BS months are solar.** They are derived from the sidereal ingress of the sun (sankranti), never from lunar/tithi data.
5. **Defects stay visible.** Known defects are preserved and labeled until official data replaces them.

## The verification ladder

Every row states its rung on the ladder:

1. **Consensus** — multiple independent open datasets agree.
2. **Portal triangulation** — live Nepali calendar portals cross-checked (opened sequentially, never in parallel, to avoid correlated caching).
3. **Sankranti window** — a BS month must start on the NPT date of its sidereal ingress or the day after. A month starting before its sankranti is astronomically impossible. Era-aware exception: 24 cataloged pre-1980 consensus rows (see the pre-2036 allowlist).
4. **Official panchang** — Nepal Panchang Nirnayak Samiti (NPNS) / Surya Panchanga = verified.

## What was done (R1–R13, condensed)

- **R1–R4 (L0):** BS calendar deep dive, hardening with a 24-anchor verification, an ecosystem accuracy audit (which found live sites running corrupted tables and a genuine 372-day-year defect in a widely used Dart library's data), and an astronomical engine with erratum.
- **R5 (L1):** solar engine built on Meeus algorithms with a calibrated sidereal reference. Ayanamsa model: `23.87508 + 1.36062·(J−2451545)/36525`. Calibrated on 48 drikpangang ingress moments AD 2025–2028: **mean error 3.7 minutes, max 8.6 minutes, 48/48 correct NPT dates.** The 1,308-anchor experiment produced the era law: no pre-sankranti month starts from BS 2036 on.
- **R6:** tithi/festival research; the "+1" day rule was shown to be a committee judgment over admissible windows — engines validate the window, the official print supplies the +1. (Negative result, published as such.)
- **R8:** printed NPNS-approved panchangs obtained and OCR-mined; engines print-validated (sunrise/sunset to 1 minute; sankranti within 5 minutes; 12/12 independent confirmation against a traditional Indian panchang chain).
- **R12:** machine cross-validation of the core table — 109/109 rows identical to the reference dataset, anchor chain closing exactly on the official Baisakh 1 2084 anchor, live confirmation across 10+ sites. Full record: [data-provenance.md](data-provenance.md).
- **R13:** ship manifest and architecture (see [architecture.md](architecture.md)).

## Invariants (all enforced in CI, fail-closed)

**Calendar (L0):**

1. Every month has 29–32 days; every core year has exactly 365 or 366 days.
2. Baisakh 1 of year N+1 = Baisakh 1 of year N + length of year N (anchor chain).
3. Every Baisakh 1 falls on April 11–15.
4. The `weekday` column matches `baisakh1`.
5. No run of 3+ identical consecutive 12-month rows in the core (runs of 2 occur in correct data).
6. The tail chains continuously from the core and starts at the official 2084 anchor.

**Sankranti (L1):**

7. Window law (HYA-358): every BS month starts on its ingress NPT date or the day after — recomputed from the table, never read from the delta column; the 24 cataloged pre-1980 rows are the sole allowlist.
8. Meeus fixture regression and published-table regression (1,308 rows) must pass.

**Pipeline:**

9. `data/` and the embedded copies in `packages/nepali_date_data` must be byte-identical (drift check).
10. The site output contract (`scripts/site_contract.py`) runs pre-merge against the local build and post-deploy as the smoke — one source of truth, no drift between gates.
11. The post-deploy smoke is N-version: an independent Python implementation recomputes today's BS date from the raw CSV and compares it to the deployed JSON and HTML. Freshness SLA: 26 hours.

**Accuracy claim (honest, current):** astronomy ±minutes (SWEPH-comparable at date level); civil rules NPNS-validated. No ephemeris knows NPNS committee discretion — where the print record exists, it wins.

## Error bars (lunar engine, R6a/R6b)

The lunar engine (`packages/nepali_panchang`) publishes an uncertainty band
for every served value, derived from recorded evidence — never aspiration.
Three anchors:

1. **Publisher parity** — the locked receipt corpora (226 limb boundaries +
   76 karana/sunrise receipts, BhaktiBharat + Hamro Patro, Oct–Nov 2026)
   gate CI on every push; bands are honest ceilings over the observed maxima.
2. **Ephemeris parity** — a Swiss-anchored independent engine (`tithi_engine`,
   Apache-2.0, dev-dependency only) cross-checks our tithi in CI: every
   day-tithi label agrees and transition instants sit inside the provisional
   bands.
3. **Swiss-truth scoreboard** (HYA-369, first CI run 2026-11-06;
   re-measured post-R7a on merge `ff8b3ae`, CI #146; re-measured
   post-rung-B on the R10.5 frame audit, PR #58) — the
   full engine window is re-solved with Swiss Ephemeris in CI:
   tithi/karana boundaries mean 4.0 s (max 11 s, signed +1.9 s —
   the residual Meeus Ch.47 truncation scatter plus the named
   skipped Moon light-time, after the rung B frame audit removed
   the nutation systematic), moonrise 0.2 s, sunrise 11.3 s
   (max 12 s, unchanged — UT-direct); the nakshatra/yoga deltas
   (~51 / ~97 s) are the ayanamsa convention gap plus the −6.5 s
   R7a ΔT wall-clock shift, stated, never absorbed. The
   Swiss-vs-engine ΔT residual reads mean −0.30 s (max 0.31 s,
   n=233).

| Limb | ± minutes | Basis |
| -- | -- | -- |
| tithi | ±1.5 | corpus max ~1.0 min; oracle labels agree, transitions mean < 2 min |
| nakshatra | ±2.0 | typical ≤0.94, observed max 1.7 near lunar perigee |
| yoga | ±2.0 | max ~0.97 post ayanamsa fit |
| karana | 0 | convention-anchored: 76/76 exact at the pinned reference moment |
| sunrise | ±1.0 | vs geometric (NOAA-style) rise; BhaktiBharat's ~+4.5 min is a stated convention offset, not an error |
| moonrise | ±12 (provisional) | JPL topocentric rise receipts vs the served Meeus 15.1 geocentric target — convention gap; Swiss parity at the identical target is 0.2 s mean |

Publisher-vs-publisher divergence (BhaktiBharat ↔ Hamro Patro agree within
2–13 min on the same boundaries) is a measured fact about Nepali publishing —
stated, never absorbed into our bands. Named systematic contributors (post-rung B): the residual
Meeus Ch.47 truncation scatter plus the deliberately skipped Moon light-time (~0.7″ ≈ 1.4 s of
boundary time) — together the measured 4.0 s mean / 11 s max tithi Swiss gap; the former ~16 s
nutation frame systematic was fixed by the R10.5 rung B frame audit, never absorbed. The former ΔT source gap (≈6.6 s for 2026) was closed by the
hybrid Delta-T channel (R7a) — see the Delta-T section below.

## Swiss-truth cross-check (HYA-369)

The engine is now also verified against Swiss Ephemeris itself, in CI on
every push. The Dart engine dumps every tithi, karana, nakshatra and yoga
boundary in the corpus window (2026-10-16 → 2026-12-02) plus every Kathmandu
sunrise (`nmiti_cli:dump_limb_instants`, base ayanamsa profile); an
independent Python harness (`tools/sweph/sweph_crosscheck.py`) re-solves
each boundary with Swiss Ephemeris (pyswisseph, Moshier file-free mode,
Lahiri sidereal mode) and scores the gap.

First scoreboard (2026-11-06): measured Swiss − engine per channel, and
the bands tightened to measured + margin (max / mean, seconds):

| Channel | n | measured mean abs | measured max | signed mean | band (hard / mean) |
| -- | -- | -- | -- | -- | -- |
| tithi | 47 | 7.9 s | 19 s | −7.9 s | 60 / 30 |
| karana | 93 | 7.9 s | 19 s | −7.8 s | 60 / 30 |
| nakshatra | 45 | 59.8 s | 71 s | −59.8 s | 180 / 120 |
| yoga | 48 | 104.3 s | 119 s | −104.3 s | 300 / 180 |
| moonrise | 44 | 0.3 s | 1 s | −0.2 s | 60 / 15 |
| sunrise | 45 | 11.3 s | 12 s | +11.3 s | 60 / 30 |
| lunar_ecl | 12 | 12.0 s | 35 s | +4.4 s | 120 / 60 |
| solar_loc | 3 | 5.0 s | 6 s | +1.8 s | 60 / 30 |
| lunar_loc | 15 | 38.8 s | 180 s | +38.7 s | 300 / 120 |

Post-R7a re-measurement (CI #146, merge `ff8b3ae`, 2026-11-06, hybrid ΔT channel): every TT limb band shifted by the −6.5 s ΔT wall-clock correction (engine ΔT dropped 75.6 → 69.1 s for the window) and every band still passes; sunrise is UT-direct and unchanged. The Swiss-vs-engine ΔT residual collapsed from ≈6.6 s to mean −0.30 s (max 0.31 s, n=233):

| Channel | n | measured mean abs | measured max | signed mean | band (hard / mean) |
| -- | -- | -- | -- | -- | -- |
| tithi | 47 | 14.3 s | 26 s | −14.3 s | 60 / 30 PASS |
| karana | 93 | 14.3 s | 26 s | −14.3 s | 60 / 30 PASS |
| nakshatra | 45 | 66.2 s | 78 s | −66.2 s | 180 / 120 PASS |
| yoga | 48 | 110.8 s | 125 s | −110.8 s | 300 / 180 PASS |
| moonrise | 44 | 0.2 s | 0 s | −0.0 s | 60 / 15 PASS |
| sunrise | 45 | 11.3 s | 12 s | +11.3 s | 60 / 30 PASS |
| lunar_ecl | 12 | 12.0 s | 35 s | +4.4 s | 120 / 60 PASS |
| solar_loc | 3 | 5.0 s | 6 s | +1.8 s | 60 / 30 PASS |
| lunar_loc | 15 | 38.8 s | 180 s | +38.7 s | 300 / 120 PASS |
| ΔT residual | 233 | 0.30 s | 0.31 s | −0.30 s | n/a |

The pre-R7a ΔT error was partially *canceling* the named Meeus
Ch.47 truncation (~20 s) in the tithi/karana channels; with ΔT
corrected the raw truncation gap (14.3 s, signed −14.3 s) stands
exposed — stated, never absorbed, still well inside every band.
The UT1-direct channels (sunrise, moonrise) did not move, confirming the
ΔT channel change as the sole cause of the shift.

**R10.5 rung B correction (HYA-445, 2026-11-07): the frame audit found
that most of the exposed "truncation" gap was not truncation.** The
tithi/karana elongation had been subtracting the nutated apparent Sun
from the geometric Moon — a frame rotation applied to one body of a
separation — so every tithi/karana angle carried −Δψ (+8.0″ in the
window ≈ 16 s of boundary time; see the frame-audit section below).
With the frames made consistent, the re-measured scoreboard (CI on the
rung B PR, all bands PASS):

| Channel | n | measured mean abs | measured max | signed mean | band (hard / mean) |
| -- | -- | -- | -- | -- | -- |
| tithi | 47 | 4.0 s | 11 s | +1.9 s | 60 / 30 PASS |
| karana | 93 | 4.1 s | 11 s | +1.9 s | 60 / 30 PASS |
| nakshatra | 45 | 51.2 s | 62 s | −51.2 s | 180 / 120 PASS |
| yoga | 48 | 96.8 s | 111 s | −96.8 s | 300 / 180 PASS |
| moonrise | 44 | 0.2 s | 0 s | −0.0 s | 60 / 15 PASS |
| sunrise | 45 | 11.3 s | 12 s | +11.3 s | 60 / 30 PASS |
| lunar_ecl | 12 | 12.0 s | 35 s | +4.4 s | 120 / 60 PASS |
| solar_loc | 3 | 5.0 s | 6 s | +1.8 s | 60 / 30 PASS |
| lunar_loc | 15 | 38.8 s | 180 s | +38.7 s | 300 / 120 PASS |
| ΔT residual | 233 | 0.30 s | 0.31 s | −0.30 s | n/a |

The tithi/karana mean collapsed 14.3 → 4.0 s and the signed mean
−14.3 → +1.9 s: the residual is the true Meeus Ch.47 truncation
scatter plus the named skipped contributor (the Moon's light-time,
~1.4 s of boundary time). The nakshatra/yoga convention gaps moved
66.2 → 51.2 s and 110.8 → 96.8 s — the engine's moon now sits in the
publishers' apparent-sidereal frame, so the remaining gap is the
ayanamsa profile difference alone. Sunrise, moonrise, both eclipse
channels and the ΔT residual did not move, confirming the change
touched only the limb frames.

Tithi, karana and moonrise are pure ephemeris/algorithm parity —
moonrise is near-exact (0.3 s mean) and the USNO low-accuracy sunrise
closed form tracks the Swiss crossing to ~11 s. The nakshatra and yoga
deltas are near-constant — the ayanamsa convention gap (our fitted base
profile vs Swiss Lahiri), itself an informative number, not noise. A
regression now trips a band within ~3× of the recorded maxima.

The harness also reports the **ΔT residual** (Swiss internal model minus
the engine's served ΔT at every boundary — the Espenak–Meeus polynomial
before R7a, the hybrid channel since) — a direct measurement of the
named systematic contributor in the error bars above — and flags
**knife-edge boundaries**: any boundary within 30 minutes of a sunrise, the
days where two honest panchangs can print different limbs. The knife-edge
list is the input the festival layer (R6b) consumes for per-source
attribution. (First-run gotcha, fixed 2026-11-06: `swe.deltat` returns
ΔT in **days** — read as seconds it produced the constant −75.60 s
"residual" that masked the real ~−6.6 s gap; the corrected measurement is
the input to the IERS ΔT adjudication, HYA-406.)

**ΔT adjudication (HYA-406, 2026-11-06): keep Espenak–Meeus, document
the systematic.** The gap is real and now source-confirmed from three
independent directions: the USNO/IERS long-term predictions table reads
ΔT = 69.05 ± 0.19 s at 2026.0; the Swiss internal model reads ≈68.8 s
(corrected residual mean −6.79 s, max 6.81 s, n=233); our
Espenak–Meeus polynomial gives 75.6 s. Decision: keep the fixed
polynomial — deterministic, no table maintenance — and keep the ~6.6 s
systematic stated: it is sub-band (every Swiss-truth band passes with
4–15× headroom) and below the publisher minute floor (±0.5 min on
displayed minutes). Swapping to an observed table would shift every
boundary time ~6.6 s, force a corpus re-baseline, and buy nothing
measurable. Stated, never absorbed; revisit only if a band ever tightens
past the systematic.

**R7a supersession (HYA-438, 2026-11-06):** the engine now serves the
**hybrid Delta-T channel** — SMH2016/Morrison2021 spline before 1973-02,
USNO observed monthly through 2026-04, USNO quarterly predictions through
2033-10, Espenak–Meeus long-range beyond, with the join steps declared, not
blended — closing the ~6.5 s systematic. Served boundary times shift ~6.5 s
later (truer); re-measured on the merge (CI #146): every TT limb band
moved by the −6.5 s ΔT correction and stays inside its published
ceiling, the Swiss-vs-engine ΔT residual collapsed from ≈6.6 s to
mean −0.30 s (n=233), and the UT1-direct channels (sunrise, moonrise)
did not move. The post-R7a scoreboard table is above.

## Delta T — the hybrid channel (R7a, HYA-438)

Delta T = TT − UT1, the gap between dynamical time (which the ephemerides
speak) and Earth's rotation (which clocks and calendars speak). Every limb
boundary the engine solves is a pure TT event; the served wall-clock time
depends entirely on which Delta T converts it. Since R7a the channel is:

| Segment | Span | Source | Uncertainty |
| -- | -- | -- | -- |
| Spline | AD −720 .. 1973-02 | Stephenson, Morrison & Hohenkerk (2016) / Morrison et al. (2021) cubic spline, Table S15 (Royal Society supplement, CC BY 4.0) — published pre-1974 segments only | published error table (15 s at 1600, 0.05 s from 1870) |
| Observed | 1973-02 .. 2026-04 | USNO deltat.data — monthly observed TT−UT1 | 0.05 s |
| Predictions | 2026-04 .. 2033-10 | USNO deltat.preds — quarterly, bridged from the last observation; observations shadow predictions inside their span | the file's own error column, interpolated (0.05 .. 1 s) |
| Long-range | 2033-10 .. 2150 | Espenak–Meeus 2005-2050 / 2050-2150 branches | declared envelope: 1 s at the join, 6 s at 2050, 12 s at 2100, 20 s at 2150 |

Join steps are **declared, never blended**: +0.228 s where the spline hands
over to the USNO observations (1973-02-01), continuous across the
observed-to-prediction bridge, and +8.91 s where the USNO stops predicting
and the polynomial long-range takes over (2033-10-01) — the USNO's own end
of record, left visible. The vendored values were validated three ways:
three Wayback snapshots of the USNO files, the independently vendored
hyper-calendar copy (C04-identity-checked to 0.002 s), and the IERS-derived
astronomia monthly series. The tables regenerate via
`tools/refresh_delta_t.dart` (monthly workflow; it refuses to write
on any anomaly), and the freshness canary asserts the observed table stays
current (last observed month within ~16 months).

**License boundary (AGPL facts-out):** Swiss Ephemeris is AGPL-3. It is
invoked only by the CI verification harness; no nMiti package imports or
links against it, no ephemeris data ships in the repository or the site,
and the harness's only outputs are numeric facts (deltas and counts). The
Dart engine stays MIT and dependency-free. This is the AGPL-compliant
harness strategy adopted in HYA-369: compute in the harness, ship only
facts. Full statement and procedure: `tools/sweph/README.md`.

## Moonrise and the nishita/chandrodaya conventions (HYA-417)

The lunar engine now also solves **moonrise**: the first rising of the
Moon within an NPT civil day, Kathmandu-anchored. The rise condition is
Meeus eq. 15.1 — the geocentric center altitude reaches
`0.7276·π − 34′` (standard upper-limb rise with refraction folded into
the target, live lunar parallax) — evaluated on the same 60-term
Meeus Ch.47 series that produces every tithi boundary, so moonrise and
the limbs share one ephemeris. Receipts: a JPL Horizons golden table
(topocentric samples at the festival dates) holds the printed values
inside a provisional ±12 min band, and the Swiss-truth harness mirrors
the **identical** target convention on Swiss Ephemeris in CI, enforcing
provisional 300/150 s bands — pure ephemeris and algorithm parity, no
rise/set convention gap.

The festival layer gained the two conventions those shastra rules
require, with the citations printed on every battery rule:

- **nishita-vyāpinī** — the tithi running at the midnight *ending* the
  civil day. Dharma Sindhu ch. 5 (V.D.N. Rao translation): "On each
  Krishna Chaturdashi, Kamya Shiva Raatri Vrata is performed as in the
  case of Maha Shiva Raatri; that is the timing should be such that
  Chaturdashi should be till midnight." The 2082 receipt pins it:
  Falgun 3 = Feb 15 2026 carried udaya tithi Trayodashi, Chaturdashi
  spanned the midnight — publishers took Feb 15 while the udaya
  convention gives Feb 16. The divergence is exposed, not absorbed.
- **chandrodaya-vyāpti** — the tithi running at the day's moonrise:
  Dharma Sindhu ch. 5's Sankata Chaturthi rule ("reckoned as of
  Chandrodaya kaala Vyapti"). Unlocked by the moonrise solver; the
  Sankata Chaturthi battery entry is pending receipts, the convention
  is exposed for callers meanwhile.

The 2026 receipt corpus (`test/fixtures/festival_receipts_2026.json`) —
Maha Shivaratri, Fagu Purnima, Janai Purnima, Teej — runs in CI as a
permanent gate alongside the 2083 corpus. Two notable receipts: Janai
Purnima 2083 (Purnima began Aug 27 09:24 NPT, publishers took the udaya
day Aug 28, *not* the first-overlap day — publishers choose udaya-vyāpinī
over pūrva-viddhā here), and Fagu Purnima 2082 (hills observe the
first-overlap day Mar 2, Terai the udaya day Mar 3 — both exposed; the
Terai day also carries a khanda-gras chandra grahan note recorded for
the eclipse module). Citations are translation-level and say so: the
shloka-level references stay marked pending until printed sources are
verified — honesty before ornament.

## Grahan (eclipses) — computed, receipt-anchored, collisions exposed (HYA-421)

The grahan layer serves every eclipse that touches the Kathmandu
anchor — visible or not — as a runtime-computed event:
geocentric lunar shadow geometry (Danjon 1/85 shadow enlargement by
default, the Chauvenet variant exposed as collision C1) and
topocentric solar circumstances. The shastra rules are
receipt-anchored, never invented: sutak is 12 hours (solar) or 9
hours (lunar) before the LOCAL visible contacts and ends at the
locally visible moksha (C4: an eclipse not visible from the location
carries no sutak); a penumbral lunar eclipse is upachhaya — not kept
as a grahan, no sutak (C5); a grastodit rise anchors the sutak clock
to the local rise. Every publisher collision is decoded and
displayed (C6: global class vs locally observed phase; C2: Hamro
Patro’s 59-minute “duration”; C3: the reversed-hours FAQ), never
silently picked.

Verification: a ~20-test Dart gate over the grahan shastra receipts
corpus (six lunar events 2026–2028 banded against the timeanddate
Kathmandu stage tables) and the NASA solar catalog 2026–2030; in
CI, two Swiss Ephemeris local-circumstances channels (`solar_local`,
`lunar_local` — provisional 300/120 s bands) re-solve every event,
including the grastodit greatest, which Swiss’s local channel clamps
to the moonrise instant. The display layer maps sutak windows onto
Nepali civil days (a 12-hour solar sutak can begin the previous
evening) by querying the day before, the day itself and the day
after.

## NPNS full-year daily-tithi audit (HYA-369)

The lunar engine is now also checked against a full-year publisher corpus, not just festival windows: every day of BS 2082 and BS 2083 — 730 receipts — crawled live from the Hamro Patro portal (the NPNS-aligned publisher), each carrying the tithi label and paksha exactly as displayed plus the portal’s own rendered AD date. The corpus itself is gated in CI: 365 days per year, month lengths matching the portal month ends, and a strictly consecutive AD chain from 2025-04-14 to 2027-04-13 — an independent cross-check of the portal’s BS↔AD mapping. The decoded label chain walks the tithi cycle with only legal udaya steps (689 normal, 26 kshaya, 14 vriddhi over the two years) — astronomy visible in the raw labels, nothing hand-transcribed.

The engine gate: the runtime tithi at udaya (the Hamro Patro display convention) must equal the portal label on every day, except on knife-edge days — a tithi boundary within half an hour of sunrise, or any vriddhi/kshaya day (engine flags or the portal’s own merged-window mark) — where publishers legitimately diverge. Agreement floor 90%, measured rather than aspirational — the first CI run (2026-11-06) agreed 671/730 days (91.92%): 59 mismatches, every one on a knife-edge day, zero disagreements anywhere else; the hard gate is exact agreement on every non-knife-edge day. Every mismatch prints to the CI log with its knife-edge status. The 40 vriddhi/kshaya days plus a fixed-stride systematic sample (every 25th day of the AD chain, offset 5) form the print spot-verification queue against the printed NPNS panchangs held from R8 — the corpus is portal-truth until print-verified, and says so.

Adjudication of the disagreement days (2026-11-06): all 59 mismatches are off-by-one, every one on a day the portal itself marks vriddhi/kshaya, forming short runs bounded by events the two sources place on different days. Third-party check: on the 30 disagreement days with populated BhaktiBharat pages (its online archive begins ~July 2026; the remaining ~29 pre-July-2026 days are unavailable there), BhaktiBharat's own tithi windows match the engine on 30/30, boundary deltas 0–1 minutes — e.g. Janai Purnima week: on 2026-07-18 BhaktiBharat's Sunrise Tithi is Panchami (the engine; the portal prints Chaturthi, which BhaktiBharat lists as the early-hours tithi that ended 4:58 AM). The disagreement class is therefore the portal's vriddhi/kshaya boundary convention — the publisher-divergence fact already on record (BhaktiBharat ↔ Hamro Patro agree within 2–13 min on the same boundaries) — stated, never absorbed. BhaktiBharat corroboration is not print verification; the R8 print spot-verification queue stands.

## Frame audit — every solver path's reference frame (R10.5 rung B, HYA-445)

Rung B walked every solver path and pinned two questions per path: is the
input instant converted UT→TT before the ephemeris sees it, and is the
output frame consistent (nutation and light-time applied symmetrically to
the bodies)? The per-path verdict:

| Path | ΔT input | Output frame | Verdict |
| -- | -- | -- | -- |
| tithi/karana boundaries | TT inside the solver; callers convert | separation frame: both bodies mean-equinox-of-date, own light-time kept, no nutation | FIXED this rung — was: nutated sun vs geometric moon |
| nakshatra | same | apparent-sidereal moon (nutation applied) − ayanamsa | FIXED this rung — was mean-sidereal |
| yoga | same | both bodies apparent-sidereal | FIXED this rung — nutation was on the sun side only |
| sunrise/sunset | UT closed form, ΔT-free by construction | geometric −0.8333° target | clean, documented |
| moonrise | UT→TT inside the altitude target | mean-equinox geometric + parallax, refraction folded into the target | clean; the rise-convention gap dominates its band |
| masa bounds | window bounds converted UT→TT | tithi solver + apparent-sidereal sun | clean |
| lunar eclipse | contact instants TT inside | both bodies geometric (the shared rotation cancels; shadow geometry) | internally consistent; the omitted solar aberration shifts contacts well under the NASA receipt bands — stated |
| solar eclipse | TT inside the geometry | true sun + aberration vs geometric moon (the shared separation helper, deduplicated this rung) | deliberate near-conjunction frame; receipt bands absorb the asymmetry |

**The finding.** Nutation in longitude (Δψ, ±17.2″ over the 18.6-year
node cycle) had been applied to the Sun alone — `sunApparentLongitude` =
true + ν + aberration — while the Moon stayed geometric (Meeus Ch.47,
mean equinox of date). For an angular separation a common frame rotation
cancels between the two bodies; applied to ONE body it turns the
separation itself: every tithi and karana angle carried −Δψ, and every
tithi/karana boundary sat correspondingly later than a true-apparent
separation puts it. In the corpus window Δψ ≈ +8.0″ ≈ 16 s of tithi
boundary time — which quantitatively explains most of the post-R7a Swiss
signed mean (−14.3 s) that had been attributed to the Meeus Ch.47
truncation alone: the truncation scatter is real but smaller; the
nutation asymmetry was the systematic. The sidereal paths carried the
same class: the moon sat in the mean-equinox frame while the publishers'
convention (apparent − ayanamsa, the drik software convention) is
nutated — nakshatra and yoga now apply the nutation to the moon like the
sun.

The named, deliberately skipped contributor is the Moon's own
light-time: ~1.3 s of time, ~0.7″ of longitude, ~1.4 s of boundary time.
Computing it would evaluate the 60-term series twice per bisection step
for a term far below the publisher minute floor — stated, never silently
dropped.

Every served boundary therefore shifts ~13–16 s earlier in the window
(ν = +8.0″: tithi/karana ~16 s, nakshatra ~15 s, yoga ~14 s). All
receipt corpora, the bounded karana knife-edge rule, the NPNS 730-day
audit, the festival gates and the rung A property suite re-verify green
in CI on this change — measured, not asserted. The fitted per-publisher
ayanamsa profiles (BhaktiBharat −0.0795°, Hamro Patro −0.0117°) are NOT
re-fit here: re-fitting is deferred to the next receipt-driven
calibration crawl so a convention change and a fit change never land in
the same PR. The post-fix Swiss scoreboard is recorded in the
Swiss-truth section above, re-measured on this change.
