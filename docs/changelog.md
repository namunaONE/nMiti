# Changelog

Data changes and releases of the nMiti commons. The dataset is versioned with the repo; the site carries the build version in its footer. Dates are ISO.

## [Unreleased] — docs pack (this PR)

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
