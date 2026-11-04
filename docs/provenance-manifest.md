# Provenance manifest

Every external input to the nMiti dataset, with identifiers. Nothing enters `data/` without appearing here.

| # | Source | Identifier / anchor | Used for | Rung |
|---|---|---|---|---|
| 1 | amitgaru/nepali-datetime — `calendar_bs.csv` | blob `83e8c16794ba4aa3da4dee472efe18ac2fb8e94e` (fetched fresh 2026-11-02) | L0 cross-validation: 109/109 rows, 1308/1308 cells machine-diffed | 1 (consensus) |
| 2 | Official BS 2084 anchor | Baisakh 1 2084 = Wednesday 2027-04-14 | Anchor-chain closure; tail `official-anchor` row | 4 (official) |
| 3 | Live Nepali calendar portals (10+) | crawl of 2026-11-02 (today = Kartik 16, 2083) | Live confirmation of the 2083 row and cross-year sanity | 2 (triangulation) |
| 4 | dibas-np/NepalKit PR #34 | national panchanga row for 2083 | Independent confirmation of the 2083 row | 2 (triangulation) |
| 5 | drikpangang per-rashi year pages | 48 ingress moments, AD 2025–2028 | Ayanamsa calibration of the L1 solar engine (mean 3.7 / max 8.6 min, 48/48 NPT dates) | 2 (triangulation) |
| 6 | Surya Panchang 2083 (NPNS-approved, print) | OCR-mined; saurojya paddhati, Kathmandu 27°04′N 85°19′E, meridian 86°15′E since BS 2042 | Print validation of engines; month-start windows; festival rules format | 4 (official) |
| 7 | Pushpanjali Panchang VS 2083 (Ujjain, traditional Indian chain) | OCR-mined | Independent 12/12 confirmation of 2083 ingress dates | 1 (consensus) |
| 8 | Meeus, *Astronomical Algorithms* | standard algorithms, sidereal correction via calibrated ayanamsa `23.87508 + 1.36062·(J−2451545)/36525` | L1 solar engine | — (method) |

**No code was copied from any source.** Only calendar facts were compared against, or digitized from, the sources above; facts are not copyrightable and the compilation is dedicated CC0.

**Corrections:** if any row here is wrong, open an issue or PR — corrections are public errata, never silent edits (see [errata.md](errata.md)).
