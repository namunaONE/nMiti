/// Nepal-first lunar panchang engine for the nMiti Commons (R6a-1, HYA-403).
///
/// The engine computes tithi, nakshatra, yoga, karana and sunrise moments at
/// runtime from celestial mechanics - full 60-term Meeus Ch.47 moon series,
/// Ch.25 solar theory, a Delta-T table and per-source ayanamsa profiles - with
/// no precomputed data files, covering the entire BS 1975-2100+ range.
///
/// Step 2 (this revision) ships the astronomy core: the Meeus Ch.47 moon
/// (example 47.a is its permanent unit test), the Ch.25 sun (example 25.a) and
/// the Espenak-Meeus Delta-T polynomials. Limbs and wrap-safe solvers
/// (step 3) and ayanamsa profiles (step 4) land in later steps; every step
/// ships green before the next.
library;

export 'src/delta_t.dart';
export 'src/julian_day.dart';
export 'src/moon.dart';
export 'src/sun.dart';
