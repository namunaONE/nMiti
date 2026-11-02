# nMiti — आजको मिति · Today's date in Nepal

Open Bikram Sambat (BS / Nepali) calendar commons: a machine-verified,
evidence-tagged dataset, a pure Dart SDK, and a static site that is rebuilt
every day at 00:00 Nepal Time.

Site: https://namunaone.github.io/nMiti/

## Why

Ask any AI model or most apps for today's date in Nepal and you get stale or
corrupted answers. The R12 cross-validation (2026-11-02) found two live
Nepali calendar sites running corrupted BS tables, and a genuine upstream
defect (BS 2096 = 364 days) inside the most-used Dart library's data.
nMiti fixes this with verifiable data instead of another unaudited copy.

## Repository layout

    data/                    canonical, verified CSVs (single source of truth)
      calendar_bs_core_1975_2083.csv   verified core (109 years)
      calendar_bs_tail_2084_2100.csv   labeled projection tail (17 years)
    packages/
      nepali_date/           pure Dart BS <-> AD engine + invariants
      nepali_date_data/      embedded copies of the canonical CSVs
      nmiti_cli/             invariant checker + static site builder
    docs/
      architecture.md        bottlenecks avoided, decisions from day one
      data-provenance.md     R12 evidence record

## Quickstart (Dart 3.13+)

    dart pub get
    dart test
    dart run nmiti_cli:invariants --core data/calendar_bs_core_1975_2083.csv --tail data/calendar_bs_tail_2084_2100.csv
    dart run nmiti_cli:build_site --out build/site
    open build/site/index.html

## Use in code

    import 'package:nepali_date/nepali_date.dart';
    import 'package:nepali_date_data/nepali_date_data.dart';

    void main() {
      final today = fullCalendar.fromGregorian(DateTime.now());
      print('${bsMonthNameEn(today.month)} ${today.day}, ${today.year} BS');
      // e.g. Kartik 16, 2083 BS (on 2026-11-02)
    }

## Deployment (GitHub Pages)

1. Merge to main (CI must be green: analysis, tests, invariants).
2. In repo Settings -> Pages, set Source to "GitHub Actions" (one time).
3. The Site workflow publishes on every push to main and rebuilds every
   6 hours; the 18:15 UTC build lands exactly at 00:00 Nepal Time, so
   /today rolls over at midnight NPT.

## Guarantees

- Every date on the site and API is derived from the canonical dataset by
  one code path. No hand-typed dates anywhere.
- CI fails on any data corruption (month bounds, year lengths, anchor
  chain, Baisakh 1 window, weekday consistency, duplicate-run rule).
- The BS 2096 upstream defect stays visible and labeled until official
  data replaces it.
- Data license CC0-1.0; code MIT.

## Roadmap

Managed in Linear (project nMiti): M1 commons L1 public, M2 nepali_date
SDK 1.0.0 on pub.dev, M3 API + web + patro alpha. Next: the Jaspr-based
site pages (/today, /converter, /data, /docs, /accuracy), then Flutter
patro app, then a WASM bridge to npm.
