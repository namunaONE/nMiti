import 'ayanamsa.dart';
import 'limbs.dart';
import 'moonrise.dart';
import 'panchang_day.dart';

/// Festival rules layer (R6b, HYA-367; shastra vocabulary and the
/// nishita/chandrodaya conventions, HYA-417).
///
/// Festivals are data, conventions are code. A festival rule names a
/// tithi and the reference moment that decides its civil day; the
/// scanner exposes every candidate day in every convention so callers
/// (site, API, tests) can show a publisher's or the samiti's published
/// choice alongside the engine's other conventions - never silently
/// picking one.
///
/// Six day-choosing conventions, each pinned by publisher/samiti
/// receipts (see test/fixtures/festival_receipts_2083.json and
/// test/fixtures/festival_receipts_2026.json):
///   udaya     - the tithi running at sunrise. The Hamro Patro display
///               convention and the samiti's usual call (Ghatasthapana,
///               Maha Navami, Vijaya Dashami, Kag/Kukur/Gai/Mha/Bhai
///               Tika, Chhath, Janai Purnima, Teej).
///   evening   - the tithi running at the 18:00 NPT evening reference,
///               for night observances (Lakshmi Puja, Kojagrat Purnima,
///               Dhanteras). The udaya convention gives the NEXT civil
///               day; the 2083 receipts show publishers use the night.
///   firstDay  - the first civil day the tithi overlaps (Fulpati 2083:
///               Saptami began 06:10 NPT on Asoj 30, minutes after
///               sunrise, and the patros took that day; Fagu Purnima
///               2082 hills: Purnima began mid-day Mar 2 2026 and the
///               hills observed that day).
///   allDays   - every civil day the tithi overlaps (Maha Ashtami
///               2083: the samiti listed both Kartik 1 and 2 - the
///               first two-day Maha Ashtami since 2000 BS).
///   nishita   - the tithi running at the midnight ENDING the civil
///               day. The Shivaratri class: Dharma Sindhu ch. 5 has
///               'the timing should be such that Chaturdashi should be
///               till midnight'; the 2082 receipt (Falgun 3 = Feb 15
///               2026, udaya tithi Trayodashi, publishers took Feb 15)
///               pins it.
///   moonrise  - the tithi running at the day's moonrise, the
///               chandrodaya-vyapti of Dharma Sindhu ch. 5's Sankata
///               Chaturthi nirnaya ('reckoned as of Chandrodaya kaala
///               Vyapti'). Unlocked by the HYA-417 moonrise solver; no
///               battery entry yet (Sankata Chaturthi receipts are
///               pending), the convention is exposed for callers.
///
/// Completeness: every tithi lasts at least ~19.7 h while the engine's
/// reference instants (udaya, noon) recur at most ~18 h apart, so every
/// tithi run is captured as the udaya or noon element of at least one
/// scanned day - no span can be invisible to the scanner. The nishita
/// and chandrodaya day sets are direct span-membership tests against
/// the complete run [b, e), exact by construction.
///
/// Shastra vocabulary (HYA-417): every battery rule carries the
/// Sanskrit category of its day-choosing principle - udaya-vyapini,
/// pradosha/ratri-vyapini, nishita-vyapini, chandrodaya-vyapti,
/// purva-tithi-viddha, vriddhi - plus the citation it rests on. The
/// citations are translation-level and say so (honesty before
/// ornament): the condensed English rendering of Dharma Sindhu by
/// V.D.N. Rao, with the shloka-level reference marked pending until a
/// printed source is verified.

/// How a festival's civil day is chosen from its tithi.
enum FestivalConvention { udaya, evening, firstDay, allDays, nishita, moonrise }

/// Dharma Sindhu, Tithi Vrata Nirnayas - the citation backing the
/// day-choosing rules. Kashinatha Upadhyaya's 1790 digest, read through
/// V.D.N. Rao's condensed English translation (kamakoti.org, ch. 5).
/// Translation-level citation, stated as such; the shloka-level
/// reference is pending printed-source verification.
const String dharmaSindhuCh5Citation =
    'Dharma Sindhu (Kashinatha Upadhyaya, 1790), ch. 5 \'Tithi Vrata '
        'Nirnayas\'; condensed English translation by V.D.N. Rao '
        '(kamakoti.org). Translation-level citation; shloka-level '
        'reference pending printed-source verification.';

/// One festival of the battery: a tithi plus the choosing convention.
class FestivalRule {
  /// Stable identifier, also the fixture receipt key.
  final String id;

  /// English display name.
  final String nameEn;

  /// Nepali display name (Devanagari).
  final String nameNp;

  /// Tithi the festival rides on, 0..29 (0 = Shukla Pratipada,
  /// 14 = Purnima, 29 = Amavasya).
  final int tithiIndex;

  /// Convention that selects the festival's civil day(s).
  final FestivalConvention convention;

  /// Human-facing note naming the rule and the pinned evidence.
  final String note;

  /// Sanskrit category of the day-choosing principle (udaya-vyapini,
  /// pradosha/ratri-vyapini, nishita-vyapini, chandrodaya-vyapti,
  /// purva-tithi-viddha, vriddhi).
  final String? shastraCategory;

  /// Shastra citation the rule rests on (see
  /// [dharmaSindhuCh5Citation] for the shared source).
  final String? shastraCitation;

  const FestivalRule({
    required this.id,
    required this.nameEn,
    required this.nameNp,
    required this.tithiIndex,
    required this.convention,
    required this.note,
    this.shastraCategory,
    this.shastraCitation,
  });
}

const String _udayaCat =
    'udaya-vyapini - tithi prevailing at sunrise';
const String _ratriCat =
    'pradosha/ratri-vyapini - tithi prevailing in the night '
        '(18:00 reference)';
const String _viddhaCat =
    'purva-tithi-viddha - first civil day the tithi overlaps';
const String _vriddhiCat =
    'vriddhi - every civil day the tithi overlaps (two-day observance)';

/// The festival battery. Every entry's convention is pinned by a
/// publisher/samiti receipt in test/fixtures/festival_receipts_2083.json
/// or test/fixtures/festival_receipts_2026.json, which the festival
/// tests run as a permanent CI gate.
const List<FestivalRule> festivalBattery = [
  FestivalRule(
      id: 'ghatasthapana',
      nameEn: 'Ghatasthapana',
      nameNp: 'घटस्थापना',
      tithiIndex: 0,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Shukla Pratipada at udaya; opens Dashain (Asoj).'),
  FestivalRule(
      id: 'fulpati',
      nameEn: 'Fulpati',
      nameNp: 'फूलपाती',
      tithiIndex: 6,
      convention: FestivalConvention.firstDay,
      shastraCategory: _viddhaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Shukla Saptami; the samiti takes the day Saptami begins '
          '(2083: Asoj 30, minutes after sunrise - engine flags '
          'borderline).'),
  FestivalRule(
      id: 'mahaAshtami',
      nameEn: 'Maha Ashtami',
      nameNp: 'महाअष्टमी',
      tithiIndex: 7,
      convention: FestivalConvention.allDays,
      shastraCategory: _vriddhiCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Every civil day Ashtami overlaps; the samiti listed both days '
          'in 2083 (first two-day Maha Ashtami since 2000 BS).'),
  FestivalRule(
      id: 'mahaNavami',
      nameEn: 'Maha Navami',
      nameNp: 'महानवमी',
      tithiIndex: 8,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Shukla Navami at udaya.'),
  FestivalRule(
      id: 'vijayaDashami',
      nameEn: 'Vijaya Dashami',
      nameNp: 'विजया दशमी',
      tithiIndex: 9,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Shukla Dashami at udaya; the tika day.'),
  FestivalRule(
      id: 'kojagratPurnima',
      nameEn: 'Kojagrat Purnima',
      nameNp: 'कोजाग्रत पूर्णिमा',
      tithiIndex: 14,
      convention: FestivalConvention.evening,
      shastraCategory: _ratriCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Kojagrat night: Purnima running in the evening; the udaya '
          'convention gives the next day.'),
  FestivalRule(
      id: 'dhanteras',
      nameEn: 'Dhanteras',
      nameNp: 'धनतेरस',
      tithiIndex: 27,
      convention: FestivalConvention.evening,
      shastraCategory: _ratriCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Krishna Trayodashi evening; Kag Tihar follows at the next '
          'udaya.'),
  FestivalRule(
      id: 'kagTihar',
      nameEn: 'Kag Tihar',
      nameNp: 'काग तिहार',
      tithiIndex: 27,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Krishna Trayodashi at udaya.'),
  FestivalRule(
      id: 'laxmiPuja',
      nameEn: 'Lakshmi Puja',
      nameNp: 'लक्ष्मी पूजा',
      tithiIndex: 29,
      convention: FestivalConvention.evening,
      shastraCategory: _ratriCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Amavasya evening; the udaya convention gives the next day '
          '(Gai Puja).'),
  FestivalRule(
      id: 'kukurTihar',
      nameEn: 'Kukur Tihar',
      nameNp: 'कुकुर तिहार',
      tithiIndex: 28,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Krishna Chaturdashi at udaya.'),
  FestivalRule(
      id: 'gaiPuja',
      nameEn: 'Gai Puja',
      nameNp: 'गाई पूजा',
      tithiIndex: 29,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Amavasya at udaya.'),
  FestivalRule(
      id: 'mhaPuja',
      nameEn: 'Mha Puja / Govardhan Puja',
      nameNp: 'म्हःपूजा',
      tithiIndex: 0,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Shukla Pratipada at udaya; Nepal Sambat new year.'),
  FestivalRule(
      id: 'bhaiTika',
      nameEn: 'Bhai Tika',
      nameNp: 'भाइटीका',
      tithiIndex: 1,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Shukla Dwitiya at udaya.'),
  FestivalRule(
      id: 'chhath',
      nameEn: 'Chhath',
      nameNp: 'छठ पर्व',
      tithiIndex: 5,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Shukla Shashthi at udaya (evening argha day).'),
  FestivalRule(
      id: 'mahaShivaratri',
      nameEn: 'Maha Shivaratri',
      nameNp: 'महाशिवरात्रि',
      tithiIndex: 28,
      convention: FestivalConvention.nishita,
      shastraCategory:
          'nishita-vyapini - tithi prevailing at the midnight ending '
              'the civil day',
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Krishna Chaturdashi running at the midnight ending the '
          'civil day. Dharma Sindhu ch. 5 (V.D.N. Rao translation): '
          '\'On each Krishna Chaturdashi, Kamya Shiva Raatri Vrata is '
          'performed as in the case of Maha Shiva Raatri; that is the '
          'timing should be such that Chaturdashi should be till '
          'midnight.\' 2082 receipt: Falgun 3 = Feb 15 2026, udaya '
          'tithi Krishna Trayodashi (Hamro Patro) - Chaturdashi began '
          'later that day and spanned the midnight, so the nishita day '
          'is Feb 15 while the udaya convention gives Feb 16: a clean '
          'divergence receipt for the nishita class.'),
  FestivalRule(
      id: 'faguPurnima',
      nameEn: 'Fagu Purnima (hills)',
      nameNp: 'फागु पूर्णिमा',
      tithiIndex: 14,
      convention: FestivalConvention.firstDay,
      shastraCategory:
          'purva-tithi-viddha (hills); the Terai takes the udaya day',
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Hills observe the first day Purnima overlaps (2082: '
          'Falgun 18 = Mar 2 2026, udaya tithi Chaturdashi - Purnima '
          'began mid-day, Hamro Patro). Terai Holi is the next udaya '
          'day, Falgun 19 = Mar 3 (udaya Purnima; HP also notes a '
          'khanda-gras chandra grahan that day - recorded for the '
          'eclipse module). The battery rule encodes the hills '
          'convention; the udaya days stay exposed as the Terai '
          'choice.'),
  FestivalRule(
      id: 'janaiPurnima',
      nameEn: 'Janai Purnima / Raksha Bandhan',
      nameNp: 'जनै पूर्णिमा',
      tithiIndex: 14,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Shukla Purnima at udaya. 2083 receipt: Bhadra 12 = '
          'Aug 28 2026 - Purnima began Aug 27 09:24 NPT (BhaktiBharat), '
          'so the first-overlap day is Aug 27; both publishers took '
          'the udaya day Aug 28 - publishers chose udaya-vyapini over '
          'purva-viddha here, a clean divergence receipt.'),
  FestivalRule(
      id: 'teej',
      nameEn: 'Teej (Hartalika)',
      nameNp: 'तीज',
      tithiIndex: 2,
      convention: FestivalConvention.udaya,
      shastraCategory: _udayaCat,
      shastraCitation: dharmaSindhuCh5Citation,
      note: 'Shukla Tritiya at udaya. 2083 receipt: Bhadra 29 = '
          'Sep 14 2026 - Tritiya ran Sep 13 07:24 to Sep 14 07:23 NPT '
          '(BhaktiBharat), overlapping both days; publishers took the '
          'udaya day Sep 14 (Hamro Patro marks Teej with udaya '
          'Tritiya).'),
];

/// Looks up a battery rule by [id]. Throws [ArgumentError] when unknown.
FestivalRule festivalRuleById(String id) {
  final rules = festivalBattery.where((r) => r.id == id).toList();
  if (rules.length != 1) {
    throw ArgumentError('unknown festival rule id: \$id');
  }
  return rules.first;
}

/// One run of a tithi through the scanned window, with the civil days it
/// selects under every convention.
class TithiOccasion {
  /// The tithi index, 0..29.
  final int tithiIndex;

  /// NPT wall clock when the tithi began (may precede the window).
  final DateTime beginsAtNpt;

  /// NPT wall clock when the tithi ends (exclusive).
  final DateTime endsAtNpt;

  /// Days (within the window) whose sunrise falls inside the tithi.
  final List<DateTime> udayaDays;

  /// Days (within the window) whose 18:00 NPT evening reference falls
  /// inside the tithi.
  final List<DateTime> eveningDays;

  /// Days (within the window) whose midnight ending the civil day
  /// (24:00 NPT) falls inside the tithi - the nishita convention
  /// (Shivaratri class, HYA-417).
  final List<DateTime> nishitaDays;

  /// Days (within the window) whose moonrise falls inside the tithi -
  /// the chandrodaya-vyapti convention (Sankata Chaturthi class,
  /// HYA-417). Days with no moonrise cannot qualify.
  final List<DateTime> moonriseDays;

  /// Every day (within the window) whose civil interval the tithi overlaps.
  final List<DateTime> overlapDays;

  /// True when any involved day's tithi boundary lands within half an
  /// hour of a sunrise: the day-label is convention-sensitive.
  final bool borderline;

  /// True when the tithi overlaps more than one civil day.
  final bool spansMultipleDays;

  /// True when the tithi runs at no udaya in the window (kshaya-like).
  final bool skippedInUdayaChain;

  /// Engine and convention description for this value set.
  final String provenance;

  /// Evidence statement for this value set.
  final String evidenceTier;

  /// Canonical tithi name for [tithiIndex].
  String get tithi => tithiName(tithiIndex);

  const TithiOccasion({
    required this.tithiIndex,
    required this.beginsAtNpt,
    required this.endsAtNpt,
    required this.udayaDays,
    required this.eveningDays,
    required this.nishitaDays,
    required this.moonriseDays,
    required this.overlapDays,
    required this.borderline,
    required this.spansMultipleDays,
    required this.skippedInUdayaChain,
    required this.provenance,
    required this.evidenceTier,
  });
}

/// A festival resolved in the scanned window: the rule, the tithi occasion
/// and the day(s) the rule's convention selects.
class FestivalObservance {
  /// The battery rule that produced this observance.
  final FestivalRule rule;

  /// The tithi run the festival rides on.
  final TithiOccasion occasion;

  /// The civil day(s) the rule's convention selects, in order.
  final List<DateTime> chosenDays;

  /// True when [chosenDays] differ from the udaya-convention days: the
  /// festival's published date and the sunrise convention disagree, and
  /// the divergence is exposed rather than hidden.
  final bool conventionDivergence;

  const FestivalObservance({
    required this.rule,
    required this.occasion,
    required this.chosenDays,
    required this.conventionDivergence,
  });
}

/// Computes [PanchangDay]s for [start, end] padded by one day each side
/// (the padding guarantees the spans of tithis that straddle the window
/// edges are seen whole).
List<PanchangDay> _scanDays(
    DateTime start, DateTime end, double sourceDelta) {
  final first = DateTime.utc(start.year, start.month, start.day)
      .subtract(const Duration(days: 1));
  final last =
      DateTime.utc(end.year, end.month, end.day).add(const Duration(days: 1));
  final days = <PanchangDay>[];
  for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
    days.add(panchangFor(
        year: d.year, month: d.month, day: d.day, sourceDelta: sourceDelta));
  }
  return days;
}

/// Builds one [TithiOccasion] per run of tithi [tithiIndex] through the
/// scanned [days], restricted to the [start, end] window.
List<TithiOccasion> _occasions(List<PanchangDay> days, int tithiIndex,
    DateTime start, DateTime end) {
  // Spans: every tithi lasts >= ~19.7 h and the reference instants recur
  // at most ~18 h apart, so each run is the udaya or noon element of at
  // least one scanned day; dedupe by begin instant (a tithi running at
  // both udaya and noon of a day is one span).
  final spanEnds = <DateTime, DateTime>{};
  for (final day in days) {
    for (final e in [day.tithiAtUdaya, day.tithiAtNoon]) {
      if (e.index == tithiIndex) {
        spanEnds[e.beginsAtNpt] = e.endsAtNpt;
      }
    }
  }
  final begins = spanEnds.keys.toList()..sort();

  final windowStart = DateTime.utc(start.year, start.month, start.day);
  final windowEnd = DateTime.utc(end.year, end.month, end.day);

  final occasions = <TithiOccasion>[];
  for (final b in begins) {
    final e = spanEnds[b]!;
    final udayaDays = <DateTime>[];
    final eveningDays = <DateTime>[];
    final nishitaDays = <DateTime>[];
    final moonriseDays = <DateTime>[];
    final overlapDays = <DateTime>[];
    var borderline = false;
    for (final day in days) {
      final d =
          DateTime.utc(day.dateNpt.year, day.dateNpt.month, day.dateNpt.day);
      if (d.isBefore(windowStart) || d.isAfter(windowEnd)) {
        continue;
      }
      // Span-local: only days whose udaya element belongs to THIS run
      // of the tithi (beginsAtNpt == b). A tithi index recurs every
      // lunar month and a long window spans more than one run; without
      // this restriction every occasion would inherit the other run's
      // days too (the 2083 window holds two Pratipadas, two
      // Trayodashis, two Amavasyas... - CI caught exactly that).
      if (day.tithiAtUdaya.index == tithiIndex &&
          day.tithiAtUdaya.beginsAtNpt == b) {
        udayaDays.add(d);
      }
      // Evening convention: the tithi running at 18:00 NPT. It is either
      // the noon tithi still running into the evening, or the next tithi
      // that begins at the noon tithi's end (any tithi beginning at or
      // before the evening reference is still running there, since no
      // tithi is shorter than ~19.7 h). Both cases are span-local like
      // the udaya test above: the deciding element must belong to THIS
      // occasion's run (case 1: the noon element IS this run, so its
      // beginsAtNpt is b; case 2: this run begins exactly at the noon
      // element's end, so that end instant IS b).
      final noon = day.tithiAtNoon;
      final eveningRef = DateTime.utc(d.year, d.month, d.day, 18);
      final runningAtEvening =
          (noon.index == tithiIndex &&
                  noon.beginsAtNpt == b &&
                  noon.endsAtNpt.isAfter(eveningRef)) ||
              ((noon.index + 1) % 30 == tithiIndex &&
                  noon.endsAtNpt == b &&
                  !noon.endsAtNpt.isAfter(eveningRef));
      if (runningAtEvening) {
        eveningDays.add(d);
      }
      // Nishita convention (HYA-417): the tithi running at the midnight
      // ENDING the civil day. The run [b, e) is complete from the
      // deduped elements, so direct span membership is exact - no
      // element indirection is needed (and none would be sound: the
      // noon element's end may precede the midnight by hours without
      // the next element belonging to this run's window day).
      final nishitaRef =
          DateTime.utc(d.year, d.month, d.day).add(const Duration(days: 1));
      if (!nishitaRef.isBefore(b) && nishitaRef.isBefore(e)) {
        nishitaDays.add(d);
      }
      // Chandrodaya convention (HYA-417): the tithi running at the
      // day's moonrise - Dharma Sindhu ch. 5's Sankata Chaturthi rule
      // ('reckoned as of Chandrodaya kaala Vyapti'). Direct span
      // membership against the live moonrise; days with no moonrise
      // (roughly one per lunar month) cannot qualify.
      final moonriseRef = moonriseNpt(year: d.year, month: d.month, day: d.day);
      if (moonriseRef != null &&
          !moonriseRef.isBefore(b) &&
          moonriseRef.isBefore(e)) {
        moonriseDays.add(d);
      }
      if (b.isBefore(d.add(const Duration(days: 1))) && e.isAfter(d)) {
        overlapDays.add(d);
      }
      if (day.tithiBorderline &&
          (udayaDays.contains(d) ||
              eveningDays.contains(d) ||
              overlapDays.contains(d) ||
              nishitaDays.contains(d) ||
              moonriseDays.contains(d))) {
        borderline = true;
      }
    }
    occasions.add(TithiOccasion(
      tithiIndex: tithiIndex,
      beginsAtNpt: b,
      endsAtNpt: e,
      udayaDays: udayaDays,
      eveningDays: eveningDays,
      nishitaDays: nishitaDays,
      moonriseDays: moonriseDays,
      overlapDays: overlapDays,
      borderline: borderline,
      spansMultipleDays: overlapDays.length > 1,
      skippedInUdayaChain: udayaDays.isEmpty,
      provenance: 'nMiti nepali_panchang festival_rules on the runtime '
          'lunar engine (60-term Meeus Ch.47 moon, VSOP87D sun, '
          'Espenak-Meeus Delta T, HYA-417 Meeus 15.1 moonrise); tithi '
          'span and udaya/evening/nishita/chandrodaya/overlap days '
          'computed, all conventions exposed.',
      evidenceTier: 'runtime-computed; festival days verified against '
          'the 2083 and 2026 festival receipt corpora (Hamro Patro '
          'labels, BhaktiBharat transitions and Nepal Panchang Nirnayak '
          'Samiti adjudications, '
          'test/fixtures/festival_receipts_2083.json, '
          'test/fixtures/festival_receipts_2026.json)',
    ));
  }
  return occasions;
}

/// One occasion per run of tithi [tithiIndex] through the NPT civil window
/// [start, end] (inclusive). See the library docs for the conventions.
List<TithiOccasion> tithiOccasions({
  required int tithiIndex,
  required DateTime start,
  required DateTime end,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  return _occasions(
      _scanDays(start, end, sourceDelta), tithiIndex, start, end);
}

/// Resolves every battery rule (or [rules]) over [start, end]: one
/// [FestivalObservance] per occasion of each rule's tithi. Days on which
/// the chosen convention and the udaya convention disagree carry
/// [FestivalObservance.conventionDivergence].
List<FestivalObservance> scanFestivals({
  required DateTime start,
  required DateTime end,
  Iterable<FestivalRule>? rules,
  double sourceDelta = ayanamsaDeltaBhaktiBharat,
}) {
  final selected = rules?.toList() ?? festivalBattery;
  final days = _scanDays(start, end, sourceDelta);
  final byIndex = <int, List<FestivalRule>>{};
  for (final r in selected) {
    byIndex.putIfAbsent(r.tithiIndex, () => []).add(r);
  }
  final out = <FestivalObservance>[];
  byIndex.forEach((index, indexRules) {
    for (final occasion in _occasions(days, index, start, end)) {
      for (final rule in indexRules) {
        out.add(_resolve(rule, occasion));
      }
    }
  });
  out.sort((a, b) {
    final ac = a.chosenDays.isEmpty
        ? a.occasion.beginsAtNpt
        : a.chosenDays.first;
    final bc = b.chosenDays.isEmpty
        ? b.occasion.beginsAtNpt
        : b.chosenDays.first;
    return ac.compareTo(bc);
  });
  return out;
}

FestivalObservance _resolve(FestivalRule rule, TithiOccasion occasion) {
  var chosen = <DateTime>[];
  switch (rule.convention) {
    case FestivalConvention.udaya:
      chosen = occasion.udayaDays;
      break;
    case FestivalConvention.evening:
      chosen = occasion.eveningDays;
      break;
    case FestivalConvention.firstDay:
      chosen = occasion.overlapDays.isEmpty
          ? <DateTime>[]
          : [occasion.overlapDays.first];
      break;
    case FestivalConvention.allDays:
      chosen = occasion.overlapDays;
      break;
    case FestivalConvention.nishita:
      chosen = occasion.nishitaDays;
      break;
    case FestivalConvention.moonrise:
      chosen = occasion.moonriseDays;
      break;
  }
  var divergence = chosen.length != occasion.udayaDays.length;
  if (!divergence) {
    for (var i = 0; i < chosen.length; i++) {
      if (chosen[i] != occasion.udayaDays[i]) {
        divergence = true;
      }
    }
  }
  return FestivalObservance(
    rule: rule,
    occasion: occasion,
    chosenDays: chosen,
    conventionDivergence: divergence,
  );
}
