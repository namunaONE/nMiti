import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

void main() {
  group('vimshottari tables', () {
    test('nine lords, 120 years total', () {
      expect(vimshottariLords.length, 9);
      expect(vimshottariYears.length, 9);
      expect(vimshottariYears.reduce((a, b) => a + b), 120);
    });

    test('lord cycle pinned in BPHS Ch. 46 order from Ashwini', () {
      expect(vimshottariLords,
          ['Ketu', 'Venus', 'Sun', 'Moon', 'Mars', 'Rahu', 'Jupiter', 'Saturn', 'Mercury']);
      expect(vimshottariYears, [7, 20, 6, 10, 7, 18, 16, 19, 17]);
    });
  });

  group('balance arithmetic (pure)', () {
    const span = 360.0 / 27.0;
    test('moon at the Ashwini start opens a full Ketu mahadasha', () {
      final b = vimshottariBalanceFromMoonDeg(0.0, yearDays: vimshottariYearDaysSolar);
      expect(b.nakshatraIndex, 0);
      expect(b.lordIndex, 0);
      expect(b.nakshatraElapsedFraction, 0.0);
      expect(b.balanceDays, closeTo(7 * 365.25, 1e-9));
    });

    test('moon at the Bharani start opens a full Venus mahadasha', () {
      final b = vimshottariBalanceFromMoonDeg(span, yearDays: vimshottariYearDaysSolar);
      expect(b.nakshatraIndex, 1);
      expect(b.lordIndex, 1);
      expect(b.balanceDays, closeTo(20 * 365.25, 1e-9));
    });

    test('half-elapsed Bharani leaves half the Venus balance', () {
      final b =
          vimshottariBalanceFromMoonDeg(span * 1.5, yearDays: vimshottariYearDaysSolar);
      expect(b.nakshatraElapsedFraction, closeTo(0.5, 1e-12));
      expect(b.balanceDays, closeTo(10 * 365.25, 1e-9));
    });

    test('Revati wrap keeps the cycle order (26 % 9 = Mercury)', () {
      final b =
          vimshottariBalanceFromMoonDeg(span * 26.25, yearDays: vimshottariYearDaysSolar);
      expect(b.nakshatraIndex, 26);
      expect(b.lordIndex, 8);
      expect(vimshottariLords[b.lordIndex], 'Mercury');
    });
  });

  group('mahadasha chain (pure)', () {
    test('spans chain, open at birth and total 120 solar years', () {
      const birth = 2440587.5;
      final mahas = vimshottariMahadashasFromMoonDeg(
          moonDeg: 0.0, birthJdTt: birth, yearDays: vimshottariYearDaysSolar);
      expect(mahas.length, 9);
      expect(mahas.first.startJdTt, birth);
      for (var i = 0; i < 8; i++) {
        expect(mahas[i].endJdTt, mahas[i + 1].startJdTt,
            reason: 'chain break at mahadasha ' + i.toString());
      }
      expect(mahas.last.endJdTt - birth, closeTo(120 * 365.25, 1e-9));
      expect(mahas.map((s) => s.lord).toList(), vimshottariLords);
    });
  });

  group('antardasha / pratyantardasha (pure)', () {
    const birth = 2440587.5;
    final mahas = vimshottariMahadashasFromMoonDeg(
        moonDeg: 0.0, birthJdTt: birth, yearDays: vimshottariYearDaysSolar);

    test('antardasha of a full Sun mahadasha opens with Sun and sums to the maha', () {
      final sun = mahas[2];
      final antars =
          vimshottariSubPeriods(sun, yearDays: vimshottariYearDaysSolar);
      expect(antars.first.lord, 'Sun');
      expect(antars.map((s) => s.lord).toList(),
          ['Sun', 'Moon', 'Mars', 'Rahu', 'Jupiter', 'Saturn', 'Mercury', 'Ketu', 'Venus']);
      final total = antars.fold<double>(0, (a, s) => a + s.spanDays);
      expect(total, closeTo(sun.spanDays, 1e-9));
      expect(antars.first.spanDays,
          closeTo(6 / 120 * 6 * vimshottariYearDaysSolar, 1e-9));
    });

    test('pratyantardasha sums to its antardasha', () {
      final antars = vimshottariSubPeriods(mahas[2],
          yearDays: vimshottariYearDaysSolar);
      final pratyantars = vimshottariSubPeriods(antars.first,
          yearDays: vimshottariYearDaysSolar, childLevel: 'pratyantardasha');
      expect(pratyantars.first.lord, 'Sun');
      final total = pratyantars.fold<double>(0, (a, s) => a + s.spanDays);
      expect(total, closeTo(antars.first.spanDays, 1e-9));
    });
  });

  group('integration with the calibrated moon', () {
    // The Meeus 47.a epoch - the permanent moon anchor (1992 Apr 12 0h TT).
    const jd = 2434696.5;
    test('balance lord matches the nakshatra of the same moon reading', () {
      final ay = ayanamsaSwissLahiriReference(jd);
      final deg = moonSiderealInFrameDeg(jd, ay);
      final bal = vimshottariBalance(jd, ay, yearDays: vimshottariYearDaysSolar);
      expect(bal.nakshatraIndex, (deg / nakshatraSpanDeg).floor());
      expect(bal.lordIndex, bal.nakshatraIndex % 9);
    });

    test('mahadashas open at birth; vimshottariAt resolves a consistent stack', () {
      final ay = ayanamsaSwissLahiriReference(jd);
      final mahas = vimshottariMahadashas(
          birthJdTt: jd, ayanamsaDeg: ay, yearDays: vimshottariYearDaysSolar);
      expect(mahas.first.startJdTt, jd);
      final atBirth = vimshottariAt(
          birthJdTt: jd, queryJdTt: jd, ayanamsaDeg: ay, yearDays: vimshottariYearDaysSolar);
      expect(atBirth.mahadasha.lord, mahas.first.lord);
      expect(atBirth.antardasha!.lord, mahas.first.lord);
      final at100 = vimshottariAt(
          birthJdTt: jd,
          queryJdTt: jd + 100,
          ayanamsaDeg: ay,
          yearDays: vimshottariYearDaysSolar);
      expect(at100.mahadasha.startJdTt, lessThanOrEqualTo(jd + 100));
      expect(at100.mahadasha.endJdTt, greaterThan(jd + 100));
      expect(at100.antardasha, isNotNull);
      expect(at100.pratyantardasha, isNotNull);
    });

    test('the dasha-year convention is a visible parameter, not a silent choice', () {
      final ay = ayanamsaSwissLahiriReference(jd);
      final solar = vimshottariMahadashas(
          birthJdTt: jd, ayanamsaDeg: ay, yearDays: vimshottariYearDaysSolar);
      final classical = vimshottariMahadashas(
          birthJdTt: jd, ayanamsaDeg: ay, yearDays: vimshottariYearDaysClassical360);
      expect(solar.last.endJdTt - classical.last.endJdTt,
          greaterThan(500),
          reason: 'the 365.25 vs 360 dasha-year conventions must drift ~630 days over the cycle');
    });
  });
}