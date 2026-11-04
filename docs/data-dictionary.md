# Data dictionary

All files are UTF-8 CSV. Lines beginning with `#` are provenance comments and must be skipped by parsers. The first non-comment line is the header. Timestamps carry explicit offsets. No column may be derived downstream by hard-coding: everything comes from these files.

## 1. `calendar_bs_core_1975_2083.csv` — L0 core (109 rows, BS 1975–2083)

Header:

    bs_year,baisakh1,weekday,baisakh,jestha,ashar,shrawan,bhadra,asoj,kartik,mangsir,poush,magh,falgun,chaitra,days,evidence

| Column | Type | Meaning |
|---|---|---|
| `bs_year` | int | Bikram Sambat year (1975–2083) |
| `baisakh1` | ISO date | Gregorian date of Baisakh 1 of that BS year |
| `weekday` | string | Weekday of Baisakh 1 (Mon..Sun); redundant check against `baisakh1` |
| `baisakh` … `chaitra` | int ×12 | Days in each BS month, Baisakh through Chaitra (29–32) |
| `days` | int | Total days in the BS year (365 or 366) |
| `evidence` | tags | Comma-separated evidence tags (see below) |

**Evidence tags (core):**

- `r12-verified` — machine-diffed 2026-11-02 against [amitgaru/nepali-datetime](https://github.com/amitgaru/nepali-datetime) `calendar_bs.csv` (blob `83e8c16…`): 109/109 rows, 1308/1308 cells identical; live-confirmed across 10+ Nepali calendar sites.
- `disputed-resolved` — historically disputed years (1989, 1991, 1993, 2004, 2062), resolved by the R12 cross-validation.
- `live-2026-11-02` — the 2083 row, additionally confirmed live and against the national panchanga row quoted in dibas-np/NepalKit PR #34.

## 2. `calendar_bs_tail_2084_2100.csv` — projection tail (17 rows, BS 2084–2100)

Same schema as the core. **Every row is projection, not verified fact.**

**Evidence tags (tail):**

- `official-anchor` — BS 2084 only: the only officially announced future date (Baisakh 1 2084 = Wednesday 2027-04-14).
- `projection` — BS 2085–2100, chained from the official anchor.
- `projection-defect` — BS 2096: 364 days (months 30,31,32,32,31,30,30,29,30,29,30,30), a genuine upstream defect, preserved and labeled, never silently fixed. Replace when official 2084+ data publishes ([HYA-357](https://linear.app/hyamuji/issue/HYA-357)).

## 3. `sankranti_moments_1975_2083.csv` — Commons Layer 1 (1,308 rows)

Header:

    bs_year,month_no,month,rashi,sankranti_npt,weekday,starts_on_delta,evidence

| Column | Type | Meaning |
|---|---|---|
| `bs_year` | int | Bikram Sambat year |
| `month_no` | int | 1–12; month 1 is Baisakh (Mesha sankranti) |
| `month` | string | BS month name (Baisakh…Chaitra) |
| `rashi` | string | Sidereal sign entered (Mesha…Meena) |
| `sankranti_npt` | ISO timestamp | Ingress instant with explicit `+05:45` Nepal Time offset |
| `weekday` | string | Weekday of the ingress NPT date |
| `starts_on_delta` | int | 0 = month starts on ingress date; 1 = next day; −1 = before ingress (only the 24 cataloged pre-2036 consensus rows) |
| `evidence` | tags | Provenance tags |

## 4. `sankranti_moments_1975_2100.csv` — L1 extended

Same schema; adds the projection years 2084–2100. Rows beyond 2083 inherit projection status: use with ±1 uncertainty, never as verified fact.

## Parsing rules

- Skip `#` comment lines; first data header is `bs_year` (or `bs_year,…`).
- Sankranti CSVs have 8 columns minimum; `evidence` may contain commas and must be re-joined (cols 8+).
- The `starts_on_delta` column is informational; the CI window check always recomputes deltas from month starts and ingress instants — it never trusts the column.

## Time

- All civil dates are Nepal Time (NPT = UTC+05:45).
- Fiscal year note: the Nepali fiscal year runs Shrawan 1 → end of Ashadh; the boundary between years matters more than any other single date for business use.
