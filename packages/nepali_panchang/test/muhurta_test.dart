import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Structural tests for the L4 muhurta recipes (HYA-420 step 3): every
/// window must partition the engine's own sunrise-sunset span exactly as
/// its rule requires. Receipt calibration (engine vs publisher) lives in
/// muhurta_calibration_test.dart; publisher self-consistency lives in
/// muhurta_receipts_test.dart.

void main() {
  // 2026-11-05 is a Thursday; Nov 5..11 cover all seven weekdays.
  final day = muhurtaFor(year: 2026, month: 11, day: 5);

  test('Rahu Kalam on Thursday is the 6th of 8 daylight parts', () {
    final dayLen = day.sunsetNpt.difference(day.sunriseNpt);
    expect(rahuKalamPartByWeekday[DateTime.thursday], 6);
    expect(day.rahuKalam.beginsAtNpt,
        day.sunriseNpt.add(dayLen * 5 ~/ 8));
    expect(day.rahuKalam.endsAtNpt,
        day.sunriseNpt.add(dayLen * 6 ~/ 8));
  });

  test('Yamaganda and Gulika sit on the same 8-part grid', () {
    final dayLen = day.sunsetNpt.difference(day.sunriseNpt);
    expect(yamagandaPartByWeekday[DateTime.thursday], 1);
    expect(day.yamaganda.beginsAtNpt, day.sunriseNpt);
    expect(day.yamaganda.endsAtNpt,
        day.sunriseNpt.add(dayLen * 1 ~/ 8));
    expect(gulikaPartByWeekday[DateTime.thursday], 3);
    expect(day.gulika.beginsAtNpt,
        day.sunriseNpt.add(dayLen * 2 ~/ 8));
    expect(day.gulika.endsAtNpt,
        day.sunriseNpt.add(dayLen * 3 ~/ 8));
  });

  test('Abhijit is the 8th of 15 daylight muhurtas, centered on midday', () {
    final dayLen = day.sunsetNpt.difference(day.sunriseNpt);
    expect(day.abhijitMuhurta.beginsAtNpt,
        day.sunriseNpt.add(dayLen * 7 ~/ 15));
    expect(day.abhijitMuhurta.endsAtNpt,
        day.sunriseNpt.add(dayLen * 8 ~/ 15));
    final mid = day.sunriseNpt.add(dayLen ~/ 2);
    final abLen = day.abhijitMuhurta.endsAtNpt
        .difference(day.abhijitMuhurta.beginsAtNpt);
    final abMid = day.abhijitMuhurta.beginsAtNpt.add(abLen ~/ 2);
    expect(abMid.difference(mid).abs(),
        lessThan(const Duration(seconds: 90)));
  });

  test('Brahma muhurta: computed night/15 and the fixed 96/48 convention', () {
    expect(day.brahmaMuhurtaFixed.beginsAtNpt,
        day.sunriseNpt.subtract(const Duration(minutes: 96)));
    expect(day.brahmaMuhurtaFixed.endsAtNpt,
        day.sunriseNpt.subtract(const Duration(minutes: 48)));
    // Computed: the 14th of the 15 muhurtas of the night ending at this
    // sunrise (previous evening's sunset -> this dawn).
    final prevNight =
        day.sunriseNpt.difference(day.previousSunsetNpt);
    expect(day.brahmaMuhurta.beginsAtNpt,
        day.previousSunsetNpt.add(prevNight * 13 ~/ 15));
    expect(day.brahmaMuhurta.endsAtNpt,
        day.previousSunsetNpt.add(prevNight * 14 ~/ 15));
    expect(day.brahmaMuhurta.endsAtNpt.isBefore(day.sunriseNpt), isTrue);
  });

  test('choghadiya: day and night parts partition their spans', () {
    expect(day.choghadiyaDay.length, 8);
    expect(day.choghadiyaNight.length, 8);
    expect(day.choghadiyaDay.first.beginsAtNpt, day.sunriseNpt);
    expect(day.choghadiyaDay.last.endsAtNpt, day.sunsetNpt);
    expect(day.choghadiyaNight.first.beginsAtNpt, day.sunsetNpt);
    expect(day.choghadiyaNight.last.endsAtNpt, day.nextSunriseNpt);
    for (var k = 0; k < 7; k++) {
      expect(day.choghadiyaDay[k].endsAtNpt,
          day.choghadiyaDay[k + 1].beginsAtNpt);
      expect(day.choghadiyaNight[k].endsAtNpt,
          day.choghadiyaNight[k + 1].beginsAtNpt);
    }
  });

  test('choghadiya types follow the weekday-lord cycles', () {
    final dayLord = weekdayLordByWeekday[DateTime.thursday]!;
    final dayCi = choghadiyaDayCycle.indexOf(dayLord);
    for (var k = 0; k < 8; k++) {
      expect(day.choghadiyaDay[k].lord,
          choghadiyaDayCycle[(dayCi + k) % 7]);
      expect(day.choghadiyaDay[k].type,
          day.choghadiyaDay[k].lord == 'Jupiter' && k == 0
              ? 'Shubh'
              : day.choghadiyaDay[k].type);
    }
    // Night part 1 belongs to the lord of the weekday 3 days later
    // (Thursday -> Sunday -> Sun).
    expect(day.choghadiyaNight.first.lord, 'Sun');
    expect(day.choghadiyaNight.first.type, 'Udveg');
  });

  test('hora: 24 unequal slots, first = weekday lord', () {
    expect(day.horas.length, 24);
    final dayLord = weekdayLordByWeekday[DateTime.thursday]!;
    final horaCi = horaLordOrder.indexOf(dayLord);
    expect(day.horas.first.lord, 'Jupiter');
    expect(day.horas.first.beginsAtNpt, day.sunriseNpt);
    expect(day.horas.last.endsAtNpt, day.nextSunriseNpt);
    expect(day.horas[11].endsAtNpt, day.sunsetNpt);
    expect(day.horas[12].beginsAtNpt, day.sunsetNpt);
    for (var k = 0; k < 23; k++) {
      expect(day.horas[k].endsAtNpt, day.horas[k + 1].beginsAtNpt);
      expect(day.horas[k].lord, horaLordOrder[(horaCi + k) % 7]);
    }
    expect(day.horas[23].lord, horaLordOrder[(horaCi + 23) % 7]);
    expect(day.horas.take(12).every((h) => h.isDaylight), isTrue);
    expect(day.horas.skip(12).every((h) => !h.isDaylight), isTrue);
  });

  test('Rahu Kalam parts match the weekday table across all 7 weekdays', () {
    for (var d = 5; d <= 11; d++) {
      final date = DateTime.utc(2026, 11, d);
      final m = muhurtaFor(year: 2026, month: 11, day: d);
      final part = rahuKalamPartByWeekday[date.weekday]!;
      final dayLen = m.sunsetNpt.difference(m.sunriseNpt);
      expect(m.rahuKalam.beginsAtNpt,
          m.sunriseNpt.add(dayLen * (part - 1) ~/ 8),
          reason: 'rahu part ' + part.toString() + ' on Nov ' + d.toString());
    }
  });

  test('conventions expose every documented collision', () {
    for (final key in [
      'rahuYamaGulika', 'brahma', 'abhijit', 'choghadiya', 'hora',
      'durMuhurta', 'varjyamAmrit',
    ]) {
      expect(day.conventions[key], isNotNull, reason: key + ' missing');
      expect(day.conventions[key]!.isNotEmpty, isTrue);
    }
    expect(day.provenance, isNotEmpty);
    expect(day.evidenceTier, isNotEmpty);
  });
}
