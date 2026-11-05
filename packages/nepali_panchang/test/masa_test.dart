import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Masa layer receipts and rules (HYA-419).
///
/// Receipt provenance (every assertion is receipt-anchored, never prose):
///  * Adhika Jyeshtha/Jestha 2026: amanta span May 17 - June 15, 2026,
///    Nija Jyeshtha from June 16 - Nepal News quoting the Nepal Panchanga
///    Decision Committee ("Adhika-masa... begun on May 17"), hindutone
///    ("Adhika Jyeshtha Masam runs from May 17 2026 to June 15 2026; the
///    Nija Jyeshtha follows from June 16"), hindupad (Adhik Maas 2026,
///    Jyeshta comes twice).
///  * Vikram Samvat 2083 amanta year (began 19 March 2026) contains an
///    adhika masa: 13 lunar months (Wikipedia, "Vikram Samvat").
///  * New-moon instant: the locked golden corpus Amavasya end
///    Nov 9 2026 12:47 NPT (BhaktiBharat receipt, engine -0.5 min).
///  * Kartik 2083 = Oct 18 (Dashain/Maha Ashtami, samiti patro),
///    Kartik 19 2083 = Nov 5 (live today.json fact), Mangsir 1 2083
///    = Nov 17 (Hamro Patro URL mapping, HYA-404).

void main() {
  test('new-moon scan reproduces the corpus Amavasya end (Nov 9 2026)', () {
    final jdStart = jdTtFromJdUt(
        jdFromDateTimeUtc(DateTime.utc(2026, 11, 8)));
    final newMoonTt = nextNewMoonJdTt(jdStart);
    final wall = dateTimeUtcFromJd(jdUtFromJdTt(newMoonTt))
        .add(const Duration(milliseconds: nptOffsetMs));
    expect([wall.year, wall.month, wall.day], [2026, 11, 9],
        reason: 'new moon must fall on Nov 9 2026 NPT');
    final receipt = DateTime.utc(2026, 11, 9, 12, 47);
    expect(wall.difference(receipt).inMinutes.abs(), lessThan(2),
        reason: 'new moon off the locked receipt: $wall vs $receipt');
  });

  test('Adhika Jestha 2026: exactly one intercalated month, May 17 - Jun 15/16', () {
    final months = masaList(
        startNpt: DateTime.utc(2026, 4, 1), endNpt: DateTime.utc(2026, 8, 1));
    final adhika = months.where((m) => m.isAdhika).toList();
    expect(adhika.length, 1, reason: 'expected exactly one adhika masa');
    final a = adhika.first;
    expect(a.monthNumber, 2, reason: 'adhika masa must take Jestha name');
    expect(a.monthName, 'Jestha');
    expect([16, 17].contains(a.beginsAtNpt.day), isTrue,
        reason: 'adhika month must begin May 16-17 2026, got ${a.beginsAtNpt}');
    expect(a.beginsAtNpt.month, 5);
    expect([15, 16].contains(a.endsAtNpt.day), isTrue,
        reason: 'adhika month must end June 15-16 2026, got ${a.endsAtNpt}');
    expect(a.endsAtNpt.month, 6);
    expect(a.sankrantiMomentsNpt, isEmpty,
        reason: 'adhika months contain no sankranti');
    // No kshaya month anywhere in 2026.
    expect(months.where((m) => m.isKshaya), isEmpty);
  });

  test('Nija Jestha follows the adhika month from June 16, same name', () {
    final m17 = masaOf(year: 2026, month: 6, day: 16);
    expect(m17.isAdhika, isFalse,
        reason: 'June 16 2026 is Nija Jyeshtha day 1, not adhika');
    expect(m17.monthNumber, 2, reason: 'June 16 2026 is Nija Jestha');
    // The adhika month itself ends at this month's new moon.
    final m10 = masaOf(year: 2026, month: 6, day: 10);
    expect(m10.isAdhika, isTrue);
    expect(m10.monthNumber, 2);
  });

  test('Vikram Samvat 2083 amanta year contains 13 lunar months', () {
    // Chaitra 2083 amanta begins at the new moon around Mar 18-19 2026
    // (Wikipedia: the 2083 amanta year begins 19 March 2026).
    final chaitra = masaOf(year: 2026, month: 3, day: 21);
    expect(chaitra.monthNumber, 12, reason: 'Mar 21 2026 is Chaitra 2083');
    final months = masaList(
        startNpt: DateTime.utc(2026, 2, 1), endNpt: DateTime.utc(2027, 6, 1));
    final inYear = months
        .where((m) =>
            !m.beginsAtNpt.isBefore(chaitra.beginsAtNpt) &&
            m.beginsAtNpt.isBefore(
                chaitra.beginsAtNpt.add(const Duration(days: 380))))
        .toList();
    expect(inYear.length, 13,
        reason: 'VS 2083 amanta must have 13 lunar months (Wikipedia)');
    // and exactly one of them is adhika
    expect(inYear.where((m) => m.isAdhika).length, 1);
  });

  test('masaOf day attribution matches the locked corpus facts', () {
    // Lunar amanta months (NOT the sankranti-anchored BS solar months,
    // which nepali_sankranti serves). The Dashain-Tihar corpus pins:
    //   * Ghatasthapana Oct 11 2083 = Ashwin Shukla Pratipada, so the
    //     lunar month running Oct 10/11 - Nov 9 is ASHWIN (it contains the
    //     Tula sankranti of Oct 17/18);
    //   * Maha Ashtami Oct 18 and Kartik 19 (Nov 5) fall inside it;
    //   * Nov 17 (BS Mangsir 1) falls in the next lunar month, Kartik
    //     (contains the Vrischika sankranti of Nov 16/17).
    expect(masaOf(year: 2026, month: 10, day: 18).monthNumber, 6,
        reason: 'Oct 18 2026 lies in lunar Ashwin (Maha Ashtami)');
    expect(masaOf(year: 2026, month: 11, day: 5).monthNumber, 6,
        reason: 'Nov 5 2026 (Kartik 19 BS) lies in lunar Ashwin');
    expect(masaOf(year: 2026, month: 11, day: 5).monthName, 'Ashwin');
    expect(masaOf(year: 2026, month: 11, day: 17).monthNumber, 7,
        reason: 'Nov 17 2026 lies in lunar Kartik (Vrischika sankranti)');
  });

  test('month spans are sane: 28-32 days, monotonic, sankrantis consistent', () {
    final months = masaList(
        startNpt: DateTime.utc(2026, 1, 1), endNpt: DateTime.utc(2027, 3, 1));
    expect(months.length, greaterThan(12));
    for (var i = 0; i < months.length; i++) {
      final span =
          months[i].endsAtNpt.difference(months[i].beginsAtNpt).inDays;
      expect(span, greaterThanOrEqualTo(28),
          reason: 'lunar month span too short: $span days');
      expect(span, lessThanOrEqualTo(32),
          reason: 'lunar month span too long: $span days');
      if (i > 0) {
        expect(months[i].beginsAtNpt, months[i - 1].endsAtNpt,
            reason: 'new-moon chain must be monotonic and contiguous');
      }
      final n = months[i].sankrantiMomentsNpt.length;
      expect(n, months[i].isAdhika ? 0 : (months[i].isKshaya ? 2 : 1));
      for (final s in months[i].sankrantiMomentsNpt) {
        expect(s.isAfter(months[i].beginsAtNpt), isTrue);
        expect(s.isBefore(months[i].endsAtNpt) || s.isAtSameMomentAs(months[i].endsAtNpt), isTrue);
      }
    }
  });
}
