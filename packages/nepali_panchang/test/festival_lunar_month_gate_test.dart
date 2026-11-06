import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// R6d lunar-month gate (HYA-367).
///
/// Root cause of the 2026-11-06 R6c revert: the battery matched tithi
/// index + convention only, so every lunar month of the year matched
/// every rule. scanFestivals now keeps only occasions whose amanta
/// lunar month contains the rule's anchor sankranti, so each rule
/// fires exactly once per year.
///
/// This sweep is the structural gate the receipt corpora cannot
/// provide (their scan windows are narrow by design): AD 2026-2044
/// is a full 19-year metonic cycle (user decision 2026-11-06),
/// asserting per year that each anchor rasi falls in exactly one
/// amanta month and every rule fires exactly once inside it.
void main() {
  const firstYear = 2026;
  const lastYear = 2044;
  // Simha, Kanya, Tula, Vrischik, Kumbha, Meena ingress order.
  const anchorRasis = [5, 6, 7, 8, 11, 12];

  test('each anchor rasi falls in exactly one amanta month per year', () {
    for (var y = firstYear; y <= lastYear; y++) {
      final months = masaList(
        startNpt: DateTime.utc(y, 1, 1),
        endNpt: DateTime.utc(y, 12, 31),
      );
      for (final rasi in anchorRasis) {
        final hits =
            months.where((m) => m.sankrantiRasis.contains(rasi)).toList();
        expect(hits.length, 1,
            reason: 'AD ' +
                y.toString() +
                ': rasi ' +
                rasi.toString() +
                ' expected exactly one amanta month, found ' +
                hits.length.toString());
      }
    }
  });

  test('every rule fires exactly once per year, inside its anchor month', () {
    for (var y = firstYear; y <= lastYear; y++) {
      final months = masaList(
        startNpt: DateTime.utc(y, 1, 1),
        endNpt: DateTime.utc(y, 12, 31),
      );
      final byRasi = <int, List<FestivalRule>>{};
      for (final r in festivalBattery) {
        byRasi.putIfAbsent(r.anchorSankrantiRasi, () => []).add(r);
      }
      byRasi.forEach((rasi, rules) {
        final month =
            months.firstWhere((m) => m.sankrantiRasis.contains(rasi));
        final observances = scanFestivals(
          start: month.beginsAtNpt.subtract(const Duration(days: 1)),
          end: month.endsAtNpt.add(const Duration(days: 1)),
          rules: rules,
        );
        for (final rule in rules) {
          final mine =
              observances.where((o) => o.rule.id == rule.id).toList();
          expect(mine.length, 1,
              reason: 'AD ' +
                  y.toString() +
                  ' ' +
                  rule.id +
                  ': expected exactly one observance in its anchor ' +
                  'month, found ' +
                  mine.length.toString());
          final span = mine.first.occasion;
          // The tithi run lies inside the anchor month: a run never
          // crosses a new moon.
          expect(span.beginsAtNpt.isBefore(month.endsAtNpt), isTrue,
              reason: 'AD ' +
                  y.toString() +
                  ' ' +
                  rule.id +
                  ': run begins after the month ends');
          expect(span.endsAtNpt.isAfter(month.beginsAtNpt), isTrue,
              reason: 'AD ' +
                  y.toString() +
                  ' ' +
                  rule.id +
                  ': run ends before the month begins');
          if (y == 2026 && rule.id == 'ghatasthapana') {
            expect(mine.first.chosenDays.first, DateTime.utc(2026, 10, 11),
                reason: '2083 receipt: Ghatasthapana = Asoj 25 = '
                    '2026-10-11');
          }
        }
      });
    }
  });
}
