import 'civil_time.dart';
import 'sunrise.dart';
import 'sunset.dart';

/// L4 muhurta layer (HYA-420 step 3).
///
/// [muhurtaFor] computes the daily muhurta windows at runtime from the
/// engine's own USNO sunrise and sunset solvers: Rahu Kalam, Yamaganda and
/// Gulika (weekday part tables over daylight divided into 8), Abhijit (the
/// 8th of 15 daylight muhurtas, centered on the day midpoint by
/// construction), Brahma muhurta (the 14th of the night's fifteen ending
/// at this day's sunrise, plus the BhaktiBharat fixed 96/48-minute
/// convention as a separate window), the day and night choghadiya (8 parts
/// each) and the 24 unequal horas (daylight/12 + night/12, sunrise to the
/// next sunrise).
///
/// Every rule is receipt-anchored, never prose-anchored: the weekday part
/// tables, the choghadiya type cycles and the window arithmetic are
/// validated against the BhaktiBharat Kathmandu corpus (2026-11-05 ..
/// 2026-11-22, test/fixtures/muhurta_receipts_2026_11.json) where the
/// published Rahu, Yamaganda and Gulika windows reproduce within 0.9 min
/// of the 8-part rule (publisher self-consistency, test/
/// muhurta_receipts_test.dart) and the engine windows are banded against
/// the receipts in test/muhurta_calibration_test.dart.
///
/// Convention collisions are exposed, never silently picked: Brahma muhurta
/// (computed night/15 vs the publisher's fixed 96/48 minutes - both are
/// served), Abhijit (computed day/15 vs the publisher's stepped tabulation,
/// documented divergence), and the horas (unequal, astronomically
/// consistent, primary - vs the Temple-tradition fixed 60-minute horas,
/// documented in [MuhurtaDay.conventions]). Dur Muhurtam is deliberately
/// NOT served: source weekday tables disagree (the corpus records the
/// windows as data only). Varjyam and Amrit Kalam are nakshatra-based and
/// deferred to a later layer.

/// Rahu Kalam part (1..8 of daylight) by weekday (DateTime.weekday).
const rahuKalamPartByWeekday = <int, int>{
  DateTime.monday: 2,
  DateTime.tuesday: 7,
  DateTime.wednesday: 5,
  DateTime.thursday: 6,
  DateTime.friday: 4,
  DateTime.saturday: 3,
  DateTime.sunday: 8,
};

/// Yamaganda part (1..8 of daylight) by weekday.
const yamagandaPartByWeekday = <int, int>{
  DateTime.monday: 4,
  DateTime.tuesday: 3,
  DateTime.wednesday: 2,
  DateTime.thursday: 1,
  DateTime.friday: 7,
  DateTime.saturday: 6,
  DateTime.sunday: 5,
};

/// Gulika part (1..8 of daylight) by weekday.
const gulikaPartByWeekday = <int, int>{
  DateTime.monday: 6,
  DateTime.tuesday: 5,
  DateTime.wednesday: 4,
  DateTime.thursday: 3,
  DateTime.friday: 2,
  DateTime.saturday: 1,
  DateTime.sunday: 7,
};

/// Choghadiya type -> ruling lord (spellings exactly as published in the
/// triple-confirmed tables: 'Amrut', not 'Amrit').
const choghadiyaTypeLords = <String, String>{
  'Udveg': 'Sun',
  'Amrut': 'Moon',
  'Rog': 'Mars',
  'Labh': 'Mercury',
  'Shubh': 'Jupiter',
  'Chal': 'Venus',
  'Kal': 'Saturn',
};

/// Weekday (DateTime.weekday, Monday = 1) -> ruling lord.
const weekdayLordByWeekday = <int, String>{
  DateTime.monday: 'Moon',
  DateTime.tuesday: 'Mars',
  DateTime.wednesday: 'Mercury',
  DateTime.thursday: 'Jupiter',
  DateTime.friday: 'Venus',
  DateTime.saturday: 'Saturn',
  DateTime.sunday: 'Sun',
};

/// Day choghadiya lord cycle: part 1 belongs to the weekday lord, then the
/// lords run in this order (part 8 wraps back to part 1's lord).
const choghadiyaDayCycle = <String>[
  'Jupiter', 'Mars', 'Sun', 'Venus', 'Mercury', 'Moon', 'Saturn',
];

/// Night choghadiya lord cycle: part 1 belongs to the lord of the weekday
/// 3 days later, then the lords run in this order.
const choghadiyaNightCycle = <String>[
  'Sun', 'Jupiter', 'Moon', 'Venus', 'Mars', 'Saturn', 'Mercury',
];

/// Hora lord order (reverse Chaldean): the 24 horas of a weekday start
/// with the weekday lord and then cycle through this order.
const horaLordOrder = <String>[
  'Sun', 'Venus', 'Mercury', 'Moon', 'Saturn', 'Jupiter', 'Mars',
];

const _choghadiyaTypeOfLord = <String, String>{
  'Sun': 'Udveg',
  'Moon': 'Amrut',
  'Mars': 'Rog',
  'Mercury': 'Labh',
  'Jupiter': 'Shubh',
  'Venus': 'Chal',
  'Saturn': 'Kal',
};

/// Documented convention collisions for [MuhurtaDay.conventions].
const _muhurtaConventions = <String, String>{
  'rahuYamaGulika':
      'daylight divided into 8 equal parts; weekday part tables '
      '(receipt-confirmed, 18/18 within 0.9 min)',
  'brahma':
      'brahmaMuhurta is the computed 14th of the night/15 ending at this '
      'day sunrise; BhaktiBharat prints a FIXED 96/48 min before sunrise, '
      'served as brahmaMuhurtaFixed',
  'abhijit':
      'computed 8th of 15 daylight muhurtas; BhaktiBharat tabulates a '
      'stepped window (up to ~3 min divergence, Nov 2026 corpus)',
  'choghadiya':
      'day = daylight/8 from sunrise, night = night/8 from sunset; type '
      'tables cross-confirmed against a live page (16/16)',
  'hora':
      'unequal horas (daylight/12 + night/12); Temple tradition uses '
      'fixed 60-min horas - collision exposed, unequal is primary',
  'durMuhurta':
      'not served: weekday tables disagree between sources (windows '
      'recorded in the fixture only)',
  'varjyamAmrit':
      'not served: nakshatra-based rules, later layer',
};

/// One muhurta window on a day, NPT wall clock.
class MuhurtaWindow {
  /// Display name, e.g. 'Rahu Kalam'.
  final String name;

  /// Rule that produced the window, e.g. 'daylight-8-parts'.
  final String ruleId;

  /// NPT wall clock (UTC fields) when the window begins.
  final DateTime beginsAtNpt;

  /// NPT wall clock (UTC fields) when the window ends.
  final DateTime endsAtNpt;

  const MuhurtaWindow({
    required this.name,
    required this.ruleId,
    required this.beginsAtNpt,
    required this.endsAtNpt,
  });
}

/// One choghadiya part (day or night).
class ChoghadiyaSlot {
  /// Type exactly as published: 'Udveg', 'Amrut', 'Rog', 'Labh', 'Shubh',
  /// 'Chal' or 'Kal'.
  final String type;

  /// Ruling lord of [type].
  final String lord;

  /// NPT wall clock (UTC fields) when the part begins.
  final DateTime beginsAtNpt;

  /// NPT wall clock (UTC fields) when the part ends.
  final DateTime endsAtNpt;

  const ChoghadiyaSlot({
    required this.type,
    required this.lord,
    required this.beginsAtNpt,
    required this.endsAtNpt,
  });
}

/// One hora slot.
class HoraSlot {
  /// Ruling lord of this hora.
  final String lord;

  /// NPT wall clock (UTC fields) when the hora begins.
  final DateTime beginsAtNpt;

  /// NPT wall clock (UTC fields) when the hora ends.
  final DateTime endsAtNpt;

  /// True for the 12 daylight horas, false for the 12 night horas.
  final bool isDaylight;

  const HoraSlot({
    required this.lord,
    required this.beginsAtNpt,
    required this.endsAtNpt,
    required this.isDaylight,
  });
}

/// The muhurta windows for one civil (AD) date in Nepal, NPT throughout.
class MuhurtaDay {
  /// The civil date of the NPT day (UTC fields; no offset applied).
  final DateTime dateNpt;

  /// This day's sunrise, NPT wall clock.
  final DateTime sunriseNpt;

  /// This day's sunset, NPT wall clock.
  final DateTime sunsetNpt;

  /// The next day's sunrise, NPT wall clock (ends the night horas).
  final DateTime nextSunriseNpt;

  /// The previous day's sunset: the evening that starts the night ending
  /// at this day's sunrise (anchor of the computed Brahma muhurta).
  final DateTime previousSunsetNpt;

  /// Rahu Kalam window (weekday part of daylight/8).
  final MuhurtaWindow rahuKalam;

  /// Yamaganda window (weekday part of daylight/8).
  final MuhurtaWindow yamaganda;

  /// Gulika window (weekday part of daylight/8).
  final MuhurtaWindow gulika;

  /// Abhijit muhurta: the 8th of 15 daylight muhurtas.
  final MuhurtaWindow abhijitMuhurta;

  /// Brahma muhurta, computed: the 14th of the 15 night muhurtas ending
  /// at this day's sunrise (night = previousSunsetNpt -> sunriseNpt).
  final MuhurtaWindow brahmaMuhurta;

  /// Brahma muhurta, BhaktiBharat fixed convention: 96/48 min before this
  /// day's sunrise (what the publisher actually prints).
  final MuhurtaWindow brahmaMuhurtaFixed;

  /// The 8 day choghadiya parts (sunrise -> sunset).
  final List<ChoghadiyaSlot> choghadiyaDay;

  /// The 8 night choghadiya parts (sunset -> next sunrise).
  final List<ChoghadiyaSlot> choghadiyaNight;

  /// The 24 hora slots (12 day + 12 night), sunrise -> next sunrise.
  final List<HoraSlot> horas;

  /// Documented convention collisions (never silently picked).
  final Map<String, String> conventions;

  /// Engine and rule-source description for this value set.
  final String provenance;

  /// Evidence statement for every value in this day block.
  final String evidenceTier;

  const MuhurtaDay({
    required this.dateNpt,
    required this.sunriseNpt,
    required this.sunsetNpt,
    required this.nextSunriseNpt,
    required this.previousSunsetNpt,
    required this.rahuKalam,
    required this.yamaganda,
    required this.gulika,
    required this.abhijitMuhurta,
    required this.brahmaMuhurta,
    required this.brahmaMuhurtaFixed,
    required this.choghadiyaDay,
    required this.choghadiyaNight,
    required this.horas,
    required this.conventions,
    required this.provenance,
    required this.evidenceTier,
  });
}

/// Computes the muhurta windows for the civil date [year]-[month]-[day]
/// (an NPT day), defaulting to the nMiti Kathmandu anchor 27.7172 N /
/// 85.324 E.
MuhurtaDay muhurtaFor({
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final dateNpt = DateTime.utc(year, month, day);
  final nextCivil = dateNpt.add(const Duration(days: 1));
  final prevCivil = dateNpt.subtract(const Duration(days: 1));
  final sunriseNpt = _nptWallUt(sunriseJdUt(
      year: year, month: month, day: day,
      latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg));
  final sunsetNpt = _nptWallUt(sunsetJdUt(
      year: year, month: month, day: day,
      latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg));
  final nextSunriseNpt = _nptWallUt(sunriseJdUt(
      year: nextCivil.year, month: nextCivil.month, day: nextCivil.day,
      latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg));
  final previousSunsetNpt = _nptWallUt(sunsetJdUt(
      year: prevCivil.year, month: prevCivil.month, day: prevCivil.day,
      latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg));

  final dayUs = sunsetNpt.difference(sunriseNpt).inMicroseconds;
  // Night as served by the choghadiya/hora slots: this evening to the
  // next dawn.
  final nightUs = nextSunriseNpt.difference(sunsetNpt).inMicroseconds;
  // Night ending at THIS day's sunrise (previous evening): the anchor of
  // the computed Brahma muhurta, matching the publisher's per-day sense.
  final prevNightUs = sunriseNpt.difference(previousSunsetNpt).inMicroseconds;

  final weekday = dateNpt.weekday;

  MuhurtaWindow eightPart(String name, int part) {
    return MuhurtaWindow(
      name: name,
      ruleId: 'daylight-8-parts',
      beginsAtNpt:
          sunriseNpt.add(Duration(microseconds: _frac(dayUs, part - 1, 8))),
      endsAtNpt:
          sunriseNpt.add(Duration(microseconds: _frac(dayUs, part, 8))),
    );
  }

  final rahu = eightPart('Rahu Kalam', rahuKalamPartByWeekday[weekday]!);
  final yama = eightPart('Yamaganda', yamagandaPartByWeekday[weekday]!);
  final gulika = eightPart('Gulika', gulikaPartByWeekday[weekday]!);

  final abhijit = MuhurtaWindow(
    name: 'Abhijit Muhurta',
    ruleId: 'daylight-15-8th',
    beginsAtNpt:
        sunriseNpt.add(Duration(microseconds: _frac(dayUs, 7, 15))),
    endsAtNpt: sunriseNpt.add(Duration(microseconds: _frac(dayUs, 8, 15))),
  );

  final brahma = MuhurtaWindow(
    name: 'Brahma Muhurta',
    ruleId: 'night-15-14th',
    beginsAtNpt: previousSunsetNpt
        .add(Duration(microseconds: _frac(prevNightUs, 13, 15))),
    endsAtNpt: previousSunsetNpt
        .add(Duration(microseconds: _frac(prevNightUs, 14, 15))),
  );

  final brahmaFixed = MuhurtaWindow(
    name: 'Brahma Muhurta (BhaktiBharat fixed convention)',
    ruleId: 'fixed-96-48-before-sunrise',
    beginsAtNpt: sunriseNpt.subtract(const Duration(minutes: 96)),
    endsAtNpt: sunriseNpt.subtract(const Duration(minutes: 48)),
  );

  // Choghadiya: day parts from sunrise, night parts from sunset.
  final dayLord = weekdayLordByWeekday[weekday]!;
  final dayCi = choghadiyaDayCycle.indexOf(dayLord);
  final choghadiyaDay = <ChoghadiyaSlot>[
    for (var k = 0; k < 8; k++)
      ChoghadiyaSlot(
        type: _choghadiyaTypeOfLord[choghadiyaDayCycle[(dayCi + k) % 7]]!,
        lord: choghadiyaDayCycle[(dayCi + k) % 7],
        beginsAtNpt:
            sunriseNpt.add(Duration(microseconds: _frac(dayUs, k, 8))),
        endsAtNpt:
            sunriseNpt.add(Duration(microseconds: _frac(dayUs, k + 1, 8))),
      ),
  ];
  final nightFirstLord = weekdayLordByWeekday[_weekdayPlus(weekday, 3)]!;
  final nightCi = choghadiyaNightCycle.indexOf(nightFirstLord);
  final choghadiyaNight = <ChoghadiyaSlot>[
    for (var k = 0; k < 8; k++)
      ChoghadiyaSlot(
        type: _choghadiyaTypeOfLord[choghadiyaNightCycle[(nightCi + k) % 7]]!,
        lord: choghadiyaNightCycle[(nightCi + k) % 7],
        beginsAtNpt:
            sunsetNpt.add(Duration(microseconds: _frac(nightUs, k, 8))),
        endsAtNpt:
            sunsetNpt.add(Duration(microseconds: _frac(nightUs, k + 1, 8))),
      ),
  ];

  // Hora: 24 unequal slots, sunrise -> next sunrise; first = weekday lord.
  final horaCi = horaLordOrder.indexOf(dayLord);
  final horas = <HoraSlot>[
    for (var k = 0; k < 12; k++)
      HoraSlot(
        lord: horaLordOrder[(horaCi + k) % 7],
        beginsAtNpt:
            sunriseNpt.add(Duration(microseconds: _frac(dayUs, k, 12))),
        endsAtNpt:
            sunriseNpt.add(Duration(microseconds: _frac(dayUs, k + 1, 12))),
        isDaylight: true,
      ),
    for (var k = 0; k < 12; k++)
      HoraSlot(
        lord: horaLordOrder[(horaCi + 12 + k) % 7],
        beginsAtNpt:
            sunsetNpt.add(Duration(microseconds: _frac(nightUs, k, 12))),
        endsAtNpt:
            sunsetNpt.add(Duration(microseconds: _frac(nightUs, k + 1, 12))),
        isDaylight: false,
      ),
  ];

  return MuhurtaDay(
    dateNpt: dateNpt,
    sunriseNpt: sunriseNpt,
    sunsetNpt: sunsetNpt,
    nextSunriseNpt: nextSunriseNpt,
    previousSunsetNpt: previousSunsetNpt,
    rahuKalam: rahu,
    yamaganda: yama,
    gulika: gulika,
    abhijitMuhurta: abhijit,
    brahmaMuhurta: brahma,
    brahmaMuhurtaFixed: brahmaFixed,
    choghadiyaDay: choghadiyaDay,
    choghadiyaNight: choghadiyaNight,
    horas: horas,
    conventions: _muhurtaConventions,
    provenance: 'nMiti nepali_panchang engine: USNO sunrise/sunset '
        'solvers; muhurta rule tables receipt-anchored to the '
        'BhaktiBharat Nov 2026 corpus (nmiti-muhurta-receipts/1).',
    evidenceTier: 'runtime-computed from engine sunrise/sunset; rules '
        'validated against 18 publisher receipt days (Rahu/Yamaganda/'
        'Gulika within 0.9 min of the 8-part rule)',
  );
}

/// Fraction n/d of [totalUs] microseconds, exact integer division.
int _frac(int totalUs, int n, int d) => (n * totalUs) ~/ d;

/// Weekday [days] after [weekday] (DateTime.weekday numbering).
int _weekdayPlus(int weekday, int days) => ((weekday - 1 + days) % 7) + 1;

/// NPT wall clock (UTC fields) for a UT Julian Day.
DateTime _nptWallUt(double jdUt) {
  return dateTimeUtcFromJd(jdUt)
      .add(const Duration(milliseconds: nptOffsetMs));
}
