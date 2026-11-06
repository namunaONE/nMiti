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
3. **Swiss-truth scoreboard** (HYA-369, first CI run 2026-11-06) — the
   full engine window is re-solved with Swiss Ephemeris in CI:
   tithi/karana boundaries mean 7.9 s (max 19 s), moonrise 0.3 s
   (max 1 s), sunrise 11.3 s (max 12 s); the nakshatra/yoga deltas
   (~60 / ~104 s) are the ayanamsa convention gap, stated, never absorbed.

| Limb | ± minutes | Basis |
| -- | -- | -- |
| tithi | ±1.5 | corpus max ~1.0 min; oracle labels agree, transitions mean < 2 min |
| nakshatra | ±2.0 | typical ≤0.94, observed max 1.7 near lunar perigee |
| yoga | ±2.0 | max ~0.97 post ayanamsa fit |
| karana | 0 | convention-anchored: 76/76 exact at the pinned reference moment |
| sunrise | ±1.0 | vs geometric (NOAA-style) rise; BhaktiBharat's ~+4.5 min is a stated convention offset, not an error |
| moonrise | ±12 (provisional) | JPL topocentric rise receipts vs the served Meeus 15.1 geocentric target — convention gap; Swiss parity at the identical target is 0.3 s mean |

Publisher-vs-publisher divergence (BhaktiBharat ↔ Hamro Patro agree within
2–13 min on the same boundaries) is a measured fact about Nepali publishing —
stated, never absorbed into our bands. Named systematic contributors: the
ΔT source gap (Espenak–Meeus 75.6 s vs observed ≈69 s for 2026) ≈ 6.6 s, and
Meeus Ch.47 truncation ≈ 20 s of boundary time.

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

Tithi, karana and moonrise are pure ephemeris/algorithm parity —
moonrise is near-exact (0.3 s mean) and the USNO low-accuracy sunrise
closed form tracks the Swiss crossing to ~11 s. The nakshatra and yoga
deltas are near-constant — the ayanamsa convention gap (our fitted base
profile vs Swiss Lahiri), itself an informative number, not noise. A
regression now trips a band within ~3× of the recorded maxima.

The harness also reports the **ΔT residual** (Swiss internal model minus our
Espenak–Meeus polynomial, at every boundary) — a direct measurement of the
named systematic contributor in the error bars above — and flags
**knife-edge boundaries**: any boundary within 30 minutes of a sunrise, the
days where two honest panchangs can print different limbs. The knife-edge
list is the input the festival layer (R6b) consumes for per-source
attribution. (First-run gotcha, fixed 2026-11-06: `swe.deltat` returns
ΔT in **days** — read as seconds it produced the constant −75.60 s
"residual" that masked the real ~−6.6 s gap; the corrected measurement is
the input to the IERS ΔT adjudication, HYA-406.)

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
