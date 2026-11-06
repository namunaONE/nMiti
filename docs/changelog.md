# Changelog

Data changes and releases of the nMiti commons. The dataset is versioned with the repo; the site carries the build version in its footer. Dates are ISO.

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
