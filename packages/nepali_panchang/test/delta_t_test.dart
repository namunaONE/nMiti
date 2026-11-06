import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

void main() {
  // Vendored USNO anchors (deltat.data parsed corruption-tolerantly and
  // cross-checked against three Wayback snapshots, the independently
  // vendored hyper-calendar copy and the IERS-derived astronomia
  // series). The pre-R7a Espenak-Meeus values are in the comments for
  // contrast.
  test('observed anchors: 1975, 1990, 2000, 2010, 2024', () {
    expect(deltaTSeconds(1975, 1), closeTo(45.5154, 0.01)); // EM: 45.49
    expect(deltaTSeconds(1990, 1), closeTo(56.8805, 0.01)); // EM: 56.92
    expect(deltaTSeconds(2000, 1), closeTo(63.8408, 0.01)); // EM: 63.87
    expect(deltaTSeconds(2010, 1), closeTo(66.0817, 0.01)); // EM: 66.72
    expect(deltaTSeconds(2024, 1), closeTo(69.1772, 0.01)); // EM: 69.26
  });

  test('corpus era November 2026 serves the USNO prediction', () {
    // The pre-R7a Espenak-Meeus polynomial read 75.62 s here; the ~6.5 s
    // systematic this channel removes (HYA-438 supersedes the HYA-406
    // KEEP adjudication).
    final v = deltaTSeconds(2026, 11);
    expect(v, closeTo(69.1145, 0.01));
    expect(v, lessThan(70));
  });

  test('long range: 2030 prediction, 2043/2050 Espenak-Meeus', () {
    expect(deltaTSeconds(2030, 6), closeTo(70.1532, 0.01));
    expect(deltaTSeconds(2043, 6), closeTo(87.4714, 0.01));
    expect(deltaTSeconds(2050, 1), closeTo(93.0781, 0.01));
  });

  test('spline era: BS 1975 (AD 1918-1919) reads the SMH2021 curve', () {
    expect(deltaTSeconds(1918, 7), closeTo(20.6, 0.3));
  });

  test('exact observed months survive the corruption-proof parse', () {
    // The four months the Wayback extraction mangled, plus the era's
    // first and last observations - each cross-verified independently.
    double at(DateTime d) => deltaTAtJdUt(jdFromDateTimeUtc(d)).seconds;
    expect(at(DateTime.utc(1973, 2, 1)), closeTo(43.4724, 0.000001));
    expect(at(DateTime.utc(1981, 1, 1)), closeTo(51.3808, 0.000001));
    expect(at(DateTime.utc(1988, 12, 1)), closeTo(56.2583, 0.000001));
    expect(at(DateTime.utc(1989, 1, 1)), closeTo(56.3000, 0.000001));
    expect(at(DateTime.utc(2012, 10, 1)), closeTo(66.8103, 0.000001));
    expect(at(DateTime.utc(2020, 9, 1)), closeTo(69.3693, 0.000001));
    expect(at(DateTime.utc(2024, 1, 1)), closeTo(69.1752, 0.000001));
    expect(at(DateTime.utc(2026, 1, 1)), closeTo(69.1099, 0.000001));
    expect(at(DateTime.utc(2026, 4, 1)), closeTo(69.1330, 0.000001));
  });

  test('sources per segment', () {
    String src(DateTime d) => deltaTAtJdUt(jdFromDateTimeUtc(d)).source;
    expect(src(DateTime.utc(1918, 7, 1)), 'smh2021-spline');
    expect(src(DateTime.utc(1973, 1, 1)), 'smh2021-spline');
    expect(src(DateTime.utc(1973, 2, 1)), 'usno-observed');
    // Prediction rows before 2026-04 are shadowed by observations.
    expect(src(DateTime.utc(2026, 2, 1)), 'usno-observed');
    expect(src(DateTime.utc(2026, 6, 15)), 'usno-preds');
    expect(src(DateTime.utc(2030, 6, 15)), 'usno-preds');
    expect(src(DateTime.utc(2043, 6, 15)), 'espenak-meeus');
  });

  test('uncertainty per segment', () {
    double err(DateTime d) =>
        deltaTAtJdUt(jdFromDateTimeUtc(d)).uncertaintySeconds;
    expect(err(DateTime.utc(1600, 6, 15)), closeTo(15, 0.001));
    expect(err(DateTime.utc(1900, 6, 15)), closeTo(0.05, 0.001));
    expect(err(DateTime.utc(2026, 2, 1)), closeTo(0.05, 0.001));
    expect(err(DateTime.utc(2026, 11, 15)), closeTo(0.309, 0.01));
    expect(err(DateTime.utc(2030, 6, 15)), closeTo(0.818, 0.01));
    expect(err(DateTime.utc(2043, 6, 15)), closeTo(3.985, 0.05));
    expect(err(DateTime.utc(2050, 1, 15)), closeTo(6.005, 0.05));
  });

  test('declared join: spline -> observed steps ~0.23 s at 1973-02-01', () {
    final jd = jdFromDateTimeUtc(DateTime.utc(1973, 2, 1));
    final before = deltaTAtJdUt(jd - 1 / 86400).seconds;
    final after = deltaTAtJdUt(jd).seconds;
    expect(after - before, closeTo(0.228, 0.05));
    expect(after - before, lessThan(0.5));
  });

  test('bridge: predictions continue the observed table at 2026-04-01', () {
    final jd = jdFromDateTimeUtc(DateTime.utc(2026, 4, 1));
    expect(deltaTAtJdUt(jd).source, 'usno-observed');
    final bridged = deltaTAtJdUt(jd + 1 / 24);
    expect(bridged.source, 'usno-preds');
    expect(bridged.seconds, closeTo(69.1330, 0.005));
  });

  test('declared join: preds -> Espenak-Meeus steps ~8.9 s at 2033-10-01', () {
    final jd = jdFromDateTimeUtc(DateTime.utc(2033, 10, 1));
    final lastPred = deltaTAtJdUt(jd).seconds;
    final em = deltaTAtJdUt(jd + 1).seconds;
    expect(lastPred, closeTo(71.25, 0.000001));
    expect(em - lastPred, closeTo(8.91, 0.05));
    expect(deltaTAtJdUt(jd).source, 'usno-preds');
    expect(deltaTAtJdUt(jd + 1).source, 'espenak-meeus');
  });

  test('no gaps: sweep AD 1918..2149 every 5 days', () {
    final start = jdFromDateTimeUtc(DateTime.utc(1918, 1, 1));
    final end = jdFromDateTimeUtc(DateTime.utc(2149, 12, 31));
    var count = 0;
    for (var jd = start; jd <= end; jd += 5) {
      final v = deltaTAtJdUt(jd).seconds;
      expect(v.isFinite, isTrue);
      expect(v, greaterThan(15));
      expect(v, lessThan(350));
      count++;
    }
    expect(count, greaterThan(8000));
  });

  test('legacy wrapper equals the instant channel at mid-month', () {
    for (final d in [
      DateTime.utc(1975, 1, 15),
      DateTime.utc(2026, 11, 15),
      DateTime.utc(2043, 6, 15),
    ]) {
      expect(deltaTSeconds(d.year, d.month),
          closeTo(deltaTAtJdUt(jdFromDateTimeUtc(d)).seconds, 0.000001));
    }
  });

  test('TT roundtrip through both funnels is the identity', () {
    final jd = jdFromDateTimeUtc(DateTime.utc(2026, 11, 15));
    final back = jdUtFromJdTt(jdTtFromJdUt(jd));
    expect((back - jd).abs(), lessThan(1 / 86400000)); // < 1 ms
  });

  test('outside AD -720..2150 throws ArgumentError', () {
    expect(() => deltaTSeconds(-800, 1), throwsArgumentError);
    expect(() => deltaTSeconds(2200, 1), throwsArgumentError);
    expect(() => deltaTAtJdUt(1458084.5), throwsArgumentError);
    expect(() => deltaTAtJdUt(2506345.5), throwsArgumentError);
    expect(deltaTAtJdUt(2506314.5).source, 'espenak-meeus');
  });
}
