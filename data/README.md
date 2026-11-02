# nMiti Bikram Sambat dataset

Two canonical CSVs, one per evidence tier. They are the single source of truth
for everything nMiti ships (SDK, site, JSON API, apps). Nothing downstream may
hard-code a date.

## Files

- calendar_bs_core_1975_2083.csv - core tier, 109 years, machine-verified
- calendar_bs_tail_2084_2100.csv - projection tier, 17 years, labeled

## Format

    bs_year,baisakh1,weekday,baisakh,jestha,ashar,shrawan,bhadra,asoj,kartik,mangsir,poush,magh,falgun,chaitra,days,evidence

- baisakh1: Gregorian (ISO) date of Baisakh 1 for that BS year
- weekday: weekday of Baisakh 1 (Mon..Sun), redundant check against baisakh1
- 12 columns: days in each BS month, Baisakh through Chaitra
- days: total days in the BS year (365 or 366 for verified data)
- evidence: comma-separated tags (see below)

Lines starting with # are provenance comments.

## Evidence tiers and tags

- Core: every row is r12-verified (machine-diffed 2026-11-02 against
  amitgaru/nepali-datetime calendar_bs.csv, blob 83e8c16; anchor chain closes
  exactly on official Baisakh 1 2084 = Wed 2027-04-14; live-confirmed across
  10+ Nepali calendar sites).
- disputed-resolved: years 1989, 1991, 1993, 2004, 2062 were disputed between
  sources; R12 resolved all five in favor of these rows.
- live-2026-11-02: row 2083 additionally confirmed live and against the
  national panchanga row quoted in dibas-np/NepalKit PR #34.
- Tail: projection only. 2084 = official-anchor (the only officially
  announced future date). 2085-2100 chain from it.
- projection-defect: BS 2096 has 364 days - a genuine upstream defect that we
  preserve and label rather than silently fix. It must be replaced when
  official data publishes.

## Invariants (enforced in CI)

- Every month has 29-32 days; every core year has exactly 365 or 366 days.
- Baisakh 1 of year N+1 equals Baisakh 1 of year N plus the length of year N.
- Every Baisakh 1 falls on April 11-15.
- The weekday column matches the baisakh1 date.
- No three consecutive years share an identical 12-month row in the core
  (runs of two occur in real, correct data; longer runs indicate corruption).
- The tail chains continuously from the core and starts at official 2084.

## License

Data in this directory: CC0-1.0 (creative commons zero). Calendar facts are
not copyrightable; we dedicate the compilation and evidence tags to the
public domain to maximize reuse and machine readability.

Cross-check source: amitgaru/nepali-datetime (GitHub). No code was copied;
only the data table was machine-diffed, and every row was independently
verified against live Nepali calendars and official anchors.
