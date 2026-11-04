import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Unit spot checks for the limb layer (R6a-1 step 3, HYA-403).
///
/// The full-corpus accuracy gate is test/receipts_calibration_test.dart; these
/// tests pin the name tables and a few engine moments computed in the sandbox
/// during development, so a regression is diagnosable without the corpus.
void main() {
  test('tithi name table is canonical and invertible', () {
    expect(tithiName(0), 'Shukla Pratipada');
    expect(tithiName(14), 'Purnima');
    expect(tithiName(15), 'Krishna Pratipada');
    expect(tithiName(18), 'Krishna Chaturthi');
    expect(tithiName(29), 'Amavasya');
    for (var i = 0; i < 30; i++) {
      expect(tithiIndexFromName(tithiName(i)), i);
    }
    expect(tithiIndexFromName('Foobar'), -1);
  });

  test('karana table: fixed karanas open and close the lunar month', () {
    expect(karanaName(1), 'Kimstughna');
    expect(karanaName(2), 'Bava');
    expect(karanaName(3), 'Balava');
    expect(karanaName(9), 'Bava');
    expect(karanaName(58), 'Shakuni');
    expect(karanaName(59), 'Chatushpada');
    expect(karanaName(60), 'Naga');
    expect(() => karanaName(0), throwsArgumentError);
    expect(() => karanaName(61), throwsArgumentError);
  });

  test('solver: Amavasya ends Nov 9 2026 at 12:47 NPT (sandbox value)', () {
    final probeWall = DateTime.utc(2026, 11, 9, 6, 0);
    final probeJdTt = jdTtFromJdUt(jdFromDateTimeUtc(probeWall));
    expect(limbIndex('tithi', probeJdTt, ayanamsaDeltaBhaktiBharat), 29);

    final boundary =
        nextLimbBoundaryJdTt('tithi', probeJdTt, ayanamsaDeltaBhaktiBharat);
    final engineWall = dateTimeUtcFromJd(jdUtFromJdTt(boundary))
        .add(const Duration(milliseconds: nptOffsetMs));
    final expected = DateTime.utc(2026, 11, 9, 12, 47);
    final deltaMin = engineWall.difference(expected).inSeconds / 60.0;
    expect(deltaMin.abs(), lessThan(2.0),
        reason: 'Amavasya end off by ${deltaMin.toStringAsFixed(2)} min');
  });

  test('yoga at Nov 9 2026 noon NPT is Saubhagya', () {
    final noonWall = DateTime.utc(2026, 11, 9, 12, 0);
    final jdTt = jdTtFromJdUt(jdFromDateTimeUtc(noonWall));
    final index = limbIndex('yoga', jdTt, ayanamsaDeltaBhaktiBharat);
    expect(yogaNames[index], 'Saubhagya');
  });

  test('sunrise Nov 9 2026 in Kathmandu lands in the published window', () {
    final rise = sunriseJdUt(year: 2026, month: 11, day: 9);
    final wall = dateTimeUtcFromJd(rise)
        .add(const Duration(milliseconds: nptOffsetMs));
    final minutes = wall.hour * 60.0 + wall.minute + wall.second / 60.0;
    expect(minutes, greaterThan(6 * 60 + 10));
    expect(minutes, lessThan(6 * 60 + 25));
  });
}
