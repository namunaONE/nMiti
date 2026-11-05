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
    python3 tools/sweph/sweph_crosscheck.py --instants build/limb_instants.json --receipts build/sweph_receipts.json

The Dart command (MIT, engine-side) dumps every tithi, karana, nakshatra
and yoga boundary plus every Kathmandu sunrise in the window, with the
engine's base ayanamsa profile and per-instant Delta T. The harness seeds
the Swiss solver ~72 minutes before each of our instants, re-solves the
boundary by bisection (mirroring the engine's wrap-safe sector solver),
and scores signed and absolute deltas.

Provisional bands (seconds, max/mean): tithi 300/150, karana 300/150,
nakshatra 600/300, yoga 600/300. Nakshatra/yoga bands are wider because
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
- Sunrise is not yet re-solved with swe.rise_trans here - the publisher
  corpus already pins our sunrise (band +/- 1 min) and a rise-time
  harness needs careful refraction/pressure conventions. It is the next
  receipt batch, not a blocker.
- JPL Horizons stays a manual spot-audit channel: compare a handful of
  boundaries per quarter via the Horizons API against the receipts file.
