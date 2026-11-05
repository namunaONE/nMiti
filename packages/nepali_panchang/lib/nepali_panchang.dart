/// Nepal-first lunar panchang engine for the nMiti Commons (R6a-1, HYA-403).
///
/// The engine computes tithi, nakshatra, yoga, karana and sunrise moments at
/// runtime from celestial mechanics - full 60-term Meeus Ch.47 moon series,
/// Ch.25 solar theory, a Delta-T table and per-source ayanamsa profiles -
/// with no precomputed data files, covering the entire BS 1975-2100+ range.
///
/// Step 2 shipped the astronomy core: the Meeus Ch.47 moon (example 47.a is
/// its permanent unit test), the Ch.25 sun (example 25.a) and the
/// Espenak-Meeus Delta-T polynomials.
///
/// Step 3 ships the limb layer on top of that core: tithi, nakshatra, yoga
/// and karana angles with canonical name tables, the wrap-safe boundary
/// solver, per-source ayanamsa profiles, NPT civil-time helpers and the
/// USNO sunrise solver. The permanent accuracy gate against the 197-receipt
/// golden corpus lives in test/receipts_calibration_test.dart.
///
/// R6a-3 (HYA-416) adds the daily-shape layer: panchangFor composes the limbs
/// into the per-day block the site and API serve, with reference moments,
/// vriddhi/kshaya flags and honesty fields.
///
/// L1 (HYA-419) adds the masa layer: amanta lunar months with adhika/kshaya
/// detection from the engine's own new-moon scan and sankranti overlay,
/// receipt-anchored to the 2026 Adhika Jestha and cross-checked against the
/// tithi_engine oracle in CI.
///
/// R6b (HYA-367) adds the festival rules layer: the Dashain-Tihar festival
/// battery as data, day-choosing conventions as code, and the 2083
/// samiti/publisher receipt corpus as the permanent CI gate. HYA-417 adds the
/// moonrise solver, the nishita and chandrodaya conventions and the 2026
/// festival receipt corpus (Shivaratri, Fagu Purnima, Janai Purnima, Teej).
///
/// L4 (HYA-420) opens the muhurta layer: the USNO sunset solver (step 1)
/// and the BhaktiBharat muhurta receipts corpus for Nov 2026 (step 2) as
/// the permanent CI gate. Step 3 ships the muhurta recipes themselves
/// (Rahu Kalam, Yamaganda, Gulika, Abhijit, Brahma, Choghadiya, Hora)
/// as muhurta.dart, receipt-calibrated against that corpus.
///
/// L6 (HYA-421) opens the grahan layer: step 1 ships the geocentric lunar
/// eclipse solver (Danjon 1/85 shadow enlargement by default, the
/// Chauvenet 1/50 rule decoded and exposed) with the freshly-parsed NASA
/// 2026 receipts as the permanent CI gate. Step 2 ships the local solar
/// circumstances solver: topocentric separation on the reference
/// ellipsoid, a coarse-grid + golden-section minimum (the parallax wobble
/// makes the topocentric minimum multimodal near the new moon), and
/// visibility gated on the Sun's altitude at the contacts - the penumbra
/// reaches past the terminator, so a graze can be geometrically real yet
/// below the horizon - receipt-anchored to the freshly-parsed Kathmandu
/// corpus (timeanddate, time.now, heliora). The Nepal receipts corpus and
/// the shastra module follow in steps 3-5.
library;

export 'src/ayanamsa.dart';
export 'src/civil_time.dart';
export 'src/delta_t.dart';
export 'src/eclipse_lunar.dart';
export 'src/eclipse_solar.dart';
export 'src/festival_rules.dart';
export 'src/julian_day.dart';
export 'src/limbs.dart';
export 'src/masa.dart';
export 'src/moon.dart';
export 'src/moonrise.dart';
export 'src/muhurta.dart';
export 'src/panchang_day.dart';
export 'src/solver.dart';
export 'src/sun.dart';
export 'src/sunrise.dart';
export 'src/sunset.dart';
export 'src/uncertainty.dart';
