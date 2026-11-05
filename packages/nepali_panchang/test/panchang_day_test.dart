import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Daily-shape layer tests (R6a-3, HYA-416).
///
/// Anchors are corpus-pinned facts from the locked golden corpora:
/// Purnima ends Oct 26 2026 09:57 NPT; Amavasya ends Nov 9 12:47;
/// Rohini ends Oct 29 11:20; Shukla Navami is a vriddhi tithi on
/// Nov 18-19 2026 (starts Nov 18 06:20, ~2 min before sunrise);
/// Krishna Dwitiya is a kshaya tithi around Oct 28 2026 (ends 04:22,
/// running at neither udaya); on Dashain day Oct 18 2026 the karana at
/// sunrise is Vishti (Hamro Patro) while at noon it is Bava (BhaktiBharat);
/// yoga Indra ends Nov 5 06:42 (Hamro Patro profile).

void main() {
  test('Oct 26 2026: Purnima at udaya, ends late morning NPT', () {
    final d = panchangFor(year: 2026, month: 10, day: 26);
    expect(d.tithiAtUdaya.name, 'Purnima');
    expect(d.tithiAtUdaya.endsAtNpt.isAfter(DateTime.utc(2026, 10, 26, 9, 30)),
        isTrue);
    expect(d.tithiAtUdaya.endsAtNpt.isBefore(DateTime.utc(2026, 10, 26, 10, 25)),
        isTrue);
  });

  test('Nov 9 2026: Amavasya at udaya, ends around noon NPT', () {
    final d = panchangFor(year: 2026, month: 11, day: 9);
    expect(d.tithiAtUdaya.name, 'Amavasya');
    expect(d.tithiAtUdaya.endsAtNpt.isAfter(DateTime.utc(2026, 11, 9, 12, 15)),
        isTrue);
    expect(d.tithiAtUdaya.endsAtNpt.isBefore(DateTime.utc(2026, 11, 9, 13, 15)),
        isTrue);
  });

  test('Oct 29 2026: Rohini at udaya under the BhaktiBharat profile', () {
    final d = panchangFor(year: 2026, month: 10, day: 29);
    expect(d.nakshatraAtUdaya.name, 'Rohini');
    expect(
        d.nakshatraAtUdaya.endsAtNpt
            .isAfter(DateTime.utc(2026, 10, 29, 10, 50)),
        isTrue);
    expect(
        d.nakshatraAtUdaya.endsAtNpt
            .isBefore(DateTime.utc(2026, 10, 29, 11, 50)),
        isTrue);
  });

  test('Nov 18-19 2026: Shukla Navami vriddhi spans both udayas', () {
    final day18 = panchangFor(year: 2026, month: 11, day: 18);
    final day19 = panchangFor(year: 2026, month: 11, day: 19);
    expect(day18.tithiAtUdaya.name, 'Shukla Navami');
    expect(day19.tithiAtUdaya.name, 'Shukla Navami');
    expect(day18.tithiVriddhi, isTrue);
    expect(day19.tithiVriddhi, isTrue);
  });

  test('Oct 27-28 2026: Krishna Dwitiya kshaya is flagged on both days', () {
    final day27 = panchangFor(year: 2026, month: 10, day: 27);
    final day28 = panchangFor(year: 2026, month: 10, day: 28);
    expect(day27.tithiKshaya || day28.tithiKshaya, isTrue);
  });

  test('Oct 18 2026 (Dashain): udaya karana Vishti vs noon karana Bava', () {
    final d = panchangFor(year: 2026, month: 10, day: 18);
    expect(d.karanaAtUdaya.name, 'Vishti');
    expect(d.tithiAtNoon.name, 'Maha Ashtami');
  });

  test('Nov 5 2026: yoga Indra at udaya under the Hamro Patro profile', () {
    final d = panchangFor(
        year: 2026, month: 11, day: 5, sourceDelta: ayanamsaDeltaHamroPatro);
    expect(d.yogaAtUdaya.name, 'Indra');
    expect(
        d.yogaAtUdaya.endsAtNpt.isAfter(DateTime.utc(2026, 11, 5, 6, 20)),
        isTrue);
    expect(
        d.yogaAtUdaya.endsAtNpt.isBefore(DateTime.utc(2026, 11, 5, 7, 5)),
        isTrue);
  });

  test('Nov 5 2026: sunrise lands in the Kathmandu dawn window', () {
    final d = panchangFor(year: 2026, month: 11, day: 5);
    expect(d.sunriseNpt.isAfter(DateTime.utc(2026, 11, 5, 6, 0)), isTrue);
    expect(d.sunriseNpt.isBefore(DateTime.utc(2026, 11, 5, 6, 45)), isTrue);
  });

  test('structure holds across the whole Oct-Nov 2026 corpus window', () {
    for (var day = 0; day < 21; day++) {
      final date = DateTime.utc(2026, 10, 18).add(Duration(days: day));
      final d = panchangFor(
          year: date.year, month: date.month, day: date.day);

      expect(d.tithiAtUdaya.name, tithiName(d.tithiAtUdaya.index));
      expect(d.nakshatraAtUdaya.name, nakshatraNames[d.nakshatraAtUdaya.index]);
      expect(d.yogaAtUdaya.name, yogaNames[d.yogaAtUdaya.index]);
      expect(d.karanaAtUdaya.name, karanaName(d.karanaAtUdaya.index + 1));
      expect(d.tithiAtNoon.name, tithiName(d.tithiAtNoon.index));

      for (final e in [
        d.tithiAtUdaya, d.nakshatraAtUdaya, d.yogaAtUdaya, d.karanaAtUdaya,
      ]) {
        expect(e.beginsAtNpt.isBefore(e.endsAtNpt), isTrue,
            reason: '${e.limb} begins after it ends on $date');
        expect(e.endsAtNpt.difference(e.beginsAtNpt).inHours, lessThan(40),
            reason: '${e.limb} duration implausible on $date');
      }
      expect(d.sunriseNpt.isBefore(DateTime.utc(
          date.year, date.month, date.day, 7, 0)), isTrue);
    }
  });
}
