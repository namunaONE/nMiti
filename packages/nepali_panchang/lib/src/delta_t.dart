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

  const DeltaTValue({
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

/// Index of the first prediction row after the observed era (the
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
      uncertaintySeconds: _splineUncertainty(y),
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
/// month (mid-month, the convention the Espenak-Meeus API used). The
/// engine's time funnel goes through [deltaTAtJdUt] at full precision;
/// this stays for compatibility with existing callers.
double deltaTSeconds(int year, int month) {
  final y = year + (month - 0.5) / 12.0;
  if (y < -720 || y >= 2150) {
    throw ArgumentError('deltaTSeconds: year $year outside AD -720..2150');
  }
  return deltaTAtJdUt(_jdFromCivilYmd(year, month, 15)).seconds;
}
