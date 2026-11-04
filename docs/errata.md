# Public errata log

Every known defect and incident, in the open. Nothing is silently fixed.

## Data

### E-1 — BS 2096 has 364 days (OPEN)

- **Status:** preserved, labeled `projection-defect`. **Class:** upstream projection defect, not ours.
- Months: 30,31,32,32,31,30,30,29,30,29,30,30. The year is one day short; the upstream table we projected from carries this defect.
- **Policy:** stays visible in the dataset and JSON until official 2084+ data publishes; then replaced and recorded here ([HYA-357](https://linear.app/hyamuji/issue/HYA-357)).
- **Consumer guidance:** do not trust BS 2096 dates beyond the labeled projection; the SDK returns them with the defect tag, not as verified fact.

### E-2 — Five disputed years (RESOLVED)

- BS 1989, 1991, 1993, 2004, 2062 were disputed between sources. R12 (2026-11-02) resolved all five in favor of the shipped rows; tagged `disputed-resolved`. If official archival evidence contradicts a row, it will be corrected here.

## Ecosystem (informational — not defects in this dataset)

- Two live Nepali calendar sites were found running corrupted BS tables in the R12 crawl (one day early / one day late from late 2083). Recorded as test vectors in [data-provenance.md](data-provenance.md); do not copy their data.

## Pipeline incidents

### I-1 — Post-deploy smoke failed on main (2026-11-03, RESOLVED)

- The smoke's sankranti CSV check expected a substring that never occurs in the canonical file (wrong column-order assumption written in PR #9). Data was correct; the expectation was wrong. Fixed in PR #11 (`fc1aae6`): one shared contract script now gates pre-merge and post-deploy, so the gates cannot drift.
- **Lesson recorded:** expectations against CSV data must be validated against real file bytes before shipping.

### I-2 — Site showed yesterday's BS date after NPT midnight (RESOLVED, HYA-398)

- GitHub scheduled runs never fired, so the site did not roll over at 00:00 NPT. Fixed with the layered schedule strategy: 6-hourly rebuilds, a 01:00 NPT guard run, a 26-hour freshness canary, and a keep-alive workflow against GitHub's 60-day cron auto-disable. Full design: [reliability.md](reliability.md).
