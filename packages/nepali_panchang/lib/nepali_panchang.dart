/// Nepal-first lunar panchang engine for the nMiti Commons (R6a-1, HYA-403).
///
/// The engine computes tithi, nakshatra, yoga, karana and sunrise moments at
/// runtime from celestial mechanics - full 60-term Meeus Ch.47 moon series,
/// Ch.25 solar theory, a Delta-T table and per-source ayanamsa profiles -
/// with no precomputed data files, covering the entire BS 1975-2100+ range.
///
/// Step 2 shipped the astronomy core: the Meeus Ch.47 moon (example 47.a is
/// its permanent unit test), the Ch.25 sun (example 25.a) and the Delta-T
/// channel. R7a (HYA-438) replaces the Espenak-Meeus polynomials with the
/// hybrid channel: the Stephenson-Morrison (2016/2021) spline before
/// 1973-02, USNO observed monthly values through 2026-04, USNO quarterly
/// predictions through 2033-10 and the Espenak-Meeus long-range branch
/// beyond - joins derived from the vendored tables, declared not blended.
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
/// corpus (timeanddate, time.now, heliora). Step 3 ships the NASA solar
/// catalog receipts (2026-2030) as the permanent CI gate. Step 4 ships
/// the grahan shastra module: sutak windows anchored to the local visible
/// contacts (12 hours before a solar, 9 hours before a lunar eclipse,
/// ending at moksha), visibility-gated (no visible contact, no sutak),
/// penumbral eclipses not kept as grahan, Khagras/Khandagras/Grastodit
/// naming, and the C1-C6 publisher convention collisions decoded and
/// exposed rather than silently resolved. Step 5 (site/API display)
/// follows.
///
/// R10.1 (HYA-441) opens the ritual display layers on the shipped engines:
/// layer 1 is the Bhadra module - the eight Vishti karana half-tithi windows
/// per lunar month with the loka (moon-rashi) table and its named contiguous
/// variant, both mukha/puchha rule families (ghati primary, fraction
/// exposed), and the begins-date convention, all derived from the karana
/// limb and gated by the 2026 Bhadra receipt corpus (Swarnsiddhi windows,
/// BhaktiBharat rule text and date lists, corpus-pinned window edges).
///
/// R10.1 layer 2 is the Panchak module: the Moon's sidereal 300-360 deg
/// transit (Dhanishta's last two padas through the end of Revati), about
/// 4.5 days per window, 13 windows a year, with the weekday-of-begin types
/// (Rog/Rajya/Agni/Madhyam/Chor/Mrityu; the Wed/Thu naming collision
/// decoded), the five nakshatra segments per window, and the Dec
/// midnight knife-edge exposed - gated by the 2026 Panchak receipt corpus
/// (Swarnsiddhi and PanchangBodh tables, the BhaktiBharat window and date
/// lists, golden-corpus Revati-end edge pins on the Oct/Nov/Dec windows).
///
/// R10.1 layer 3 is the Chandra Darshan module: the first sighting of the
/// young crescent Moon after each new moon, saait = [sunset, moonset] of
/// the darshan evening, day rule = the first civil evening at or after the
/// local conjunction whose moonset-minus-sunset lag reaches 39.0 min
/// (corpus band 37.80-40.33, the classical ~8 deg darshan-amsha carried as
/// an honesty field), the conjunction-day darshan decoded (May 17 2026),
/// 'Dwitiya at sunset' refuted, the drikpanchang Delhi divergences recorded
/// and never absorbed - gated by the 2026-11-08 Chandra Darshan receipt
/// corpus (nepaljyotish Kathmandu windows, BhaktiBharat day-calls, the
/// drikpanchang 2026-2027 tables) and backed by the new moonset solver,
/// the setting twin of moonrise.
///
/// R10.2 (HYA-441) opens the lagna layer: the rising-sign (ascendant)
/// engine - the sidereal ascendant from GMST (Meeus 12.4, UT domain) plus
/// the mean obliquity (Meeus 22.2) through the closed-form tropical
/// ascendant, minus the engine BASE ayanamsa (the corpus fits the base
/// alone, no per-source delta), a wrap-safe rashi-boundary solver (a
/// 2-min membership scan, a 60-iteration bisection and a
/// derivative-accelerated Newton cross-check - two methods, one answer,
/// on every boundary), the day-table frame SOLVED by walking back from the
/// publisher's printed sunrise (never a fixed-hour scan), the
/// running-lagna query, the nepaljyotish sunrise-anchored vs Swarnsiddhi
/// true-instant frame conventions decoded, and a polar-latitude refusal
/// (|latitude| >= 66.5 deg) - gated by the 2026-11-09 lagna receipt
/// corpus (Swarnsiddhi six-city boundary tables with frame closes and
/// live rising-now degrees, the nepaljyotish Kathmandu table, the
/// PanchangBodh dated day-calls): 78/78 boundary receipts within 0.05
/// min, 6/6 rising-now degrees within 0.19 deg, 12/12 nepaljyotish
/// interior boundaries within 2.28 min (minute-rounded print), 9/9
/// PanchangBodh sunrise-sign day-calls exact. Zero divergences.
library;

export 'src/ayanamsa.dart';
export 'src/bhadra.dart';
export 'src/chandra_darshan.dart';
export 'src/civil_time.dart';
export 'src/delta_t.dart';
export 'src/eclipse_lunar.dart';
export 'src/eclipse_solar.dart';
export 'src/festival_rules.dart';
export 'src/grahan.dart';
export 'src/julian_day.dart';
export 'src/lagna.dart';
export 'src/limbs.dart';
export 'src/masa.dart';
export 'src/moon.dart';
export 'src/moonrise.dart';
export 'src/moonset.dart';
export 'src/muhurta.dart';
export 'src/panchak.dart';
export 'src/panchang_day.dart';
export 'src/solver.dart';
export 'src/sun.dart';
export 'src/sunrise.dart';
export 'src/sunset.dart';
export 'src/uncertainty.dart';
