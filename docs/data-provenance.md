# Data provenance record

## The R12 cross-validation (2026-11-02)

- Source table: amitgaru/nepali-datetime calendar_bs.csv
  (blob 83e8c16794ba4aa3da4dee472efe18ac2fb8e94e), fetched fresh.
- Machine diff against our reference: 109/109 core rows (BS 1975-2083),
  1308/1308 cells identical.
- All 5 historically disputed years (BS 1989, 1991, 1993, 2004, 2062)
  match; tagged disputed-resolved.
- The 109-year anchor chain closes exactly on the only official future
  anchor: Baisakh 1 2084 = Wednesday 2027-04-14.
- Every Baisakh 1 falls in the April 11-15 window (checked machine-wide).
- Live confirmation on 2026-11-02 (today = Kartik 16, 2083, Monday)
  across 10+ Nepali calendar sites; the 2083 row matches the national
  panchanga row quoted in dibas-np/NepalKit PR #34.

## Known defect, preserved and labeled

- BS 2096 in the projection tail has 364 days
  (months 30,31,32,32,31,30,30,29,30,29,30,30) — a genuine upstream
  defect. It is tagged projection-defect and reported by the invariant
  checker as a known defect (builds stay green; the defect stays visible
  in the JSON API). Replace with official data when Nepal publishes the
  2084+ calendar; never silently fix projections.

## Live corrupted-variant carriers (test vectors, do not copy)

- nepalicalendar.online — one day early from Kartik 2083 onward.
- KhataIN — one day late from Mangsir 2083 (Mangsir 30 days;
  Poush 1 = Dec 17, 2026).

## Structural facts (machine-checked)

- Identical consecutive rows do occur in correct data: runs of exactly 2
  exist (1993-94, 1997-98, 2082-83); no run of 3+ exists in the core.
  The correct invariant is therefore "no run >= 3 identical consecutive
  rows", not "no duplicates in a window".
- The core has 13 distinct 12-month row shapes and 28 leap (366-day)
  years.
