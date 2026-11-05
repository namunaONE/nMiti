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
Two anchors:

1. **Publisher parity** — the locked receipt corpora (226 limb boundaries +
   76 karana/sunrise receipts, BhaktiBharat + Hamro Patro, Oct–Nov 2026)
   gate CI on every push; bands are honest ceilings over the observed maxima.
2. **Ephemeris parity** — a Swiss-anchored independent engine (`tithi_engine`,
   Apache-2.0, dev-dependency only) cross-checks our tithi in CI: every
   day-tithi label agrees and transition instants sit inside the provisional
   bands.

| Limb | ± minutes | Basis |
| -- | -- | -- |
| tithi | ±1.5 | corpus max ~1.0 min; oracle labels agree, transitions mean < 2 min |
| nakshatra | ±2.0 | typical ≤0.94, observed max 1.7 near lunar perigee |
| yoga | ±2.0 | max ~0.97 post ayanamsa fit |
| karana | 0 | convention-anchored: 76/76 exact at the pinned reference moment |
| sunrise | ±1.0 | vs geometric (NOAA-style) rise; BhaktiBharat's ~+4.5 min is a stated convention offset, not an error |

Publisher-vs-publisher divergence (BhaktiBharat ↔ Hamro Patro agree within
2–13 min on the same boundaries) is a measured fact about Nepali publishing —
stated, never absorbed into our bands. Named systematic contributors: the
ΔT source gap (Espenak–Meeus 75.6 s vs observed ≈69 s for 2026) ≈ 6.6 s, and
Meeus Ch.47 truncation ≈ 20 s of boundary time.
