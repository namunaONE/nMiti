import 'ayanamsa.dart';
import 'limbs.dart';
import 'muhurta.dart';
import 'panchang_day.dart';

/// R10.4 saait layer (HYA-441 item 5): the auspicious-date finders.
///
/// Two evidence kinds, never conflated:
///
/// 1. Traditional-fixed ceremony day lists - the katigate BS 2083 sahit
///    pages (vivah, bratabandha, pasni, griha aramba, griha pravesh,
///    vyaparik, plus the dhanyachhedan/hom/rudri events block), frozen
///    in the receipt corpus test/fixtures/saait_receipts_2083.json
///    (schema nmiti-saait-receipts/1, crawl 2026-11-10). The lists are
///    the publisher's published-or-estimated traditional lists - served
///    as named evidence, never recomputed as engine truth, and never
///    silently extended: griha aramba serves only the event-anchored
///    Mangsir days because its remaining digit strings fit multiple
///    months (recorded in the fixture, not guessed).
///
/// 2. In-day windows and yogas - runtime-computed from the shipped
///    layers: Abhijit, the good (Amrut/Shubh/Labh) choghadiya parts and
///    the auspicious (Moon/Mercury/Jupiter/Venus) horas from the L4
///    muhurta layer; Sarvartha Siddhi and Amrit Siddhi from the L3
///    panchang udaya elements (weekday x the Moon's nakshatra at
///    sunrise, the classical Muhurta Chintamani/Nirnaya Sindhu table).
///
/// Honest absences, stated not hidden: the classical SSY overrides
/// (Rahu Kaal suspension, Bhadra/Vishti karana, Panchak reduction,
/// eclipse) are authority-dependent and NOT applied. Jupiter/Venus
/// combustion (asta) closures are not applied by this layer either -
/// the shipped graha engine (Wave 1, HYA-450) serves the provisional
/// classical combustion limits, so callers can flag asta seasons
/// (exposed, never filtered) while publisher closure notes are
/// carried verbatim.
/// The Amrit Dec 18 2026 convention collision (a window that opens
/// mid-run under the publisher's convention) is recorded in the fixture
/// and never absorbed: this layer serves the at-sunrise convention only.

/// The nine ceremony types served by the saait layer.
enum SaaitCeremony {
  vivah,
  bratabandha,
  pasni,
  grihaAramba,
  grihaPravesh,
  vyaparik,
  dhanyachhedan,
  hom,
  rudri,
}

/// One traditional-fixed ceremony day, exactly as published: BS date,
/// AD date and the publisher's tithi label. Evidence, not engine output.
class SaaitFixedDay {
  /// BS month number, 1 Baisakh .. 12 Chaitra.
  final int bsMonth;

  /// BS day of month.
  final int bsDay;

  /// The civil (AD) date parts, Nepal time; the day materializes as
  /// DateTime.utc(adYear, adMonth, adDay) via [dateNpt]. The parts are
  /// stored because DateTime's constructors are not const, and the
  /// profile tables are compile-time constants.
  final int adYear;
  final int adMonth;
  final int adDay;

  /// The tithi label printed by the publisher (bare name, no paksha).
  final String tithiLabel;

  const SaaitFixedDay(this.bsMonth, this.bsDay, this.adYear, this.adMonth,
      this.adDay, this.tithiLabel);

  /// The civil (AD) day, Nepal time, as DateTime.utc(y, m, d).
  DateTime get dateNpt => DateTime.utc(adYear, adMonth, adDay);
}

/// A ceremony's BS 2083 traditional-fixed profile: publisher metadata
/// plus the served day list (only receipt-certain days; ambiguous raw
/// digit strings stay unserved, retained in the fixture).
class SaaitProfile {
  final SaaitCeremony ceremony;
  final String displayName;
  final int bsYear;

  /// The publisher's claimed full-year count; -1 = not claimed on a
  /// dedicated page (the merged-block singletons).
  final int claimedCount;

  /// The page the list was crawled from.
  final String sourcePage;

  /// Publisher closure note (e.g. the Chaturmas wedding closure), or
  /// null when the page states none.
  final String? closureNote;

  /// Honesty caveats carried with the data.
  final List<String> caveats;

  final List<SaaitFixedDay> days;

  const SaaitProfile({
    required this.ceremony,
    required this.displayName,
    required this.bsYear,
    required this.claimedCount,
    required this.sourcePage,
    required this.closureNote,
    required this.caveats,
    required this.days,
  });
}

/// The BS 2083 sahit profiles, generated from the same parse as the
/// frozen fixture test/fixtures/saait_receipts_2083.json (crawl
/// 2026-11-10); the equality is CI-gated. Claimed counts are the
/// publisher's full-year claims (41/13/2/9/36/44 for the six paged
/// ceremonies), served counts cover only the upcoming window the pages
/// list (26/9/1/3/14/26) plus the three merged-block singletons.
const Map<SaaitCeremony, SaaitProfile> saaitProfiles2083 = {
  SaaitCeremony.vivah: const SaaitProfile(
    ceremony: SaaitCeremony.vivah,
    displayName: 'Vivah (wedding)',
    bsYear: 2083,
    claimedCount: 41,
    sourcePage: 'https://katigate.com/en/sahit/vivah',
    closureNote: "These months fall in Chaturmas, the four months from Harishayani Ekadashi to Haribodhini Ekadashi. By tradition, weddings are not held in this period.",
    caveats: const <String>[],
    days: const [
      SaaitFixedDay(8, 9, 2026, 11, 25, 'Pratipada'),
      SaaitFixedDay(8, 10, 2026, 11, 26, 'Dwitiya'),
      SaaitFixedDay(8, 16, 2026, 12, 2, 'Navami'),
      SaaitFixedDay(8, 17, 2026, 12, 3, 'Dashami'),
      SaaitFixedDay(8, 19, 2026, 12, 5, 'Dwadashi'),
      SaaitFixedDay(8, 24, 2026, 12, 10, 'Pratipada'),
      SaaitFixedDay(8, 25, 2026, 12, 11, 'Dwitiya'),
      SaaitFixedDay(8, 26, 2026, 12, 12, 'Tritiya'),
      SaaitFixedDay(10, 4, 2027, 1, 18, 'Dashami'),
      SaaitFixedDay(10, 12, 2027, 1, 26, 'Chaturthi'),
      SaaitFixedDay(10, 15, 2027, 1, 29, 'Ashtami'),
      SaaitFixedDay(10, 19, 2027, 2, 2, 'Ekadashi'),
      SaaitFixedDay(10, 20, 2027, 2, 3, 'Dwadashi'),
      SaaitFixedDay(10, 27, 2027, 2, 10, 'Chaturthi'),
      SaaitFixedDay(11, 3, 2027, 2, 15, 'Navami'),
      SaaitFixedDay(11, 4, 2027, 2, 16, 'Dashami'),
      SaaitFixedDay(11, 11, 2027, 2, 23, 'Tritiya'),
      SaaitFixedDay(11, 12, 2027, 2, 24, 'Chaturthi'),
      SaaitFixedDay(11, 15, 2027, 2, 27, 'Saptami'),
      SaaitFixedDay(11, 16, 2027, 2, 28, 'Ashtami'),
      SaaitFixedDay(11, 17, 2027, 3, 1, 'Navami'),
      SaaitFixedDay(11, 18, 2027, 3, 2, 'Dashami'),
      SaaitFixedDay(11, 20, 2027, 3, 4, 'Ekadashi'),
      SaaitFixedDay(11, 25, 2027, 3, 9, 'Pratipada'),
      SaaitFixedDay(11, 26, 2027, 3, 10, 'Dwitiya'),
      SaaitFixedDay(11, 30, 2027, 3, 14, 'Shashthi'),
    ],
  ),
  SaaitCeremony.bratabandha: const SaaitProfile(
    ceremony: SaaitCeremony.bratabandha,
    displayName: 'Bratabandha',
    bsYear: 2083,
    claimedCount: 13,
    sourcePage: 'https://katigate.com/en/sahit/bratabandha',
    closureNote: null,
    caveats: const <String>[],
    days: const [
      SaaitFixedDay(10, 25, 2027, 2, 8, 'Dwitiya'),
      SaaitFixedDay(11, 10, 2027, 2, 22, 'Dwitiya'),
      SaaitFixedDay(11, 13, 2027, 2, 25, 'Panchami'),
      SaaitFixedDay(11, 26, 2027, 3, 10, 'Dwitiya'),
      SaaitFixedDay(12, 3, 2027, 3, 17, 'Navami'),
      SaaitFixedDay(12, 4, 2027, 3, 18, 'Ekadashi'),
      SaaitFixedDay(12, 10, 2027, 3, 24, 'Dwitiya'),
      SaaitFixedDay(12, 25, 2027, 4, 8, 'Dwitiya'),
      SaaitFixedDay(12, 28, 2027, 4, 11, 'Panchami'),
    ],
  ),
  SaaitCeremony.grihaPravesh: const SaaitProfile(
    ceremony: SaaitCeremony.grihaPravesh,
    displayName: 'Griha Pravesh (housewarming)',
    bsYear: 2083,
    claimedCount: 2,
    sourcePage: 'https://katigate.com/en/sahit/griha-pravesh',
    closureNote: null,
    caveats: const <String>[],
    days: const [
      SaaitFixedDay(11, 20, 2027, 3, 4, 'Ekadashi'),
    ],
  ),
  SaaitCeremony.grihaAramba: const SaaitProfile(
    ceremony: SaaitCeremony.grihaAramba,
    displayName: 'Griha Aramba (breaking ground)',
    bsYear: 2083,
    claimedCount: 9,
    sourcePage: 'https://katigate.com/en/sahit/griha-aramba',
    closureNote: "These months fall in Chaturmas, when tradition avoids starting major work. They are also the wettest months of the year.",
    caveats: const <String>[
      "months beyond Mangsir are ambiguous (4 event-consistent of 5 month assignments); the unserved raw strings are retained in test/fixtures/saait_receipts_2083.json",
    ],
    days: const [
      SaaitFixedDay(8, 5, 2026, 11, 21, 'Ekadashi'),
      SaaitFixedDay(8, 9, 2026, 11, 25, 'Pratipada'),
      SaaitFixedDay(8, 10, 2026, 11, 26, 'Dwitiya'),
    ],
  ),
  SaaitCeremony.pasni: const SaaitProfile(
    ceremony: SaaitCeremony.pasni,
    displayName: 'Pasni (rice feeding)',
    bsYear: 2083,
    claimedCount: 36,
    sourcePage: 'https://katigate.com/en/sahit/pasni',
    closureNote: null,
    caveats: const <String>[],
    days: const [
      SaaitFixedDay(7, 30, 2026, 11, 16, 'Saptami'),
      SaaitFixedDay(8, 10, 2026, 11, 26, 'Dwitiya'),
      SaaitFixedDay(8, 17, 2026, 12, 3, 'Dashami'),
      SaaitFixedDay(9, 1, 2026, 12, 16, 'Saptami'),
      SaaitFixedDay(9, 15, 2026, 12, 30, 'Saptami'),
      SaaitFixedDay(10, 15, 2027, 1, 29, 'Ashtami'),
      SaaitFixedDay(10, 25, 2027, 2, 8, 'Dwitiya'),
      SaaitFixedDay(11, 7, 2027, 2, 19, 'Trayodashi'),
      SaaitFixedDay(11, 13, 2027, 2, 25, 'Panchami'),
      SaaitFixedDay(11, 26, 2027, 3, 10, 'Dwitiya'),
      SaaitFixedDay(12, 3, 2027, 3, 17, 'Navami'),
      SaaitFixedDay(12, 10, 2027, 3, 24, 'Dwitiya'),
      SaaitFixedDay(12, 18, 2027, 4, 1, 'Dashami'),
      SaaitFixedDay(12, 25, 2027, 4, 8, 'Dwitiya'),
    ],
  ),
  SaaitCeremony.vyaparik: const SaaitProfile(
    ceremony: SaaitCeremony.vyaparik,
    displayName: 'Vyaparik (business)',
    bsYear: 2083,
    claimedCount: 44,
    sourcePage: 'https://katigate.com/en/sahit/vyaparik',
    closureNote: null,
    caveats: const <String>[],
    days: const [
      SaaitFixedDay(7, 29, 2026, 11, 15, 'Shashthi'),
      SaaitFixedDay(8, 5, 2026, 11, 21, 'Ekadashi'),
      SaaitFixedDay(8, 6, 2026, 11, 22, 'Trayodashi'),
      SaaitFixedDay(8, 9, 2026, 11, 25, 'Pratipada'),
      SaaitFixedDay(8, 10, 2026, 11, 26, 'Dwitiya'),
      SaaitFixedDay(8, 13, 2026, 11, 29, 'Shashthi'),
      SaaitFixedDay(8, 17, 2026, 12, 3, 'Dashami'),
      SaaitFixedDay(8, 19, 2026, 12, 5, 'Dwadashi'),
      SaaitFixedDay(8, 26, 2026, 12, 12, 'Tritiya'),
      SaaitFixedDay(9, 4, 2026, 12, 19, 'Dashami'),
      SaaitFixedDay(9, 11, 2026, 12, 26, 'Tritiya'),
      SaaitFixedDay(9, 15, 2026, 12, 30, 'Saptami'),
      SaaitFixedDay(9, 25, 2027, 1, 9, 'Dwitiya'),
      SaaitFixedDay(10, 9, 2027, 1, 23, 'Pratipada'),
      SaaitFixedDay(10, 14, 2027, 1, 28, 'Saptami'),
      SaaitFixedDay(10, 29, 2027, 2, 12, 'Shashthi'),
      SaaitFixedDay(11, 7, 2027, 2, 19, 'Trayodashi'),
      SaaitFixedDay(11, 13, 2027, 2, 25, 'Panchami'),
      SaaitFixedDay(11, 20, 2027, 3, 4, 'Ekadashi'),
      SaaitFixedDay(11, 26, 2027, 3, 10, 'Dwitiya'),
      SaaitFixedDay(12, 4, 2027, 3, 18, 'Ekadashi'),
      SaaitFixedDay(12, 10, 2027, 3, 24, 'Dwitiya'),
      SaaitFixedDay(12, 18, 2027, 4, 1, 'Dashami'),
      SaaitFixedDay(12, 25, 2027, 4, 8, 'Dwitiya'),
      SaaitFixedDay(12, 28, 2027, 4, 11, 'Panchami'),
      SaaitFixedDay(12, 29, 2027, 4, 12, 'Shashthi'),
    ],
  ),
  SaaitCeremony.dhanyachhedan: const SaaitProfile(
    ceremony: SaaitCeremony.dhanyachhedan,
    displayName: 'Dhanyachhedan (harvest offering)',
    bsYear: 2083,
    claimedCount: -1,
    sourcePage: 'https://katigate.com/en/sahit',
    closureNote: null,
    caveats: const <String>[
      'single receipt day from the sahit home events block (Kartik 26 2083); the ceremony likely recurs in the merged table but is not month-attributed in text extraction',
    ],
    days: const [
      SaaitFixedDay(7, 26, 2026, 11, 12, 'Tritiya'),
    ],
  ),
  SaaitCeremony.hom: const SaaitProfile(
    ceremony: SaaitCeremony.hom,
    displayName: 'Hom (fire ritual)',
    bsYear: 2083,
    claimedCount: -1,
    sourcePage: 'https://katigate.com/en/sahit',
    closureNote: null,
    caveats: const <String>[
      'single receipt day from the sahit home events block (Kartik 27 2083); the ceremony likely recurs in the merged table but is not month-attributed in text extraction',
    ],
    days: const [
      SaaitFixedDay(7, 27, 2026, 11, 13, 'Chaturthi'),
    ],
  ),
  SaaitCeremony.rudri: const SaaitProfile(
    ceremony: SaaitCeremony.rudri,
    displayName: 'Rudri (Rudra recitation)',
    bsYear: 2083,
    claimedCount: -1,
    sourcePage: 'https://katigate.com/en/sahit',
    closureNote: null,
    caveats: const <String>[
      'single receipt day from the sahit home events block (Kartik 28 2083); the ceremony likely recurs in the merged table but is not month-attributed in text extraction',
    ],
    days: const [
      SaaitFixedDay(7, 28, 2026, 11, 14, 'Panchami'),
    ],
  ),

};

/// Sarvartha Siddhi vara-nakshatra table (classical Muhurta Chintamani /
/// Nirnaya Sindhu, via the dekhopanchang table frozen in the fixture).
/// Nakshatra INDICES keyed by DateTime.weekday (1 Monday .. 7 Sunday):
/// Sunday [Ashwini, Pushya, Uttara Phalguni, Hasta, Mula, Uttara
/// Ashadha, Uttara Bhadrapada], Monday [Rohini, Mrigashira, Pushya,
/// Hasta, Anuradha, Shravana], Tuesday [Ashwini, Krittika, Uttara
/// Phalguni, Uttara Ashadha, Uttara Bhadrapada], Wednesday [Rohini,
/// Mrigashira, Hasta, Anuradha, Jyeshtha, Revati], Thursday = Friday
/// [Ashwini, Punarvasu, Pushya, Anuradha, Shravana, Revati], Saturday
/// [Rohini, Swati, Shravana, Revati].
const Map<int, List<int>> sarvarthaSiddhiNakshatrasByWeekday = {
  DateTime.monday: [3, 4, 7, 12, 16, 21],
  DateTime.tuesday: [0, 2, 11, 20, 25],
  DateTime.wednesday: [3, 4, 12, 16, 17, 26],
  DateTime.thursday: [0, 6, 7, 16, 21, 26],
  DateTime.friday: [0, 6, 7, 16, 21, 26],
  DateTime.saturday: [3, 14, 21, 26],
  DateTime.sunday: [0, 7, 11, 12, 18, 20, 25],
};

/// Amrit Siddhi: exactly one nakshatra per weekday - Sunday Hasta,
/// Monday Mrigashira, Tuesday Ashwini, Wednesday Anuradha, Thursday
/// Pushya, Friday Revati, Saturday Rohini (indices into
/// [nakshatraNames]).
const Map<int, int> amritSiddhiNakshatraByWeekday = {
  DateTime.monday: 4,
  DateTime.tuesday: 0,
  DateTime.wednesday: 16,
  DateTime.thursday: 7,
  DateTime.friday: 26,
  DateTime.saturday: 3,
  DateTime.sunday: 12,
};

/// The SSY qualifying nakshatra names for a DateTime.weekday, for
/// display and honesty pages.
List<String> sarvarthaSiddhiNames(int weekday) => [
      for (final i in sarvarthaSiddhiNakshatrasByWeekday[weekday]!)
        nakshatraNames[i],
    ];

/// The saait layer's conventions, exposed for the site/API honesty
/// pages. Stated, never silently resolved.
const Map<String, String> saaitConventions = {
  'dayLists': 'Traditional-fixed ceremony day lists (katigate BS 2083 '
      'sahit pages; receipt corpus test/fixtures/saait_receipts_2083.json, '
      'schema nmiti-saait-receipts/1) are served as named evidence and '
      'never recomputed as truth. In-day windows are runtime-computed '
      'from the shipped L4 muhurta layer.',
  'ssy': 'Sarvartha Siddhi and Amrit Siddhi = weekday x the Moon\'s '
      'nakshatra at sunrise (udaya); window = sunrise to the end of the '
      'qualifying nakshatra (classical Muhurta Chintamani/Nirnaya '
      'Sindhu). A window that opens mid-run under another publisher\'s '
      'convention (hinducalendar.app Dec 18 2026, Revati from 16:09 IST) '
      'is a recorded collision, not applied.',
  'ssyOverrides': 'The classical overrides - Rahu Kaal suspension, '
      'Bhadra (Vishti) karana, Panchak reduction, eclipse - are '
      'authority-dependent and documented here, NOT applied.',
  'windows': 'Abhijit (the 8th of the 15 daylight muhurtas); good '
      'choghadiya = the Amrut, Shubh and Labh parts, day and night; '
      'auspicious horas = the Moon, Mercury, Jupiter and Venus lord '
      'horas. A composition of the receipt-anchored L4 recipes, no new '
      'rules.',
  'guruShukraAsta': 'Jupiter/Venus combustion (asta) closures are NOT '
      'applied by the saait engine; the graha engine (Wave 1, HYA-450) '
      'serves the provisional classical combustion limits (Jupiter 11, '
      'Venus 10 deg) so callers can flag asta seasons - exposed, never '
      'filtered. Publisher closure notes (e.g. the Chaturmas wedding '
      'closure) are carried verbatim.',
  'location': 'Day lists are Nepal civil days (NPT). Windows and yogas '
      'honour the given latitude/longitude (default Kathmandu): the '
      'udaya convention is location-honouring, so a tithi or nakshatra '
      'can be kshaya at one city and not another.',
};

/// One Sarvartha (or Amrit) Siddhi Yoga occurrence, at-sunrise
/// convention.
class SarvarthaSiddhi {
  /// The civil day the yoga fires on.
  final DateTime dateNpt;

  /// True iff the pair is also the weekday's single Amrit Siddhi pair.
  final bool amrit;

  /// The qualifying nakshatra's canonical name.
  final String nakshatraName;

  /// The yoga window: the day's sunrise.
  final DateTime beginsAtNpt;

  /// The end of the qualifying nakshatra.
  final DateTime endsAtNpt;

  const SarvarthaSiddhi({
    required this.dateNpt,
    required this.amrit,
    required this.nakshatraName,
    required this.beginsAtNpt,
    required this.endsAtNpt,
  });
}

/// Sarvartha Siddhi on one civil day: fires iff the Moon's nakshatra AT
/// SUNRISE is in the weekday's list; [SarvarthaSiddhi.amrit] is true iff
/// it is also the weekday's single Amrit pair. Window: sunrise to the
/// end of the qualifying nakshatra. The classical overrides (Rahu Kaal,
/// Bhadra karana, Panchak, eclipse) are documented in
/// [saaitConventions] and NOT applied.
SarvarthaSiddhi? sarvarthaSiddhiOn({
  required int year,
  required int month,
  required int day,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  final p = panchangFor(
      year: year, month: month, day: day, sourceDelta: sourceDelta);
  final weekday = DateTime.utc(year, month, day).weekday;
  final nak = p.nakshatraAtUdaya;
  if (!sarvarthaSiddhiNakshatrasByWeekday[weekday]!.contains(nak.index)) {
    return null;
  }
  return SarvarthaSiddhi(
    dateNpt: DateTime.utc(year, month, day),
    amrit: amritSiddhiNakshatraByWeekday[weekday] == nak.index,
    nakshatraName: nak.name,
    beginsAtNpt: p.sunriseNpt,
    endsAtNpt: nak.endsAtNpt,
  );
}

/// Every Sarvartha Siddhi occurrence whose at-sunrise day falls in
/// [startNpt, endNpt] (inclusive, civil days).
List<SarvarthaSiddhi> sarvarthaSiddhiBetween(
  DateTime startNpt,
  DateTime endNpt, {
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  final out = <SarvarthaSiddhi>[];
  for (var d = DateTime.utc(startNpt.year, startNpt.month, startNpt.day);
      !d.isAfter(DateTime.utc(endNpt.year, endNpt.month, endNpt.day));
      d = d.add(const Duration(days: 1))) {
    final s = sarvarthaSiddhiOn(
        year: d.year, month: d.month, day: d.day, sourceDelta: sourceDelta);
    if (s != null) out.add(s);
  }
  return out;
}

/// The in-day auspicious windows of a saait day, composed from the L4
/// muhurta layer (no new rules).
class SaaitWindows {
  /// The Abhijit muhurta (the 8th of the 15 daylight muhurtas).
  final MuhurtaWindow abhijit;

  /// The good choghadiya parts (Amrut, Shubh, Labh), day then night.
  final List<ChoghadiyaSlot> goodChoghadiya;

  /// The auspicious horas (Moon, Mercury, Jupiter, Venus lords).
  final List<HoraSlot> auspiciousHoras;

  const SaaitWindows({
    required this.abhijit,
    required this.goodChoghadiya,
    required this.auspiciousHoras,
  });
}

const Set<String> _goodChoghadiyaTypes = {'Amrut', 'Shubh', 'Labh'};
const Set<String> _auspiciousHoraLords = {'Moon', 'Mercury', 'Jupiter', 'Venus'};

/// Composes a saait day's windows from [muhurtaFor].
SaaitWindows saaitWindowsFor({
  required int year,
  required int month,
  required int day,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final m = muhurtaFor(
      year: year, month: month, day: day,
      latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg);
  return SaaitWindows(
    abhijit: m.abhijitMuhurta,
    goodChoghadiya: [
      ...m.choghadiyaDay.where((s) => _goodChoghadiyaTypes.contains(s.type)),
      ...m.choghadiyaNight.where((s) => _goodChoghadiyaTypes.contains(s.type)),
    ],
    auspiciousHoras:
        m.horas.where((h) => _auspiciousHoraLords.contains(h.lord)).toList(),
  );
}

/// One saait day fully composed: the traditional-fixed day (evidence)
/// plus its runtime-computed windows, yoga and engine honesty flags.
class SaaitDay {
  /// The ceremony profile the day belongs to.
  final SaaitProfile profile;

  /// The traditional-fixed day (publisher evidence).
  final SaaitFixedDay fixed;

  /// Sarvartha/Amrit Siddhi on this day, or null when it does not fire.
  final SarvarthaSiddhi? sarvarthaSiddhi;

  /// The in-day auspicious windows (Abhijit, good choghadiya, auspicious
  /// horas).
  final SaaitWindows windows;

  /// The engine's udaya tithi (canonical name, paksha-prefixed).
  final String tithiAtUdaya;

  /// Knife-edge: a tithi ends within half an hour of this or the next
  /// sunrise - the day label is convention-sensitive.
  final bool tithiBorderline;

  /// The same tithi runs at two consecutive udayas.
  final bool tithiVriddhi;

  /// A tithi ends between two udayas without running at either.
  final bool tithiKshaya;

  /// Engine and ayanamsa provenance of the computed parts.
  final String provenance;

  /// Evidence statement for the composed day.
  final String evidenceTier;

  const SaaitDay({
    required this.profile,
    required this.fixed,
    required this.sarvarthaSiddhi,
    required this.windows,
    required this.tithiAtUdaya,
    required this.tithiBorderline,
    required this.tithiVriddhi,
    required this.tithiKshaya,
    required this.provenance,
    required this.evidenceTier,
  });
}

/// Composes one traditional-fixed day into a full [SaaitDay]. The fixed
/// day is publisher evidence; everything computed comes from the
/// shipped L3/L4 layers at [latitudeDeg]/[longitudeDeg] (default
/// Kathmandu).
SaaitDay saaitDayFor(
  SaaitFixedDay fixed,
  SaaitProfile profile, {
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final d = fixed.dateNpt;
  final p = panchangFor(
      year: d.year, month: d.month, day: d.day, sourceDelta: sourceDelta);
  return SaaitDay(
    profile: profile,
    fixed: fixed,
    sarvarthaSiddhi: sarvarthaSiddhiOn(
        year: d.year, month: d.month, day: d.day, sourceDelta: sourceDelta),
    windows: saaitWindowsFor(
        year: d.year, month: d.month, day: d.day,
        latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg),
    tithiAtUdaya: p.tithiAtUdaya.name,
    tithiBorderline: p.tithiBorderline,
    tithiVriddhi: p.tithiVriddhi,
    tithiKshaya: p.tithiKshaya,
    provenance: p.provenance,
    evidenceTier: 'traditional-fixed day list (receipt corpus '
        'nmiti-saait-receipts/1, crawl 2026-11-10) + runtime-computed '
        'in-day windows',
  );
}

/// A ceremony's served days whose civil date falls in
/// [startNpt, endNpt] (inclusive), composed and date-sorted.
List<SaaitDay> saaitDaysBetween(
  SaaitCeremony ceremony,
  DateTime startNpt,
  DateTime endNpt, {
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final profile = saaitProfiles2083[ceremony]!;
  final s = DateTime.utc(startNpt.year, startNpt.month, startNpt.day);
  final e = DateTime.utc(endNpt.year, endNpt.month, endNpt.day);
  return [
    for (final d in profile.days)
      if (!d.dateNpt.isBefore(s) && !d.dateNpt.isAfter(e))
        saaitDayFor(d, profile,
            sourceDelta: sourceDelta,
            latitudeDeg: latitudeDeg,
            longitudeDeg: longitudeDeg),
  ];
}

/// All ceremonies' served days in the range, merged and sorted by date
/// (then by ceremony order within a date).
List<SaaitDay> saaitAllDaysBetween(
  DateTime startNpt,
  DateTime endNpt, {
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
  double latitudeDeg = 27.7172,
  double longitudeDeg = 85.324,
}) {
  final out = <SaaitDay>[];
  for (final c in SaaitCeremony.values) {
    out.addAll(saaitDaysBetween(c, startNpt, endNpt,
        sourceDelta: sourceDelta,
        latitudeDeg: latitudeDeg,
        longitudeDeg: longitudeDeg));
  }
  out.sort((a, b) {
    final byDate = a.fixed.dateNpt.compareTo(b.fixed.dateNpt);
    if (byDate != 0) return byDate;
    return a.profile.ceremony.index.compareTo(b.profile.ceremony.index);
  });
  return out;
}
