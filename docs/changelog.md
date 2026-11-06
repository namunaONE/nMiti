# Changelog

Data changes and releases of the nMiti commons. The dataset is versioned with the repo; the site carries the build version in its footer. Dates are ISO.

## [Unreleased] — hybrid Delta-T display layer (R7a, HYA-438)

- `api/v1/today.json` panchang block gains a `delta_t` honesty block: the served Delta-T value at local noon with its source segment (`smh2021-spline`, `usno-observed`, `usno-preds` or `espenak-meeus`), uncertainty, source span and the evaluated-at NPT stamp — the R7a engine channel surfaced, never re-derived. The pre-R7a Espenak–Meeus polynomial read 75.62 s for Nov 2026 where the USNO observed value is 69.13 s; every limb boundary now renders ~6.5 s later (truer) in wall clock.
- The methodology page and the docs-pack methodology gain a Delta-T receipts section: the four segments with spans, sources and uncertainties, and the declared (not blended) join steps — +0.228 s at 1973-02-01 (spline → observed), continuous bridge (observed → predictions), +8.91 s at 2033-10-01 (predictions → Espenak–Meeus long-range) — plus the HYA-406 KEEP adjudication superseded and the three-way data validation (Wayback snapshots × hyper-calendar × astronomia).
- New monthly workflow `refresh-delta-t.yml` wires the engine PR's `tools/refresh_delta_t.dart`: fetch the USNO files (Wayback fallback), validate, regenerate the vendored tables between markers, open a review PR when they change, and raise an urgent issue on validation failure (the tool refuses to write on any anomaly).
- The freshness & correctness canary gains a ΔT freshness assertion: the vendored observed table's last month must be within ~16 months of today.
- Site contract: today.json `delta_t`/`uncertainty_seconds`/`source_span` and methodology `id="delta-t"` + `hybrid Delta-T channel` markers enforced pre-merge and post-deploy. llms.txt and the data.html API description updated. No engine changes — this layer renders the shipped R7a channel only.

## [Unreleased] — ayanamsa methodology page (R6g, HYA-437)

- New honesty page `ayanamsa.html`: the sidereal reference stated exactly — the fitted model `23.87508° + 1.36062°/Julian century (TT)` calibrated on the 48 drikpanchang ingress receipts (mean 3.7 min, max 8.6 min, 48/48 NPT dates), and the per-source profiles (BhaktiBharat −0.0795°, Hamro Patro −0.0117°) with the corpus finding that forces profiles rather than one universal value.
- Build-time computed values on the page: today's base ayanamsa and both publisher profiles, plus the Sun's sayana→nirayana longitude with the rashi it occupies and the degrees to the next 30° ingress edge — the arithmetic behind every sankranti.
- Per-limb sensitivity table with the Swiss-truth measured gaps: tithi/karana are ayanamsa-free (7.9 s mean), nakshatra 59.8 s and yoga 104.3 s vs Swiss Lahiri — the convention gap, stated, never absorbed.
- The Nepal divergence record, evidence-tiered: the NPNS method (Surya Siddhanta panchang khand + Ketaki Grahaganitam planets, official patro since 2078 BS, the rolled-back Dec 2025 Ketaki move), the press-reported ~21 kala printed-patro offset vs Chitra-pakshiya with sankranti up to 15+ h off drik (print verification pending, R8 queue), and the 2083 two-day Maha Ashtami / 26.39 h vriddhi case this engine reproduces.
- Wiring: doc nav, index nav, sitemap, llms.txt; `ayanamsa.html` markers added to the site contract (pre-merge + post-deploy) and the deploy smoke 200-list. No engine, fixture or API changes.

## [Unreleased] — masa + muhurta display layer (R6f)

- `api/v1/today.json` gains a `masa` block: the amanta lunar month containing today (udaya attribution) — month number and name, begins/ends at the bounding new moons NPT, adhika/kshaya flags, and the sankranti instants inside the month, with provenance and evidence tier. The block note states that amanta lunar months are a separate stream from the sankranti-anchored BS solar months (in 2083, lunar Chaitra ran Mar 19 – Apr 17 2026 while solar Baisakh began Apr 14), so the two month systems can never be conflated silently.
- `api/v1/today.json` gains a `muhurta` block: Rahu Kalam, Yamaganda, Gulika, Abhijit, Brahma (computed night/15 plus the BhaktiBharat fixed 96/48 convention), the 8+8 choghadiya slots and the 24 unequal horas — every window NPT-stamped, with the engine convention-collision map serialized (Dur Muhurtam stated as not served; Varjyam/Amrit Kalam stated as deferred — never silently dropped).
- New `masa.html`: the lunar month containing today (bilingual card with adhika/kshaya flags and the sankrantis inside), the coming amanta year with adhika/kshaya columns, the naming/adhika/kshaya rule table with receipts (Adhika Jestha 2026; the VS 2083 13-month year; the Ghatasthapana anchor), and the oracle/receipt verification pointers.
- New `muhurta.html`: today's windows table with the sunrise/sunset line, the day and night choghadiya tables (dates shown — night parts cross midnight), the 24-hour hora table, the full convention-collision table, and the receipt corpus pointers.
- Site contract: `masa.html` + `muhurta.html` markers and today.json `masa`/`muhurta` markers enforced pre-merge and post-deploy; the pages.yml smoke 200-list gains both pages. Nav (index + doc shell), sitemap, llms.txt and the data.html API description wired. No engine or fixture changes — the display layer renders the shipped HYA-419 masa module and HYA-420 muhurta module only.

## [Unreleased] — festival display layer (R6e, re-ship on the R6d-gated battery)

- `api/v1/today.json` gains a `festivals` block: today's observances, `next_festival` and the 45-day horizon (`festival_window_days`), every entry carrying its day-choosing convention, the tithi span, the udaya-convention alternate whenever they diverge (`convention_divergence`), vriddhi/kshaya/borderline flags and BS + AD labels. Keys always serialize, so the contract markers are date-stable on festival days and quiet days alike.
- New `festivals.html`: today's observances, the next festival card, the coming year's festival calendar with a divergence column exposing the udaya alternate (Shivaratri 2027 shows nishita Mar 6 vs udaya Mar 7; Fagu Purnima hills Mar 21 vs Terai/udaya Mar 22), the six day-choosing conventions with their Dharma Sindhu shastra categories, the kshaya (first-overlap resolution) and vriddhi (both days listed) rules, and the three receipt corpora. Zero client JavaScript.
- Honesty texts updated to match reality: the panchang page's "festivals are not covered" line and today.json's panchang note now point to the festivals layer; the accuracy and methodology pages state the festival layer is served with conventions exposed, never silently picked (the old "festivals and tithi are not covered" bullet is retired).
- Site contract: `festivals.html` markers (five section ids + the Dharma Sindhu citation anchor) and today.json `festivals` markers appended pre-merge and enforced post-deploy; the pages.yml smoke 200-list gains `festivals.html`. Nav, sitemap and llms.txt wired. No engine or fixture changes — the display layer renders the R6d lunar-month-gated battery only — every rule now fires exactly once per year, so the 370-day year table lists true occurrences alone. Re-ship of the R6c layer reverted in PR #48: the rendering was live-verified correct; only the ungated battery under it produced the ghost repeats, and the R6d gate (PR #49) is exactly that fix.

## [Unreleased] — festival lunar-month gate (R6d)

- `scanFestivals` now gates every battery rule to the amanta lunar month that contains its anchor sankranti: Dashain and the Tihar Krishna-paksha rules (Dhanteras through Gai Puja) ride the Tula-ingress month (amanta Ashwin), Mha Puja, Bhai Tika and Chhath the Vrischik-ingress month (amanta Kartik), Maha Shivaratri the Kumbha-ingress month (amanta Magh — Nepal's "Falgun Krishna Chaturdashi" is the purnimanta name of the same paksha), Fagu Purnima the Meena-ingress month (Falgun), Janai Purnima the Simha-ingress month (Shrawan), Teej the Kanya-ingress month (Bhadra). A wide scan now returns one observance per rule per year instead of one per lunar month. Root cause of the 2026-11-06 R6c revert (PRs #47/#48): the battery matched tithi index + convention only, and the receipt tests' narrow scan windows masked that every lunar month of the year matched too — Shivaratri was served for 2026-11-07, ghost Dashain clusters were listed, ~170 of 188 year-table rows were false. The gate keys on ingress containment, not month name, so a kshaya month that swallows two sankrantis keeps both its festivals; an adhika month (no sankranti) can never own a battery festival.
- `MasaInfo` now exposes `sankrantiRasis` (rasi index 1..12, Mesha..Meena ingress order, parallel to `sankrantiMomentsNpt`) so callers can key on the ingress itself.
- New permanent CI gate `packages/nepali_panchang/test/festival_lunar_month_gate_test.dart`: a full 19-year metonic sweep (AD 2026–2044, per the 2026-11-06 user decision) asserting per year that each anchor rasi falls in exactly one amanta month and every battery rule fires exactly once, inside its anchor month; the 2083 Ghatasthapana receipt (Asoj 25 = 2026-10-11) is cross-checked inside the sweep. Adds roughly 45–60 s to CI — accepted for a structural gate the narrow receipt windows cannot provide.
- No display changes in this release: the R6c display layer re-ships unchanged on top of this gate once green (its rendering was live-verified correct on 2026-11-06; only the battery under it was ungated).

## [Unreleased] — 2027-season festival receipts corpus (R6b-2)

- New permanent CI corpus `packages/nepali_panchang/test/fixtures/festival_receipts_2027.json`: Maha Shivaratri (Falgun 22 = 2027-03-06) and Fagu Purnima (hills Chaitra 7 = 2027-03-21 / Terai Chaitra 8 = 2027-03-22), crawled 2026-11-06 from the Hamro Patro BS 2083 season pages — the whole season is published server-side, so unlike the 2026 corpus these receipts pin day-labels, udaya-tithi labels AND samapti instants (Devanagari numerals decoded at parse time): Chaturdashi runs Mar 6 12:20 → Mar 7 14:04 NPT (Shivaratri nishita day Mar 6, udaya day Mar 7); Purnima runs Mar 21 18:35 → Mar 22 16:25 NPT (hills first-overlap day Mar 21, Terai udaya day Mar 22).
- Two convention-stress observations from the same crawl, recorded in the fixture's `observations` array (deliberately outside the battery — they gate the tithi scanner, not a festival rule): the Magha Purnima kshaya (Purnima began 08:12 on Feb 20 and ended before the Feb 21 sunrise, so no udaya day shows Purnima; HP keeps the Magh Snan / Swasthani Samapti / Pashupatinath Chhaya Darshan labels on Falgun 8 = Feb 20, the first overlap day) and the Krishna Ekadashi vriddhi (udaya Ekadashi on both Mar 3 and Mar 4, the portal's merged samapti 07:37 printed on both days, the Vijaya Ekadashi Vrat label on the second day Mar 4).
- Source honesty: BhaktiBharat's 2027 pages are verified empty templates (rolling-window limitation) and Hamro Patro's BS 2084 pages are verified unpopulated as of 2026-11-06, so Janai Purnima and Teej 2084 (engine adjudication: Aug 17 / Sep 3 2027) are recorded as `pending_2084` — expected, not gated; promote them to receipts when the 2084 season populates or the official 2084 patro publishes (expected spring 2027). The Samiti-patro news corroboration checked during the 2026-11-06 adjudication renders client-side and cannot be re-cited from a fresh fetch, so the gated receipts rest on Hamro Patro alone.
- New CI gate `packages/nepali_panchang/test/festival_receipts_2027_test.dart`: both published days reproduced under the pinned conventions with the divergences exposed (Shivaratri nishita vs udaya; Fagu hills first-overlap vs Terai udaya); the kshaya observation gates `skippedInUdayaChain` + `overlapDays == [Feb 20, Feb 21]` with the festival on the first overlap day; the vriddhi observation gates `udayaDays == [Mar 3, Mar 4]` + `spansMultipleDays`; six occasion-bound and three chain instants band-checked against the HP samapti instants at ±10 min (measured engine deltas 0–4 min). No engine or battery changes — the receipts pin the existing rules.

## [Unreleased] — NPNS full-year daily-tithi audit corpus (HYA-369)

- New permanent CI corpus `packages/nepali_panchang/test/fixtures/npns_daily_tithi_2082_2083.json`: every day of BS 2082 + BS 2083 — 730 live receipts crawled from the Hamro Patro portal (the NPNS-aligned publisher) on 2026-11-06 — the per-day tithi label and paksha exactly as displayed, plus the portal-rendered AD date parsed to ISO. Structural gates: 365 days per year, month lengths match the portal month ends, and the AD chain is strictly consecutive (2025-04-14 → 2027-04-13, no gaps, no repeats) — an independent cross-check of the portal BS↔AD mapping.
- Chain sanity gate: the decoded portal labels walk the tithi cycle with only legal udaya steps — 689 normal, 26 kshaya (a tithi skipped between udayas), 14 vriddhi (the same tithi at consecutive udayas), nothing else across the two years. Vriddhi/kshaya days carry the portal’s own merged-window mark; nothing in the fixture is transcribed by hand.
- Engine agreement gate (`packages/nepali_panchang/test/npns_daily_tithi_audit_test.dart`): the runtime engine’s tithi at udaya (the Hamro Patro display convention) must equal the portal label on every day except knife-edge days — a tithi boundary within half an hour of sunrise, or a vriddhi/kshaya day — with a full mismatch scoreboard printed to the CI log. First-run scoreboard (CI 2026-11-06): 671/730 days agree (91.92%); all 59 mismatches fall on knife-edge days and there are zero disagreements on any non-knife-edge day — the floor is set to a measured 90%, the hard gate is the non-knife-edge requirement.
- Third-party adjudication (2026-11-06): of the 59 disagreement days, the 30 with populated BhaktiBharat pages (its online archive begins ~July 2026; the earlier days are unavailable there) were checked against BhaktiBharat's own tithi windows — BhaktiBharat matches the engine on 30/30, boundary deltas 0–1 min; the portal is the outlier on every one. The mismatches are the portal's vriddhi/kshaya boundary convention, not an engine defect — stated, never absorbed.

## [Unreleased] — ΔT adjudication: keep Espenak–Meeus, document the systematic (HYA-406)

- Docs-only close-out. The ΔT source gap (our Espenak–Meeus 75.6 s vs observed ≈69 s for 2026) is confirmed from three independent directions: the corrected Swiss residual (mean −6.79 s, max 6.81 s, n=233 → Swiss internal ΔT ≈68.8 s), the USNO/IERS long-term predictions table (69.05 ± 0.19 s at 2026.0), and community practice (e.g. AstronomyKit’s default switch to interpolated IERS values).
- Decision: keep the Espenak–Meeus polynomial — deterministic and maintenance-free; the ~6.6 s systematic is sub-band (all 9 Swiss-truth bands pass with 4–15× headroom) and below the publisher minute floor. A ΔT-source swap would shift every boundary time ~6.6 s and force a corpus re-baseline for no measurable gain.
- Adjudication text added to `uncertainty.dart` (named-contributors doc block; header corrected to three anchors) and `docs/methodology.md` (Swiss-truth section). No engine, data, band, or site changes.

## [Unreleased] — Swiss bands tightened to measured + ΔT units fix (HYA-369 A2)

- Every Swiss-truth CI band tightened from provisional to the first-run scoreboard (2026-11-06) measured maxima + margin: tithi/karana 60/30 s (measured 7.9/19 s), nakshatra 180/120 (59.8/71), yoga 300/180 (104.3/119), moonrise 60/15 (0.3/1 — near-exact parity), sunrise 60/30 (11.3/12), lunar_ecl 120/60 (12.0/35), solar_loc 60/30 (5.0/6), lunar_loc 300/120 held (38.8/180). A regression now trips a band within ~3× of the recorded maxima.
- **ΔT units bug fixed:** `swe.deltat()` returns ΔT in days; the harness read it as seconds, producing the constant −75.60 s "residual" that masked the true Swiss-vs-Espenak–Meeus gap. Corrected (×86400) — the now-measurable residual (~−6.6 s expected) is the input to the IERS ΔT adjudication (HYA-406).
- `publishedErrorBars` gains the missing **moonrise** band (±12 min provisional, JPL-receipts basis; the Swiss parity 0.3 s is noted in the basis) and every basis text now carries its measured Swiss-truth scoreboard number. The methodology error-bars anchor list gains the Swiss scoreboard as anchor 3, and the Swiss-truth section carries the full measured table. No engine, data, or site changes.

## [Unreleased] — Swiss sunrise parity channel + readable scoreboard (HYA-369)

- `tools/sweph/sweph_crosscheck.py` gains a **sunrise parity channel**: the Swiss mirror bisects the same USNO −0.8333° geometric center-altitude target the Dart `sunriseJdUt` solves, on Swiss apparent geocentric RA/dec — the same target on both sides, so the scored delta is the full ephemeris + low-accuracy-algorithm reconstruction gap of the served sunrise (no rise/set convention gap). Provisional band 600/300 s until the first CI run records the actual deltas.
- The Swiss scoreboard is now readable **without sign-in log access**: every channel is emitted as a notice annotation (rendered in the run page's server-side Annotations table) and as a markdown summary appended to the GitHub run Summary (`--summary`, wired in ci.yml with `if: always()` so a banded failure still shows the measured deltas). These are the numbers the band-tightening pass reads.

## [Unreleased] — grahan (eclipse) display layer (HYA-421)

- `api/v1/today.json` gains a `grahan` block: the grahan event touching today’s Nepali civil day (visible, sutak or eclipse span), whether sutak is active at build time, and the next grahan — every event carrying its Nepali name (roman + Devanagari), global class, local visibility flags, sutak window, moksha, magnitude and the engine evidence tier.
- New `grahan.html`: today’s sutak state, the next grahan, the upcoming eclipses at Kathmandu (two-year table), the full sutak-rule and convention-collision table (C1–C6), the exemptions note and the receipts pointers. `panchang.html` gains an always-present sutak line.
- Site contract: `grahan.html` and today.json grahan markers enforced pre-merge and post-deploy; the pages.yml smoke fetches the new page; nav, sitemap and llms.txt wired. No engine or fixture changes — the display layer renders the shipped grahan module only.

## [Unreleased] — moonrise solver + festival shastra layer (HYA-417)

- Added `packages/nepali_panchang/lib/src/moonrise.dart`: the first moonrise within an NPT civil day at the Kathmandu anchor — Meeus eq. 15.1 target (0.7276·π − 34′, live parallax) on the same 60-term Ch.47 ephemeris the lunar engine uses. Golden receipts from JPL Horizons topocentric samples pin six 2026 festival dates to a provisional ±12 min band (`test/moonrise_test.dart`).
- `festival_rules.dart`: two new day-choosing conventions — `nishita` (the tithi running at the midnight ending the civil day; Dharma Sindhu ch. 5: "Chaturdashi should be till midnight") and `moonrise` (chandrodaya-vyāpti, Sankata Chaturthi's class; unlocked by the solver, battery entry pending receipts). Every battery rule now carries `shastraCategory` + `shastraCitation` — translation-level (V.D.N. Rao's condensed rendering, kamakoti.org), with the shloka-level citation marked pending.
- Battery extended with four receipt-pinned entries: Maha Shivaratri (Krishna Chaturdashi, nishita — Falgun 3 = Feb 15 2026, udaya gives Feb 16, divergence exposed), Fagu Purnima (Purnima, firstDay hills / udaya Terai, Mar 2–3 2026), Janai Purnima (udaya Aug 28 2026, publishers chose udaya over first-overlap Aug 27) and Teej (udaya Sep 14 2026). New corpus `test/fixtures/festival_receipts_2026.json` + permanent CI gate.
- CI harness: `dump_limb_instants` dumps the per-day moonrise (+ no-rise day count); `sweph_crosscheck.py` mirrors the identical Meeus 15.1 convention on Swiss Ephemeris (geocentric equatorial, same target, 30-min scan + bisection) and enforces provisional 300/150 s moonrise bands. No site or data changes.

## [Unreleased] — Swiss-truth cross-check harness (HYA-369)

- Added `packages/nmiti_cli/bin/dump_limb_instants.dart`: engine-side dump of every lunar limb boundary (base ayanamsa profile) and Kathmandu sunrise in a window — an MIT-clean facts-out command for any truth harness.
- Added `tools/sweph/sweph_crosscheck.py` (+ README): Swiss Ephemeris (pyswisseph, Moshier file-free mode, Lahiri sidereal mode) re-solves every dumped boundary, scores the reconstruction gap per limb, flags knife-edge boundaries (≤30 min from a sunrise) and measures the ΔT-model residual (Swiss internal vs our Espenak–Meeus). AGPL harness boundary: no package imports it, nothing ships from it, outputs are numeric facts only.
- CI (`ci.yml` verify) now runs the dump + cross-check on every push with provisional bands (tithi/karana 300/150 s; nakshatra/yoga 600/300 s — wider because they include the ayanamsa convention gap). No data changes.

## [Unreleased] — commons site pages /docs + /data (HYA-402)

- Added `/docs` (`docs.html`): the documentation pack rendered verbatim as static semantic HTML by the site build, zero client JavaScript. Regenerated from `docs/*.md` on every build, so the page cannot drift from the repository files.
- Extended `/data` (`data.html`): all four canonical CSVs downloadable (the two sankranti CSVs are now served too), a build-time SHA-256 checksum table computed from the exact bytes served, and an explicit CC0-1.0 data license notice.
- The independent Python site contract (pre-merge and post-deploy) now also checks docs.html markers, the L1 CSV structure (1,308 rows, BS 1975–2083), and re-verifies every published SHA-256 digest against the served bytes. No data changes.

## 2026-11-04 — docs pack (PR #15, merge `4ace3c9`)

- Added commons documentation pack: docs index, data dictionary, methodology, changelog, errata log, provenance manifest (HYA-373). No data or code changes.

## 2026-11-03 — site contract fix (PR #11, merge `fc1aae6`)

- `scripts/site_contract.py` became the single source of truth for the site output contract; `ci.yml` runs it pre-merge, `pages.yml` imports it post-deploy. Fixes a post-deploy smoke failure caused by an incorrect CSV marker expectation written in PR #9. No data changes.

## 2026-11-02 — Commons Layer 1 shipped (PRs #7–#9)

- Added `packages/nepali_sankranti`: pure-Dart sidereal ingress engine (Meeus-based, calibrated ayanamsa) + Commons Layer 1 dataset `sankranti_moments_1975_2083.csv` (1,308 NPT moments) and the 1975–2100 extension.
- Added sankranti window-law invariant to CI (HYA-358), including the 24-row pre-1980 allowlist.
- CI calibration record: mean 3.7 min / max 8.6 min vs 48 drikpangang moments (AD 2025–2028), 48/48 correct NPT dates.

## 2026-11-02 — repository scaffold & L0 verified core (PR #1)

- Pub-workspace monorepo (Dart 3.13.7 CI pin): `packages/nepali_date` (pure-Dart BS↔AD engine + invariant checker), `packages/nepali_date_data` (embedded byte-identical CSVs), `packages/nmiti_cli` (invariants gate + static site builder).
- Canonical dataset locked: core 109 verified years + labeled projection tail; BS 2096 upstream defect preserved as `projection-defect`.
- CI: analyze + tests + invariants (fail-closed). Pages: deploy on push + 6-hourly rebuild; 18:15 UTC = 00:00 NPT rollover.
