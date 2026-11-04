# nMiti Commons documentation

nMiti is an open Bikram Sambat (BS / Nepali) calendar commons: a machine-verified, evidence-tagged dataset, a pure-Dart SDK, and a static site rebuilt daily at 00:00 Nepal Time.

**Vision:** no Nepali app — human or AI — ever shows the wrong date.

## Start here

- [Data dictionary](data-dictionary.md) — every file, every column, every evidence tag
- [Methodology](methodology.md) — how the data was built and verified
- [Changelog](changelog.md) — what changed, when, and why
- [Errata](errata.md) — known defects and incidents, in the open
- [Provenance manifest](provenance-manifest.md) — every external source, with identifiers

## The dataset

- `data/calendar_bs_core_1975_2083.csv` — 109 verified years (L0)
- `data/calendar_bs_tail_2084_2100.csv` — 17 labeled projection years
- `data/sankranti_moments_1975_2083.csv` — 1,308 sidereal ingress moments, NPT (L1)
- `data/sankranti_moments_1975_2100.csv` — L1 extended through the projection tail

## Guarantees

1. One canonical dataset; every date on the site, in the SDK, and in the JSON is derived from it by one code path. No hand-typed dates.
2. CI refuses to ship on any data corruption (invariants + drift checks + sankranti window law).
3. Projections are labeled, never presented as verified.
4. Known defects are preserved and labeled, never silently fixed.
5. Data: CC0-1.0. Code: MIT.

## Licenses & attribution

- Data files (and their embedded copies in `packages/nepali_date_data`): CC0-1.0
- Code: MIT (see repository root `LICENSE`)
- Cite sources, tag provenance — calendar facts belong to everyone.
