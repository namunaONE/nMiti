import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// R10.5 rung A (HYA-445): property-based invariant suite.
///
/// The SOFA published-validation-vector pattern applied continuously to
/// our own engine: seeded-random property windows over AD 1975-2100
/// assert the structural laws every served value must obey, independent
/// of any receipt corpus. The generator is a fixed-seed LCG, so every
/// CI run samples the same instants - a failure is reproducible to the
/// seed and a green run never flakes.
///
/// Properties:
///  * limb chains advance the sector index by exactly one per boundary,
///    with in-band durations (the elongation-rate envelope);
///  * the elongation is strictly increasing at a physical rate;
///  * karana is the half-tithi identity at every instant;
///  * the canonical name tables round-trip;
///  * the day block's elements contain their reference instants and
///    the vriddhi/kshaya flags match the udaya chain across days;
///  * sunrise and sunset bracket sane Kathmandu daylight inside the
///    queried civil day; moonrise solves to a zero margin;
///  * amanta months chain exactly with the sankranti overlay laws;
///  * Delta T stays in range, is continuous inside the observed and
///    prediction eras, and round-trips through both JD funnels;
///  * the ayanamsa drifts at exactly the fitted rate.

const int _seed = 20261107;

/// Deterministic 31-bit LCG (rand() semantics, reproducible everywhere).
class _Lcg {
  int _state;
  _Lcg([this._state = _seed]);

  double next01() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 2147483647.0;
  }
}

final double _jdLo = julianDayFromCivil(1975, 1, 1.0);
final double _jdHi = julianDayFromCivil(2101, 1, 1.0);

double _randomJd(_Lcg rand) => _jdLo + rand.next01() * (_jdHi - _jdLo);

DateTime _randomDate(_Lcg rand) => dateTimeUtcFromJd(_randomJd(rand));

/// Probe half-width around a solved boundary: ~8.6 ms, far above the
/// bisection solver's sub-millisecond residue and far below the
/// shortest limb run, so the probes never cross a second seam.
const double _eps = 1.0e-7;

void main() {
  group('R10.5 property invariants (HYA-445)', () {
    test('limb chains advance the sector index by exactly one, in band',
        () {
      final rand = _Lcg();
      const limbSpecs = [
        ('tithi', 30, 0.68, 1.30, 0.0),
        ('karana', 60, 0.33, 0.68, 0.0),
        ('nakshatra', 27, 0.80, 1.25, ayanamsaDeltaBhaktiBharat),
        ('yoga', 27, 0.75, 1.15, ayanamsaDeltaBhaktiBharat),
      ];
      for (final spec in limbSpecs) {
        final (limb, sectors, minDays, maxDays, delta) = spec;
        for (var s = 0; s < 6; s++) {
          var start = _randomJd(rand);
          // Keep the sample at least ~8 s clear of the next seam so the
          // epsilon probes around the first boundary stay inside the
          // start sector.
          var guard = 0;
          while (limbIndex(limb, start + 1.0e-4, delta) !=
              limbIndex(limb, start, delta)) {
            start += 0.01;
            guard++;
            expect(guard, lessThan(1000));
          }
          final first = limbIndex(limb, start, delta);
          var prevB = nextLimbBoundaryJdTt(limb, start, delta);
          expect(limbIndex(limb, prevB - _eps, delta), first,
              reason: limb + ' first boundary, before');
          expect(limbIndex(limb, prevB + _eps, delta), (first + 1) % sectors,
              reason: limb + ' first boundary, after');
          for (var i = 1; i < 5; i++) {
            final b = nextLimbBoundaryJdTt(limb, prevB, delta);
            expect(b, greaterThan(prevB), reason: limb + ' not increasing');
            final span = b - prevB;
            expect(span, greaterThan(minDays),
                reason: limb + ' interval too short');
            expect(span, lessThan(maxDays),
                reason: limb + ' interval too long');
            final before = limbIndex(limb, b - _eps, delta);
            final after = limbIndex(limb, b + _eps, delta);
            expect(after, (before + 1) % sectors,
                reason: limb + ' index jump');
            expect(before, (first + i) % sectors,
                reason: limb + ' chain order');
            prevB = b;
          }
        }
      }
    });

    test('elongation strictly increases at a physical rate', () {
      final rand = _Lcg();
      for (var w = 0; w < 10; w++) {
        final t0 = _randomJd(rand);
        var prev = elongationDeg(t0);
        for (var i = 1; i <= 16; i++) {
          final e = elongationDeg(t0 + i * 0.25);
          var d = e - prev;
          if (d < -180.0) d += 360.0;
          expect(d, greaterThan(0.0));
          final rate = d / 0.25;
          expect(rate, greaterThan(9.5));
          expect(rate, lessThan(17.5));
          prev = e;
        }
      }
    });

    test('karana is the half-tithi identity at every instant', () {
      final rand = _Lcg();
      for (var i = 0; i < 400; i++) {
        final t = _randomJd(rand);
        final ti = limbIndex('tithi', t, 0.0);
        final ka = limbIndex('karana', t, 0.0);
        expect(ka == 2 * ti || ka == 2 * ti + 1, isTrue,
            reason: 'jd=' + t.toString());
        expect(karanaNumber(t), ka + 1);
      }
    });

    test('canonical name tables round-trip', () {
      for (var i = 0; i < 30; i++) {
        expect(tithiIndexFromName(tithiName(i)), i);
        expect(limbName('tithi', i), tithiName(i));
      }
      expect(nakshatraNames.toSet().length, 27);
      expect(yogaNames.toSet().length, 27);
      expect(karanaName(1), 'Kimstughna');
      expect(karanaName(2), 'Bava');
      expect(karanaName(58), 'Shakuni');
      expect(karanaName(59), 'Chatushpada');
      expect(karanaName(60), 'Naga');
      expect({for (var n = 1; n <= 60; n++) karanaName(n)}.length, 11);
    });

    test(
        'day block elements contain their reference instants; '
        'flags match the udaya chain', () {
      final rand = _Lcg();
      PanchangDay dayFor(DateTime d) =>
          panchangFor(year: d.year, month: d.month, day: d.day);
      void checkContainment(PanchangDay day) {
        final noon = day.dateNpt.add(const Duration(hours: 12));
        for (final e in [
          day.tithiAtUdaya,
          day.nakshatraAtUdaya,
          day.yogaAtUdaya,
          day.karanaAtUdaya,
        ]) {
          expect(day.sunriseNpt.isBefore(e.endsAtNpt), isTrue,
              reason: e.limb + ' udaya end');
          expect(!day.sunriseNpt.isBefore(e.beginsAtNpt), isTrue,
              reason: e.limb + ' udaya begin');
        }
        for (final e in [
          day.tithiAtNoon,
          day.nakshatraAtNoon,
          day.yogaAtNoon,
          day.karanaAtNoon,
        ]) {
          expect(noon.isBefore(e.endsAtNpt), isTrue,
              reason: e.limb + ' noon end');
          expect(!noon.isBefore(e.beginsAtNpt), isTrue,
              reason: e.limb + ' noon begin');
        }
      }

      for (var s = 0; s < 6; s++) {
        final d = _randomDate(rand);
        final p = dayFor(d.subtract(const Duration(days: 1)));
        final c = dayFor(d);
        final n = dayFor(d.add(const Duration(days: 1)));
        checkContainment(p);
        checkContainment(c);
        checkContainment(n);
        final pi = p.tithiAtUdaya.index;
        final ci = c.tithiAtUdaya.index;
        final ni = n.tithiAtUdaya.index;
        expect(c.tithiVriddhi, ci == ni || ci == pi);
        expect(c.tithiKshaya, (ni - ci) % 30 == 2 || (ci - pi) % 30 == 2);
        if (ci == ni) {
          expect(c.tithiVriddhi, isTrue);
          expect(n.tithiVriddhi, isTrue);
        }
        if (ci == pi) {
          expect(c.tithiVriddhi, isTrue);
          expect(p.tithiVriddhi, isTrue);
        }
        if ((ni - ci) % 30 == 2) {
          expect(c.tithiKshaya, isTrue);
          expect(n.tithiKshaya, isTrue);
        }
        if ((ci - pi) % 30 == 2) {
          expect(c.tithiKshaya, isTrue);
          expect(p.tithiKshaya, isTrue);
        }
      }
    });

    test(
        'sunrise and sunset bracket sane Kathmandu daylight inside the '
        'civil day', () {
      final rand = _Lcg();
      for (var i = 0; i < 60; i++) {
        final d = _randomDate(rand);
        final sr = sunriseJdUt(year: d.year, month: d.month, day: d.day);
        final ss = sunsetJdUt(year: d.year, month: d.month, day: d.day);
        final srNpt = dateTimeUtcFromJd(sr)
            .add(const Duration(milliseconds: nptOffsetMs));
        final ssNpt = dateTimeUtcFromJd(ss)
            .add(const Duration(milliseconds: nptOffsetMs));
        expect([srNpt.year, srNpt.month, srNpt.day],
            [d.year, d.month, d.day]);
        expect([ssNpt.year, ssNpt.month, ssNpt.day],
            [d.year, d.month, d.day]);
        final tod = srNpt.hour * 60 + srNpt.minute;
        expect(tod, greaterThan(285), reason: 'sunrise before 04:45 NPT');
        expect(tod, lessThan(435), reason: 'sunrise after 07:15 NPT');
        final daylight = (ss - sr) * 24.0;
        expect(daylight, greaterThan(10.0));
        expect(daylight, lessThan(14.0));
      }
    });

    test('moonrise solves to a zero margin inside the civil day', () {
      final rand = _Lcg();
      var noRiseDays = 0;
      for (var i = 0; i < 12; i++) {
        final d = _randomDate(rand);
        final rise = moonriseNpt(year: d.year, month: d.month, day: d.day);
        if (rise == null) {
          noRiseDays++;
          continue;
        }
        expect([rise.year, rise.month, rise.day], [d.year, d.month, d.day]);
        final jdRise = jdFromDateTimeUtc(
            rise.subtract(const Duration(milliseconds: nptOffsetMs)));
        final margin = moonGeocentricAltitudeDeg(jdUt: jdRise) -
            moonRiseTargetAltitudeDeg(jdRise);
        expect(margin.abs(), lessThan(1.0e-6));
      }
      expect(noRiseDays, lessThan(3));
    });

    test('amanta months chain exactly with the sankranti overlay laws', () {
      void checkWindow(DateTime start, DateTime end) {
        final months = masaList(startNpt: start, endNpt: end);
        expect(months, isNotEmpty);
        for (var i = 0; i < months.length; i++) {
          final m = months[i];
          final span = m.endsAtNpt.difference(m.beginsAtNpt);
          expect(span.inHours, greaterThan(28 * 24));
          expect(span.inHours, lessThan(32 * 24));
          expect(m.monthNumber, greaterThan(0));
          expect(m.monthNumber, lessThan(13));
          expect(m.isAdhika, m.sankrantiMomentsNpt.isEmpty);
          expect(m.isKshaya, m.sankrantiMomentsNpt.length == 2);
          if (!m.isAdhika && !m.isKshaya) {
            expect(m.sankrantiMomentsNpt.length, 1);
          }
          for (final sk in m.sankrantiMomentsNpt) {
            expect(!sk.isBefore(m.beginsAtNpt), isTrue);
            expect(sk.isBefore(m.endsAtNpt), isTrue);
          }
          if (m.isKshaya) {
            expect(m.sankrantiRasis.length, 2);
            expect(m.sankrantiRasis[1], m.sankrantiRasis[0] + 1);
          }
          if (i > 0) {
            final prevM = months[i - 1];
            expect(m.beginsAtNpt, prevM.endsAtNpt);
            expect(m.isAdhika && prevM.isAdhika, isFalse);
          }
        }
      }

      // Fixed window containing the receipt-anchored Adhika Jestha 2026.
      checkWindow(DateTime.utc(2026, 1, 1), DateTime.utc(2027, 3, 1));
      // One random 400-day window anywhere in the sweep.
      final rand = _Lcg();
      final s = _randomDate(rand);
      checkWindow(DateTime.utc(s.year, s.month, s.day),
          DateTime.utc(s.year, s.month, s.day).add(const Duration(days: 400)));
    });

    test(
        'Delta T stays in range, continuous in the observed and prediction '
        'eras, and round-trips', () {
      final rand = _Lcg();
      const sources = {
        'smh2021-spline',
        'usno-observed',
        'usno-preds',
        'espenak-meeus'
      };
      for (var i = 0; i < 200; i++) {
        final v = deltaTAtJdUt(_randomJd(rand));
        expect(sources.contains(v.source), isTrue);
        expect(v.seconds, greaterThan(20.0));
        expect(v.seconds, lessThan(400.0));
        expect(v.uncertaintySeconds, greaterThan(0.0));
        expect(v.uncertaintySeconds, lessThan(25.0));
      }
      // Monthly continuity strictly inside the observed + prediction eras
      // (away from the declared 2033-10 Espenak-Meeus join step).
      var t = julianDayFromCivil(2020, 1, 1.0);
      final tEnd = julianDayFromCivil(2032, 12, 1.0);
      var prev = deltaTAtJdUt(t).seconds;
      while (t < tEnd) {
        t += 31.0;
        final cur = deltaTAtJdUt(t).seconds;
        expect((cur - prev).abs(), lessThan(0.5));
        prev = cur;
      }
      for (var i = 0; i < 50; i++) {
        final x = _randomJd(rand);
        final rt1 = jdUtFromJdTt(jdTtFromJdUt(x));
        expect((rt1 - x).abs(), lessThan(1.0e-8));
        final rt2 = jdTtFromJdUt(jdUtFromJdTt(x));
        expect((rt2 - x).abs(), lessThan(1.0e-8));
      }
    });

    test('ayanamsa drifts at exactly the fitted rate', () {
      final rand = _Lcg();
      for (var i = 0; i < 50; i++) {
        final t = _randomJd(rand);
        // One tropical year: exactly 1% of the Julian-century argument.
        final drift = ayanamsaBase(t + 365.25) - ayanamsaBase(t);
        expect(drift, closeTo(0.0136062, 1.0e-9));
      }
    });
  });
}
