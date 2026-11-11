part of 'build_site.dart';

/// The next-festival horizon of the today.json festivals block (days).
const int _festivalWindowDays = 45;

/// ISO dates of an occasion's udaya-convention days, comma-joined.
String _udayaList(FestivalObservance o) =>
    [for (final d in o.occasion.udayaDays) _iso(d)].join(', ');

/// The divergence cell of the year table: exposes the udaya-convention
/// alternate, including the kshaya case where no udaya day exists.
String _divCell(FestivalObservance o) {
  if (!o.conventionDivergence) return 'no';
  if (o.occasion.udayaDays.isEmpty) {
    return 'yes - the tithi runs at no sunrise (kshaya); the first-' +
        'overlap day is taken';
  }
  return 'yes - udaya would give ' + _udayaList(o);
}

/// One festival observance as a JSON object body. Every key is always
/// emitted so the site-contract markers stay date-stable on festival
/// days and quiet days alike.
String _festivalJson(String ind, FestivalObservance o, BsCalendar full) {
  final rule = o.rule;
  final occ = o.occasion;
  String isoNpt(DateTime t) =>
      '${_iso(t)}T${_skTwo(t.hour)}:${_skTwo(t.minute)}:00+05:45';
  final adDates = [for (final d in o.chosenDays) '"${_iso(d)}"'].join(', ');
  final udayaDates =
      [for (final d in occ.udayaDays) '"${_iso(d)}"'].join(', ');
  final bs = full.fromGregorian(o.chosenDays.first);
  final bsEn = '${bsMonthNameEn(bs.month)} ${bs.day}, ${bs.year} BS';
  final bsNp =
      '${bsMonthNameNp(bs.month)} ${toNepaliDigits(bs.day.toString())}, '
          '${toNepaliDigits(bs.year.toString())}';
  return [
    '$ind"id": "${rule.id}",',
    '$ind"name_en": "${rule.nameEn}",',
    '$ind"name_np": "${rule.nameNp}",',
    '$ind"tithi": "${occ.tithi}",',
    '$ind"convention": "${rule.convention.name}",',
    '$ind"shastra_category": "${rule.shastraCategory ?? ''}",',
    '$ind"ad_date": "${_iso(o.chosenDays.first)}",',
    '$ind"ad_dates": [$adDates],',
    '$ind"bs_date": "$bsEn",',
    '$ind"bs_date_np": "$bsNp",',
    '$ind"tithi_begins_npt": "${isoNpt(occ.beginsAtNpt)}",',
    '$ind"tithi_ends_npt": "${isoNpt(occ.endsAtNpt)}",',
    '$ind"convention_divergence": ${o.conventionDivergence},',
    '$ind"udaya_days": [$udayaDates],',
    '$ind"spans_multiple_days": ${occ.spansMultipleDays},',
    '$ind"skipped_in_udaya_chain": ${occ.skippedInUdayaChain},',
    '$ind"borderline": ${occ.borderline},',
    '$ind"note": "${rule.note}"',
  ].join('\n');
}

/// A JSON array of festival observance objects ('[]' when empty).
String _festivalArray(
    String ind, List<FestivalObservance> list, BsCalendar full) {
  if (list.isEmpty) return '[]';
  final items = [
    for (final o in list)
      '{\n' + _festivalJson(ind + '  ', o, full) + '\n' + ind + '}'
  ];
  return '[\n' + ind + items.join(',\n' + ind) + '\n' + ind + ']';
}

/// The festivals block of today.json (R6c): today's observances, the
/// next festival and the 45-day horizon - every entry naming its
/// day-choosing convention and the udaya alternate when they diverge.
/// The block keys always serialize, so the contract markers are
/// date-stable on festival days and quiet days alike.
String _festivalsBlock(BsCalendar full, DateTime todayAd, String urlBase) {
  final today = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final horizon = today.add(const Duration(days: _festivalWindowDays));
  final scanned = scanFestivals(
      start: today.subtract(const Duration(days: 7)), end: horizon);
  final withDays =
      scanned.where((o) => o.chosenDays.isNotEmpty).toList();
  final todayOnes =
      withDays.where((o) => o.chosenDays.any((d) => d == today)).toList();
  final nextOnes =
      withDays.where((o) => o.chosenDays.first.isAfter(today)).toList();
  final upcoming = nextOnes
      .where((o) => !o.chosenDays.first.isAfter(horizon))
      .toList();
  final nextJson = nextOnes.isEmpty
      ? 'null'
      : '{\n' + _festivalJson('      ', nextOnes.first, full) + '\n    }';
  final todayJson = _festivalArray('    ', todayOnes, full);
  final upcomingJson = _festivalArray('    ', upcoming, full);
  return '{\n' +
      '    "note": "engine-computed at build time; every entry names its day-choosing convention and the udaya alternate when they diverge",\n' +
      '    "festival_window_days": $_festivalWindowDays,\n' +
      '    "today": ' + todayJson + ',\n' +
      '    "next_festival": ' + nextJson + ',\n' +
      '    "upcoming": ' + upcomingJson + ',\n' +
      '    "conventions": {\n' +
      '      "udaya": "tithi running at sunrise (the Hamro Patro display convention)",\n' +
      '      "evening": "tithi running at the 18:00 NPT reference (night observances)",\n' +
      '      "firstDay": "first civil day the tithi overlaps (purva-tithi-viddha)",\n' +
      '      "allDays": "every civil day the tithi overlaps (two-day observances)",\n' +
      '      "nishita": "tithi running at the midnight ending the civil day (the Shivaratri class)",\n' +
      '      "moonrise": "tithi running at the day\'s moonrise (chandrodaya-vyapti)"\n' +
      '    },\n' +
      '    "provenance": "nMiti nepali_panchang festival battery on the runtime lunar engine; festivals are data, conventions are code - every rule receipt-pinned",\n' +
      '    "evidence_tier": "runtime-computed; day choices pinned by the festival receipt corpora (2083, 2026 and 2027 seasons) in the repository test fixtures",\n' +
      '    "details": "${urlBase}festivals.html"\n' +
      '  }';
}

/// The /festivals page (R6c, HYA-367): today's festival observances,
/// the next festival, the coming year's festival calendar with every
/// convention divergence exposed, the six day-choosing conventions
/// with their shastra categories, and the receipt corpora behind
/// them. Computed at build time by the nepali_panchang festival
/// battery; zero client JavaScript. Conventions are shown, never
/// silently picked.
String _festivalsPageHtml(BsCalendar full, DateTime todayAd, String urlBase,
    String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final today = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final yearEnd = today.add(const Duration(days: 370));
  final obs = scanFestivals(
          start: today.subtract(const Duration(days: 7)), end: yearEnd)
      .where((o) => o.chosenDays.isNotEmpty)
      .where((o) => o.chosenDays.any((d) => !d.isBefore(today)))
      .toList();
  final todayOnes =
      obs.where((o) => o.chosenDays.any((d) => d == today)).toList();
  final nextOnes =
      obs.where((o) => o.chosenDays.first.isAfter(today)).toList();
  String hm(DateTime t) => '${_skTwo(t.hour)}:${_skTwo(t.minute)}';
  String bsLabel(DateTime d) {
    final bs = full.fromGregorian(d);
    return '${bsMonthNameEn(bs.month)} ${bs.day} '
        '(${bsMonthNameNp(bs.month)} ${toNepaliDigits(bs.day.toString())}), ${bs.year} BS';
  }
  final todaySection = todayOnes.isEmpty
      ? '<p>No battery festival falls on ${_adMonthNames[today.month - 1]} ${today.day}, ${today.year} (${bsLabel(today)}). The next one is below.</p>'
      : [
          for (final o in todayOnes)
            '<p><strong>${o.rule.nameEn}</strong> <span lang="ne">${o.rule.nameNp}</span> - ${o.occasion.tithi}, ${o.rule.convention.name} convention: today.' +
                (o.conventionDivergence
                    ? ' The udaya convention would give ${_udayaList(o)} - exposed, not hidden.'
                    : '') +
                '</p>'
        ].join('\n');
  final String nextCard;
  if (nextOnes.isEmpty) {
    nextCard = '<p>No battery festival is computed within the next year.</p>';
  } else {
    final o = nextOnes.first;
    final endsNextDay =
        o.occasion.endsAtNpt.day != o.occasion.beginsAtNpt.day;
    final tithiLine = '${o.occasion.tithi}, ${hm(o.occasion.beginsAtNpt)} to ${hm(o.occasion.endsAtNpt)} NPT' +
        (endsNextDay ? ' (ends the next day)' : '');
    final divLine = o.conventionDivergence
        ? '<li><strong>मतभेद · Divergence:</strong> the udaya convention would give ${_udayaList(o)}; the chosen day stays exposed, never silently picked.</li>'
        : '<li><strong>मतभेद · Divergence:</strong> none - the udaya convention agrees.</li>';
    nextCard = [
      '<p><strong>${o.rule.nameEn}</strong> <span lang="ne">${o.rule.nameNp}</span></p>',
      '<ul>',
      '<li><strong>मिति · Date:</strong> ${_iso(o.chosenDays.first)} - ${bsLabel(o.chosenDays.first)}</li>',
      '<li><strong>तिथि · Tithi:</strong> ' + tithiLine + '</li>',
      '<li><strong>नियम · Convention:</strong> ${o.rule.convention.name} - ${o.rule.shastraCategory ?? ''}</li>',
      divLine,
      '<li>${o.rule.note}</li>',
      '</ul>',
    ].join('\n');
  }
  final yearRows = [
    for (final o in obs)
      '<tr><td>' +
          [for (final d in o.chosenDays) _iso(d)].join(', ') +
          '<br><small>' +
          bsLabel(o.chosenDays.first) +
          '</small></td>' +
          '<td>${o.rule.nameEn}<br><span lang="ne">${o.rule.nameNp}</span></td>' +
          '<td>${o.occasion.tithi}</td>' +
          '<td>${o.rule.convention.name}</td>' +
          '<td>' +
          _divCell(o) +
          '</td></tr>'
  ].join('\n');
  final body = '''
<h1>Festivals <span lang="ne">· चाडपर्व</span></h1>
<p>Nepal's festival dates are lunar: each festival rides a tithi, and the civil day it lands on depends on which day-choosing convention is applied. Different panchangs can legitimately print different days. This page never silently picks: every observance below names its convention, and the sunrise (udaya) convention's day is shown alongside whenever they disagree. Computed at build time by the open <code>nepali_panchang</code> festival battery - every rule pinned by publisher receipts.</p>

<h2 id="festivals-today">आज · Today</h2>
$todaySection

<h2 id="festivals-next">अर्को चाडपर्व · Next festival</h2>
$nextCard

<h2 id="festivals-year">आगामी वर्षको पात्रो · The coming year</h2>
<p>Every battery festival from today through ${_iso(yearEnd)} (${obs.length} observances). Divergent rows expose the udaya-convention alternate.</p>
<table>
<tr><th>Date (AD)</th><th>Festival</th><th>Tithi</th><th>Convention</th><th>Divergence</th></tr>
$yearRows
</table>

<h2 id="festivals-conventions">दिन छान्ने नियम · The six day-choosing conventions</h2>
<p>Each rule's day choice rests on a shastra principle - Dharma Sindhu (Kashinatha Upadhyaya, 1790), ch. 5 'Tithi Vrata Nirnayas', read through V.D.N. Rao's condensed English translation (translation-level citation; the shloka-level reference is pending printed-source verification).</p>
<table>
<tr><th>Convention</th><th>Principle</th><th>Decides</th></tr>
<tr><td><code>udaya</code></td><td>udaya-vyapini - tithi prevailing at sunrise</td><td>Ghatasthapana, Maha Navami, Vijaya Dashami, Kag/Kukur/Gai Tihar, Bhai Tika, Chhath, Janai Purnima, Teej - the Hamro Patro display convention</td></tr>
<tr><td><code>evening</code></td><td>pradosha/ratri-vyapini - tithi prevailing at the 18:00 NPT reference</td><td>night observances: Lakshmi Puja, Kojagrat Purnima, Dhanteras</td></tr>
<tr><td><code>firstDay</code></td><td>purva-tithi-viddha - first civil day the tithi overlaps</td><td>Fulpati, Fagu Purnima in the hills</td></tr>
<tr><td><code>allDays</code></td><td>vriddhi - every civil day the tithi overlaps</td><td>two-day observances: Maha Ashtami 2083 (Kartik 1 and 2 - the first two-day Maha Ashtami since 2000 BS)</td></tr>
<tr><td><code>nishita</code></td><td>nishita-vyapini - tithi prevailing at the midnight ending the civil day</td><td>Maha Shivaratri ('Chaturdashi should be till midnight')</td></tr>
<tr><td><code>moonrise</code></td><td>chandrodaya-vyapti - tithi prevailing at the day's moonrise</td><td>the Sankata Chaturthi class (battery entry pending receipts)</td></tr>
</table>
<p><strong>Kshaya resolution:</strong> when a tithi runs entirely between two sunrises (a kshaya in the udaya chain), no udaya day shows it at all; Nepal's publishers keep the festival on the <em>first day the tithi overlaps</em> (receipt: Magha Purnima 2027, Feb 20 - the day's udaya tithi was Chaturdashi, yet the Magh Snan / Swasthani Samapti labels stayed on the day Purnima began). <strong>Vriddhi:</strong> when one tithi spans two udaya days, the observance lists both (receipt: Krishna Ekadashi Mar 3-4 2027, udaya Ekadashi on both days, the Vijaya Ekadashi Vrat on the second).</p>

<h2 id="festivals-receipts">प्रमाण · Receipts</h2>
<p>Every rule above is pinned by a crawled publisher receipt, run as a permanent CI gate on every change:</p>
<ul>
<li><a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/festival_receipts_2083.json">festival_receipts_2083.json</a> - the Dashain/Tihar/Chhath conventions (including the two-day Maha Ashtami)</li>
<li><a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/festival_receipts_2026.json">festival_receipts_2026.json</a> - Shivaratri (nishita vs udaya), Fagu Purnima (hills vs Terai), Janai Purnima and Teej 2026</li>
<li><a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/festival_receipts_2027.json">festival_receipts_2027.json</a> - the 2027 season: Shivaratri (Falgun 22 = Mar 6 2027, nishita; udaya gives Mar 7), Fagu Purnima (Mar 21 hills / Mar 22 Terai), the Magha Purnima kshaya and Krishna Ekadashi vriddhi observations</li>
</ul>

<h2 id="festivals-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> the nMiti nepali_panchang festival battery on the runtime lunar engine (ELP2000-82B moon, VSOP87D sun, hybrid Delta-T channel); festivals are data, conventions are code.</li>
<li><strong>Evidence:</strong> day choices pinned by the receipt corpora above; the engine's tithi timing is band-checked against publisher corpora and Swiss Ephemeris in CI.</li>
<li><strong>Coverage, stated honestly:</strong> the battery holds ${festivalBattery.length} receipt-pinned festivals - it is NOT a complete list of Nepal's festivals. New entries ship only with fresh publisher receipts; nothing is guessed. Janai Purnima and Teej for BS 2084 are recorded as pending in the 2027 fixture until the official 2084 patro publishes (expected spring 2027).</li>
<li><strong>Machine-readable:</strong> <a href="${urlBase}api/v1/today.json">today.json</a> carries a <code>festivals</code> block (today, next_festival, the 45-day horizon).</li>
</ul>
''';
  return _docShell(
      'Festivals',
      'Nepal festival calendar from the nMiti engine: today\'s observances, the next festival, the coming year with every day-choosing convention (udaya, evening, firstDay, allDays, nishita, moonrise) and divergence exposed - receipt-pinned, never guessed.',
      urlBase,
      'festivals.html',
      body,
      shortSha);
}
