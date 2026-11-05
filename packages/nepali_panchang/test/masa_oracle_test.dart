import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';
import 'package:tithi_engine/tithi_engine.dart';
import 'package:tithi_engine/data/all.dart';

/// Masa-layer oracle (HYA-419): our amanta month naming and adhika
/// detection cross-checked day-by-day against tithi_engine's exhaustively
/// verified lunar months (Swiss-anchored, 1900-2100 sweep, Kathmandu a
/// registry city). Methods and oracles only - no data taken from them.
///
/// Dense coverage around the 2026 Adhika Jestha boundaries (May 15-20,
/// June 14-18) where month attribution is knife-edge; 3-day sampling over
/// the full 2026-2028 window otherwise.

/// tithi_engine LunarMonth enum in amanta order chaitra..phalguna.
const List<LunarMonth> _theirOrder = [
  LunarMonth.chaitra, LunarMonth.vaishakha, LunarMonth.jyeshtha,
  LunarMonth.ashadha, LunarMonth.shravana, LunarMonth.bhadrapada,
  LunarMonth.ashvina, LunarMonth.kartika, LunarMonth.margashirsha,
  LunarMonth.pausha, LunarMonth.magha, LunarMonth.phalguna,
];

/// Our BS month number 1..12 (Baisakh=1) mapped to their month enum
/// (vaishakha=1, jyeshtha=2, ..., chaitra=12).
LunarMonth _theirMonthOf(int ourMonthNumber) =>
    _theirOrder[ourMonthNumber % 12];

void main() {
  // Amant system: our masa layer is amanta (new moon to new moon),
  // the convention the Adhika Jestha 2026 receipts pin. tithi_engine
  // defaults to Purnimant, which shifts month attribution by half a
  // lunation - comparing systems would mismatch every paksha boundary.
  final oracle =
      Panchang([registerAllCities], system: MonthSystem.amant);
  final kathmandu = City.of('Kathmandu');

  final days = <DateTime>{};
  // Dense: the adhika boundary weeks of 2026.
  for (var d = 15; d <= 20; d++) {
    days.add(DateTime.utc(2026, 5, d));
  }
  for (var d = 14; d <= 18; d++) {
    days.add(DateTime.utc(2026, 6, d));
  }
  // Sampled sweep 2026-01-01 .. 2028-12-31.
  for (var d = DateTime.utc(2026, 1, 1);
      !d.isAfter(DateTime.utc(2028, 12, 31));
      d = d.add(const Duration(days: 3))) {
    days.add(d);
  }
  final sorted = days.toList()..sort();

  test('month naming and adhika flags agree with tithi_engine', () {
    var checked = 0;
    var adhikaDays = 0;
    final mismatches = <String>[];
    for (final date in sorted) {
      final ours = masaOf(year: date.year, month: date.month, day: date.day);
      final info = oracle.tithiOnDate(date, kathmandu);
      final okMonth = info.month == _theirMonthOf(ours.monthNumber);
      final okAdhika = info.isAdhika == ours.isAdhika;
      if (ours.isAdhika) adhikaDays++;
      if (!okMonth || !okAdhika) {
        mismatches.add('${date.toIso8601String().substring(0, 10)}: '
            'ours ${ours.monthNumber}${ours.isAdhika ? ' adhika' : ''} '
            'vs theirs ${info.month}${info.isAdhika ? ' adhika' : ''}');
      }
      checked++;
    }
    // ignore: avoid_print
    print('masa oracle scoreboard: days=$checked adhikaDays=$adhikaDays '
        'mismatches=${mismatches.length}');
    expect(mismatches, isEmpty,
        reason: 'month mismatches vs tithi_engine:\n'
            '${mismatches.take(20).join('\n')}');
    expect(adhikaDays, greaterThan(0),
        reason: 'the sweep must cover the 2026 Adhika Jestha window');
  });
}
