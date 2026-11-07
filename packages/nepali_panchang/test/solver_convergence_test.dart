import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// R10.5 rung C (HYA-445): solver convergence cross-check.
///
/// The wrap-safe boundary solver now solves every crossing two ways -
/// the served 60-iteration bisection upper bound and an independent
/// derivative-accelerated Newton solve from the same coarse bracket -
/// and throws on disagreement inside nextLimbBoundaryJdTt itself, so
/// every corpus test already re-verifies the gate on every boundary it
/// solves. This suite pins the convergence claim directly: full
/// sector-chain sweeps (every tithi sector crossed twice, every karana,
/// nakshatra and yoga sector at least once per sweep) plus seeded-random
/// windows over AD 1975-2100, with the sector index probed to flip
/// across every Newton crossing.

const int _seed = 20261107;

/// Deterministic 31-bit LCG (rand() semantics, same seed family as the
/// rung A property suite - reproducible failures, zero flake).
class _Lcg {
  int _state = _seed;

  double next01() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 2147483647.0;
  }
}

final double _jdLo = julianDayFromCivil(1975, 1, 1.0);
final double _jdHi = julianDayFromCivil(2101, 1, 1.0);

/// Probe half-width around a solved crossing: ~8.6 ms, far above the
/// solver's ~100 microseconds double-precision residue and far below
/// the shortest limb run.
const double _eps = 1.0e-7;

void main() {
  test(
      'full sector-chain sweeps: Newton and bisection agree on every '
      'crossing', () {
    const specs = [
      ('tithi', 62, 30, 0.0),
      ('karana', 124, 60, 0.0),
      ('nakshatra', 30, 27, ayanamsaDeltaBhaktiBharat),
      ('yoga', 30, 27, ayanamsaDeltaBhaktiBharat),
    ];
    for (final (limb, count, sectors, delta) in specs) {
      var start = julianDayFromCivil(2026, 10, 16.0);
      for (var i = 0; i < count; i++) {
        final bisected = nextLimbBoundaryJdTt(limb, start, delta);
        final newton =
            nextLimbBoundaryNewtonJdTt(limb, start, delta);
        expect((bisected - newton).abs(), lessThan(1.0e-8),
            reason: '$limb crossing #$i disagrees');
        final target = limbIndex(limb, start, delta);
        expect(limbIndex(limb, newton - _eps, delta), target,
            reason: '$limb newton #$i before');
        expect(limbIndex(limb, newton + _eps, delta),
            (target + 1) % sectors,
            reason: '$limb newton #$i after');
        expect(bisected, greaterThan(start),
            reason: '$limb chain not increasing');
        start = bisected;
      }
    }
  });

  test('seeded-random windows over AD 1975-2100 agree and flip', () {
    final rand = _Lcg();
    const specs = [
      ('tithi', 30, 0.0),
      ('karana', 60, 0.0),
      ('nakshatra', 27, ayanamsaDeltaBhaktiBharat),
      ('yoga', 27, ayanamsaDeltaBhaktiBharat),
    ];
    for (final (limb, sectors, delta) in specs) {
      for (var i = 0; i < 30; i++) {
        final start = _jdLo + rand.next01() * (_jdHi - _jdLo);
        final bisected = nextLimbBoundaryJdTt(limb, start, delta);
        final newton =
            nextLimbBoundaryNewtonJdTt(limb, start, delta);
        expect((bisected - newton).abs(), lessThan(1.0e-8),
            reason: '$limb sample #$i disagrees');
        final target = limbIndex(limb, start, delta);
        expect(limbIndex(limb, newton - _eps, delta), target,
            reason: '$limb sample #$i before');
        expect(limbIndex(limb, newton + _eps, delta),
            (target + 1) % sectors,
            reason: '$limb sample #$i after');
      }
    }
  });

  test('the solver is deterministic: repeated calls return identical '
      'doubles', () {
    const limb = 'tithi';
    const start = 2461000.0;
    final a = nextLimbBoundaryJdTt(limb, start, 0.0);
    final b = nextLimbBoundaryJdTt(limb, start, 0.0);
    final n1 = nextLimbBoundaryNewtonJdTt(limb, start, 0.0);
    final n2 = nextLimbBoundaryNewtonJdTt(limb, start, 0.0);
    expect(a, b);
    expect(n1, n2);
    expect(a, greaterThan(start));
  });
}
