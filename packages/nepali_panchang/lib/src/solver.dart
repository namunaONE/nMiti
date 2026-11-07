import 'limbs.dart';

/// Wrap-safe limb boundary solver (R6a-1 step 3, HYA-403; convergence
/// documented and cross-checked by the R10.5 rung C audit, HYA-445).
///
/// All limb angles are strictly increasing in time (the moon outruns the
/// sun by 10.8-15.7 deg/day and the sidereal rates are positive), so the
/// next boundary after a start instant can be found by stepping forward in
/// six-hour increments until the sector index changes, then bisecting the
/// bracket to sub-millisecond precision. The sector-index formulation is
/// wrap-safe: it never compares raw angles across the 0/360 seam.
///
/// ## Convergence (R10.5 rung C, HYA-445)
///
/// The coarse bracket is always exactly 0.25 d wide (the six-hour step),
/// and the served value is the 60-iteration bisection upper bound - the
/// smallest double the bisection can place strictly AFTER the crossing,
/// which the contract requires. Near JD 2460000 one double-precision ULP
/// is about 5.4e-10 d (~47 microseconds), so the bisection is
/// bit-converged after ~35 of its 60 declared iterations; the declared
/// count is belt-and-suspenders, not waste, and the served value sits
/// within ~2 ULP (~100 microseconds) of the true crossing - far below
/// every receipt band (minutes) and every Swiss-truth band (seconds).
///
/// The cross-check: every served boundary is also solved by an
/// INDEPENDENT derivative-accelerated Newton iteration
/// ([nextLimbBoundaryNewtonJdTt]) started from the same coarse bracket
/// - never from the collapsed bisection bracket, so agreement is a
/// genuine two-method result, not a clamp artifact. The Newton solve
/// linearizes the wrap-safe signed distance to the boundary angle
/// (wrap180(angle - span*(target+1))) with a central-difference rate
/// (step 1e-4 d), takes bracket-clamped Newton steps, and converges
/// quadratically to machine precision in ~3-4 iterations (~15 angle
/// evaluations vs the bisection's ~63). The two answers must agree
/// within [_crossCheckToleranceDays] (1e-8 d, ~0.86 ms - about 9x the
/// 2-ULP bisection residue) or the solver throws: two independent
/// methods, one answer, enforced on every boundary the engine serves,
/// which means every CI corpus run re-verifies the convergence claim.

/// Maximum allowed |bisection - Newton| disagreement, in days (~0.86 ms;
/// ~9x the double-precision bisection residue at JD 2.46e6).
const double _crossCheckToleranceDays = 1.0e-8;

/// Central-difference step for the Newton rate, in days (~8.6 s): the
/// limb rates (9.5-17.5 deg/day) vary far slower than this over the
/// 0.25 d bracket, so the finite difference is an accurate derivative
/// while smoothing single-evaluation rounding noise.
const double _newtonRateStepDays = 1.0e-4;

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
  // Rung C: the Newton cross-check solves the SAME crossing from the
  // coarse bracket, independently of the bisection below.
  final newton = _newtonSolve(limb, sourceDelta, target, lo, hi);
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (limbIndex(limb, mid, sourceDelta) == target) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  if ((newton - hi).abs() > _crossCheckToleranceDays) {
    throw StateError(
        '$limb boundary solver cross-check failed: bisection $hi vs '
        'Newton $newton (start jdTt $jdTtStart)');
  }
  return hi;
}

/// The same crossing as [nextLimbBoundaryJdTt] solved by the
/// derivative-accelerated Newton iteration - the R10.5 rung C
/// cross-check path (HYA-445), exported for tests and for a future
/// fast path (~4x fewer angle evaluations).
///
/// Returns the crossing itself, which may sit infinitesimally BELOW the
/// strictly-after bound the served solver returns - callers that need
/// the bound semantics must use [nextLimbBoundaryJdTt].
double nextLimbBoundaryNewtonJdTt(
    String limb, double jdTtStart, double sourceDelta) {
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
  return _newtonSolve(limb, sourceDelta, target, lo, hi);
}

/// Safeguarded Newton solve of the sector crossing inside the coarse
/// bracket [lo, hi]: the wrap-safe signed distance to the boundary angle
/// is linearized with a central-difference rate and iterated with steps
/// clamped to the bracket. Converges quadratically in ~3-4 iterations
/// for the near-affine limb rates.
double _newtonSolve(
    String limb, double sourceDelta, int target, double lo, double hi) {
  final boundaryDeg = limbSpanDeg(limb) * (target + 1);
  double distanceDeg(double t) =>
      _wrap180(limbAngle(limb, t, sourceDelta) - boundaryDeg);
  var t = (lo + hi) / 2;
  for (var i = 0; i < 12; i++) {
    final rate = (distanceDeg(t + _newtonRateStepDays) -
            distanceDeg(t - _newtonRateStepDays)) /
        (2.0 * _newtonRateStepDays);
    if (rate <= 0.0) {
      throw StateError('$limb Newton solve rate not positive at jdTt $t');
    }
    var next = t - distanceDeg(t) / rate;
    if (next < lo) next = lo;
    if (next > hi) next = hi;
    if ((next - t).abs() <= 1.0e-12) {
      return next;
    }
    t = next;
  }
  return t;
}

/// Wrap a signed angle difference into [-180, 180) so the distance to
/// the boundary is continuous across the 0/360 seam.
double _wrap180(double deg) {
  var d = deg % 360.0;
  if (d >= 180.0) d -= 360.0;
  if (d < -180.0) d += 360.0;
  return d;
}
