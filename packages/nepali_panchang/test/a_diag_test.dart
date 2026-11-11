import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:nepali_panchang/src/elp2000/elp_table.dart';
import 'package:test/test.dart';

// TEMPORARY diagnostic for the HYA-369 upgrade CI failure - delete
// before merge. Writes the Dart-side internals to
// build/moon_diag.txt; the temporary ci.yml summary step cats that
// file into the run Summary (annotation output is capped at 10 lines,
// which hid the previous diagnostic attempt).
void main() {
  test('a-diag HYA-369 (temporary - remove before merge)', () {
    final pos = moonPosition(2448724.5);
    final buf = StringBuffer()
      ..writeln('DIAG1 lon=${pos.longitudeDeg} lat=${pos.latitudeDeg} '
          'dist=${pos.distanceKm} px=${pos.parallaxDeg}')
      ..writeln('DIAG2 len=${elpTerms.length} counts=$kElpSectionCounts')
      ..writeln('DIAG3 w=$kElpMeanLongitudeRad')
      ..writeln('DIAG4 e0=${elpTerms[0]} e1=${elpTerms[1]} '
          'e5=${elpTerms[5]} e7=${elpTerms[7]}')
      ..writeln('DIAG5 e9984=${elpTerms[9984]} e19965=${elpTerms[19965]} '
          'e19967=${elpTerms[19967]}');
    Directory('build').createSync(recursive: true);
    File('build/moon_diag.txt').writeAsStringSync(buf.toString());
    expect(buf.length, greaterThan(0));
  });
}
