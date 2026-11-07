import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

void main() {
  // The day the caller serves throughout: 2026-11-07, the rung D ship
  // date. The engine never reads a clock, so every probe is
  // deterministic - the test states today.
  final now = jdFromDateTimeUtc(DateTime.utc(2026, 11, 7));

  double envelopeAt(DateTime d) => deltaTHorizonAtJdUt(
          jdFromDateTimeUtc(d), nowJdUt: now)
      .uncertaintySeconds;

  test('measured facts: overlap optimism factor, join disagreement', () {
    // Measured on the vendored tables, never hardcoded: the factor is
    // the max realized |prediction - observed| / stated error over the
    // 15 prediction rows the observations shadow (2022-07 .. 2026-01),
    // worst case 2023-10 (0.062 s realized against 0.027 s stated; max
    // absolute miss 0.095 s at 2024-10 against 0.070 s stated). The
    // independent hyper-calendar vendoring of the same USNO file
    // measured the same class of understatement at up to 2.7x.
    expect(deltaTPredsOverlapInflationFactor, closeTo(2.31, 0.06));
    expect(deltaTPredsOverlapInflationFactor, greaterThan(2.0));
    expect(deltaTPredsOverlapInflationFactor, lessThan(2.7));
    // The declared +8.91 s join step, derived from the tables.
    expect(deltaTEmJoinDisagreementSeconds, closeTo(8.91, 0.05));
    expect(deltaTObservationsFreshnessWindowDays, 497);
  });

  test('envelope never below the R7a segment declaration', () {
    for (final d in [
      DateTime.utc(1600, 6, 15),
      DateTime.utc(1918, 7, 15),
      DateTime.utc(1975, 1, 15),
      DateTime.utc(2026, 2, 1),
      DateTime.utc(2026, 11, 15),
      DateTime.utc(2030, 6, 15),
      DateTime.utc(2043, 6, 15),
      DateTime.utc(2100, 6, 15),
      DateTime.utc(2149, 6, 15),
    ]) {
      final jd = jdFromDateTimeUtc(d);
      final declared = deltaTAtJdUt(jd).uncertaintySeconds;
      expect(deltaTHorizonAtJdUt(jd, nowJdUt: now).uncertaintySeconds,
          greaterThanOrEqualTo(declared - 1e-9),
          reason: d.toIso8601String());
    }
  });

  test('history does not age: observed and spline eras exact', () {
    for (final d in [
      DateTime.utc(1600, 6, 15),
      DateTime.utc(1918, 7, 15),
      DateTime.utc(1975, 1, 15),
      DateTime.utc(2026, 2, 1),
    ]) {
      final jd = jdFromDateTimeUtc(d);
      expect(deltaTHorizonAtJdUt(jd, nowJdUt: now).uncertaintySeconds,
          closeTo(deltaTAtJdUt(jd).uncertaintySeconds, 1e-12));
    }
    // The published SMH2021 error table, step-interpolated as
    // published: 15 s at 1600 (the 1000-era step).
    expect(envelopeAt(DateTime.utc(1600, 6, 15)), closeTo(15, 0.001));
  });

  test('preds era: stated error scaled by the measured optimism factor', () {
    for (final d in [
      DateTime.utc(2026, 11, 15),
      DateTime.utc(2027, 6, 15),
      DateTime.utc(2030, 6, 15),
    ]) {
      final jd = jdFromDateTimeUtc(d);
      final stated = deltaTAtJdUt(jd).uncertaintySeconds;
      final horizon = deltaTHorizonAtJdUt(jd, nowJdUt: now);
      expect(horizon.uncertaintySeconds,
          closeTo(stated * deltaTPredsOverlapInflationFactor, 1e-9));
      expect(horizon.segment, 'usno-preds');
      expect(horizon.basis, contains('optimism'));
    }
    // Receipts: Nov 2026 stated ~0.31 s -> ~0.71 s honest.
    expect(envelopeAt(DateTime.utc(2026, 11, 15)), closeTo(0.71, 0.05));
  });

  test('EM era: join disagreement composed in quadrature with knots', () {
    final level = deltaTEmJoinDisagreementSeconds;
    for (final d in [
      DateTime.utc(2033, 10, 2),
      DateTime.utc(2043, 6, 15),
      DateTime.utc(2050, 1, 15),
      DateTime.utc(2100, 6, 15),
      DateTime.utc(2149, 6, 15),
    ]) {
      final jd = jdFromDateTimeUtc(d);
      final knot = deltaTAtJdUt(jd).uncertaintySeconds;
      final horizon = deltaTHorizonAtJdUt(jd, nowJdUt: now);
      final square = horizon.uncertaintySeconds * horizon.uncertaintySeconds;
      expect(square, closeTo(level * level + knot * knot, 1e-8));
      expect(horizon.segment, 'espenak-meeus');
      expect(horizon.basis, contains('quadrature'));
    }
    // Receipts: R7a's 1 s knot at the join covered the USNO
    // trajectory's own error; the served polynomial sits the measured
    // step above it. ~8.96 s honest at the join, 9.76 s at 2043,
    // 21.8 s by 2149.
    expect(envelopeAt(DateTime.utc(2033, 10, 2)), closeTo(8.96, 0.1));
    expect(envelopeAt(DateTime.utc(2043, 6, 15)), closeTo(9.76, 0.1));
    expect(envelopeAt(DateTime.utc(2149, 6, 15)), closeTo(21.8, 0.3));
  });

  test('error bars grow with the forecast horizon', () {
    final probes = [
      DateTime.utc(2027, 6, 15),
      DateTime.utc(2030, 6, 15),
      DateTime.utc(2033, 6, 15),
      DateTime.utc(2034, 6, 15),
      DateTime.utc(2043, 6, 15),
      DateTime.utc(2050, 6, 15),
      DateTime.utc(2100, 6, 15),
      DateTime.utc(2149, 6, 15),
    ];
    for (var i = 1; i < probes.length; i++) {
      expect(envelopeAt(probes[i]), greaterThan(envelopeAt(probes[i - 1])),
          reason: probes[i].toIso8601String());
    }
    // Today itself: matured, sub-second.
    expect(envelopeAt(DateTime.utc(2026, 11, 7)), lessThan(0.8));
  });

  test('matured vs forecast classification and horizon days', () {
    final matured = deltaTHorizonAtJdUt(
        jdFromDateTimeUtc(DateTime.utc(2026, 11, 1)), nowJdUt: now);
    expect(matured.horizonDays, closeTo(-6, 1e-9));
    expect(matured.basis, contains('matured'));
    final forecast = deltaTHorizonAtJdUt(
        jdFromDateTimeUtc(DateTime.utc(2026, 11, 20)), nowJdUt: now);
    expect(forecast.horizonDays, closeTo(13, 1e-9));
    expect(forecast.basis, contains('forecast'));
    expect(matured.segment, forecast.segment);
    expect(matured.nowJdUt, now);
    expect(matured.jdUt, jdFromDateTimeUtc(DateTime.utc(2026, 11, 1)));
  });

  test('freshness window: the canary guarantee stated per call', () {
    // 2026-11-07 is 220 days past the last observed month (2026-04-01):
    // within the 497-day window.
    expect(
        deltaTHorizonAtJdUt(now, nowJdUt: now).observationsCurrent, isTrue);
    final anchor = jdFromDateTimeUtc(DateTime.utc(2026, 4, 1));
    expect(
        deltaTHorizonAtJdUt(anchor, nowJdUt: anchor + 400)
            .observationsCurrent,
        isTrue);
    expect(
        deltaTHorizonAtJdUt(anchor, nowJdUt: anchor + 600)
            .observationsCurrent,
        isFalse);
  });

  test('determinism: same inputs, same horizon', () {
    final jd = jdFromDateTimeUtc(DateTime.utc(2031, 3, 15));
    final a = deltaTHorizonAtJdUt(jd, nowJdUt: now);
    final b = deltaTHorizonAtJdUt(jd, nowJdUt: now);
    expect(a.uncertaintySeconds, b.uncertaintySeconds);
    expect(a.basis, b.basis);
    expect(a.toString(), b.toString());
  });

  test('outside AD -720..2150 either instant throws', () {
    expect(() => deltaTHorizonAtJdUt(1458084.5, nowJdUt: now),
        throwsArgumentError);
    expect(() => deltaTHorizonAtJdUt(2506345.5, nowJdUt: now),
        throwsArgumentError);
    expect(() => deltaTHorizonAtJdUt(now, nowJdUt: 2506345.5),
        throwsArgumentError);
    expect(() => deltaTHorizonAtJdUt(now, nowJdUt: 1458084.5),
        throwsArgumentError);
  });

  test('sweep: future envelope non-decreasing, past sane', () {
    var prev = 0.0;
    for (var jd = now + 180; jd < 2465200.0; jd += 180) {
      final h = deltaTHorizonAtJdUt(jd, nowJdUt: now);
      expect(h.uncertaintySeconds.isFinite, isTrue);
      expect(h.uncertaintySeconds, greaterThan(0));
      expect(h.uncertaintySeconds, greaterThanOrEqualTo(prev - 1e-9));
      prev = h.uncertaintySeconds;
    }
    final past = jdFromDateTimeUtc(DateTime.utc(1975, 1, 1));
    for (var jd = now - 180; jd > past; jd -= 365) {
      final h = deltaTHorizonAtJdUt(jd, nowJdUt: now);
      expect(h.uncertaintySeconds, greaterThan(0));
      expect(h.uncertaintySeconds, lessThan(200));
    }
  });
}
