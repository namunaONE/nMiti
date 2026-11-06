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

Provisional bands (seconds, max/mean): tithi 300/150, karana 300/150,
nakshatra 600/300, yoga 600/300, moonrise 300/150, sunrise 600/300
(the sunrise band stays generous until the first CI run records the
actual deltas). Nakshatra/yoga bands are wider because
they include the ayanamsa convention gap (our fitted base vs Swiss
Lahiri); tithi/karana are pure ephemeris parity. Bands tighten as receipts
accumulate, exactly like the publisher corpus bands before them.

The harness also reports:

- **Delta-T residual** - Swiss internal Delta-T model minus our
  Espenak-Meeus polynomial at every boundary (the named systematic
  contributor in the published error bars; expected order ~5-10 s near
  2026).
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
stay pinned by the Dart gate. Provisional band 300/120 s (max/mean),
tightened once the first runs record the actual Swiss-vs-NASA deltas.

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

Provisional bands 300/120 s (max/mean) on both contact channels,
tightened once the first CI run records the actual deltas.

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

