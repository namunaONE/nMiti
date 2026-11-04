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
