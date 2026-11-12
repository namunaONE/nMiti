part of 'build_site.dart';

/// The saait block/page horizon of today.json (R10.4 display, HYA-441):
/// the same 45-day window the vrat and festival blocks use.
const int _saaitWindowDays = 45;

const List<String> _saaitWd = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

/// URL-stable ceremony keys for JSON consumers.
const Map<SaaitCeremony, String> _saaitCeremonyKeys = {
  SaaitCeremony.vivah: 'vivah',
  SaaitCeremony.bratabandha: 'bratabandha',
  SaaitCeremony.pasni: 'pasni',
  SaaitCeremony.grihaAramba: 'griha_aramba',
  SaaitCeremony.grihaPravesh: 'griha_pravesh',
  SaaitCeremony.vyaparik: 'vyaparik',
  SaaitCeremony.dhanyachhedan: 'dhanyachhedan',
  SaaitCeremony.hom: 'hom',
  SaaitCeremony.rudri: 'rudri',
};

/// Devanagari ceremony names (display layer; the engine carries the
/// English profile names).
const Map<SaaitCeremony, String> _saaitCeremonyNamesNp = {
  SaaitCeremony.vivah: 'विवाह',
  SaaitCeremony.bratabandha: 'ब्रतबन्ध',
  SaaitCeremony.pasni: 'पास्नी',
  SaaitCeremony.grihaAramba: 'गृहारम्भ',
  SaaitCeremony.grihaPravesh: 'गृहप्रवेश',
  SaaitCeremony.vyaparik: 'व्यापारिक',
  SaaitCeremony.dhanyachhedan: 'धान्यछेदन',
  SaaitCeremony.hom: 'होम',
  SaaitCeremony.rudri: 'रुद्री',
};

/// NPT ISO stamp for JSON windows.
String _saaitIsoNpt(DateTime t) =>
    _iso(t) + 'T' + _skTwo(t.hour) + ':' + _skTwo(t.minute) + ':00+05:45';

/// BS date label for display: month name, day, year.
String _saaitBsDate(SaaitFixedDay f, int bsYear) =>
    bsMonthNameEn(f.bsMonth) + ' ' + f.bsDay.toString() + ', ' +
    bsYear.toString();

/// Guru/Shukra asta (combustion) state of a served saait day, from the
/// Wave 1 graha engine's provisional classical limits at the NPT-noon
/// eval instant (display v1.5). The flags are EXPOSED on the grid and
/// the today/next cards, never filtered on - the traditional day
/// lists are served as published either way.
String _saaitAstaCell(DateTime adDay) {
  final flags = [
    if (_grahaAstaOn(GrahaBody.jupiter, adDay)) 'Guru asta',
    if (_grahaAstaOn(GrahaBody.venus, adDay)) 'Shukra asta',
  ];
  return flags.isEmpty ? '-' : flags.join(' + ');
}

/// The in-day windows of one saait day as JSON (today/next entries
/// carry them; upcoming entries stay lean with windows: null).
String _saaitWindowsJson(String ind, SaaitWindows w) {
  final chogh = [
    for (final s in w.goodChoghadiya)
      '{"type": "' + s.type + '", "lord": "' + s.lord +
          '", "begins_at": "' + _saaitIsoNpt(s.beginsAtNpt) +
          '", "ends_at": "' + _saaitIsoNpt(s.endsAtNpt) + '"}'
  ].join(', ');
  final horas = [
    for (final h in w.auspiciousHoras)
      '{"lord": "' + h.lord + '", "begins_at": "' +
          _saaitIsoNpt(h.beginsAtNpt) + '", "ends_at": "' +
          _saaitIsoNpt(h.endsAtNpt) + '", "is_daylight": ' +
          (h.isDaylight ? 'true' : 'false') + '}'
  ].join(', ');
  return '{\n' +
      ind + '  "abhijit": {"name": "' + w.abhijit.name +
          '", "begins_at": "' + _saaitIsoNpt(w.abhijit.beginsAtNpt) +
          '", "ends_at": "' + _saaitIsoNpt(w.abhijit.endsAtNpt) + '"},\n' +
      ind + '  "good_choghadiya": [' + chogh + '],\n' +
      ind + '  "auspicious_horas": [' + horas + ']\n' +
      ind + '}';
}

/// One saait day as JSON. [withWindows] includes the runtime-computed
/// in-day windows (true for the today/next entries); lean entries emit
/// an explicit windows: null.
String _saaitDayJson(String ind, SaaitDay d, bool withWindows) {
  final f = d.fixed;
  final wd = _saaitWd[f.dateNpt.weekday - 1];
  final ssy = d.sarvarthaSiddhi;
  final b = StringBuffer();
  b.write(ind + '  "ceremony": "' +
      _saaitCeremonyKeys[d.profile.ceremony]! + '",\n');
  b.write(ind + '  "ceremony_name": "' + d.profile.displayName + '",\n');
  b.write(ind + '  "ceremony_name_np": "' +
      _saaitCeremonyNamesNp[d.profile.ceremony]! + '",\n');
  b.write(ind + '  "bs_date": "' + d.profile.bsYear.toString() + '-' +
      f.bsMonth.toString() + '-' + f.bsDay.toString() + '",\n');
  b.write(ind + '  "ad_date": "' + _iso(f.dateNpt) + '",\n');
  b.write(ind + '  "weekday": "' + wd + '",\n');
  b.write(ind + '  "publisher_tithi_label": "' + f.tithiLabel + '",\n');
  b.write(ind + '  "tithi_at_udaya": "' + d.tithiAtUdaya + '",\n');
  b.write(ind + '  "tithi_borderline": ' +
      (d.tithiBorderline ? 'true' : 'false') + ',\n');
  b.write(ind + '  "tithi_vriddhi": ' +
      (d.tithiVriddhi ? 'true' : 'false') + ',\n');
  b.write(ind + '  "tithi_kshaya": ' +
      (d.tithiKshaya ? 'true' : 'false') + ',\n');
  if (ssy == null) {
    b.write(ind + '  "sarvartha_siddhi": null,\n');
  } else {
    b.write(ind + '  "sarvartha_siddhi": {"nakshatra": "' +
        ssy.nakshatraName + '", "amrit": ' +
        (ssy.amrit ? 'true' : 'false') + ', "begins_at": "' +
        _saaitIsoNpt(ssy.beginsAtNpt) + '", "ends_at": "' +
        _saaitIsoNpt(ssy.endsAtNpt) + '"},\n');
  }
  if (withWindows) {
    b.write(ind + '  "windows": ' + _saaitWindowsJson(ind, d.windows) + '\n');
  } else {
    b.write(ind + '  "windows": null\n');
  }
  return b.toString();
}

/// One Sarvartha/Amrit Siddhi occurrence as JSON.
String _saaitSsyJson(SarvarthaSiddhi s) =>
    '{"date": "' + _iso(s.dateNpt) + '", "weekday": "' +
    _saaitWd[s.dateNpt.weekday - 1] + '", "nakshatra": "' +
    s.nakshatraName + '", "amrit": ' + (s.amrit ? 'true' : 'false') +
    ', "begins_at": "' + _saaitIsoNpt(s.beginsAtNpt) + '", "ends_at": "' +
    _saaitIsoNpt(s.endsAtNpt) + '"}';

/// One ceremony summary: claimed vs served counts, the next served day
/// in the publisher's list, the closure note and the caveats.
String _saaitCeremonySummaryJson(SaaitCeremony c, DateTime today) {
  final p = saaitProfiles2083[c]!;
  SaaitFixedDay? next;
  for (final f in p.days) {
    if (f.dateNpt.isAfter(today)) {
      next = f;
      break;
    }
  }
  final caveats = [for (final x in p.caveats) '"' + x + '"'].join(', ');
  final b = StringBuffer();
  b.write('      {"key": "' + _saaitCeremonyKeys[c]! + '", ');
  b.write('"name": "' + p.displayName + '", ');
  b.write('"name_np": "' + _saaitCeremonyNamesNp[c]! + '", ');
  b.write('"claimed_count": ' + p.claimedCount.toString() + ', ');
  b.write('"served_count": ' + p.days.length.toString() + ', ');
  if (next == null) {
    b.write('"next": null, ');
  } else {
    b.write('"next": {"bs_date": "' + p.bsYear.toString() + '-' +
        next.bsMonth.toString() + '-' + next.bsDay.toString() +
        '", "ad_date": "' + _iso(next.dateNpt) + '", "weekday": "' +
        _saaitWd[next.dateNpt.weekday - 1] + '"}, ');
  }
  b.write('"closure_note": ' +
      (p.closureNote == null ? 'null' : '"' + p.closureNote! + '"') + ', ');
  b.write('"caveats": [' + caveats + ']}');
  return b.toString();
}

/// The saait block of today.json (R10.4 display): today's ceremony
/// days, the next saait day, the lean 45-day horizon, the per-ceremony
/// summaries with the publisher's claimed vs served counts, and the
/// Sarvartha/Amrit Siddhi scan - every entry carries the publisher's
/// tithi label beside the engine's udaya tithi with its flags.
String _saaitBlock(DateTime todayAd, String urlBase) {
  final today = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final horizon = today.add(const Duration(days: _saaitWindowDays));
  final scanned = saaitAllDaysBetween(today, horizon);
  final todayOnes = scanned.where((d) => d.fixed.dateNpt == today).toList();
  final upcoming =
      scanned.where((d) => d.fixed.dateNpt.isAfter(today)).toList();
  final next = upcoming.isEmpty ? null : upcoming.first;
  String one(String ind, SaaitDay d, bool withWindows) =>
      '{\n' + _saaitDayJson(ind + '  ', d, withWindows) + '\n' + ind + '}';
  final todayJson = todayOnes.isEmpty
      ? '[]'
      : '[\n' +
          [for (final d in todayOnes) one('      ', d, true)].join(',\n') +
          '\n    ]';
  final nextJson = next == null ? 'null' : one('    ', next, true);
  final upcomingJson = upcoming.isEmpty
      ? '[]'
      : '[\n' +
          [for (final d in upcoming) one('      ', d, false)].join(',\n') +
          '\n    ]';
  final ceremonyItems = [
    for (final c in SaaitCeremony.values) _saaitCeremonySummaryJson(c, today)
  ].join(',\n');
  final ssyScan = sarvarthaSiddhiBetween(today, horizon);
  final ssyOnes = ssyScan.where((s) => s.dateNpt == today).toList();
  final ssyUpcoming =
      ssyScan.where((s) => s.dateNpt.isAfter(today)).toList();
  final ssyTodayJson =
      ssyOnes.isEmpty ? 'null' : _saaitSsyJson(ssyOnes.first);
  final ssyNextJson =
      ssyUpcoming.isEmpty ? 'null' : _saaitSsyJson(ssyUpcoming.first);
  final ssyUpcomingJson = ssyUpcoming.isEmpty
      ? '[]'
      : '[\n        ' +
          [for (final s in ssyUpcoming) _saaitSsyJson(s)]
              .join(',\n        ') +
          '\n      ]';
  final conventions = [
    for (final k in saaitConventions.keys)
      '      "' + k + '": "' + saaitConventions[k]! + '"'
  ].join(',\n');
  final provenance = scanned.isEmpty
      ? 'nMiti nepali_panchang saait calendar layer on the runtime lunar engine'
      : scanned.first.provenance;
  final evidence = scanned.isEmpty
      ? 'traditional-fixed day lists (receipt corpus nmiti-saait-receipts/1, crawl 2026-11-10) + runtime-computed in-day windows'
      : scanned.first.evidenceTier;
  return '{\n'
      '    "note": "traditional-fixed ceremony day lists served as publisher evidence, never recomputed as truth; in-day windows and the Siddhi yogas are runtime-computed. Entries in today and next carry in-day windows; upcoming entries are lean.",\n'
      '    "today": ' + todayJson + ',\n'
      '    "next": ' + nextJson + ',\n'
      '    "upcoming": ' + upcomingJson + ',\n'
      '    "saait_window_days": ' + _saaitWindowDays.toString() + ',\n'
      '    "ceremonies": [\n' + ceremonyItems + '\n    ],\n'
      '    "sarvartha_siddhi": {\n'
      '      "today": ' + ssyTodayJson + ',\n'
      '      "next": ' + ssyNextJson + ',\n'
      '      "upcoming": ' + ssyUpcomingJson + '\n'
      '    },\n'
      '    "conventions": {\n' + conventions + '\n    },\n'
      '    "provenance": "' + provenance + '",\n'
      '    "evidence_tier": "' + evidence + '",\n'
      '    "details": "' + urlBase + 'saait.html"\n'
      '  }';
}

/// One ceremony row of the page's ceremony table.
String _saaitCeremonyRowHtml(SaaitCeremony c, DateTime today) {
  final p = saaitProfiles2083[c]!;
  SaaitFixedDay? next;
  for (final f in p.days) {
    if (f.dateNpt.isAfter(today)) {
      next = f;
      break;
    }
  }
  final notes = [
    if (p.closureNote != null) '<em>Closure:</em> ' + p.closureNote!,
    for (final x in p.caveats) '<em>Caveat:</em> ' + x,
  ].join(' ');
  return '<tr><td>' + p.displayName + '<br><span lang="ne">' +
      _saaitCeremonyNamesNp[c]! + '</span></td>'
      '<td>' + (p.claimedCount < 0 ? '-' : p.claimedCount.toString()) +
      '</td>'
      '<td>' + p.days.length.toString() + '</td>'
      '<td>' +
      (next == null
          ? 'none left in the served list'
          : _saaitBsDate(next, p.bsYear) + ' BS<br>' + _iso(next.dateNpt)) +
      '</td>'
      '<td><a href="' + p.sourcePage + '">katigate</a></td>'
      '<td>' + (notes.isEmpty ? '-' : notes) + '</td></tr>';
}

/// The /saait page (R10.4 display, HYA-441): today's ceremony days, the
/// next saait card, the ceremony tables with the publisher's claimed
/// vs served counts, the Sarvartha/Amrit Siddhi scan, the BS 2083 grid
/// of every served day, and the full conventions record - the
/// traditional lists shown as evidence, never recomputed as truth.
String _saaitPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final today = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final horizon = today.add(const Duration(days: _saaitWindowDays));
  final scanned = saaitAllDaysBetween(today, horizon);
  final todayOnes = scanned.where((d) => d.fixed.dateNpt == today).toList();
  final upcoming =
      scanned.where((d) => d.fixed.dateNpt.isAfter(today)).toList();
  final next = upcoming.isEmpty ? null : upcoming.first;
  final all = saaitAllDaysBetween(
      DateTime.utc(2026, 1, 1), DateTime.utc(2027, 12, 31));
  final ssyScan = sarvarthaSiddhiBetween(today, horizon);
  final astaByDate = <DateTime, String>{
    for (final d in all) d.fixed.dateNpt: _saaitAstaCell(d.fixed.dateNpt),
  };
  String hm(DateTime t) => _skTwo(t.hour) + ':' + _skTwo(t.minute);
  String dt(DateTime t) => _iso(t) + ' ' + hm(t) + ' NPT';
  String ssyCell(SaaitDay d) {
    final s = d.sarvarthaSiddhi;
    if (s == null) return '-';
    return s.nakshatraName + (s.amrit ? ' (Amrit)' : ' (Sarvartha)');
  }
  String flagCell(SaaitDay d) {
    final flags = [
      if (d.tithiBorderline) 'borderline',
      if (d.tithiVriddhi) 'vriddhi',
      if (d.tithiKshaya) 'kshaya',
    ];
    return flags.isEmpty ? '-' : flags.join(' + ');
  }
  String cardHtml(SaaitDay d) {
    final f = d.fixed;
    final s = d.sarvarthaSiddhi;
    final w = d.windows;
    final chogh = [
      for (final c in w.goodChoghadiya)
        c.type + ' ' + hm(c.beginsAtNpt) + '-' + hm(c.endsAtNpt)
    ].join(' &middot; ');
    return [
      '<p><strong>' + d.profile.displayName + ' <span lang="ne">' +
          _saaitCeremonyNamesNp[d.profile.ceremony]! +
          '</span></strong> - ' + _saaitBsDate(f, d.profile.bsYear) +
          ' BS (' + _iso(f.dateNpt) + ', ' +
          _saaitWd[f.dateNpt.weekday - 1] + ')</p>',
      '<ul>',
      '<li><strong>प्रकाशकको तिथि · Publisher tithi label:</strong> ' +
          f.tithiLabel + '</li>',
      '<li><strong>इन्जिनको उदया तिथि · Engine udaya tithi:</strong> ' +
          d.tithiAtUdaya +
          (flagCell(d) == '-' ? '' : ' - flagged: ' + flagCell(d)) +
          '</li>',
      '<li><strong>अभिजित · Abhijit:</strong> ' +
          hm(w.abhijit.beginsAtNpt) + '-' + hm(w.abhijit.endsAtNpt) +
          ' NPT</li>',
      '<li><strong>शुभ चौघडिया · Good choghadiya:</strong> ' + chogh +
          ' NPT</li>',
      '<li><strong>शुभ होरा · Auspicious horas:</strong> ' +
          w.auspiciousHoras.length.toString() +
          ' windows (Moon, Mercury, Jupiter, Venus lords) - the full ' +
          '24-hora day table is on <a href="' + urlBase +
          'muhurta.html">muhurta</a></li>',
      '<li><strong>सिद्धि योग · Siddhi yoga:</strong> ' +
          (s == null
              ? 'no Sarvartha/Amrit Siddhi on this day'
              : (s.amrit ? 'Amrit Siddhi' : 'Sarvartha Siddhi') + ' - ' +
                  s.nakshatraName + ', window ' + dt(s.beginsAtNpt) +
                  ' to ' + dt(s.endsAtNpt)) + '</li>',
      '<li><strong>गुरु/शुक्र अस्त · Guru/Shukra asta:</strong> ' +
          (astaByDate[f.dateNpt] == '-'
              ? 'neither Guru nor Shukra is combust at the NPT-noon eval'
              : astaByDate[f.dateNpt]! +
                  ' - the planet is combust at the NPT-noon eval (provisional limits); flagged, never filtered') +
          '</li>',
      '<li><strong>प्रमाण · Evidence:</strong> ' + d.evidenceTier + '</li>',
      '</ul>',
    ].join('\n');
  }
  final todaySection = todayOnes.isEmpty
      ? '<p>No ceremony day falls on ' + _iso(today) +
          ' in the served 2083 lists. A quiet day is not an anomaly - ' +
          'the lists are the publisher\'s traditional-fixed dates; the ' +
          'next saait day is below.</p>'
      : [for (final d in todayOnes) cardHtml(d)].join('\n');
  final String nextCard;
  if (next == null) {
    nextCard = '<p>No saait day is served within the next ' +
        _saaitWindowDays.toString() +
        ' days - the BS 2083 lists end with the served window; BS 2084 ' +
        'lists arrive with the new patro year.</p>';
  } else {
    nextCard = cardHtml(next);
  }
  final ceremonyRows = [
    for (final c in SaaitCeremony.values) _saaitCeremonyRowHtml(c, today)
  ].join('\n');
  final ssyRows = ssyScan.isEmpty
      ? '<tr><td colspan="4">No Sarvartha or Amrit Siddhi day falls in ' +
          'the next ' + _saaitWindowDays.toString() + ' days.</td></tr>'
      : [
          for (final s in ssyScan)
            '<tr><td>' + _iso(s.dateNpt) +
                (s.dateNpt == today ? ' (today)' : '') + '<br><small>' +
                _saaitWd[s.dateNpt.weekday - 1] + '</small></td>' +
                '<td>' +
                (s.amrit ? 'Amrit Siddhi' : 'Sarvartha Siddhi') +
                '</td>' + '<td>' + s.nakshatraName + '</td>' +
                '<td>' + dt(s.beginsAtNpt) + ' - ' + dt(s.endsAtNpt) +
                '</td></tr>'
        ].join('\n');
  final gridRows = [
    for (final d in all)
      '<tr><td>' + _iso(d.fixed.dateNpt) + '<br><small>' +
          _saaitWd[d.fixed.dateNpt.weekday - 1] + '</small></td>' +
          '<td>' + _saaitBsDate(d.fixed, d.profile.bsYear) + '</td>' +
          '<td>' + d.profile.displayName + '<br><span lang="ne">' +
          _saaitCeremonyNamesNp[d.profile.ceremony]! + '</span></td>' +
          '<td>' + d.fixed.tithiLabel + '</td>' +
          '<td>' + d.tithiAtUdaya +
          (flagCell(d) == '-' ? '' : '<br><small>' + flagCell(d) + '</small>') +
          '</td>' +
          '<td>' + ssyCell(d) + '</td>' +
          '<td>' + astaByDate[d.fixed.dateNpt]! + '</td></tr>'
  ].join('\n');
  final counts = <SaaitCeremony, int>{};
  for (final d in all) {
    counts[d.profile.ceremony] = (counts[d.profile.ceremony] ?? 0) + 1;
  }
  final countLine = [
    for (final c in SaaitCeremony.values)
      _saaitCeremonyKeys[c]! + ' ' + (counts[c] ?? 0).toString()
  ].join(', ');
  final borderlineCount =
      all.where((d) => d.tithiBorderline).length;
  final convLabels = <String, String>{
    'dayLists': 'Day lists vs windows',
    'ssy': 'Siddhi yogas (Sarvartha / Amrit)',
    'ssyOverrides': 'Classical SSY overrides',
    'windows': 'In-day windows',
    'guruShukraAsta': 'Guru/Shukra asta closures',
    'location': 'Location',
  };
  final convRows = [
    for (final k in convLabels.keys)
      '<tr><td>' + convLabels[k]! + '</td><td>' +
          (saaitConventions[k] ?? '(not recorded)') + '</td></tr>'
  ].join('\n');
  final provenance = all.isEmpty
      ? 'the nMiti nepali_panchang saait calendar layer on the runtime lunar engine'
      : all.first.provenance;
  final evidence = all.isEmpty
      ? 'traditional-fixed day lists (receipt corpus nmiti-saait-receipts/1, crawl 2026-11-10) + runtime-computed in-day windows'
      : all.first.evidenceTier;
  final body = '''
<h1>Saait <span lang="ne">· साइत</span> — auspicious dates</h1>
<p>The saait (auspicious-date) layer serves two evidence kinds, never conflated. The ceremony day lists - vivah, bratabandha, pasni, griha aramba, griha pravesh, vyaparik plus the dhanyachhedan/hom/rudri events block - are the katigate BS 2083 sahit pages frozen as a receipt corpus: published-or-estimated traditional lists, served as named evidence and never recomputed as truth. The in-day windows (Abhijit, the good choghadiya parts, the auspicious horas) and the Sarvartha and Amrit Siddhi yogas are runtime-computed from the shipped muhurta and panchang engines for the nMiti Kathmandu anchor (27.7172 N, 85.324 E), NPT (UTC+05:45) - no copied tables, no client JavaScript.</p>

<h2 id="saait-today">आज · Today</h2>
$todaySection

<h2 id="saait-next">अर्को साइत · Next saait day</h2>
$nextCard

<h2 id="saait-ceremonies">संस्कार · The ceremony lists</h2>
<p>Every ceremony profile with the publisher's claimed BS 2083 count beside the served count - the served list covers only the window the sahit pages list, and where a digit string fits multiple months (griha aramba beyond Mangsir), the ambiguous days stay unserved and the raw strings are retained in the receipt corpus. Closure notes and caveats are carried verbatim, never silently dropped.</p>
<table>
<tr><th>Ceremony</th><th>Claimed 2083</th><th>Served</th><th>Next served day</th><th>Source</th><th>Closures &amp; caveats</th></tr>
$ceremonyRows
</table>

<h2 id="saait-ssy">सिद्धि योग · Sarvartha &amp; Amrit Siddhi</h2>
<p>Sarvartha Siddhi and Amrit Siddhi are the weekday-x-nakshatra yogas of the Muhurta Chintamani / Nirnaya Sindhu: the yoga fires when the Moon's nakshatra at sunrise is in the weekday's list, and the window runs from sunrise to the end of the qualifying nakshatra. Amrit Siddhi is the single nakshatra pair of the weekday. The scan below covers the next $_saaitWindowDays days at the at-sunrise convention.</p>
<table>
<tr><th>Date</th><th>Yoga</th><th>Nakshatra at sunrise</th><th>Window (NPT)</th></tr>
$ssyRows
</table>
<p>Receipts record: the gate pins the Nov 11 2026 Amrit Siddhi fire, and that the Dec 18 2026 Revati window - which opens mid-run at 16:09 IST under another publisher's convention - does NOT fire at the at-sunrise convention. It is a recorded collision, never absorbed. The classical overrides (Rahu Kaal suspension, Bhadra karana, Panchak reduction, eclipse) are authority-dependent and documented below, not applied; Jupiter/Venus combustion (asta) closure seasons are computed from the Wave 1 graha engine and flagged in the grid below (display v1.5) - flagged, never filtered - while publisher closure notes (e.g. the Chaturmas wedding closure) are still carried verbatim.</p>

<h2 id="saait-year">BS 2083 grid · All served days</h2>
<p>Every served day of every ceremony profile - ${all.length} days: $countLine; $borderlineCount flagged borderline. The publisher's tithi label is shown beside the engine's udaya tithi: where they differ, the day label is convention-sensitive and the flag says which (borderline, vriddhi or kshaya). Computed, not copied - the engine column comes from the runtime lunar chain. The asta column flags days inside a Guru (Jupiter) or Shukra (Venus) combustion season - exposed, never filtered.</p>
<table>
<tr><th>Date (AD)</th><th>BS date</th><th>Ceremony</th><th>Publisher tithi</th><th>Engine udaya tithi</th><th>Siddhi yoga</th><th>Asta</th></tr>
$gridRows
</table>

<h2 id="saait-conventions">नियम · Conventions</h2>
<p>Every rule below is stated, never silently resolved; where publishers disagree, the collision is recorded and shown.</p>
<table>
<tr><th>Rule</th><th>What nMiti serves and why</th></tr>
$convRows
</table>

<p><strong>Guru/Shukra asta, display v1.5:</strong> since the Wave 1 graha engine the display layer computes the Jupiter and Venus combustion seasons over the served days at the NPT-noon eval instant, on the provisional classical limits (Jupiter 11&deg;, Venus 10&deg; apparent separation). Grid days inside a season are FLAGGED - never filtered: the traditional lists are served as published, and the closure decision stays with the reader. The engine saait layer itself applies no closure (see the conventions row above), and the BPHS ch. 9 citation for the limits remains an open receipt; the full graha conventions live on <a href="${urlBase}graha.html">graha.html</a>.</p>

<h2 id="saait-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> $provenance</li>
<li><strong>Evidence:</strong> $evidence</li>
<li><strong>Verification:</strong> the gate (<code>saait_calendar_test.dart</code>, 21 tests) checks the 82-day profile==fixture equality against the frozen corpus, the publisher tithi labels with knife-edge-only tolerance, the Sarvartha Siddhi two-directional scan, the Nov 11 2026 Amrit fire and the Dec 18 2026 collision non-fire, the Nov 22 2026 Dwadashi kshaya, the conventions record and the griha pravesh singleton. See <a href="${urlBase}methodology.html">methodology</a> and <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a>.</li>
<li><strong>Receipts:</strong> <a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/saait_receipts_2083.json">saait_receipts_2083.json</a> - schema nmiti-saait-receipts/1, crawl 2026-11-10: the katigate sahit ceremony lists, the publisher tithi labels, the claimed counts and the caveats, including the griha aramba unserved digit strings.</li>
<li><strong>Machine-readable:</strong> the <a href="${urlBase}api/v1/today.json">today.json</a> <code>saait</code> block carries today's ceremony days, the next saait day, the 45-day lean horizon, the per-ceremony summaries and the Siddhi scan.</li>
</ul>
''';
  return _docShell(
      'Saait (auspicious dates)',
      'Nepal auspicious dates from nMiti: the ceremony day lists - wedding, bratabandha, pasni, griha pravesh, griha aramba, business - served as publisher evidence with runtime-computed in-day windows and the Sarvartha/Amrit Siddhi yogas - receipt-anchored, never copied.',
      urlBase,
      'saait.html',
      body,
      shortSha);
}
