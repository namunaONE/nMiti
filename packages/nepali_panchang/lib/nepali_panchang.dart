/// Nepal-first lunar panchang engine for the nMiti Commons (R6a-1, HYA-403).
///
/// The engine computes tithi, nakshatra, yoga, karana and sunrise moments at
/// runtime from celestial mechanics - full 60-term Meeus Ch.47 moon series,
/// Ch.25 solar theory, a Delta-T table and per-source ayanamsa profiles - with
/// no precomputed data files, covering the entire BS 1975-2100+ range.
///
/// Step 2 shipped the astronomy core: the Meeus Ch.47 moon (example 47.a is
/// its permanent unit test), the Ch.25 sun (example 25.a) and the
/// Espenak-Meeus Delta-T polynomials.
///
/// Step 3 (this revision) ships the limb layer on top of that core: tithi,
/// nakshatra, yoga and karana angles with canonical name tables, the
/// wrap-safe boundary solver, per-source ayanamsa profiles, NPT civil-time
/// helpers and the USNO sunrise solver. The permanent accuracy gate against
/// the 197-receipt golden corpus lives in test/receipts_calibration_test.dart.
library;

export 'src/ayanamsa.dart';
export 'src/civil_time.dart';
export 'src/delta_t.dart';
export 'src/julian_day.dart';
export 'src/limbs.dart';
export 'src/moon.dart';
export 'src/solver.dart';
export 'src/sun.dart';
export 'src/sunrise.dart';
