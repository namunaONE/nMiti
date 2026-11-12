# Swiss-truth cross-check harness (HYA-369)

Re-solves every lunar limb boundary of the nMiti engine with Swiss
Ephemeris and scores the reconstruction gap. This is truth channel 3 in
the engine's verification ladder:

| Truth channel | License | Where it runs |
| -- | -- | -- |
| Publisher receipts (BhaktiBharat + Hamro Patro, 226 limb boundaries + 76 karana/sunrise receipts) | facts, CC0 | CI on every push |
| tithi_engine (Swiss .se1-anchored; Kathmandu is a registry city in our anchor cell) | Apache-2.0 | CI dev-dependency oracle (HYA-418) |
| **Swiss Ephemeris via pyswisseph (this harness)** | **AGPL-3, harness boundary** | **CI on every push (HYA-369)** |
| JPL Horizons | public API | manual spot audits (network + rate limits; not wired into CI) |

## How it runs in CI

    dart run nmiti_cli:dump_limb_instants --start 2026-10-16 --end 2026-12-02 --out build/limb_instants.json
    python3 -m pip install pyswisseph
    python3 tools/sweph/sweph_crosscheck.py --instants build/limb_instants.json --receipts build/sweph_receipts.json --summary build/sweph_summary.md

The `--summary` markdown is appended to `GITHUB_STEP_SUMMARY` by ci.yml,
so the full scoreboard renders on the run's Summary tab without
sign-in log access; every channel line is also emitted as a notice
annotation on the run page.

The Dart command (MIT, engine-side) dumps every tithi, karana, nakshatra
and yoga boundary plus every Kathmandu sunrise in the window, with the
engine's base ayanamsa profile and per-instant Delta T. The harness seeds
the Swiss solver ~72 minutes before each of our instants, re-solves the
boundary by bisection (mirroring the engine's wrap-safe sector solver),
and scores signed and absolute deltas.

Bands tightened to the first CI scoreboard (2026-11-06), measured
maxima + margin (seconds, band hard/mean): tithi 60/30 and karana
60/30 (measured 7.9|19), nakshatra 180/120 (59.8|71) and yoga 300/180
(104.3|119 - wider because they include the ayanamsa convention gap,
our fitted base vs Swiss Lahiri), moonrise 60/15 (0.3|1 - near-exact
parity), sunrise 60/30 (11.3|12). A regression now trips a band
within ~3x of the recorded maxima.

HYA-369 alignment (2026-11-10): beside the raw scoreboard, the
harness also scores two derived channels into the Summary and the
receipts JSON. The aligned channels subtract the
engine-base-vs-Swiss-Lahiri convention term per receipt (via the
new ayanamsa_deg / ayanamsa_reference_deg fields in the dump;
bands 60/30 s for nakshatra and yoga - expected in the tithi
class: pure ephemeris parity). The reference-line channel checks
the receipts-measured Dart constant (23.85709 deg at J2000 +
1.398024 deg/cy) against swe.get_ayanamsa_ut over the dump window
(band 5 arcsec). The raw bands stay unchanged, so a regression
trips either way and the alignment itself stays under test.

The harness also reports:

- **Delta-T residual** - Swiss internal Delta-T model minus our
  Espenak-Meeus polynomial at every boundary (the named systematic
  contributor in the published error bars). First-run gotcha, fixed
  2026-11-06: swe.deltat returns Delta-T in DAYS - read as seconds it
  produced a constant -75.60 s "residual" masking the true ~-6.6 s
  gap; the harness now converts (x86400). The corrected residual is
  the input to the IERS Delta-T adjudication (HYA-406).
  Adjudicated 2026-11-06: KEEP Espenak-Meeus - deterministic, no table
  maintenance, and the ~6.6 s systematic is sub-band and below the
  publisher minute floor. Stated in the published error bars, never
  absorbed.
- **Knife-edge flags** - every boundary within 30 minutes of a sunrise:
  the days two honest panchangs can print different limbs. This list is
  the input the festival layer (R6b) consumes for per-source attribution.

## Lunar eclipse receipts cross-check (HYA-421)

The harness also cross-checks the NASA 2026 lunar eclipse receipts
fixture (default
`packages/nepali_panchang/test/fixtures/nasa_lunar_2026.json`, override
with `--eclipse-fixture`) - the same corpus the Dart CI gate pins
`eclipse_lunar.dart` against - by re-solving each eclipse with
`swe.lun_eclipse_when` (global, geocentric: the same channel the Dart
solver computes). The receipts are therefore validated by two independent
ephemerides, and the engine-vs-NASA deltas measured in the Dart gate are
attributed to the engine, not to the receipts.

Contact times only: the global search does not return magnitudes, which
stay pinned by the Dart gate. Band tightened to the first scoreboard
(2026-11-06, measured 12.0|35 s, n=12): 120/60 s (max/mean).

## Nepal-local circumstances channels (HYA-421 step 4)

`grahan.dart` - the shastra module shipping sutak windows anchored to
the LOCAL visible contacts - is built on the local-circumstances
solvers, so the harness cross-checks those channels too:

- **`solar_local`**: `swe.sol_eclipse_when_loc` re-solves the Kathmandu
  solar receipts fixture (default
  `packages/nepali_panchang/test/fixtures/solar_kathmandu_receipts.json`,
  override with `--solar-fixture`) - partial contacts and greatest
  against the timeanddate clock receipts, NASA magnitude (attr[8]) and
  obscuration (attr[2]) with a 0.02 band, apparent sun altitude at
  greatest within 2 deg, and ordering sanity (tret[1] < tret[0] <
  tret[4], full-tret dump on failure). The below-horizon
  penumbra-past-terminator grazes must be SKIPPED by Swiss's own
  visibility gate - the same gate the Dart sutak logic trusts - and
  that agreement is asserted, not assumed.
- **`lunar_local`**: `swe.lun_eclipse_when_loc` re-solves the grahan
  shastra fixture's lunar events (default
  `packages/nepali_panchang/test/fixtures/grahan_shastra_receipts.json`,
  override with `--grahan-fixture`). Swiss's local visibility gate must
  agree with the timeanddate verdicts (not-visible eclipses are
  skipped); the visible contacts reproduce the tAD stage tables
  (grastodit events compare greatest-only - the pre-moonrise phases
  are clipped by the gate itself); receipt stages the local channel
  omits must be below the moon's horizon or they fail. The
  `lun_when_loc` tret slot layout is resolved empirically per event by
  candidate-slot scoring (the recorded `lun_eclipse_when` layout
  gotcha), the winning candidate named in the receipts JSON.

Bands tightened to the first CI scoreboard (2026-11-06): solar_local
60/30 s (max/mean; measured 5.0|6 s, n=3), lunar_local 300/120 s held
(measured 38.8|180 s, n=15 - rise/set clamp variance on the tAD stage
tables).

## ELP2000-82B truncation spike (HYA-369 follow-up)

`elp_spike.py` measures what a NASA-canon-class moon would do to the
tithi/karana bands - the engine-perfection research move #2 - without
touching the engine:

    python3 tools/sweph/elp_spike.py --instants build/limb_instants.json --receipts build/sweph_receipts.json --out build/elp_spike.json --summary build/elp_spike_summary.md

It downloads the ELP2000-82B semi-analytical lunar theory (Chapront-
Touze & Chapront 1983; distributed by IMCCE/Bureau des Longitudes) at
CI time (~3 MB, cached under `build/elp82b/`), truncates it per the
NASA Five Millennium Canon recipe (neglect periodic terms smaller than
0.0005 arcsec in longitude/latitude and about 1 m in distance) and
evaluates it at the engine's own boundary instants in both argument
variants (raw 1983 ELP82B mean elements vs the improved Chapront 2002
arguments - the same polynomials the engine's Meeus Ch.47 moon uses).
The evaluator is a faithful port of the reference Fortran `elp82b_1`.

Outputs, as annotations on its own CI step plus a markdown summary:

- survivor term counts per file and total (the Dart port size), and
  an evaluation timing benchmark;
- truncated-ELP moon longitude accuracy vs Swiss geometric
  mean-of-date at every boundary - and the same error curve for the
  current engine moon (the error an upgrade would remove);
- predicted post-upgrade tithi/karana bands: the moon substitution
  shifts each boundary by dLambda/rate, applied to the per-boundary
  Swiss deltas from `sweph_receipts.json` - plus two floors: a
  perfect geometric moon and a perfect apparent moon (the
  decomposition ladder for the go/no-go call on an engine upgrade).

The dump gained one field for this: `moon_deg`, the engine's
geometric moon longitude at each boundary.

**License boundary:** ELP2000-82B is public research data from the
Bureau des Longitudes/IMCCE; this spike downloads it at CI time and
emits numeric facts only. Nothing from it ships in any artifact, and
the MIT engine is untouched - vendoring a truncated coefficient table
into the engine would be a separate PR with its own review (and
served-value changes).

## ELP2000-82B engine upgrade (HYA-369)

That separate PR shipped: the engine moon (`moon.dart`) now evaluates
the truncated ELP2000-82B series with the Chapront 2002 mean
arguments - the spike's go-decision variant (predicted tithi
1.2|3 s vs the 4.1|11 s the 60-term Meeus Ch.47 moon measured). The
frame and conventions are unchanged - geometric, mean ecliptic and
equinox of date, no nutation, no aberration, light-time still the
named skip - so this is a fit change only; served limb times move by
the seconds the scoreboard measures, and convention changes stay in
their own PRs.

The coefficient table under
`packages/nepali_panchang/lib/src/elp2000/` is GENERATED, never
hand-edited:

    python3 tools/sweph/elp_build_table.py --data-dir build/elp82b --out-dir packages/nepali_panchang/lib/src/elp2000

`elp_build_table.py` reuses the spike's parser (`ElpTheory`), folds
the distance cosine shift and the a0/ath scale factor into the table
at generation time, verifies the emitted flat table against the
reference evaluator at three epochs plus the Meeus 47.a anchor, and
writes the chunks in a deterministic byte-stable layout. Two guards
keep it honest:

- `.github/workflows/elp-table-gen.yml` regenerates and COMMITS the
  table when the generator changes, so the ~300 KB of coefficients
  never travels through a review tool;
- the ci.yml "elp2000 vendored table freshness gate" regenerates it
  from the `build/elp82b` download on EVERY run and fails on any
  byte drift - a stale table cannot ride a recipe change through
  review. The gate prints the 47.a anchor values as run notices;
  `moon_47a_test.dart` pins them.

**License:** the vendored table is numeric facts computed from the
public IMCCE ELP2000-82B research data; the theory is cited academic
work (Chapront-Touze & Chapront 1983; Chapront, Chapront-Touze,
Francou & Laskar 2002) and no text or code from the distribution is
copied - the same facts-only boundary as the publisher receipts.

## License boundary (AGPL facts-out) - read this before touching

Swiss Ephemeris is AGPL-3 (free for open-source use; CHF 700 commercial).
The strategy adopted in HYA-369 keeps the commons license-clean:

1. **Compute in the harness, ship only facts.** pyswisseph is invoked
   only by this CI/verification harness. No nMiti package imports or
   links against it; no ephemeris data ships in the repository or the
   site; the harness's only outputs are numeric facts (deltas, counts) -
   not copyrightable, and already ours.
2. **The Dart engine stays MIT and dependency-free** - nothing AGPL ever
   enters the dependency graph of any published package.
3. **Treat `sweph_crosscheck.py` as under pyswisseph's terms** for
   distribution-safety; it lives in `tools/`, outside every package, and
   imports nothing from nMiti (only reads its JSON output).

If a future offline SWEPH pipeline generates derived date facts (festival
CSVs), it follows the same boundary: generated facts are committed as
data (CC0), the generating harness stays in `tools/`, and nothing links.

## The graha channels (HYA-450, Wave 1)

`dump_limb_instants.dart` also dumps a daily graha row: the
five visible planets' sidereal longitudes (Mercury, Venus, Mars,
Jupiter, Saturn) and the mean lunar node (Rahu) at 12:00 UT, sidereal
on the BASE ayanamsa profile so the harness measures the ayanamsa
convention gap itself - the same facts-out discipline as the lunar
channels. The engine side (graha.dart) is MIT, built on the generated
vendored VSOP87D table (`tools/sweph/graha_build_table.py`,
IMCCE public data - numeric facts only, same license boundary as the
ELP table: the theory is cited academic work, Bretagnon & Francou
1988, and no text or code from the distribution is copied).

The Swiss-side scorer for these rows (`graha_crosscheck.py`)
is a follow-up arc: re-solving each graha row with pyswisseph, scoring
the ephemeris gap and the ayanamsa convention gap separately, banded
per the CI scoreboard. Until it lands, the graha channels are gated by
the JPL Horizons receipts fixture in CI (apparent longitude/latitude
vs DE441, PROVISIONAL 15"/5" bands) and the ci.yml vendored-table
freshness gate regenerates and byte-diffs the VSOP87D table on every
run.

## Notes and next steps

- Moshier mode (FLG_MOSEPH) is file-free and deterministic - right for
  CI. If stronger parity is ever needed, drop .se1 files into an
  ephemeris path and switch FLG_MOSEPH to FLG_SWIEPH; the receipts should
  tighten, not change conclusions (Moshier is sub-arcsecond on the Moon).
- Sunrise parity SHIPPED (HYA-369 close-out): the harness bisects the
  same USNO -0.8333 deg geometric center-altitude target the Dart
  sunriseJdUt solves, on Swiss apparent geocentric RA/dec - the same
  target on both sides, so no refraction/pressure convention gap
  enters; the scored delta is the full low-accuracy-algorithm +
  ephemeris reconstruction gap of the served sunrise.
- JPL Horizons stays a manual spot-audit channel: compare a handful of
  boundaries per quarter via the Horizons API against the receipts file.

