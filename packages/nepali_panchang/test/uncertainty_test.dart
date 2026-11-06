import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// HYA-423: the published error bars are honest ceilings over the recorded
/// scoreboards and every served day carries them.
void main() {
  test('published error bars cover every served limb', () {
    final limbs = publishedErrorBars.map((b) => b.limb).toSet();
    expect(limbs, {'tithi', 'nakshatra', 'yoga', 'karana', 'sunrise', 'moonrise'});
  });

  test('bands are honest ceilings from the recorded scoreboards', () {
    final byLimb = {for (final b in publishedErrorBars) b.limb: b};
    // Recorded corpus maxima (Oct-Nov 2026, full 60-term + VSOP87D engine):
    // tithi max ~1.0 min, nakshatra max 1.7 min (perigee), yoga max ~0.97.
    expect(byLimb['tithi']!.plusMinusMinutes, greaterThanOrEqualTo(1.0));
    expect(byLimb['nakshatra']!.plusMinusMinutes, greaterThanOrEqualTo(1.7));
    expect(byLimb['yoga']!.plusMinusMinutes, greaterThanOrEqualTo(1.0));
    // Karana is convention-anchored: exact identity, zero band.
    expect(byLimb['karana']!.plusMinusMinutes, 0);
    // Sunrise band is the geometric parity claim, stated separately from
    // the publisher convention offset.
    expect(byLimb['sunrise']!.plusMinusMinutes, 1.0);
    // Moonrise: JPL topocentric receipts observed max ~12 min (a
    // provisional rise-convention gap); the Swiss-truth scoreboard at
    // the identical Meeus 15.1 target reads 0.3 s mean, 1 s max (PR #42)
    // - the band is all receipts-side convention, not ephemeris error.
    expect(byLimb['moonrise']!.plusMinusMinutes, greaterThanOrEqualTo(12.0));
    // Every band must state its basis.
    for (final b in publishedErrorBars) {
      expect(b.basis.length, greaterThan(40), reason: b.limb);
    }
  });

  test('every served day carries the published bands', () {
    final day = panchangFor(year: 2026, month: 11, day: 5);
    expect(day.uncertainty, same(publishedErrorBars));
    expect(day.uncertainty.map((b) => b.limb), contains('tithi'));
  });
}
