import 'dart:math' show sqrt;

import 'delta_t_data.dart';

/// Delta T = TT - UT1 in seconds: the hybrid four-segment channel
/// (R7a, HYA-438).
///
/// The channel replaces the Espenak-Meeus polynomials everywhere except
/// the long range past the USNO's own prediction horizon. Segments (all
/// joins derived from the vendored tables in delta_t_data.dart,
/// declared rather than blended):
///
/// 1. Before the first observed month (1973-02-01): the cubic spline of
///    Stephenson, Morrison & Hohenkerk (2016) and Morrison, Stephenson,
///    Hohenkerk & Zawilski (2021) - Table S15 of the Royal Society
///    supplement, CC BY 4.0. Only the published pre-1974 segments are
///    vendored; third-party post-2013 refits are not carried.
/// 2. Through the last observed month (2026-04-01): USNO deltat.data,
///    the monthly observed TT-UT1, linear between samples.
/// 3. Through the last USNO prediction (2033-10-01): USNO deltat.preds,
///    quarterly rows linear in JD, bridged from the last observed
///    sample; prediction rows inside the observed era are shadowed by
///    the observations. The uncertainty is the file's own error column,
///    interpolated.
/// 4. Beyond: the Espenak-Meeus 2005-2050 and 2050-2150 branches,
///    re-scoped. The +8.91 s step at 2033-10-01 is declared, not
///    blended: the USNO stops predicting there, and the polynomial is a
///    2006 forecast that already runs ~6.5 s high in 2026.
///
/// Valid range: AD -720 through 2150; outside, [ArgumentError]. The
/// uncertainty is the honest per-segment envelope, never zero.
///
/// R10.5 rung D (HYA-445) adds the horizon surface at the bottom of
/// this file: one function composing these declarations into the
/// Delta-T error bar for any served date, growing with |date - today|.

/// One Delta T evaluation: the value, its source segment and that
/// segment's honest uncertainty.
class DeltaTValue {
  /// TT - UT1 in seconds.
  final double seconds;

  /// 'smh2021-spline', 'usno-observed', 'usno-preds' or 'espenak-meeus'.
  final String source;

  /// Uncertainty of the segment at this instant, in seconds.
  final double uncertaintySeconds;

  /// The source segment's span.
  final String sourceSpan;

  const Delt
aTValue({
    required this.seconds,
    required this.source,
    required this.uncertaintySeconds,
    required this.sourceSpan,
  });

  @override
  String toString() =>
      'DeltaTValue(${seconds.toStringAsFixed(4)} s from $source, '
      'uncertainty ${uncertaintySeconds.toStringAsFixed(3)} s)';
}

/// JD (UT) of 0h on [year]-[month]-[day], proleptic Gregorian.
double _jdFromCivilYmd(int year, int month, int day) {
  var y = year;
  var m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      day +
      b -
      1524.5;
}

/// Decimal year fraction of a JD (UT), used by the spline and the
/// long-range segments.
double _yearFraction(double jd) {
  var y = (2000 + (jd - 2451545.0) / 365.2425).floor();
  var jan = _jdFromCivilYmd(y, 1, 1);
  while (jan > jd) {
    y -= 1;
    jan = _jdFromCivilYmd(y, 1, 1);
  }
  var next = _jdFromCivilYmd(y + 1, 1, 1);
  while (next <= jd) {
    y += 1;
    jan = next;
    next = _jdFromCivilYmd(y + 1, 1, 1);
  }
  return y + (jd - jan) / (next - jan);
}

/// Linear interpolation over paired tables, clamped at both ends.
double _interp(List<double> xs, List<double> ys, double x) {
  var lo = 0, hi = xs.length - 1;
  if (x <= xs[0]) return ys[0];
  if (x >= xs[hi]) return ys[hi];
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (xs[mid] <= x) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final f = (x - xs[lo]) / (xs[hi] - xs[lo]);
  return ys[lo] + f * (ys[hi] - ys[lo]);
}

// Era boundaries, derived from the vendored tables - never hardcoded.
final double _firstObservedJd = usnoObservedJd.first;
final double _lastObservedJd = usnoObservedJd.last;
final double _lastObservedSeconds = usnoObservedSeconds.last;
final double _lastPredJd = usnoPredsJd.last;
final double _minJd = _jdFromCivilYmd(-720, 1, 1);

/// Index of the first prediction row after the
 observed era (the
/// bridge target), derived from the tables.
final int _bridgePredIndex = () {
  for (var i = 0; i < usnoPredsJd.length; i++) {
    if (usnoPredsJd[i] > _lastObservedJd) return i;
  }
  return usnoPredsJd.length;
}();

/// SMH2016/Morrison2021 spline at decimal year [y].
double _splineSeconds(double y) {
  var i = smhSplineY0.length - 1;
  while (i > 0 && y < smhSplineY0[i]) {
    i--;
  }
  final t = (y - smhSplineY0[i]) / (smhSplineY1[i] - smhSplineY0[i]);
  return smhSplineA0[i] +
      t * (smhSplineA1[i] + t * (smhSplineA2[i] + t * smhSplineA3[i]));
}

/// The published SMH2021 error table, step-interpolated as published.
double _splineUncertainty(double y) {
  if (y < smhErrorYear.first) return smhErrorSeconds.first;
  var i = smhErrorYear.length - 1;
  while (i > 0 && y < smhErrorYear[i]) {
    i--;
  }
  return smhErrorSeconds[i];
}

/// Espenak-Meeus long-range value at decimal year [y] (the 2005-2050
/// and 2050-2150 branches only; the pre-2005 branches were retired with
/// the spline taking over).
double _espMeeusSeconds(double y) {
  final u = y - 2000;
  if (u < 50) return 62.92 + 0.32217 * u + 0.005589 * u * u;
  final v = (y - 1820) / 100;
  return -20 + 32 * v * v - 0.5628 * (2150 - y);
}

// Declared uncertainty of the re-scoped Espenak-Meeus segment: a linear
// envelope over its own drift from the USNO trajectory (1 s at the
// join, 6 s at 2050, 12 s at 2100, 20 s at 2150).
const List<double> _emErrorYear = [2033.75, 2050, 2100, 2150];
const List<double> _emErrorSeconds = [1, 6, 12, 20];

/// Delta T at a UT Julian Day, with source and uncertainty.
///
/// Throws [ArgumentError] outside AD -720..2150.
DeltaTValue deltaTAtJdUt(double jdUt) {
  if (jdUt < _minJd) {
    throw ArgumentError('deltaTAtJdUt: JD before AD -720');
  }
  if (jdUt < _firstObservedJd) {
    final y = _yearFraction(jdUt);
    return DeltaTValue(
      seconds: _splineSeconds(y),
      source: 'smh2021-spline',
      uncertaintySeconds: _splineUncertainty(
y),
      sourceSpan: 'SMH2016/Morrison2021 spline, -720..1973-02',
    );
  }
  if (jdUt <= _lastObservedJd) {
    return DeltaTValue(
      seconds: _interp(usnoObservedJd, usnoObservedSeconds, jdUt),
      source: 'usno-observed',
      uncertaintySeconds: 0.05,
      sourceSpan: 'USNO deltat.data observed monthly, 1973-02..2026-04',
    );
  }
  if (jdUt <= _lastPredJd) {
    if (_bridgePredIndex > 0 && jdUt <= usnoPredsJd[_bridgePredIndex]) {
      final t = (jdUt - _lastObservedJd) /
          (usnoPredsJd[_bridgePredIndex] - _lastObservedJd);
      final seconds = _lastObservedSeconds +
          t * (usnoPredsSeconds[_bridgePredIndex] - _lastObservedSeconds);
      final uncertainty =
          0.05 + t * (usnoPredsErrorSeconds[_bridgePredIndex] - 0.05);
      return DeltaTValue(
        seconds: seconds,
        source: 'usno-preds',
        uncertaintySeconds: uncertainty,
        sourceSpan: 'USNO deltat.preds quarterly, 2026-04..2033-10',
      );
    }
    return DeltaTValue(
      seconds: _interp(usnoPredsJd, usnoPredsSeconds, jdUt),
      source: 'usno-preds',
      uncertaintySeconds: _interp(usnoPredsJd, usnoPredsErrorSeconds, jdUt),
      sourceSpan: 'USNO deltat.preds quarterly, 2026-04..2033-10',
    );
  }
  final y = _yearFraction(jdUt);
  if (y >= 2150) {
    throw ArgumentError('deltaTAtJdUt: year >= 2150');
  }
  return DeltaTValue(
    seconds: _espMeeusSeconds(y),
    source: 'espenak-meeus',
    uncertaintySeconds: _interp(_emErrorYear, _emErrorSeconds, y),
    sourceSpan: 'Espenak-Meeus long-range, 2033-10..2150',
  );
}

/// Delta T at a TT Julian Day: two fixed-point iterations resolve the
/// UT instant the tables are indexed by.
DeltaTValue deltaTAtJdTt(double jdTt) {
  var value = deltaTAtJdUt(jdTt);
  for (var i = 0; i < 2; i++) {
    value = deltaTAtJdUt(jdTt - value.seconds / 86400.0);
  }
  return value;
}

/// Legacy month-granular wrapper: Delta T at 0h UT on the 15th of the
/// month (mid-month, the convention the Espenak-Me
eus API used). The
/// engine's time funnel goes through [deltaTAtJdUt] at full precision;
/// this stays for compatibility with existing callers.
double deltaTSeconds(int year, int month) {
  final y = year + (month - 0.5) / 12.0;
  if (y < -720 || y >= 2150) {
    throw ArgumentError('deltaTSeconds: year $year outside AD -720..2150');
  }
  return deltaTAtJdUt(_jdFromCivilYmd(year, month, 15)).seconds;
}

// ---------------------------------------------------------------------------
// R10.5 rung D (HYA-445): the Delta-T horizon term.
//
// One function - deltaTHorizonAtJdUt below - composes the honest
// Delta-T uncertainty for any queried instant, relative to the day the
// caller serves, so every served error bar can carry a Delta-T
// component that grows with how far the queried date sits from today.
// The channel above is untouched: same segments, same served values,
// same R7a per-segment declarations. The horizon layer adds what the
// vendored tables measure about their own prediction error - never an
// invented growth law:
//
// 1. The USNO error column is an estimate, not a bound. Over the
//    vendored overlap (the prediction rows the observations shadow,
//    2022-07 .. 2026-01) the realized |prediction - observed| exceeded
//    the stated error by up to a measured factor
//    (deltaTPredsOverlapInflationFactor, ~2.3 on the current tables);
//    an independent vendoring of the same USNO file measured the same
//    class of understatement at up to 2.7x (hyper-calendar PR #140).
//    The preds-era envelope is the stated error scaled by that factor.
// 2. The Espenak-Meeus join step (+8.91 s at 2033-10-01, declared by
//    R7a) is the measured disagreement between the polynomial the
//    channel serves and the USNO trajectory it replaces. The R7a knot
//    envelope declared 1 s at the join - the USNO trajectory's own
//    horizon error - but the served value there is the polynomial,
//    which sits the full step above that trajectory, and a level bias
//    does not decay with calendar year. The EM-era envelope composes
//    the measured disagreement (deltaTEmJoinDisagreementSeconds) in
//    quadrature with the unchanged growth knots (1/6/12/20 s at
//    2033.75/2050/2100/2150). The knots stand corroborated two ways:
//    the vendored SMH2021 published error table extends into the
//    future (2 s at 2030, 6 s at 2050, 10 s at 2100) and Espenak's own
//    sigma estimate is 0.8 t^2 with t = (year - 1820)/100 - both at or
//    below the declared knots at every point.
// 3. History never ages. For queried dates inside the observations
//    the envelope stays the R7a declaration (0.05 s; the published
//    SMH2021 error table before 1973-02), whatever today is. The
//    envelopes are anchored at the tables' own epochs; while the
//    freshness guarantee holds (the canary asserts the observed table
//    stays within ~16 months of today), the anchor sits within months
//    of today and the envelope reads as growth with |date - today|.
//    The function takes today explicitly - the engine never reads a
//    clock - and exposes the freshness verdict per call.
//
// Wall-clock mapping (rung B frame audit): on the TT-anchored channels
// (tithi/karana/nakshatra/yoga, masa, eclipse contacts) one second of
// Delta-T error is one second of served boundary time. The UT-direct
// channels (sunrise, sunset, moonrise) are Delta-T-free by
// construction and carry zero Delta-T wall-clock uncertainty.

/// The measured USNO optimism factor over the vendored overlap: the
/// maximum of |prediction - observed| / stated error across the
/// prediction rows the observations shadow, floored at 1. Computed from
/// the vendored tables at first use - never hardcoded - so the refresh
/// workflow re-measures it whenever it lands new tables.
final double deltaTPredsOverlapInflationFactor = () {
  var worst = 1.0;
  for (var i = 0; i < usnoPredsJd.length; i++) {
    if (usnoPredsJd[i] > _lastObservedJd) break;
    final observed =
        _interp(usnoObservedJd, usnoObservedSeconds, usnoPredsJd[i]);
    final stated = usnoPredsErrorSeconds[i];
    if (stated <= 0) continue;
    final ratio = (usnoPredsSeconds[i] - observed).abs() / stated;
    if (ratio > worst) worst = ratio;
  }
  return worst;
}();

/// The measured channel disagreement at the Espenak-Meeus join: the
/// long-range polynomial's value at the last USNO prediction minus the
/// prediction itself - the declared +8.91 s step, derived from the
/// tables. A level systematic of the served value beyond the join; the
/// horizon function composes it in quadrature with the R7a growth
/// knots.
final double deltaTEmJoinDisagreementSeconds =
    _espMeeusSeconds(_yearFraction(_lastPredJd)) - usnoPredsSeconds.last;

/// The freshness guarantee the site canary asserts for the vendored
/// observed table: the last observed month must be within ~16 months
/// of today. Declared at sixteen maximum-length (31-day) months.
const int deltaTObservationsFreshnessWindowDays = 497;

/// One Delta-T horizon evaluation: the honest uncertainty of the
/// served Delta-T at a queried instant, relative to the day the
/// caller serves.
class DeltaTHorizon {
  /// The queried instant, UT Julian Day.
  final double jdUt;

  /// The instant the caller serves as today, UT Julian Day.
  final double nowJdUt;

  /// jdUt - nowJdUt, signed: positive is the forecast horizon,
  /// negative the matured past.
  final double horizonDays;

  /// The serving channel segment id, as [DeltaTValue.source].
  final String segment;

  /// The honest Delta-T envelope at the queried instant, in seconds:
  /// the R7a segment declaration composed with the measured horizon
  /// terms - never below the declaration.
  final double uncertaintySeconds;

  /// Machine-stable composition statement, for receipts and the
  /// honesty pages.
  final String basis;

  /// Whether the vendored observations satisfy the freshness window
  /// against [nowJdUt] (the canary's ~16-month guarantee).
  final bool observationsCurrent;

  const DeltaTHorizon({
    required this.jdUt,
    required this.nowJdUt,
    required this.horizonDays,
    required this.segment,
    required this.uncertaintySeconds,
    required this.basis,
    required this.observationsCurrent,
  });

  @override
  String toString() =>
      'DeltaTHorizon(' +
      uncertaintySeconds.toStringAsFixed(3) +
      ' s at horizon ' +
      horizonDays.toStringAsFixed(1) +
      ' d, ' +
      segment +
      ')';
}

/// The one Delta-T error-bar surface (R10.5 rung D, HYA-445): the honest
/// uncertainty of the Delta-T behind a served value at [jdUt], given
/// that the caller serves [nowJdUt] as today. The engine never reads a
/// clock - the caller states today, so tests and receipts are
/// reproducible and the site build passes its own build date.
///
/// Throws [ArgumentError] outside AD -720..2150 for either instant.
DeltaTHorizon deltaTHorizonAtJdUt(double jdUt, {required double nowJdUt}) {
  if (nowJdUt < _minJd || _yearFraction(nowJdUt) >= 2150) {
    throw ArgumentError('deltaTHorizonAtJdUt: now outside AD -720..2150');
  }
  final value = deltaTAtJdUt(jdUt);
  final horizonDays = jdUt - nowJdUt;
  final side = horizonDays <= 0 ? 'matured' : 'forecast';
  var envelope = value.uncertaintySeconds;
  String basis;
  if (value.source == 'usno-preds') {
    envelope *= deltaTPredsOverlapInflationFactor;
    basis = 'USNO stated error x overlap-measured optimism factor; ' + side;
  } else if (value.source == 'espenak-meeus') {
    final level = deltaTEmJoinDisagreementSeconds;
    final knot = value.uncertaintySeconds;
    envelope = sqrt(level * level + knot * knot);
    basis =
        'growth knots + measured join disagreement in quadrature; ' + side;
  } else if (value.source == 'usno-observed') {
    basis = 'USNO observed monthly, 0.05 s; history does not age; ' + side;
  } else {
    basis = 'published SMH2021 error table; history does not age; ' + side;
  }
  return DeltaTHorizon(
    jdUt: jdUt,
    nowJdUt: nowJdUt,
    horizonDays: horizonDays,
    segment: value.source,
    uncertaintySeconds: envelope,
    basis: basis,
    observationsCurrent: (nowJdUt - _lastObservedJd) <=
        deltaTObservationsFreshnessWindowDays,
  );
}
