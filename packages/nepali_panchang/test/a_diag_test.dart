import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:nepali_panchang/src/elp2000/elp_table.dart';
import 'package:test/test.dart';

// TEMPORARY diagnostic for the HYA-369 upgrade CI failure - delete
// before merge. Fails on purpose so the expanded reporter prints the
// Dart-side internals (the failing-test annotation step renders each
// output line as a run annotation).
void main() {
  test('a-diag HYA-369 (temporary - remove before merge)', () {
    final pos = moonPosition(2448724.5);
    fail('DIAG1 lon=${pos.longitudeDeg} lat=${pos.latitudeDeg} dist=${pos.distanceKm} px=${pos.parallaxDeg}\n'
        'DIAG2 len=${elpTerms.length} counts=$kElpSectionCounts\n'
        'DIAG3 w=$kElpMeanLongitudeRad\n'
        'DIAG4 e0=${elpTerms[0]} e1=${elpTerms[1]} e5=${elpTerms[5]} e7=${elpTerms[7]}\n'
        'DIAG5 e9984=${elpTerms[9984]} e19965=${elpTerms[19965]} e19967=${elpTerms[19967]}');
  });
}
