/// Ayanamsa profiles for sidereal limbs (R6a-1 step 3, HYA-403).
///
/// The base ayanamsa is the solar fit validated against the live-crawled
/// publisher corpus: 23.87508 deg at J2000 drifting +1.36062 deg per Julian
/// century. Per-source deltas are fitted offsets that reconcile each
/// publisher's sidereal convention - profiles, never one universal ayanamsa
/// (the corpus proved a single universal value cannot explain both sources).

/// Fitted delta for BhaktiBharat, degrees (corpus fit, Oct-Nov 2026).
const double ayanamsaDeltaBhaktiBharat = -0.0795;

/// Fitted delta for Hamro Patro, degrees (corpus fit, Nov 2026).
const double ayanamsaDeltaHamroPatro = -0.0117;

/// Base ayanamsa at [jdTt] (Terrestrial Time Julian Day), degrees.
double ayanamsaBase(double jdTt) {
  return 23.87508 + 1.36062 * (jdTt - 2451545.0) / 36525.0;
}

/// Ayanamsa at [jdTt] for a source profile: base plus the source delta.
double ayanamsaTotal(double jdTt, double sourceDelta) {
  return ayanamsaBase(jdTt) + sourceDelta;
}

/// Receipts-measured reference ayanamsa of the Swiss Ephemeris Lahiri
/// (SIDM_LAHIRI) frame (HYA-369, reconciled 2026-11-10): 23.85709 deg
/// at J2000 drifting +1.398024 deg per Julian century (50.329"/yr).
/// Measured, never adopted from a table: the offset of the engine base
/// from this line was pinned through two independent limb routes
/// (+28.37" nakshatra, +28.84" yoga at the Oct 17 - Dec 1 2026 window
/// mid, JD_TT 2461352.5008), and the implied drift converges on the
/// general precession rate (50.29"/yr).
///
/// Convention/display surface only. It is a receipts-measured linear
/// approximation of the Swiss SIDM_LAHIRI frame, carried so the
/// Swiss-truth harness can align the nakshatra/yoga scores and the
/// honesty pages can state the frame difference. It is NOT the IAE
/// table: the printed-patro anchor of the true Chitra-pakshiya value
/// is an open receipt (print verification pending). No served value
/// changes on its account - the limbs keep the base + per-source
/// profiles above.
const double ayanamsaSwissLahiriReferenceJ2000 = 23.85709;
const double ayanamsaSwissLahiriReferenceRatePerCy = 1.398024;

/// Swiss-Lahiri reference ayanamsa at [jdTt] (TT), degrees.
double ayanamsaSwissLahiriReference(double jdTt) {
  return ayanamsaSwissLahiriReferenceJ2000 +
      ayanamsaSwissLahiriReferenceRatePerCy * (jdTt - 2451545.0) / 36525.0;
}
