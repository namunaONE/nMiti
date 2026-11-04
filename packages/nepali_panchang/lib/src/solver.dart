import 'limbs.dart';

/// Wrap-safe limb boundary solver (R6a-1 step 3, HYA-403).
///
/// All limb angles are strictly increasing in time (the moon outruns the
/// sun by 10.8-15.7 deg/day and the sidereal rates are positive), so the
/// next boundary after a start instant can be found by stepping forward in
/// six-hour increments until the sector index changes, then bisecting the
/// bracket to sub-millisecond precision. The sector-index formulation is
/// wrap-safe: it never compares raw angles across the 0/360 seam.

/// TT Julian Day of the next sector boundary of [limb] strictly after
/// [jdTtStart], using the ayanamsa profile [sourceDelta] for sidereal limbs.
double nextLimbBoundaryJdTt(String limb, double jdTtStart, double sourceDelta) {
  final target = limbIndex(limb, jdTtStart, sourceDelta);
  var lo = jdTtStart;
  var hi = jdTtStart + 0.25;
  while (limbIndex(limb, hi, sourceDelta) == target) {
    lo = hi;
    hi += 0.25;
    if (hi - jdTtStart > 4.0) {
      throw StateError(
          'boundary solver failed to bracket the next $limb crossing');
    }
  }
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (limbIndex(limb, mid, sourceDelta) == target) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}
