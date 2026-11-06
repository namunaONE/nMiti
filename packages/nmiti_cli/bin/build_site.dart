import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_date_data/nepali_date_data.dart';
import 'package:nepali_sankranti/nepali_sankranti.dart';
import 'package:nepali_panchang/nepali_panchang.dart';

const _adMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _adMonthNamesNp = [
  'जनवरी', 'फेब्रुअरी', 'मार्च', 'अप्रिल', 'मे', 'जुन',
  'जुलाई', 'अगस्ट', 'सेप्टेम्बर', 'अक्टोबर', 'नोभेम्बर', 'डिसेम्बर',
];

const _gridHeadsNp = ['आइत', 'सोम', 'मङ्गल', 'बुध', 'बिही', 'शुक्र', 'शनि'];
const _gridHeadsEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

void main(List<String> args) {
  final outPath = _arg(args, '--out') ?? 'build/site';
  final urlBase = _arg(args, '--url') ?? 'https://namunaone.github.io/nMiti/';
  final core = coreCalendar;
  final tail = tailCalendar;
  final full = fullCalendar;

  // Build provenance, stamped into every artifact (traceable answers).
  final commitSha = Platform.environment['NM_COMMIT_SHA'] ?? 'local';
  final runId = Platform.environment['NM_RUN_ID'] ?? 'local';

  final sankrantiRows = parseSankrantiTableCsv(
      _readSourceFile('data/sankranti_moments_1975_2100.csv'));

  final fatal = [
    ...validateCore(core),
    ...validateTail(core, tail).where((v) => !v.knownDefect),
    ..._validateSankrantiTable(full, sankrantiRows),
  ];
  if (fatal.isNotEmpty) {
    for (final v in fatal) {
      stderr.writeln('data invariant failure: $v');
    }
    stderr.writeln('refusing to build the site from invalid data.');
    exitCode = 1;
    return;
  }

  // Nepal Time is a fixed UTC+05:45 offset (no DST, ever).
  final todayAd = todayInNepalTime();
  final today = full.fromGregorian(todayAd);
  final gToday = full.toGregorian(today);
  final tomorrow = full.fromGregorian(gToday.add(const Duration(days: 1)));

  final out = Directory(outPath);
  if (out.existsSync()) out.deleteSync(recursive: true);
  final apiDir = Directory('${out.path}/api/v1')..createSync(recursive: true);
  Directory('${apiDir.path}/calendar').createSync(recursive: true);

  _write(File('${out.path}/api/v1/today.json'),
      _todayJson(full, today, todayAd, tomorrow, urlBase, commitSha, runId));
  _write(File('${out.path}/api/v1/meta.json'), _metaJson(core, tail, urlBase, commitSha));
  _write(File('${out.path}/api/v1/sankranti.json'),
      _sankrantiJson(sankrantiRows, urlBase, commitSha));
  for (final y in full.years) {
    _write(File('${apiDir.path}/calendar/$y.json'), _yearJson(full, y, urlBase));
  }
  _write(File('${out.path}/index.html'), _indexHtml(full, today, urlBase, commitSha));
  _write(File('${out.path}/404.html'), _notFoundHtml(urlBase));
  _write(File('${out.path}/robots.txt'),
      'User-agent: *\n'
      'Allow: /\n'
      'Sitemap: ${urlBase}sitemap.xml\n');
  _write(File('${out.path}/.nojekyll'), '');
  _write(File('${out.path}/sitemap.xml'), _sitemap(urlBase));
  _write(File('${out.path}/llms.txt'), _llmsTxt(core, tail, urlBase, today));
  final dataDir = Directory('${out.path}/data')..createSync(recursive: true);
  _write(File('${dataDir.path}/calendar_bs_core_1975_2083.csv'), calendarBsCoreCsv);
  _write(File('${dataDir.path}/calendar_bs_tail_2084_2100.csv'), calendarBsTailCsv);
  _write(File('${dataDir.path}/sankranti_moments_1975_2100.csv'),
      File('data/sankranti_moments_1975_2100.csv').readAsStringSync());
  _write(File('${dataDir.path}/sankranti_moments_1975_2083.csv'),
      _readSourceFile('data/sankranti_moments_1975_2083.csv'));
  _write(File('${out.path}/sankranti.html'),
      _sankrantiPageHtml(sankrantiRows, urlBase, commitSha));
  _write(File('${out.path}/panchang.html'),
      _panchangPageHtml(todayAd, urlBase, commitSha));
  _write(File('${out.path}/grahan.html'),
      _grahanPageHtml(todayAd, urlBase, commitSha));
  _write(File('${out.path}/festivals.html'),
      _festivalsPageHtml(full, todayAd, urlBase, commitSha));
  _write(File('${out.path}/masa.html'),
      _masaPageHtml(todayAd, urlBase, commitSha));
  _write(File('${out.path}/muhurta.html'),
      _muhurtaPageHtml(todayAd, urlBase, commitSha));
  _write(File('${out.path}/accuracy.html'),
      _accuracyPageHtml(core, tail, urlBase, commitSha));
  _write(File('${out.path}/methodology.html'),
      _methodologyPageHtml(urlBase, commitSha));
  _write(File('${out.path}/data.html'),
      _dataPageHtml(core, tail, urlBase, commitSha));
  _write(File('${out.path}/docs.html'), _docsPageHtml(urlBase, commitSha));
  final embedDir = Directory('${out.path}/embed/v1')..createSync(recursive: true);
  _write(File('${embedDir.path}/widget.js'), _widgetJs(full, today, urlBase));
  _write(File('${out.path}/embed/example.html'),
      _embedExampleHtml(urlBase, commitSha));

  final tier = full.row(today.year).evidence.split(',').first;
  stdout.writeln('site built: BS ${today.year}-${today.month}-${today.day} '
      '(tier: $tier), AD ${_iso(todayAd)}, commit $commitSha');
}

String _todayJson(BsCalendar full, BsDate today, DateTime todayAd, BsDate tomorrow,
    String urlBase, String commitSha, String runId) {
  final row = full.row(today.year);
  final g = full.toGregorian(today);
  final gTomorrow = full.toGregorian(tomorrow);
  final wdEn = weekdayNamesEn[g.weekday];
  final wdNp = weekdayNamesNp[g.weekday];
  final labelEn = '${bsMonthNameEn(today.month)} ${today.day}, ${today.year} BS';
  final labelNp = '${bsMonthNameNp(today.month)} ${toNepaliDigits(today.day.toString())}, ${toNepaliDigits(today.year.toString())}';
  final tier = row.evidence.split(',').first;
  // R6a-3: the daily panchang block, engine-computed at build time.
  final p = panchangFor(year: todayAd.year, month: todayAd.month, day: todayAd.day);
  String isoNpt(DateTime t) =>
      '${_iso(t)}T${_skTwo(t.hour)}:${_skTwo(t.minute)}:00+05:45';
  String elJson(String ind, String key, PanchangElement e) =>
      '$ind"$key": {"name": "${e.name}", "begins_at": "${isoNpt(e.beginsAtNpt)}", "ends_at": "${isoNpt(e.endsAtNpt)}"}';
  String limbJson(String ind, PanchangElement udaya, PanchangElement noon) =>
      '${elJson(ind, 'udaya', udaya)},\n${elJson(ind, 'madhyahna', noon)}';
  return '''
{
  "bs": {
    "year": ${today.year},
    "month": ${today.month},
    "day": ${today.day},
    "month_name_en": "${bsMonthNameEn(today.month)}",
    "month_name_np": "${bsMonthNameNp(today.month)}",
    "weekday_en": "$wdEn",
    "weekday_np": "$wdNp",
    "label_en": "$labelEn",
    "label_np": "$labelNp",
    "evidence": "${row.evidence}",
    "tier": "$tier"
  },
  "ad": {
    "iso": "${_iso(todayAd)}",
    "label_en": "$wdEn, ${_adMonthNames[todayAd.month - 1]} ${todayAd.day}, ${todayAd.year}"
  },
  "tomorrow": {
    "bs": {
      "year": ${tomorrow.year},
      "month": ${tomorrow.month},
      "day": ${tomorrow.day}
    },
    "ad": "${_iso(gTomorrow)}"
  },
  "panchang": {
    "note": "engine-computed at build time; festival observances are served in the festivals block",
    "conventions": {
      "udaya": "element running at engine sunrise - the Hamro Patro display convention",
      "madhyahna": "element running at local noon - the BhaktiBharat display convention"
    },
    "tithi": {
${limbJson('      ', p.tithiAtUdaya, p.tithiAtNoon)}
    },
    "nakshatra": {
${limbJson('      ', p.nakshatraAtUdaya, p.nakshatraAtNoon)}
    },
    "yoga": {
${limbJson('      ', p.yogaAtUdaya, p.yogaAtNoon)}
    },
    "karana": {
${limbJson('      ', p.karanaAtUdaya, p.karanaAtNoon)}
    },
    "sunrise_npt": "${isoNpt(p.sunriseNpt)}",
    "flags": {
      "tithi_vriddhi": ${p.tithiVriddhi},
      "tithi_kshaya": ${p.tithiKshaya},
      "tithi_borderline": ${p.tithiBorderline}
    },
    "provenance": "${p.provenance}",
    "evidence_tier": "${p.evidenceTier}",
    "details": "${urlBase}panchang.html"
  },
  "grahan": ${_grahanBlock(todayAd, urlBase)},
  "festivals": ${_festivalsBlock(full, todayAd, urlBase)},
  "masa": ${_masaBlock(todayAd, urlBase)},
  "muhurta": ${_muhurtaBlock(todayAd, urlBase)},
  "timezone": "Asia/Kathmandu (UTC+05:45, no DST)",
  "generated_at_utc": "${DateTime.now().toUtc().toIso8601String()}",
  "commit": "$commitSha",
  "build": "run-$runId",
  "source": "nMiti verified Bikram Sambat dataset (R12 cross-validation, 2026-11-02)",
  "license": "CC0-1.0",
  "homepage": "$urlBase",
  "api": {
    "today": "${urlBase}api/v1/today.json",
    "calendar_year": "${urlBase}api/v1/calendar/{bs_year}.json"
  }
}
''';
}

String _metaJson(BsCalendar core, BsCalendar tail, String urlBase, String commitSha) {
  return '''
{
  "name": "nmiti-bikram-sambat-dataset",
  "description": "Open, verified, evidence-tagged Bikram Sambat (Nepali) calendar data",
  "core": {
    "first_year": ${core.firstYear},
    "last_year": ${core.lastYear},
    "rows": ${core.years.length},
    "evidence": "R12 cross-validation 2026-11-02; anchor chain closes on official Baisakh 1 2084 = Wed 2027-04-14"
  },
  "tail": {
    "first_year": ${tail.firstYear},
    "last_year": ${tail.lastYear},
    "rows": ${tail.years.length},
    "evidence": "projection; only 2084 officially anchored; BS 2096 carries a known labeled defect (364 days)"
  },
  "commit": "$commitSha",
  "license": "CC0-1.0",
  "homepage": "$urlBase",
  "repository": "https://github.com/namunaONE/nMiti"
}
''';
}

String _yearJson(BsCalendar full, int year, String urlBase) {
  final row = full.row(year);
  final lengths = row.months.join(',');
  final namesEn = [for (var m = 1; m <= 12; m++) '"${bsMonthNameEn(m)}"'].join(',');
  final namesNp = [for (var m = 1; m <= 12; m++) '"${bsMonthNameNp(m)}"'].join(',');
  final tier = row.evidence.split(',').first;
  return '''
{
  "bs_year": $year,
  "baisakh1": "${_iso(row.baisakh1)}",
  "weekday": "${row.weekday}",
  "days": ${row.days},
  "month_lengths": [$lengths],
  "month_names_en": [$namesEn],
  "month_names_np": [$namesNp],
  "evidence": "${row.evidence}",
  "tier": "$tier",
  "license": "CC0-1.0",
  "homepage": "$urlBase"
}
''';
}

String _indexHtml(BsCalendar full, BsDate today, String urlBase, String commitSha) {
  final row = full.row(today.year);
  final g = full.toGregorian(today);
  final tier = row.evidence.split(',').first;
  final monthNameEn = bsMonthNameEn(today.month);
  final monthNameNp = bsMonthNameNp(today.month);
  final wdEn = weekdayNamesEn[g.weekday];
  final wdNp = weekdayNamesNp[g.weekday];
  final yearNp = toNepaliDigits(today.year.toString());
  final dayNp = toNepaliDigits(today.day.toString());
  final adLabel = '$wdEn, ${_adMonthNames[g.month - 1]} ${g.day}, ${g.year}';
  final adLabelNp = '$wdNp, ${_adMonthNamesNp[g.month - 1]} ${toNepaliDigits(g.day.toString())}, ${toNepaliDigits(g.year.toString())}';
  final builtAt = DateTime.now().toUtc().toIso8601String();
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final b1 = full.baisakh1(today.year);
  final tierNote = tier == 'r12-verified'
      ? 'Verified core data (R12 cross-validation, 2026-11-02).'
      : 'Evidence tier: $tier. Dates beyond the verified core are labeled projections; only Baisakh 1 2084 (2027-04-14) is official.';
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>आजको मिति - Today's date in Nepal: $monthNameEn ${today.day}, ${today.year} BS | nMiti</title>
<meta name="description" content="Today's Bikram Sambat (Nepali) date is $monthNameEn ${today.day}, ${today.year} BS ($monthNameNp $dayNp, $yearNp) - $adLabel AD. Open, verified, machine-checked calendar data. Updated daily at 00:00 Nepal Time.">
<link rel="canonical" href="$urlBase">
<meta property="og:type" content="website">
<meta property="og:title" content="Today's date in Nepal: $monthNameEn ${today.day}, ${today.year} BS | nMiti">
<meta property="og:description" content="$monthNameEn ${today.day}, ${today.year} BS ($monthNameNp $dayNp, $yearNp) - $adLabel.">
<meta property="og:url" content="$urlBase">
<meta property="og:locale" content="ne_NP">
<script type="application/ld+json">{"@context":"https://schema.org","@type":"WebSite","name":"nMiti - Today's date in Nepal","url":"$urlBase","inLanguage":["ne","en"]}</script>
<style>
:root{color-scheme:light dark}
body{font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,Noto Sans Devanagari,sans-serif;max-width:44rem;margin-inline:auto;padding:2rem 1rem}
h1{font-size:1.4rem}
h2{font-size:1.05rem;margin-top:2rem}
.answer{font-size:1.35rem;line-height:1.55;margin:.6rem 0}
.tier{font-size:.85rem;opacity:.7}
table{border-collapse:collapse}
th,td{padding:.35rem .65rem;text-align:center;border:1px solid #8884;font-size:.9rem}
.today{background:#0a72c4;color:#fff;border-radius:6px}
.foot{font-size:.8rem;opacity:.7;margin-top:2rem}
a{color:#0a72c4}
.nav{font-size:.9rem;opacity:.8}
</style>
</head>
<body>
<main>
<h1>आजको मिति · Today's date in Nepal</h1>
<p class="nav"><a href="accuracy.html">Accuracy &amp; honesty</a> · <a href="methodology.html">Methodology</a> · <a href="data.html">Data &amp; API</a> · <a href="sankranti.html">Sankranti</a> · <a href="masa.html">Masa</a> · <a href="panchang.html">Panchang</a> · <a href="muhurta.html">Muhurta</a> · <a href="grahan.html">Grahan</a> · <a href="festivals.html">Festivals</a> · <a href="docs.html">Docs</a></p>
<p class="answer" id="ans-en">Today is <strong>$monthNameEn ${today.day}, ${today.year} BS</strong> (<span lang="ne">$monthNameNp $dayNp, $yearNp</span>)<br>— <strong>$adLabel</strong> (Gregorian).</p>
<p class="answer" lang="ne" id="ans-ne">आज <strong>$adLabelNp</strong> विक्रम संवत् अनुसार <strong>$monthNameNp $dayNp, $yearNp</strong> हो।</p>
<p class="tier" id="tier-note">$tierNote</p>
<h2 id="cal-heading"><span lang="ne">$monthNameNp</span> · $monthNameEn ${today.year}</h2>
${_monthGrid(full, today)}
<h2>Machine-readable</h2>
<ul>
<li><a href="api/v1/today.json">api/v1/today.json</a> — today as JSON</li>
<li><a href="api/v1/calendar/${today.year}.json">api/v1/calendar/${today.year}.json</a> — the full BS ${today.year} table</li>
<li><a href="https://github.com/namunaONE/nMiti">Dataset and source code on GitHub</a></li>
</ul>
<p>BS ${today.year} began on Baisakh 1, <strong>${_iso(b1)}</strong> (${row.weekday}). This page is rebuilt automatically from the verified dataset — no hand-typed dates anywhere.</p>
<p class="foot">nMiti — open Bikram Sambat calendar commons · data CC0-1.0 · code MIT · rebuilt daily around 00:00 Nepal Time (UTC+05:45) · built $builtAt UTC from $shortSha</p>
</main>
<script>
${_clientGuardJs(full, today, g)}
</script>
</body>
</html>
''';
}

String _monthGrid(BsCalendar full, BsDate today) {
  final first = full.toGregorian(BsDate(today.year, today.month, 1));
  final length = full.monthLength(today.year, today.month);
  final startCol = first.weekday % 7; // Sunday-first grid
  final cells = <String>[];
  for (var i = 0; i < startCol; i++) {
    cells.add('<td></td>');
  }
  for (var d = 1; d <= length; d++) {
    final cls = d == today.day ? ' class="today"' : '';
    cells.add('<td$cls>${toNepaliDigits(d.toString())}</td>');
  }
  while (cells.length % 7 != 0) {
    cells.add('<td></td>');
  }
  final heads = [
    for (var i = 0; i < 7; i++)
      '<th><span lang="ne">${_gridHeadsNp[i]}</span><br>${_gridHeadsEn[i]}</th>'
  ].join();
  final body = [
    for (var i = 0; i < cells.length; i += 7)
      '<tr>${cells.sublist(i, i + 7).join()}</tr>'
  ].join();
  return '''
<table id="cal-grid">
<thead><tr>$heads</tr></thead>
<tbody>
$body
</tbody>
</table>''';
}

/// Year rows embedded for the client-side guard:
/// [bsYear, "baisakh1 ISO", [12 month lengths]] for the years around the
/// build date, so the browser can map any nearby AD date to a BS date.
String _rowsForJs(BsCalendar full, int centerYear) {
  final years = full.years
      .where((y) => y >= centerYear - 1 && y <= centerYear + 2)
      .toList()
    ..sort();
  final rows = [
    for (final y in years)
      '[${y},"${_iso(full.row(y).baisakh1)}",[${full.row(y).months.join(',')}]]'
  ];
  return '[${rows.join(',')}]';
}

/// Defense in depth, layer 11 - the last mile. The page is a build-time
/// snapshot, but a visitor may arrive after the Nepal-midnight rollover
/// while every scheduled rebuild is delayed or dropped (GitHub documents
/// scheduled runs as delayed/dropped under load; on the first night after
/// launch, 2026-11-02/03, BOTH midnight runs were skipped and the site
/// served the previous date for hours). This tiny dependency-free script
/// recomputes "today" in the visitor's browser, in Nepal Time (fixed
/// UTC+05:45, no DST), from the same year rows, and corrects the page -
/// honestly labeled - whenever the build is stale. If JS is off or the
/// script fails, the page keeps its build-time content: it fails closed,
/// never wronger. No framework; the static build remains the source of
/// truth for crawlers.
String _clientGuardJs(BsCalendar full, BsDate today, DateTime builtAd) {
  final monthsEn = [for (var m = 1; m <= 12; m++) '"${bsMonthNameEn(m)}"'].join(',');
  final monthsNp = [for (var m = 1; m <= 12; m++) '"${bsMonthNameNp(m)}"'].join(',');
  final adEn = [for (final n in _adMonthNames) '"$n"'].join(',');
  final adNp = [for (final n in _adMonthNamesNp) '"$n"'].join(',');
  return '''
(function () {
  'use strict';
  var NPT_MS = 20700000; // Nepal Time: fixed UTC+05:45, no DST, ever.
  var ROWS = ${_rowsForJs(full, today.year)};
  var BUILD_AD = "${_iso(builtAd)}";
  var M_EN = [$monthsEn];
  var M_NP = [$monthsNp];
  var AD_EN = [$adEn];
  var AD_NP = [$adNp];
  var H_NP = ['आइत', 'सोम', 'मङ्गल', 'बुध', 'बिही', 'शुक्र', 'शनि'];
  var H_EN = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  var W_EN = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  var W_NP = ['आइतबार', 'सोमबार', 'मङ्गलबार', 'बुधबार', 'बिहीबार', 'शुक्रबार', 'शनिबार'];
  var NP_DIGITS = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
  function npNum(n) {
    n = String(n);
    var out = '';
    for (var i = 0; i < n.length; i++) {
      out += (n[i] >= '0' && n[i] <= '9') ? NP_DIGITS[+n[i]] : n[i];
    }
    return out;
  }
  function parseIso(s) { return Date.UTC(+s.slice(0, 4), +s.slice(5, 7) - 1, +s.slice(8, 10)); }
  function isoOf(ms) { return new Date(ms).toISOString().slice(0, 10); }
  function weekdayOf(adIso) { return new Date(parseIso(adIso) + 43200000).getUTCDay(); }
  function bsFromAd(adIso) {
    var t = parseIso(adIso);
    for (var i = 0; i < ROWS.length; i++) {
      var r = ROWS[i];
      var b1 = parseIso(r[1]);
      var days = 0;
      for (var j = 0; j < 12; j++) { days += r[2][j]; }
      if (t >= b1 && t < b1 + days * 86400000) {
        var doy = Math.floor((t - b1) / 86400000) + 1;
        var m = 1, d = doy;
        for (var k = 0; k < 12; k++) { if (d <= r[2][k]) { break; } d -= r[2][k]; m++; }
        return { y: r[0], m: m, d: d };
      }
    }
    return null;
  }
  var nowAd = isoOf(Date.now() + NPT_MS);
  var builtBs = bsFromAd(BUILD_AD);
  var nowBs = bsFromAd(nowAd);
  if (!builtBs || !nowBs) { return; }
  if (builtBs.y === nowBs.y && builtBs.m === nowBs.m && builtBs.d === nowBs.d) { return; }
  // The served build predates the current Nepal date (scheduled rebuild
  // dropped or delayed). Correct the page, honestly labeled.
  var wd = weekdayOf(nowAd);
  var ay = +nowAd.slice(0, 4), am = +nowAd.slice(5, 7), ad = +nowAd.slice(8, 10);
  var elEn = document.getElementById('ans-en');
  var elNe = document.getElementById('ans-ne');
  if (!elEn || !elNe) { return; }
  elEn.innerHTML = 'Today is <strong>' + M_EN[nowBs.m - 1] + ' ' + nowBs.d + ', ' + nowBs.y + ' BS</strong> (<span lang="ne">' + M_NP[nowBs.m - 1] + ' ' + npNum(nowBs.d) + ', ' + npNum(nowBs.y) + '</span>)<br>— <strong>' + W_EN[wd] + ', ' + AD_EN[am - 1] + ' ' + ad + ', ' + ay + '</strong> (Gregorian).';
  elNe.innerHTML = 'आज <strong>' + W_NP[wd] + ', ' + AD_NP[am - 1] + ' ' + npNum(ad) + ', ' + npNum(ay) + '</strong> विक्रम संवत् अनुसार <strong>' + M_NP[nowBs.m - 1] + ' ' + npNum(nowBs.d) + ', ' + npNum(nowBs.y) + '</strong> हो।';
  var head = document.getElementById('cal-heading');
  if (head) { head.innerHTML = '<span lang="ne">' + M_NP[nowBs.m - 1] + '</span> · ' + M_EN[nowBs.m - 1] + ' ' + nowBs.y; }
  var grid = document.getElementById('cal-grid');
  if (grid) {
    var row = null;
    for (var i2 = 0; i2 < ROWS.length; i2++) { if (ROWS[i2][0] === nowBs.y) { row = ROWS[i2]; } }
    if (row) {
      var before = 0;
      for (var j2 = 0; j2 < nowBs.m - 1; j2++) { before += row[2][j2]; }
      var startCol = weekdayOf(isoOf(parseIso(row[1]) + before * 86400000));
      var len = row[2][nowBs.m - 1];
      var cells = [];
      var c;
      for (c = 0; c < startCol; c++) { cells.push('<td></td>'); }
      for (c = 1; c <= len; c++) {
        cells.push('<td' + (c === nowBs.d ? ' class="today"' : '') + '>' + npNum(c) + '</td>');
      }
      while (cells.length % 7 !== 0) { cells.push('<td></td>'); }
      var heads = '';
      var h;
      for (h = 0; h < 7; h++) { heads += '<th><span lang="ne">' + H_NP[h] + '</span><br>' + H_EN[h] + '</th>'; }
      var rowsHtml = '';
      var r2;
      for (r2 = 0; r2 < cells.length; r2 += 7) {
        rowsHtml += '<tr>' + cells.slice(r2, r2 + 7).join('') + '</tr>';
      }
      grid.innerHTML = '<thead><tr>' + heads + '</tr></thead><tbody>' + rowsHtml + '</tbody>';
    }
  }
  var note = document.getElementById('tier-note');
  if (note) {
    note.innerHTML = note.innerHTML + ' <em>(Live date corrected to Nepal Time in your browser — the scheduled rebuild for ' + nowAd + ' had not run yet when this page was built.)</em>';
  }
  document.title = "आजको मिति - Today's date in Nepal: " + M_EN[nowBs.m - 1] + ' ' + nowBs.d + ', ' + nowBs.y + ' BS | nMiti';
})();
''';
}

/// Shared CSS for the honesty-layer documentation pages.
const _docCss = '''
:root{color-scheme:light dark}
body{font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,Noto Sans Devanagari,sans-serif;max-width:46rem;margin-inline:auto;padding:2rem 1rem}
h1{font-size:1.4rem}
h2{font-size:1.05rem;margin-top:2rem}
table{border-collapse:collapse}
th,td{padding:.35rem .65rem;text-align:left;border:1px solid #8884;font-size:.9rem;vertical-align:top}
code{background:#8882;padding:.1rem .3rem;border-radius:4px;font-size:.85em}
.foot{font-size:.8rem;opacity:.7;margin-top:2rem}
a{color:#0a72c4}
.nav{font-size:.9rem;opacity:.85}
''';

String _docShell(String title, String description, String urlBase,
    String canonical, String body, String shortSha) {
  final builtAt = DateTime.now().toUtc().toIso8601String();
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title | nMiti</title>
<meta name="description" content="$description">
<link rel="canonical" href="$urlBase$canonical">
<meta property="og:type" content="website">
<meta property="og:title" content="$title | nMiti">
<meta property="og:description" content="$description">
<meta property="og:url" content="$urlBase$canonical">
<meta property="og:locale" content="ne_NP">
<style>
$_docCss
</style>
</head>
<body>
<main>
<p class="nav"><a href="$urlBase">आजको मिति · Today</a> · <a href="${urlBase}accuracy.html">Accuracy &amp; honesty</a> · <a href="${urlBase}methodology.html">Methodology</a> · <a href="${urlBase}data.html">Data &amp; API</a> · <a href="${urlBase}sankranti.html">Sankranti</a> · <a href="${urlBase}masa.html">Masa</a> · <a href="${urlBase}panchang.html">Panchang</a> · <a href="${urlBase}muhurta.html">Muhurta</a> · <a href="${urlBase}grahan.html">Grahan</a> · <a href="${urlBase}festivals.html">Festivals</a> · <a href="${urlBase}docs.html">Docs</a></p>
$body
<p class="foot">nMiti — open Bikram Sambat calendar commons · data CC0-1.0 · code MIT · built $builtAt UTC from $shortSha</p>
</main>
</body>
</html>
''';
}

/// Honesty layer - the /accuracy page: what is verified, what is
/// uncertain, how errors are corrected. No hand-waving.
String _accuracyPageHtml(BsCalendar core, BsCalendar tail, String urlBase,
    String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final body = '''
<h1>Accuracy &amp; honesty <span lang="ne">· शुद्धता र इमानदारी</span></h1>
<p>Every date nMiti serves is derived from one canonical, machine-verified dataset - never hand-typed. This page documents what that claim is worth: how the data was verified, what is uncertain, and how errors are corrected.</p>

<h2 id="trust">What you are trusting</h2>
<ul>
<li><strong>R12 cross-validation (2026-11-02):</strong> all ${core.years.length} core rows (BS 1975-${core.lastYear}) were machine-diffed against an independent reference table (amitgaru/nepali-datetime, calendar_bs.csv blob 83e8c16) - ${core.years.length}/${core.years.length} rows and 1,308/1,308 cells identical.</li>
<li><strong>The anchor chain closes on an official date:</strong> counting Baisakh 1 + year length forward for ${core.years.length} years lands exactly on the only officially announced future date: Baisakh 1 2084 = Wednesday 2027-04-14. A century-long chain that closes on an official anchor is not a coincidence you can fake.</li>
<li><strong>Live confirmation:</strong> on 2026-11-02 the table matched 10+ live Nepali calendar sites, and the 2083 row matches the national panchanga row quoted in dibas-np/NepalKit PR #34.</li>
<li><strong>Checked continuously:</strong> CI enforces structural invariants on every build, and an independent Python implementation re-derives the deployed date from the raw CSVs after every deploy. The test suite also round-trip converts every single day of BS 1975-2100 (about 46,000 days) in both directions on every CI run.</li>
</ul>

<h2 id="evidence-tiers">Evidence tiers</h2>
<p>Every row carries its evidence in the data itself; no untagged rows exist.</p>
<table>
<tr><th>Tag</th><th>Meaning</th><th>Rows</th></tr>
<tr><td><code>r12-verified</code></td><td>Machine-verified by the R12 cross-validation.</td><td>All core years (1975-${core.lastYear})</td></tr>
<tr><td><code>disputed-resolved</code></td><td>Years 1989, 1991, 1993, 2004, 2062 were disputed between sources; R12 resolved all five in favor of these rows.</td><td>5 years</td></tr>
<tr><td><code>live-2026-11-02</code></td><td>Row additionally confirmed live and against the national panchanga row.</td><td>2083</td></tr>
<tr><td><code>official-anchor</code></td><td>The only officially announced future Baisakh 1.</td><td>2084 = 2027-04-14</td></tr>
<tr><td><code>projection</code></td><td>Chained forward from the official 2084 anchor; replaced by official data when Nepal publishes.</td><td>${tail.firstYear + 1}-${tail.lastYear}</td></tr>
<tr><td><code>projection-defect</code></td><td>A genuine upstream defect we preserve and label rather than silently fix.</td><td>2096 (364 days)</td></tr>
</table>

<h2 id="known-issues">Known issues, stated plainly</h2>
<ul>
<li><strong>BS 2096 has 364 days</strong> in the projection tail. It is a genuine upstream defect. We do not invent a fix - the row stays tagged <code>projection-defect</code> until Nepal publishes the official calendar.</li>
<li><strong>Corrupted tables are live in the wild.</strong> During verification we found nepalicalendar.online running one day early from Kartik 2083 onward, and KhataIn one day late from Mangsir 2083 (kept as test vectors, never as copy sources). Unaudited copies drift - that is why this dataset exists.</li>
<li><strong>Festival dates can legitimately differ between panchangs</strong> - a festival's civil day depends on which day-choosing convention is applied (Kojagrat Purnima 2083: printed Oct 25 in one panchang, adjudicated Oct 26 by others). The <a href="festivals.html">festival layer</a> therefore never silently picks: every observance names its convention, and the udaya-convention alternate is shown whenever they diverge - receipt-pinned to the festival corpora in the repository.</li>
</ul>

<h2 id="freshness">Freshness, and what happens at midnight</h2>
<p>The static site is rebuilt three times around Nepal midnight (00:00, 00:30, 01:00 NPT) and every 6 hours. But GitHub documents that scheduled runs can be delayed or silently dropped - and we measured it. On the first night after launch (2026-11-02/03) both scheduled midnight runs were dropped and the site served the previous BS date for hours; the next night the 00:15 UTC slot ran about 80 minutes late. The design therefore does not trust schedules:</p>
<ul>
<li>The homepage corrects itself <em>in your browser</em> at Nepal midnight (fixed UTC+05:45, no DST) from embedded year rows - humans see the right date at 00:00:00 NPT even if every scheduled rebuild fails.</li>
<li>A correctness canary runs 4 times a day, independently recomputing today from the raw CSVs in Asia/Kathmandu and comparing against the deployed today.json. A mismatch or staleness (26-hour SLA) opens an urgent issue.</li>
</ul>

<h2 id="errata">Errata policy</h2>
<p>Errors are fixed in the open. If you find a wrong date, <a href="https://github.com/namunaONE/nMiti/issues">open an issue</a> with evidence - a photo of a printed patro, an official publication, or a contradicting source. We verify, update the CSV with an evidence tag, and the correction is visible in the repository history. Projections are never silently corrected; only official data replaces a projection. Known defects stay visible and labeled until then.</p>

<h2 id="scope">What nMiti is not</h2>
<p>Not a panchang: no tithi, no festivals, no muhurta - only the civil Bikram Sambat calendar, the date layer every source agrees on. The <a href="sankranti.html">sankranti moments</a> (precise solar ingress timestamps, BS 1975-2100) are now served, so every month boundary is independently checkable against the sun. Until a claim is on this site with evidence, we do not make it.</p>
''';
  return _docShell(
      'Accuracy &amp; honesty',
      'How the nMiti Bikram Sambat dataset is verified: evidence tiers, known defects, freshness model and errata policy.',
      urlBase, 'accuracy.html', body, shortSha);
}

/// Honesty layer - the /methodology page: the verification story, the
/// calendar-layer model, and the invariants CI enforces.
String _methodologyPageHtml(String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final body = '''
<h1>Methodology <span lang="ne">· कसरी प्रमाणित?</span></h1>
<p>How nMiti verifies more than a century of Bikram Sambat data and keeps it honest.</p>

<h2 id="verification">Verification method</h2>
<ol>
<li><strong>Machine diff (R12):</strong> the core CSV was diffed cell by cell against an independent reference table (amitgaru/nepali-datetime, calendar_bs.csv, blob 83e8c16): 109/109 rows and 1,308/1,308 cells identical.</li>
<li><strong>Anchor chain:</strong> Baisakh 1 of each year plus that year's length must land exactly on Baisakh 1 of the next. The 109-year chain closes precisely on the official Baisakh 1 2084 = Wednesday 2027-04-14 - roughly 40,000 consecutive days that end on the one officially announced future date.</li>
<li><strong>Live confirmation:</strong> on 2026-11-02 (Kartik 16, 2083) the current row matched 10+ live Nepali calendar sites and the national panchanga row quoted in dibas-np/NepalKit PR #34.</li>
<li><strong>Continuous invariants, and an exhaustive trust machine, enforced by CI on every build:</strong> month lengths 29-32; core year lengths 365-366; chain continuity; every Baisakh 1 falls on April 11-15; the weekday column matches the baisakh1 date; no run of 3+ identical consecutive rows; the tail chains from the official 2084 anchor; and every one of the ~46,000 days (BS 1975-2100) is round-trip converted in both directions, with every day's weekday cross-checked by an independent path.</li>
<li><strong>Independent re-derivation:</strong> after every deploy, a Python implementation - not the Dart engine that built the site - recomputes today's date straight from the raw CSVs and compares it against the deployed JSON. A 4-times-daily canary repeats the check against the live site.</li>
</ol>

<h2 id="layers">Calendar layers: why today's date is unambiguous but festivals are not</h2>
<p>The Bikram Sambat calendar is solar: every month begins at a precise solar ingress (sankranti). The panchang adds a lunar layer - the tithi - which can change <em>during the afternoon</em>, and festival dates depend on rules layered on both. Two correct panchangs can therefore print different festival dates while agreeing perfectly on today's civil date. nMiti Layer 1 serves the civil solar layer - the one every source agrees on - and the lunar layers ship with their conventions exposed: the panchang (every limb at both the udaya and madhyahna references), grahan (eclipses), and festival observances (each rule's day-choosing convention shown, never silently picked; see the festivals page).</p>

<h2 id="structural">Structural facts, machine-checked</h2>
<ul>
<li>The core contains 13 distinct 12-month row shapes and 28 leap (366-day) years.</li>
<li>Identical consecutive years do occur in correct data - runs of exactly two (1993-94, 1997-98, 2082-83). The correct invariant is no run of 3+, not "no duplicates".</li>
<li>Every Baisakh 1 falls on April 11-15.</li>
</ul>

<h2 id="provenance">Full provenance record</h2>
<p>The complete evidence record - source blob, the five historically disputed years, and the corrupted-variant carriers kept as test vectors - lives in <a href="https://github.com/namunaONE/nMiti/blob/main/docs/data-provenance.md">docs/data-provenance.md</a> and <a href="https://github.com/namunaONE/nMiti/blob/main/docs/reliability.md">docs/reliability.md</a>.</p>
''';
  return _docShell(
      'Methodology',
      'How nMiti verifies its Bikram Sambat dataset: R12 cross-validation, the official anchor chain, CI invariants, and the calendar layer model.',
      urlBase, 'methodology.html', body, shortSha);
}

/// Honesty layer - the /data page: canonical downloads, data dictionary,
/// JSON API docs, and the license statement.
String _dataPageHtml(BsCalendar core, BsCalendar tail, String urlBase,
    String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  // Checksums are computed from the EXACT bytes the build serves, so the
  // page can never list a digest that does not match the download. The
  // independent Python contract re-derives every digest post-deploy.
  final servedCsv = [
    ('data/calendar_bs_core_1975_2083.csv', calendarBsCoreCsv),
    ('data/calendar_bs_tail_2084_2100.csv', calendarBsTailCsv),
    ('data/sankranti_moments_1975_2083.csv',
        _readSourceFile('data/sankranti_moments_1975_2083.csv')),
    ('data/sankranti_moments_1975_2100.csv',
        _readSourceFile('data/sankranti_moments_1975_2100.csv')),
  ];
  final checksumRows = [
    for (final f in servedCsv)
      '<tr><td><a href="${f.$1}">${(f.$1).split('/').last}</a></td>'
      '<td>${utf8.encode(f.$2).length}</td>'
      '<td><code>${sha256.convert(utf8.encode(f.$2))}</code></td></tr>'
  ].join('\n');
  final body = '''
<h1>Data &amp; API <span lang="ne">· डाटा र एपीआई</span></h1>
<p>Four canonical CSVs are the single source of truth for everything nMiti ships - the site, the JSON API, the Dart SDK. Nothing downstream may hard-code a date. Data license: <strong>CC0-1.0</strong> (public domain).</p>

<h2 id="downloads">Downloads</h2>
<ul>
<li><a href="data/calendar_bs_core_1975_2083.csv">calendar_bs_core_1975_2083.csv</a> - verified core, ${core.years.length} years (BS 1975-${core.lastYear}), served as an exact copy of the repository file</li>
<li><a href="data/calendar_bs_tail_2084_2100.csv">calendar_bs_tail_2084_2100.csv</a> - labeled projection tail, ${tail.years.length} years (BS ${tail.firstYear}-${tail.lastYear})</li>
<li><a href="data/sankranti_moments_1975_2083.csv">sankranti_moments_1975_2083.csv</a> - Commons Layer 1: 1,308 verified sidereal ingress moments, NPT (BS 1975-${core.lastYear})</li>
<li><a href="data/sankranti_moments_1975_2100.csv">sankranti_moments_1975_2100.csv</a> - Layer 1 extended through the projection tail: 1,512 rows (BS 1975-${tail.lastYear}); rows beyond ${core.lastYear} are labeled projections</li>
<li>Canonical source and full history: <a href="https://github.com/namunaONE/nMiti/tree/main/data">github.com/namunaONE/nMiti/tree/main/data</a></li>
</ul>

<h2 id="checksums">SHA-256 checksums</h2>
<p>Verify what you download: these digests are computed by the site build from the exact bytes served above, and re-verified after every deploy by the independent Python site contract.</p>
<table>
<tr><th>File</th><th>Bytes</th><th>SHA-256</th></tr>
$checksumRows
</table>

<h2 id="license">License</h2>
<p>The data files above are dedicated to the public domain: <strong>CC0-1.0</strong> (Creative Commons Zero). Calendar facts belong to everyone; no permission is needed and no attribution is required. License text: <a href="https://github.com/namunaONE/nMiti/blob/main/data/LICENSE">data/LICENSE</a>. The code is MIT-licensed.</p>

<h2 id="data-dictionary">Data dictionary</h2>
<p>Both CSVs share one format. Lines starting with <code>#</code> are provenance comments.</p>
<table>
<tr><th>Column</th><th>Type</th><th>Meaning</th></tr>
<tr><td><code>bs_year</code></td><td>integer</td><td>Bikram Sambat year (1975-2100)</td></tr>
<tr><td><code>baisakh1</code></td><td>ISO date</td><td>Gregorian date of Baisakh 1 of that BS year (always April 11-15)</td></tr>
<tr><td><code>weekday</code></td><td>Mon..Sun</td><td>Weekday of Baisakh 1 - a redundant cross-check against baisakh1</td></tr>
<tr><td><code>baisakh</code> ... <code>chaitra</code></td><td>integer x 12</td><td>Days in each BS month, Baisakh through Chaitra (each 29-32)</td></tr>
<tr><td><code>days</code></td><td>integer</td><td>Total days in the BS year (365 or 366 in the verified core)</td></tr>
<tr><td><code>evidence</code></td><td>tag list</td><td>Comma-separated evidence tags - see <a href="accuracy.html#evidence-tiers">evidence tiers</a></td></tr>
</table>

<h2 id="api">JSON API - static, no keys, CC0</h2>
<ul>
<li><code><a href="api/v1/today.json">api/v1/today.json</a></code> - today in BS and AD, weekday and month names in Nepali and English, the evidence tier, plus a <code>tomorrow</code> object so consumers can self-correct at their own midnight, and a <code>panchang</code> block - tithi, nakshatra, yoga, karana at both udaya (sunrise) and madhyahna (noon) reference moments, sunrise, vriddhi/kshaya/borderline flags, provenance and evidence tier - plus a <code>grahan</code> block: the eclipse or sutak window touching today, whether sutak is active, and the next grahan with its Nepali name and honesty fields, plus a <code>festivals</code> block: today's festival observances, the next festival and the 45-day horizon, each naming its day-choosing convention and any convention divergence - plus a <code>masa</code> block (the amanta lunar month containing today, with adhika/kshaya flags) and a <code>muhurta</code> block (Rahu Kalam, Yamaganda, Gulika, Abhijit and Brahma muhurta, the choghadiya slots and the 24 horas). Engine-computed at build time. Stamped with the commit and build run.</li>
<li><code>api/v1/calendar/{bs_year}.json</code> - one BS year: baisakh1, weekday, days, the 12 month lengths, month names, evidence tier (BS 1975-2100). Example: <a href="api/v1/calendar/2083.json">api/v1/calendar/2083.json</a></li>
<li><code><a href="api/v1/meta.json">api/v1/meta.json</a></code> - dataset metadata: coverage, evidence summary, license.</li>
</ul>

<h2 id="cite">Using and citing</h2>
<p>CC0 means no permission is needed for the data and no attribution is required - though it is always welcome: <em>"Data: nMiti - open Bikram Sambat dataset (CC0), namunaone.github.io/nMiti."</em> For reproducibility, pin a commit SHA; <code>today.json</code> carries the current one. The code is MIT-licensed.</p>
<script type="application/ld+json">{"@context":"https://schema.org","@type":"Dataset","name":"nMiti Bikram Sambat calendar dataset","description":"Open, verified, evidence-tagged Bikram Sambat (Nepali) calendar data, BS 1975-2100.","license":"https://creativecommons.org/publicdomain/zero/1.0/","creator":{"@type":"Organization","name":"nMiti"},"distribution":[{"@type":"DataDownload","encodingFormat":"text/csv","contentUrl":"${urlBase}data/calendar_bs_core_1975_2083.csv"},{"@type":"DataDownload","encodingFormat":"text/csv","contentUrl":"${urlBase}data/calendar_bs_tail_2084_2100.csv"},{"@type":"DataDownload","encodingFormat":"text/csv","contentUrl":"${urlBase}data/sankranti_moments_1975_2083.csv"},{"@type":"DataDownload","encodingFormat":"text/csv","contentUrl":"${urlBase}data/sankranti_moments_1975_2100.csv"}]}</script>
''';
  return _docShell(
      'Data &amp; API',
      'Download the nMiti Bikram Sambat dataset (CC0 CSVs), read the data dictionary, and use the static JSON API.',
      urlBase, 'data.html', body, shortSha);
}

/// Embeddable "today in BS" widget (HYA-399). A single dependency-free
/// <script> that renders today's Bikram Sambat date into every
/// <div data-nmiti="today"></div> on the host page, inside a Shadow DOM
/// so no styles leak either way. The date is recomputed in the browser
/// in Nepal Time (fixed UTC+05:45) from the same verified year rows as
/// the site client-side guard, so embeds are correct at Nepal midnight
/// without any server round-trip. Terms: free; the visible "via nMiti"
/// credit link is the condition of use. No tracking, no cookies, no
/// external requests. Fails closed: on any error an embed shows only
/// the credit link, never a wrong date. Served from a versioned path
/// (/embed/v1/); a future v2 will be a new path so v1 keeps working.
String _widgetJs(BsCalendar full, BsDate today, String urlBase) {
  final monthsEn = [for (var m = 1; m <= 12; m++) '"${bsMonthNameEn(m)}"'].join(',');
  final monthsNp = [for (var m = 1; m <= 12; m++) '"${bsMonthNameNp(m)}"'].join(',');
  final adEn = [for (final n in _adMonthNames) '"$n"'].join(',');
  final adNp = [for (final n in _adMonthNamesNp) '"$n"'].join(',');
  return '''
/* nMiti "today in Bikram Sambat" embed widget v1.
   Docs and terms: ${urlBase}embed/example.html
   Free to use. Condition: the visible "via nMiti" credit link stays.
   No tracking, no cookies, no external requests - the date is computed
   in the browser from verified year rows (fails closed, never wrong). */
(function () {
  'use strict';
  var NPT_MS = 20700000; // Nepal Time: fixed UTC+05:45, no DST, ever.
  var ROWS = ${_rowsForJs(full, today.year)};
  var M_EN = [$monthsEn];
  var M_NP = [$monthsNp];
  var AD_EN = [$adEn];
  var AD_NP = [$adNp];
  var W_EN = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  var W_NP = ['आइतबार', 'सोमबार', 'मङ्गलबार', 'बुधबार', 'बिहीबार', 'शुक्रबार', 'शनिबार'];
  var NP_DIGITS = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
  var SITE = '$urlBase';
  function npNum(n) {
    n = String(n);
    var out = '';
    for (var i = 0; i < n.length; i++) {
      out += (n[i] >= '0' && n[i] <= '9') ? NP_DIGITS[+n[i]] : n[i];
    }
    return out;
  }
  function parseIso(s) { return Date.UTC(+s.slice(0, 4), +s.slice(5, 7) - 1, +s.slice(8, 10)); }
  function isoOf(ms) { return new Date(ms).toISOString().slice(0, 10); }
  function weekdayOf(adIso) { return new Date(parseIso(adIso) + 43200000).getUTCDay(); }
  function bsFromAd(adIso) {
    var t = parseIso(adIso);
    for (var i = 0; i < ROWS.length; i++) {
      var r = ROWS[i];
      var b1 = parseIso(r[1]);
      var days = 0;
      for (var j = 0; j < 12; j++) { days += r[2][j]; }
      if (t >= b1 && t < b1 + days * 86400000) {
        var doy = Math.floor((t - b1) / 86400000) + 1;
        var m = 1, d = doy;
        for (var k = 0; k < 12; k++) { if (d <= r[2][k]) { break; } d -= r[2][k]; m++; }
        return { y: r[0], m: m, d: d };
      }
    }
    return null;
  }
  function creditHtml() {
    return '<a class="nmiti-credit" href="' + SITE + '">via nMiti — open Bikram Sambat calendar</a>';
  }
  function render(host) {
    var root = host.shadowRoot || host.attachShadow({ mode: 'open' });
    var lang = host.getAttribute('data-nmiti-lang') || 'both';
    var nowAd = isoOf(Date.now() + NPT_MS);
    var nowBs = bsFromAd(nowAd);
    var css = ''
      + ':host{display:block;font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans Devanagari",sans-serif;max-width:34rem}'
      + '.nmiti-w{border:1px solid #8884;border-radius:10px;padding:.55rem .9rem}'
      + '.nmiti-d{display:block;font-weight:600}'
      + '.nmiti-credit{display:block;font-size:.75rem;opacity:.75;margin-top:.15rem;color:inherit}';
    var html = '<style>' + css + '</style><div class="nmiti-w">';
    if (nowBs) {
      var wd = weekdayOf(nowAd);
      var ay = +nowAd.slice(0, 4), am = +nowAd.slice(5, 7), ad = +nowAd.slice(8, 10);
      if (lang !== 'ne') {
        html += '<span class="nmiti-d">Today: ' + M_EN[nowBs.m - 1] + ' ' + nowBs.d + ', ' + nowBs.y + ' BS'
          + ' — ' + W_EN[wd] + ', ' + AD_EN[am - 1] + ' ' + ad + ', ' + ay + '</span>';
      }
      if (lang !== 'en') {
        html += '<span class="nmiti-d" lang="ne">' + (lang === 'ne' ? 'आज: ' : '') + M_NP[nowBs.m - 1] + ' ' + npNum(nowBs.d) + ', ' + npNum(nowBs.y)
          + ' — ' + W_NP[wd] + ', ' + AD_NP[am - 1] + ' ' + npNum(ad) + ', ' + npNum(ay) + '</span>';
      }
    } else {
      html += '<span class="nmiti-d">Today in Nepal (Bikram Sambat)</span>';
    }
    html += creditHtml() + '</div>';
    root.innerHTML = html;
  }
  function scan() {
    var nodes = document.querySelectorAll('[data-nmiti="today"]');
    for (var i = 0; i < nodes.length; i++) {
      try {
        render(nodes[i]);
      } catch (e) {
        try { nodes[i].innerHTML = '<a href="' + SITE + '">via nMiti — open Bikram Sambat calendar</a>'; } catch (e2) {}
      }
    }
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', scan);
  } else {
    scan();
  }
  setInterval(scan, 600000); // long-lived tabs roll over at Nepal midnight
})();
''';
}

/// The /embed/example.html page: how to embed the widget, the terms of
/// use, and a live demo.
String _embedExampleHtml(String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final body = '''
<h1>Embed the "today in BS" widget <span lang="ne">· आजको मिति विजेट</span></h1>
<p>Show today's Bikram Sambat date on your site - free, no tracking, no cookies, no external requests. The date is computed in the visitor's browser in Nepal Time (UTC+05:45) from nMiti's verified year rows, so embeds are correct at Nepal midnight without any server round-trip.</p>

<h2 id="snippet">Copy-paste snippet</h2>
<pre><code>&lt;div data-nmiti="today"&gt;&lt;/div&gt;
&lt;script src="https://namunaone.github.io/nMiti/embed/v1/widget.js" async&gt;&lt;/script&gt;</code></pre>
<p>Options: <code>data-nmiti-lang="both"</code> (default) — English + Nepali · <code>"en"</code> — English only · <code>"ne"</code> — Nepali only. Put the attribute on the target div.</p>

<h2 id="terms">Terms</h2>
<ul>
<li>Free to use on any site. The visible "via nMiti" credit link must stay - you may rephrase the text, but it must link to nMiti.</li>
<li>No tracking, no cookies, no external requests - the widget is a single static file and computes everything locally.</li>
<li>Versioned: this is v1 at <code>/embed/v1/</code>; a future v2 will be a separate path so v1 keeps working forever.</li>
<li>Data license: CC0-1.0 · code: MIT. If anything ever looks wrong, <a href="${urlBase}accuracy.html">we say so publicly</a>.</li>
</ul>

<h2 id="demo">Live demo</h2>
<div data-nmiti="today"></div>
<script src="v1/widget.js" async></script>
''';
  return _docShell(
      'Embed widget',
      'Free embeddable today in Bikram Sambat widget for any website - copy-paste, no tracking, correct at Nepal midnight by design.',
      urlBase, 'embed/example.html', body, shortSha);
}

/// The /docs page (HYA-402): the commons documentation pack rendered as
/// static semantic HTML. The page is regenerated from docs/*.md on every
/// build, so it can never drift from the repository files; crawlers and
/// AI agents find the data dictionary and methodology verbatim. Zero
/// client JavaScript - the entire page is pre-rendered.
String _docsPageHtml(String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final pack = <List<String>>[
    ['readme', 'Index', 'docs/README.md'],
    ['data-dictionary', 'Data dictionary', 'docs/data-dictionary.md'],
    ['methodology', 'Methodology', 'docs/methodology.md'],
    ['changelog', 'Changelog', 'docs/changelog.md'],
    ['errata', 'Errata', 'docs/errata.md'],
    ['provenance', 'Provenance manifest', 'docs/provenance-manifest.md'],
  ];
  final toc = [
    for (final p in pack) '<li><a href="#${p[0]}">${p[1]}</a></li>'
  ].join('\n');
  final articles = [
    for (final p in pack)
      '<article id="${p[0]}">\n${_mdToHtml(_readSourceFile(p[2]))}\n</article>'
  ].join('\n');
  final body = '''
<h1>Documentation <span lang="ne">· कागजात</span></h1>
<p>The commons documentation pack, rendered verbatim from <a href="https://github.com/namunaONE/nMiti/tree/main/docs">docs/</a> on every build - the repository files remain the single source of truth, so this page can never drift from them. Zero client JavaScript.</p>
<ol id="docs-toc">
$toc
</ol>
$articles
''';
  return _docShell(
      'Documentation',
      'The nMiti commons documentation pack rendered verbatim: data dictionary, methodology, changelog, public errata log and provenance manifest.',
      urlBase, 'docs.html', body, shortSha);
}

/// Minimal markdown-to-HTML renderer for the docs pack. Handles exactly
/// the constructs the docs use - ATX headings, paragraphs, ordered and
/// unordered lists, pipe tables, indented code blocks, horizontal rules,
/// and inline code/bold/italic/links - and HTML-escapes everything else.
/// Text is preserved verbatim; anything unrecognized falls through to a
/// paragraph, never dropped. Headings are demoted one level so the page
/// keeps a single h1.
String _mdToHtml(String md) {
  final lines = md.split('\n');
  final out = <String>[];
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final t = line.trim();
    if (t.isEmpty) {
      i++;
      continue;
    }
    final indent = line.length - line.trimLeft().length;
    if (indent >= 4) {
      // Indented code block.
      final buf = <String>[];
      while (i < lines.length) {
        final l = lines[i];
        if (l.trim().isEmpty) {
          buf.add('');
          i++;
        } else if (l.length - l.trimLeft().length >= 4) {
          buf.add(l.substring(4));
          i++;
        } else {
          break;
        }
      }
      while (buf.isNotEmpty && buf.last.isEmpty) {
        buf.removeLast();
      }
      out.add('<pre><code>${_htmlEscape(buf.join('\n'))}</code></pre>');
      continue;
    }
    final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(t);
    if (h != null) {
      final level = h.group(1)!.length + 1;
      out.add('<h$level>${_mdInline(h.group(2)!)}</h$level>');
      i++;
      continue;
    }
    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(t)) {
      out.add('<hr>');
      i++;
      continue;
    }
    if (t.startsWith('|') &&
        i + 1 < lines.length &&
        RegExp(r'^\|[\s:|-]+\|?$').hasMatch(lines[i + 1].trim())) {
      // Pipe table: header row, separator row, then body rows.
      String stripEdges(String row) {
        var c = row.trim();
        if (c.startsWith('|')) c = c.substring(1);
        if (c.endsWith('|')) c = c.substring(0, c.length - 1);
        return c;
      }
      final head = stripEdges(t)
          .split('|')
          .map((c) => '<th>${_mdInline(c.trim())}</th>')
          .join();
      i += 2;
      final rows = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        rows.add('<tr>'
            '${stripEdges(lines[i]).split('|').map((c) => '<td>${_mdInline(c.trim())}</td>').join()}'
            '</tr>');
        i++;
      }
      out.add(
          '<table><thead><tr>$head</tr></thead><tbody>${rows.join()}</tbody></table>');
      continue;
    }
    final ul = RegExp(r'^[-*]\s+(.*)$').firstMatch(t);
    final ol = RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(t);
    if (ul != null || ol != null) {
      final ordered = ol != null;
      final items = <String>[];
      while (i < lines.length) {
        final l = lines[i].trim();
        final m = ordered
            ? RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(l)
            : RegExp(r'^[-*]\s+(.*)$').firstMatch(l);
        if (m == null) break;
        items.add('<li>${_mdInline(m.group(1)!)}</li>');
        i++;
      }
      out.add(ordered ? '<ol>${items.join()}</ol>' : '<ul>${items.join()}</ul>');
      continue;
    }
    // Paragraph: consecutive plain lines.
    final para = <String>[];
    while (i < lines.length) {
      final l = lines[i];
      final lt = l.trim();
      if (lt.isEmpty || l.length - l.trimLeft().length >= 4) break;
      if (RegExp(r'^#{1,6}\s').hasMatch(lt) ||
          RegExp(r'^[-*]\s').hasMatch(lt) ||
          RegExp(r'^\d+[.)]\s').hasMatch(lt) ||
          lt.startsWith('|') ||
          RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(lt)) {
        break;
      }
      para.add(lt);
      i++;
    }
    out.add('<p>${_mdInline(para.join(' '))}</p>');
  }
  return out.join('\n');
}

/// Inline markdown: escape first, then code spans, links, bold, italic.
/// Relative links to sibling .md docs resolve on GitHub, not on the
/// served site, so they are pointed at the repository files.
String _mdInline(String s) {
  var out = _htmlEscape(s);
  out = out.replaceAllMapped(
      RegExp(r'`([^`]+)`'), (m) => '<code>${m.group(1)}</code>');
  out = out.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) {
    var href = m.group(2)!.trim();
    if (!href.startsWith('http')) {
      href = 'https://github.com/namunaONE/nMiti/blob/main/docs/$href';
    }
    return '<a href="$href">${m.group(1)}</a>';
  });
  out = out.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'), (m) => '<strong>${m.group(1)}</strong>');
  out = out.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'), (m) => '<em>${m.group(1)}</em>');
  return out;
}

String _htmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
String _notFoundHtml(String urlBase) => '''
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Not found | nMiti</title></head>
<body>
<main>
<h1>404 — not found</h1>
<p><a href="$urlBase">nMiti — today's date in Nepal</a> · <a href="${urlBase}api/v1/today.json">today.json</a></p>
</main>
</body>
</html>
''';

/// Reads a source data file from the repository (not the build output).
/// The build runs from the repo root; some runners use a package cwd.
String _readSourceFile(String rel) {
  for (final path in [rel, '../../' + rel]) {
    final f = File(path);
    if (f.existsSync()) return f.readAsStringSync();
  }
  throw StateError('Required source data file not found: ' + rel);
}

/// Build-time gate: the site refuses to deploy from a broken sankranti
/// table. Everything except the six pinned projection-tail defects is
/// fatal; the defects are the documented upstream month-length issue.
List<String> _validateSankrantiTable(
    BsCalendar full, List<SankrantiTableRow> rows) {
  final problems = <String>[];
  if (rows.length != 1512) {
    problems.add('sankranti table must have 1,512 rows, got ' +
        rows.length.toString());
  }
  if (rows.isNotEmpty &&
      (rows.first.bsYear != 1975 || rows.last.bsYear != 2100)) {
    problems.add('sankranti table must span BS 1975-2100');
  }
  for (final v in checkSankrantiWindows(full, rows)) {
    if (!kProjectionWindowDefects.contains(v.key)) {
      problems.add('sankranti window violation: ' + v.toString());
    }
  }
  return problems;
}

String _skTwo(int n) => n < 10 ? '0' + n.toString() : n.toString();

String _skUtc(DateTime t) =>
    t.year.toString() +
    '-' +
    _skTwo(t.month) +
    '-' +
    _skTwo(t.day) +
    'T' +
    _skTwo(t.hour) +
    ':' +
    _skTwo(t.minute) +
    ':00Z';

String _skNpt(DateTime t) {
  final wall = t.add(nepalTimeOffset);
  return wall.year.toString() +
      '-' +
      _skTwo(wall.month) +
      '-' +
      _skTwo(wall.day) +
      'T' +
      _skTwo(wall.hour) +
      ':' +
      _skTwo(wall.minute) +
      ':00+05:45';
}

/// api/v1/sankranti.json: the rasi the Sun is in now, and the next
/// sankranti, derived from the published table. minutes_until counts
/// from THIS BUILD; consumers should compute from instant_utc.
String _sankrantiJson(
    List<SankrantiTableRow> rows, String urlBase, String commitSha) {
  final now = DateTime.now().toUtc();
  var idx = 0;
  for (var i = 0; i < rows.length; i++) {
    if (!rows[i].ingressUtc.isAfter(now)) idx = i;
  }
  if (idx + 1 >= rows.length) {
    throw StateError('No next sankranti after the table end.');
  }
  final cur = rows[idx];
  final nxt = rows[idx + 1];
  final minutesUntil = nxt.ingressUtc.difference(now).inMinutes;
  return [
    '{',
    '  "as_of_utc": "' + _skUtc(now) + '",',
    '  "as_of_npt": "' + _skNpt(now) + '",',
    '  "current_rasi": {',
    '    "index": ' + cur.monthNo.toString() + ',',
    '    "rasi_en": "' + cur.rashiEn + '",',
    '    "rasi_ne": "' + cur.rashiNe + '",',
    '    "since_utc": "' + _skUtc(cur.ingressUtc) + '",',
    '    "since_npt": "' + _skNpt(cur.ingressUtc) + '",',
    '    "bs_year": ' + cur.bsYear.toString() + ',',
    '    "month_no": ' + cur.monthNo.toString() + ',',
    '    "month_en": "' + cur.monthEn + '"',
    '  },',
    '  "next": {',
    '    "rasi_en": "' + nxt.rashiEn + '",',
    '    "rasi_ne": "' + nxt.rashiNe + '",',
    '    "bs_year": ' + nxt.bsYear.toString() + ',',
    '    "month_no": ' + nxt.monthNo.toString() + ',',
    '    "month_en": "' + nxt.monthEn + '",',
    '    "instant_utc": "' + _skUtc(nxt.ingressUtc) + '",',
    '    "instant_npt": "' + _skNpt(nxt.ingressUtc) + '",',
    '    "minutes_until": ' + minutesUntil.toString() + ',',
    '    "date_provisional": ' +
        (nxt.dateProvisional ? 'true' : 'false') +
        ',',
    '    "evidence": "' + nxt.evidence + '"',
    '  },',
    '  "dataset": {',
    '    "rows": 1512,',
    '    "bs_range": "1975-2100",',
    '    "csv": "' + urlBase + 'data/sankranti_moments_1975_2100.csv",',
    '    "page": "' + urlBase + 'sankranti.html"',
    '  },',
    '  "generated_at_utc": "' + now.toIso8601String() + '",',
    '  "commit": "' + commitSha + '"',
    '}',
  ].join('\n');
}

/// The /sankranti page: now-card, accuracy contract, window law, era
/// law, the 24 cataloged exceptions and the 6 projection defects.
String _sankrantiPageHtml(
    List<SankrantiTableRow> rows, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final now = DateTime.now().toUtc();
  var idx = 0;
  for (var i = 0; i < rows.length; i++) {
    if (!rows[i].ingressUtc.isAfter(now)) idx = i;
  }
  if (idx + 1 >= rows.length) {
    throw StateError('No next sankranti after the table end.');
  }
  final cur = rows[idx];
  final nxt = rows[idx + 1];
  final minutesUntil = nxt.ingressUtc.difference(now).inMinutes;
  final daysUntil = minutesUntil ~/ 1440;
  final hoursUntil = (minutesUntil % 1440) ~/ 60;
  final minsRemain = minutesUntil % 60;
  final exceptions =
      rows.where((r) => r.eraLaw == 'pre_2036_exception').toList();
  final defects = rows.where((r) => r.eraLaw == 'projection_defect').toList();
  final provisional = rows.where((r) => r.dateProvisional).length;
  final d0 = rows.where((r) => r.startsOnDelta == 0).length;
  final d1 = rows.where((r) => r.startsOnDelta == 1).length;
  final dm1 = rows.where((r) => r.startsOnDelta == -1).length;
  final body = '''
<h1>Sankranti <span lang="ne">· संक्रान्ति</span></h1>
<p>The Bikram Sambat calendar is solar: every BS month begins when the Sun crosses into a new rasi (zodiac sign) - a precise instant called the sankranti. This page serves those instants for BS 1975-2100, computed by the open <code>nepali_sankranti</code> engine and re-verified by CI on every run.</p>

<h2 id="sankranti-now">Now</h2>
<p>The Sun is currently in <strong lang="ne">${cur.rashiNe}</strong> (${cur.rashiEn}), since ${_skNpt(cur.ingressUtc)} Nepal Time.</p>
<p>The next sankranti is <strong lang="ne">${nxt.rashiNe}</strong> (${nxt.rashiEn}) - the start of ${nxt.monthEn} ${nxt.bsYear} BS - at <strong>${_skNpt(nxt.ingressUtc)}</strong> NPT (${_skUtc(nxt.ingressUtc)} UTC), about ${daysUntil}d ${hoursUntil}h ${minsRemain}m from this build. This page is rebuilt every 6 hours: for a live countdown, use the instant from <a href="${urlBase}api/v1/sankranti.json">api/v1/sankranti.json</a>, not this page.</p>

<h2 id="accuracy-contract">Accuracy contract</h2>
<ul>
<li><strong>Declared tolerance: &plusmn;31 seconds maximum</strong> (~15s mean) against published panchang sankranti times - the residual measured across all 1,308 verified moments of the R5 calibration artifact. Published instants are minute-rounded.</li>
<li><strong>Engine:</strong> Meeus (<em>Astronomical Algorithms</em>, Ch.25) solar longitude plus the R5-calibrated Lahiri-family ayanamsa, solved to under a second. No third-party ephemeris.</li>
<li><strong>Verification:</strong> the engine reproduces all 1,308 artifact moments with identical NPT civil dates, deltas and weekdays; CI re-computes all 1,512 published rows from the canonical calendar on every run and the site refuses to deploy on any mismatch.</li>
<li><strong>Provisional dates:</strong> ${provisional} of 1,512 instants fall within 45 minutes of Nepal midnight and are flagged <code>date_provisional</code> in the data - a conservative honesty flag, not an error under the declared tolerance.</li>
</ul>

<h2 id="window-law">The window law</h2>
<p>Every BS month must start on the NPT civil date of its sankranti or the day after - never before it. The dataset records this as <code>starts_on_delta</code>:</p>
<table>
<tr><th>Delta</th><th>Meaning</th><th>Rows</th></tr>
<tr><td><code>0</code></td><td>Month starts on the ingress date.</td><td>${d0}</td></tr>
<tr><td><code>1</code></td><td>Month starts the day after the ingress.</td><td>${d1}</td></tr>
<tr><td><code>-1</code></td><td>Month starts <em>before</em> the ingress - only with an <code>era_law</code> label, never unlabeled.</td><td>${dm1}</td></tr>
</table>
<p><strong>Era law:</strong> <code>ok</code> (window holds) - the default; <code>pre_2036_exception</code> - the ${exceptions.length} cataloged pre-2036 consensus rows below; <code>projection_defect</code> - the ${defects.length} labeled projection-tail defects below. CI enforces the law over the entire calendar on every run.</p>

<h2 id="exceptions">The ${exceptions.length} cataloged exceptions</h2>
<p>All before-sankranti rows are pre-2036 consensus-class months, cataloged in the R5 verification experiment and pinned by test. They are data, not bugs: in these historical consensus rows the calendar month started a day before the computed ingress.</p>
<table>
<tr><th>BS year-month</th><th>Month</th><th>Rashi</th><th>Sankranti (NPT)</th></tr>
${exceptions.map((r) => '<tr><td>' + r.bsYear.toString() + '-' + r.monthNo.toString() + '</td><td>' + r.monthEn + '</td><td>' + r.rashiEn + '</td><td>' + _skNpt(r.ingressUtc) + '</td></tr>').join('\n')}
</table>

<h2 id="projection-defects">Projection-tail defects, stated plainly</h2>
<p>BS 2084-2100 month lengths are projections (only Baisakh 1 2084 is officially anchored). In ${defects.length} rows the projected month starts before its sankranti. These are upstream projection defects - preserved, labeled <code>projection_defect</code>, and pinned by test so any new one fails CI. They will be replaced with official data when Nepal publishes the BS 2084+ calendar. Not silently fixed.</p>
<table>
<tr><th>BS year-month</th><th>Month</th><th>Sankranti (NPT)</th></tr>
${defects.map((r) => '<tr><td>' + r.bsYear.toString() + '-' + r.monthNo.toString() + '</td><td>' + r.monthEn + '</td><td>' + _skNpt(r.ingressUtc) + '</td></tr>').join('\n')}
</table>
<p><strong>BS 2096 note:</strong> the 364-day projection-defect year keeps every sankranti window - that defect is in the year length, not the month boundaries.</p>

<h2 id="data">Data and API</h2>
<ul>
<li><a href="${urlBase}data/sankranti_moments_1975_2100.csv">Full CSV</a> - 1,512 rows, CC0-1.0, with provenance comments.</li>
<li><a href="${urlBase}api/v1/sankranti.json">api/v1/sankranti.json</a> - current rasi and next sankranti, stamped with the deploy commit.</li>
<li>Regenerate locally: <code>dart run nepali_sankranti:generate</code>.</li>
<li><a href="${urlBase}methodology.html">Methodology</a> - how the engine and dataset are verified.</li>
</ul>
''';
  return _docShell(
      'Sankranti moments',
      'Sidereal solar ingress (sankranti) moments for every BS month 1975-2100: current rasi, next sankranti, accuracy contract, era law and labeled defects.',
      urlBase,
      'sankranti.html',
      body,
      shortSha);
}

/// The /panchang page (R6a-3, HYA-416): today's lunar panchang details,
/// computed at BUILD TIME by the open nepali_panchang engine (full 60-term
/// Meeus Ch.47 moon, VSOP87D sun, Espenak-Meeus Delta T, per-source
/// ayanamsa profiles) - runtime compute, zero data files, zero client
/// JavaScript. Conventions are exposed, never silently picked: every limb
/// is shown at BOTH reference moments (udaya = the Hamro Patro display
/// convention; madhyahna = the BhaktiBharat convention), and every value
/// carries the engine provenance and evidence tier per the public
/// truth-data policy.
String _panchangPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final d = panchangFor(
      year: todayAd.year, month: todayAd.month, day: todayAd.day);
  String hm(DateTime t) => '${_skTwo(t.hour)}:${_skTwo(t.minute)}';
  final grahanState = _grahanDayState(todayAd);
  String when(DateTime t) {
    final later = t.isAfter(
        DateTime.utc(todayAd.year, todayAd.month, todayAd.day, 23, 59));
    final earlier = t
        .isBefore(DateTime.utc(todayAd.year, todayAd.month, todayAd.day));
    return '${hm(t)} NPT${later ? ' (next day)' : ''}${earlier ? ' (prev day)' : ''}';
  }
  String row(String limbNp, String limbEn, PanchangElement udaya,
          PanchangElement noon) =>
      '<tr><th lang="ne">${limbNp}</th><th>${limbEn}</th>'
      '<td>${udaya.name}<br><small>ends ${when(udaya.endsAtNpt)}</small></td>'
      '<td>${noon.name}<br><small>ends ${when(noon.endsAtNpt)}</small></td></tr>';
  final flags = <String>[];
  if (d.tithiVriddhi) {
    flags.add(
        '<li><strong>वृद्धि (vriddhi):</strong> the same tithi runs at two consecutive sunrises - a vriddhi day.</li>');
  }
  if (d.tithiKshaya) {
    flags.add(
        '<li><strong>क्षय (kshaya):</strong> a tithi ends between two sunrises without being present at either - a kshaya day.</li>');
  }
  if (d.tithiBorderline) {
    flags.add(
        '<li><strong>Borderline:</strong> a tithi boundary falls within half an hour of a sunrise - the day label is convention-sensitive.</li>');
  }
  final flagsHtml = flags.isEmpty
      ? '<p>No vriddhi, kshaya or borderline conditions on this day.</p>'
      : '<ul>\n${flags.join('\n')}\n</ul>';
  final body = '''
<h1>Panchang <span lang="ne">· आजको पञ्चाङ्ग</span></h1>
<p>Today's lunar details for Kathmandu (27.7172 N, 85.324 E), NPT (UTC+05:45), computed by the open <code>nepali_panchang</code> engine at build time - no precomputed data files. Nepal's publishers differ by display convention, so every limb is shown at both reference moments: <strong>उदय udaya</strong> (at sunrise; the Hamro Patro convention) and <strong>मध्याह्न madhyahna</strong> (at noon; the BhaktiBharat convention).</p>

<table id="panchang-tithi">
<tr><th></th><th></th><th>उदय · at sunrise</th><th>मध्याह्न · at noon</th></tr>
${row('तिथि', 'Tithi', d.tithiAtUdaya, d.tithiAtNoon)}
${row('नक्षत्र', 'Nakshatra', d.nakshatraAtUdaya, d.nakshatraAtNoon)}
${row('योग', 'Yoga', d.yogaAtUdaya, d.yogaAtNoon)}
${row('करण', 'Karana', d.karanaAtUdaya, d.karanaAtNoon)}
</table>

<p id="panchang-sunrise"><strong>सूर्योदय · Sunrise:</strong> ${hm(d.sunriseNpt)} NPT</p>
<p id="panchang-sutak"><strong>सूतक · Sutak:</strong> ${grahanState.sutakActive ? 'ACTIVE today - see the <a href="grahan.html">grahan page</a> for the window and exemptions.' : 'not active today.'}</p>

<h2>वृद्धि / क्षय · vriddhi, kshaya, borderline</h2>
$flagsHtml

<h2 id="panchang-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> ${d.provenance}</li>
<li><strong>Evidence:</strong> ${d.evidenceTier}</li>
<li><strong>Accuracy:</strong> minute-level parity with the locked BhaktiBharat and Hamro Patro golden corpora (226 boundary receipts), enforced by CI on every change. See <a href="${urlBase}methodology.html">methodology</a> and <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a>.</li>
<li><strong>Festivals:</strong> served on the <a href="festivals.html">festivals page</a> and in the <code>festivals</code> block of today.json - every day-choosing convention exposed, never silently picked.</li>
</ul>
''';
  return _docShell(
      'Panchang today',
      'Today\'s lunar panchang for Kathmandu: tithi, nakshatra, yoga, karana and sunrise, engine-computed with both udaya and madhyahna display conventions.',
      urlBase,
      'panchang.html',
      body,
      shortSha);
}

/// L6 grahan display state (HYA-421 step 5): the grahan events whose
/// visible, sutak or eclipse span touches the given NPT civil day,
/// and whether sutak is active at the build instant. A 12-hour solar
/// sutak can begin the previous evening, so the query unions
/// grahanNear over the previous, current and next civil day and
/// deduplicates by greatest instant - mapping sutak windows onto
/// Nepali civil days is this layer's job per the grahan module doc.
class _GrahanDayState {
  final List<GrahanEvent> touching;
  final bool sutakActive;
  const _GrahanDayState(this.touching, this.sutakActive);
}

_GrahanDayState _grahanDayState(DateTime todayAd) {
  final now = DateTime.now().toUtc();
  final dayStartUtc = DateTime.utc(todayAd.year, todayAd.month, todayAd.day)
      .subtract(nepalTimeOffset);
  final dayEndUtc = dayStartUtc.add(const Duration(days: 1));
  final seen = <String>{};
  final touching = <GrahanEvent>[];
  var sutakActive = false;
  bool overlaps(DateTime? startUtc, DateTime? endUtc) =>
      startUtc != null &&
      endUtc != null &&
      startUtc.isBefore(dayEndUtc) &&
      endUtc.isAfter(dayStartUtc);
  for (final delta in [-1, 0, 1]) {
    final d = DateTime.utc(todayAd.year, todayAd.month, todayAd.day)
        .add(Duration(days: delta));
    final e = grahanNear(d.year, d.month, d.day);
    if (e == null) continue;
    if (!seen.add(e.jdUtGreatest.toStringAsFixed(5))) continue;
    final sutakStartUtc = e.sutakStartNpt?.subtract(nepalTimeOffset);
    final sutakEndUtc = e.sutakEndNpt?.subtract(nepalTimeOffset);
    final visibleStartUtc = e.visibleStartNpt?.subtract(nepalTimeOffset);
    final visibleEndUtc = e.visibleEndNpt?.subtract(nepalTimeOffset);
    final eclipseStartUtc = e.greatestNpt.subtract(nepalTimeOffset);
    final eclipseEndUtc = e.mokshaNpt.subtract(nepalTimeOffset);
    if (overlaps(sutakStartUtc, sutakEndUtc) ||
        overlaps(visibleStartUtc, visibleEndUtc) ||
        overlaps(eclipseStartUtc, eclipseEndUtc)) {
      touching.add(e);
    }
    if (sutakStartUtc != null &&
        sutakEndUtc != null &&
        !sutakStartUtc.isAfter(now) &&
        now.isBefore(sutakEndUtc)) {
      sutakActive = true;
    }
  }
  return _GrahanDayState(touching, sutakActive);
}

/// The Devanagari rendering of an event's traditional name: the
/// global class plus the grastodit observation state.
String _grahanNameNp(GrahanEvent e) {
  final String base;
  if (e.kind == GrahanKind.suryaGrahan) {
    base = e.grahanClass == GrahanClass.khagras
        ? 'खग्रास सूर्य ग्रहण'
        : 'खण्डग्रास सूर्य ग्रहण';
  } else if (e.grahanClass == GrahanClass.khagras) {
    base = 'खग्रास चन्द्र ग्रहण';
  } else if (e.grahanClass == GrahanClass.khandagras) {
    base = 'खण्डग्रास चन्द्र ग्रहण';
  } else {
    base = 'उपचय चन्द्र ग्रहण (ग्रहण नगनिने)';
  }
  return e.risesEclipsed ? '$base (ग्रस्तोदित)' : base;
}

/// One grahan event as a JSON object body. Every key is always
/// emitted (null when the window does not apply) so the site
/// contract markers stay date-stable; NPT wall stamps are
/// minute-truncated like the panchang block.
String _grahanEventJson(String ind, GrahanEvent e) {
  String isoNpt(DateTime t) =>
      '${_iso(t)}T${_skTwo(t.hour)}:${_skTwo(t.minute)}:00+05:45';
  String q(DateTime? t) => t == null ? 'null' : '"${isoNpt(t)}"';
  final sutakHours =
      e.kind == GrahanKind.suryaGrahan ? sutakSolarHours : sutakLunarHours;
  final sutakStart = e.sutakStartNpt;
  final sutakEnd = e.sutakEndNpt;
  final String sutak;
  if (sutakStart == null || sutakEnd == null) {
    sutak = 'null';
  } else {
    sutak = '{\n'
        '$ind  "hours": $sutakHours,\n'
        '$ind  "start_npt": "${isoNpt(sutakStart)}",\n'
        '$ind  "end_npt": "${isoNpt(sutakEnd)}"\n'
        '$ind}';
  }
  final obscuration = e.obscuration;
  return [
    '$ind"date_iso": "${_iso(e.greatestNpt)}",',
    '$ind"kind": "${e.kind == GrahanKind.suryaGrahan ? 'surya_grahan' : 'chandra_grahan'}",',
    '$ind"grahan_class": "${e.grahanClass.name}",',
    '$ind"nepali_name": "${e.nepaliName}",',
    '$ind"nepali_name_np": "${_grahanNameNp(e)}",',
    '$ind"kept_as_grahan": ${e.keptAsGrahan},',
    '$ind"visible_at_location": ${e.visibleAtLocation},',
    '$ind"rises_eclipsed": ${e.risesEclipsed},',
    '$ind"sets_eclipsed": ${e.setsEclipsed},',
    '$ind"greatest_npt": "${isoNpt(e.greatestNpt)}",',
    '$ind"moksha_npt": "${isoNpt(e.mokshaNpt)}",',
    '$ind"visible_start_npt": ${q(e.visibleStartNpt)},',
    '$ind"visible_end_npt": ${q(e.visibleEndNpt)},',
    '$ind"sutak": $sutak,',
    '$ind"magnitude": ${e.magnitude},',
    '$ind"obscuration": ${obscuration ?? 'null'},',
    '$ind"evidence_tier": "${e.evidenceTier}"',
  ].join('\n');
}

/// The grahan block of today.json. The keys - "grahan", "today",
/// "sutak_active", "next" - always serialize on every build, so
/// the site contract markers are date-stable on eclipse days and on
/// quiet days alike.
String _grahanBlock(DateTime todayAd, String urlBase) {
  final state = _grahanDayState(todayAd);
  final next = nextGrahanAfter(todayAd.year, todayAd.month, todayAd.day);
  final today = state.touching.isEmpty ? null : state.touching.first;
  final todayJson = today == null
      ? 'null'
      : '{\n${_grahanEventJson('      ', today)}\n    }';
  final nextJson = next == null
      ? 'null'
      : '{\n${_grahanEventJson('      ', next)}\n    }';
  return '{\n'
      '    "note": "engine-computed at build time; sutak windows are mapped onto Nepali civil days by this layer",\n'
      '    "today": $todayJson,\n'
      '    "sutak_active": ${state.sutakActive},\n'
      '    "next": $nextJson,\n'
      '    "details": "${urlBase}grahan.html"\n'
      '  }';
}

/// The /grahan page (HYA-421 step 5): today's sutak state, the next
/// grahan, the upcoming eclipses at Kathmandu, and the full sutak
/// rule and convention-collision table - every rule
/// receipt-anchored, every collision exposed, never silently
/// picked, per the public truth-data policy.
String _grahanPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final state = _grahanDayState(todayAd);
  final next = nextGrahanAfter(todayAd.year, todayAd.month, todayAd.day);
  final upcoming = [
    ...grahanInYear(todayAd.year).where((e) => e.greatestNpt
        .isAfter(DateTime.utc(todayAd.year, todayAd.month, todayAd.day))),
    ...grahanInYear(todayAd.year + 1),
  ];
  String hm(DateTime t) => '${_skTwo(t.hour)}:${_skTwo(t.minute)}';
  final todaySection = state.touching.isEmpty
      ? '<p>No grahan, eclipse phase or sutak window touches today.</p>'
      : [
          for (final e in state.touching)
            '<p><strong>${e.nepaliName}</strong> touches today. Sutak active at this build: ${state.sutakActive ? 'yes' : 'no'}. Full details in <a href="${urlBase}api/v1/today.json">today.json</a>.</p>'
        ].join('\n');
  final String nextCard;
  if (next == null) {
    nextCard = '<p>No grahan is computed within the next twelve years.</p>';
  } else {
    final sutakLine = (next.sutakStartNpt == null || next.sutakEndNpt == null)
        ? '<li><strong>सूतक · Sutak:</strong> none (the eclipse is not kept as a grahan or not visible at Kathmandu)</li>'
        : '<li><strong>सूतक · Sutak:</strong> ${_iso(next.sutakStartNpt!)} ${hm(next.sutakStartNpt!)} to ${hm(next.sutakEndNpt!)} NPT (${next.kind == GrahanKind.suryaGrahan ? sutakSolarHours : sutakLunarHours} h before the local first visible contact)</li>';
    nextCard = [
      '<p><strong>${next.nepaliName}</strong> <span lang="ne">${_grahanNameNp(next)}</span></p>',
      '<ul>',
      '<li><strong>मिति · Date of greatest eclipse:</strong> ${_iso(next.greatestNpt)} at ${hm(next.greatestNpt)} NPT</li>',
      '<li><strong>वर्ग · Class:</strong> ${next.grahanClass.name}${next.keptAsGrahan ? '' : ' - not kept as a grahan (upachhaya, C5)'}</li>',
      '<li><strong>काठमाडौंमा देखिने? · Visible at Kathmandu:</strong> ${next.visibleAtLocation ? 'yes' : 'no'}${next.risesEclipsed ? ' - grastodit: rises already eclipsed' : ''}${next.setsEclipsed ? ' - sets before moksha' : ''}</li>',
      sutakLine,
      '<li><strong>मोक्ष · Moksha:</strong> ${hm(next.mokshaNpt)} NPT</li>',
      '<li><strong>Magnitude:</strong> ${next.magnitude}${next.obscuration == null ? '' : ' (obscuration ${next.obscuration})'}</li>',
      '</ul>',
    ].join('\n');
  }
  final upcomingRows = [
    for (final e in upcoming)
      '<tr><td>${_iso(e.greatestNpt)}</td>'
      '<td>${e.nepaliName}<br><span lang="ne">${_grahanNameNp(e)}</span></td>'
      '<td>${e.grahanClass.name}</td>'
      '<td>${e.visibleAtLocation ? 'yes' : 'no'}</td>'
      '<td>${hm(e.greatestNpt)}</td>'
      '<td>${e.sutakStartNpt == null ? '-' : hm(e.sutakStartNpt!) + ' to ' + hm(e.sutakEndNpt!)}</td>'
      '<td>${hm(e.mokshaNpt)}</td>'
      '<td>${e.magnitude}</td></tr>'
  ].join('\n');
  final conv = next?.conventions ?? const <String, String>{};
  final convLabels = <String, String>{
    'sutakHours': 'Sutak hours',
    'sutakAnchor': 'Sutak anchor (C4)',
    'sutakEnd': 'Sutak end',
    'grastodit': 'Grastodit (rises eclipsed)',
    'upachhaya': 'Upachhaya (C5)',
    'naming': 'Naming (C6)',
    'annularNaming': 'Annular naming',
    'belowHorizonSolar': 'Below-horizon solar grazes',
    'publisherDivergence': 'Publisher divergence (C2)',
    'sutakHoursReversedFaq': 'Reversed-hours FAQ (C3)',
    'shadowEnlargement': 'Shadow enlargement (C1)',
    'sutakExemptions': 'Sutak exemptions',
  };
  final convRows = [
    for (final entry in convLabels.entries)
      '<tr><th>${entry.value}</th><td>${conv[entry.key] ?? '(not recorded)'}</td></tr>'
  ].join('\n');
  final body = '''
<h1>Grahan <span lang="ne">· ग्रहण</span></h1>
<p>Eclipses (grahan) for the Kathmandu anchor (27.7172 N, 85.324 E), NPT (UTC+05:45), computed at build time by the open <code>nepali_panchang</code> engine and anchored to dated receipts. An eclipse that is NOT visible at Kathmandu is still shown, flagged - never hidden; a penumbral lunar eclipse (upachhaya) is shown but not kept as a grahan.</p>

<h2 id="grahan-today">आज · Today</h2>
$todaySection

<h2 id="grahan-next">अर्को ग्रहण · Next grahan</h2>
$nextCard

<h2 id="grahan-upcoming">आउँदै ग्रहणहरू · Upcoming eclipses</h2>
<p>Every grahan the engine computes for ${todayAd.year} and ${todayAd.year + 1} at Kathmandu, in time order. Sutak windows can cross Nepali civil midnight.</p>
<table>
<tr><th>Date</th><th>Name</th><th>Class</th><th>Visible at KTM</th><th>Greatest (NPT)</th><th>Sutak (NPT)</th><th>Moksha (NPT)</th><th>Magnitude</th></tr>
$upcomingRows
</table>

<h2 id="grahan-conventions">सूतक नियम र मतभेद · Sutak rules and convention collisions</h2>
<p>Every rule below is receipt-anchored (BhaktiBharat, PanchangBodh, HinduCalculator, nepalipatro, drik - the grahan shastra corpus). Where Nepal's publishers disagree, the collision is decoded and shown, never silently picked.</p>
<table>
<tr><th>Rule</th><th>What nMiti serves and why</th></tr>
$convRows
</table>

<h2 id="grahan-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> ${next?.provenance ?? 'The nepali_panchang grahan module.'}</li>
<li><strong>Evidence:</strong> ${next?.evidenceTier ?? ''}</li>
<li><strong>Verification:</strong> the Dart CI gate over the grahan shastra receipts corpus (six lunar events 2026-2028 banded against the timeanddate Kathmandu stage tables) and the NASA solar catalog 2026-2030; Swiss Ephemeris local-circumstances channels (solar_local, lunar_local - provisional 300/120 s bands) re-solve the events in CI. See <a href="${urlBase}methodology.html">methodology</a> and <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a>.</li>
<li><strong>Receipts:</strong> <a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/grahan_shastra_receipts.json">grahan_shastra_receipts.json</a> · <a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/solar_kathmandu_receipts.json">solar_kathmandu_receipts.json</a> · <a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/nasa_solar_2026_2030.json">nasa_solar_2026_2030.json</a>.</li>
<li><strong>Exemptions, noted - never computed:</strong> ${next?.exemptionsNote ?? 'Children, the sick and the elderly traditionally observe one prahar; pregnant women are advised precautions.'}</li>
</ul>
''';
  return _docShell(
      'Grahan (eclipses)',
      'Eclipses for Kathmandu: next grahan, sutak windows, upcoming eclipses and every convention collision - engine-computed, receipt-anchored, never copied.',
      urlBase,
      'grahan.html',
      body,
      shortSha);
}

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
<li><strong>Engine:</strong> the nMiti nepali_panchang festival battery on the runtime lunar engine (60-term Meeus Ch.47 moon, VSOP87D sun, Espenak-Meeus Delta T); festivals are data, conventions are code.</li>
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

/// The masa block of today.json (R6f): the amanta lunar month
/// containing today by udaya attribution. Lunar months are a separate
/// stream from the sankranti-anchored BS solar months - the note says
/// exactly that, so the two month systems can never be conflated.
String _masaBlock(DateTime todayAd, String urlBase) {
  final m = masaOf(year: todayAd.year, month: todayAd.month, day: todayAd.day);
  String isoNpt(DateTime t) =>
      '${_iso(t)}T${_skTwo(t.hour)}:${_skTwo(t.minute)}:00+05:45';
  final sankrantis = [
    for (var i = 0; i < m.sankrantiMomentsNpt.length; i++)
      '{"rasi_index": ${m.sankrantiRasis[i]}, '
      '"instant_npt": "${isoNpt(m.sankrantiMomentsNpt[i])}"}'
  ].join(', ');
  return '{\n'
      '    "note": "amanta lunar month (new moon to new moon) containing '
      'today by udaya attribution - a separate stream from the '
      'sankranti-anchored BS solar month",\n'
      '    "month_number": ${m.monthNumber},\n'
      '    "month_name": "${m.monthName}",\n'
      '    "is_adhika": ${m.isAdhika},\n'
      '    "is_kshaya": ${m.isKshaya},\n'
      '    "begins_at": "${isoNpt(m.beginsAtNpt)}",\n'
      '    "ends_at": "${isoNpt(m.endsAtNpt)}",\n'
      '    "sankrantis": [$sankrantis],\n'
      '    "provenance": "${m.provenance}",\n'
      '    "evidence_tier": "${m.evidenceTier}",\n'
      '    "details": "${urlBase}masa.html"\n'
      '  }';
}

/// The muhurta block of today.json (R6f): the daily windows, the
/// choghadiya and the horas, all computed by the muhurta layer from
/// the engine sunrise/sunset. Convention collisions serialize as
/// data - Dur Muhurtam is stated as not served, never silently
/// dropped.
String _muhurtaBlock(DateTime todayAd, String urlBase) {
  final mu = muhurtaFor(
      year: todayAd.year, month: todayAd.month, day: todayAd.day);
  String isoNpt(DateTime t) =>
      '${_iso(t)}T${_skTwo(t.hour)}:${_skTwo(t.minute)}:00+05:45';
  String windowJson(String key, MuhurtaWindow w) =>
      '    "$key": {"name": "${w.name}", "begins_at": '
      '"${isoNpt(w.beginsAtNpt)}", "ends_at": "${isoNpt(w.endsAtNpt)}"}';
  String slotArray(String key, List<ChoghadiyaSlot> slots) {
    final items = [
      for (final s in slots)
        '{"type": "${s.type}", "lord": "${s.lord}", '
        '"begins_at": "${isoNpt(s.beginsAtNpt)}", '
        '"ends_at": "${isoNpt(s.endsAtNpt)}"}'
    ].join(',\n      ');
    return '    "$key": [\n      $items\n    ]';
  }
  String horaArray(List<HoraSlot> slots) {
    final items = [
      for (final s in slots)
        '{"lord": "${s.lord}", "begins_at": '
        '"${isoNpt(s.beginsAtNpt)}", "ends_at": '
        '"${isoNpt(s.endsAtNpt)}", "is_daylight": ${s.isDaylight}}'
    ].join(',\n      ');
    return '    "horas": [\n      $items\n    ]';
  }
  final conventions = [
    for (final k in mu.conventions.keys)
      '      "$k": "${mu.conventions[k]}"'
  ].join(',\n');
  return '{\n'
      '    "note": "engine-computed at build time; window boundaries '
      'inherit the sunrise convention divergence between publishers",\n'
      '    "sunrise_npt": "${isoNpt(mu.sunriseNpt)}",\n'
      '    "sunset_npt": "${isoNpt(mu.sunsetNpt)}",\n'
      '${windowJson('rahu_kalam', mu.rahuKalam)},\n'
      '${windowJson('yamaganda', mu.yamaganda)},\n'
      '${windowJson('gulika', mu.gulika)},\n'
      '${windowJson('abhijit_muhurta', mu.abhijitMuhurta)},\n'
      '${windowJson('brahma_muhurta', mu.brahmaMuhurta)},\n'
      '${windowJson('brahma_muhurta_fixed', mu.brahmaMuhurtaFixed)},\n'
      '${slotArray('choghadiya_day', mu.choghadiyaDay)},\n'
      '${slotArray('choghadiya_night', mu.choghadiyaNight)},\n'
      '${horaArray(mu.horas)},\n'
      '    "conventions": {\n$conventions\n    },\n'
      '    "provenance": "${mu.provenance}",\n'
      '    "evidence_tier": "${mu.evidenceTier}",\n'
      '    "details": "${urlBase}muhurta.html"\n'
      '  }';
}

/// The /masa page (R6f): the amanta lunar month containing today, the
/// coming amanta year, and the naming/adhika/kshaya conventions with
/// their receipts. The BS solar months live on sankranti.html; this
/// page states the distinction instead of conflating the two streams.
String _masaPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final today = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final current =
      masaOf(year: todayAd.year, month: todayAd.month, day: todayAd.day);
  final months = masaList(
      startNpt: today.subtract(const Duration(days: 45)),
      endNpt: today.add(const Duration(days: 370)));
  String dt(DateTime t) =>
      '${_iso(t)} ${_skTwo(t.hour)}:${_skTwo(t.minute)} NPT';
  final currentSankrantis = current.sankrantiMomentsNpt.isEmpty
      ? 'none inside this month'
      : [
          for (var i = 0; i < current.sankrantiMomentsNpt.length; i++)
            'ingress into rashi ${current.sankrantiRasis[i]} of 12 '
            '(Mesha = 1, Meena = 12) at ${dt(current.sankrantiMomentsNpt[i])}'
        ].join(' and ');
  final currentCard = [
    '<p><strong>${current.monthName} '
    '<span lang="ne">${bsMonthNameNp(current.monthNumber)}</span></strong>'
        '${current.isAdhika ? ' — <strong>अधिक मास · adhika (intercalated) month</strong>' : ''}'
        '${current.isKshaya ? ' — <strong>क्षय मास · kshaya (elided) month</strong>' : ''}</p>',
    '<ul>',
    '<li><strong>आरम्भ · Begins (new moon):</strong> ${dt(current.beginsAtNpt)}</li>',
    '<li><strong>अन्त्य · Ends (next new moon):</strong> ${dt(current.endsAtNpt)}</li>',
    '<li><strong>भित्रका सङ्क्रान्ति · Sankrantis inside:</strong> $currentSankrantis</li>',
    '</ul>',
  ].join('\n');
  final rows = [
    for (final m in months)
      '<tr><td>${_iso(m.beginsAtNpt)}</td>'
      '<td>${m.monthName} <span lang="ne">${bsMonthNameNp(m.monthNumber)}</span></td>'
      '<td>${m.isAdhika ? 'yes' : '-'}</td>'
      '<td>${m.isKshaya ? 'yes' : '-'}</td>'
      '<td>${m.sankrantiMomentsNpt.isEmpty ? '-' : [for (var i = 0; i < m.sankrantiMomentsNpt.length; i++) _iso(m.sankrantiMomentsNpt[i])].join(', ')}</td>'
      '<td>${_iso(m.endsAtNpt)}</td></tr>'
  ].join('\n');
  final body = '''
<h1>Masa · <span lang="ne">मास</span> — the lunar months</h1>
<p>The amanta lunar months of the nMiti engine: new moon to new moon, each named after the solar month that ends within it, with adhika (intercalated) and kshaya (elided) months detected at runtime. Computed, not copied — the new moons come from the wrap-safe tithi solver, the sankrantis from the VSOP87D sun on the same calibrated constants as the sankranti pages.</p>

<h2 id="masa-current">आजको मास · The lunar month containing today</h2>
$currentCard
<p>Today belongs to this month by udaya attribution — the month whose span contains this sunrise, the same convention the panchang day uses.</p>

<h2 id="masa-year">आगामी मासहरू · The coming amanta year</h2>
<p>Every lunar month intersecting the next 370 days, starting from the month that contains today. Adhika months carry the name of the month that follows them; kshaya months take the name of their first contained sankranti.</p>
<table>
<tr><th>Begins (new moon)</th><th>Month</th><th>Adhika</th><th>Kshaya</th><th>Sankranti(s) inside</th><th>Ends (next new moon)</th></tr>
$rows
</table>

<h2 id="masa-conventions">नियम · Naming and detection rules</h2>
<p>Lunar months and BS solar months are two coexisting streams: the solar months live on <a href="${urlBase}sankranti.html">sankranti.html</a>, anchored to sidereal solar ingress; the amanta lunar months here are anchored to new moons. In BS 2083, lunar Chaitra ran Mar 19 – Apr 17 2026 while solar Baisakh began Apr 14.</p>
<table>
<tr><th>Rule</th><th>Definition</th><th>Receipt</th></tr>
<tr><td>Amanta month</td><td>new moon to new moon; a day belongs to the month whose span contains its sunrise (udaya attribution)</td><td>the same convention the panchang day uses</td></tr>
<tr><td>Naming</td><td>a lunar month is named after the solar month that ENDS within it: the Mesha sankranti falls in Chaitra (12), Vrishabha in Baisakh (1), ..., Meena in Falgun (11)</td><td>Ghatasthapana Oct 11 2026 = Ashwin Shukla Pratipada, in the lunar month containing the Tula sankranti</td></tr>
<tr><td>Adhika (intercalated)</td><td>a lunar month containing no sankranti; it takes the name of the month that follows it</td><td>Adhika Jestha 2026: amanta May 17 – Jun 15/16 (Nepal Panchanga Decision Committee via Nepal News; hindutone; hindupad)</td></tr>
<tr><td>Kshaya (elided)</td><td>a lunar month containing two sankrantis; it takes the name of its first contained sankranti. None occurs in 2026–2029; the naming branch is cross-checked by the tithi_engine oracle in CI and needs a dated publisher receipt before it is served as truth</td><td>honesty rule: no convention ships without a receipt</td></tr>
</table>

<h2 id="masa-receipts">प्रमाण · Receipts and verification</h2>
<ul>
<li>VS 2083 carries 13 amanta lunar months (the Adhika Jestha year) — the engine reproduces both the 13-month year and the adhika window.</li>
<li>Day-by-day month-name agreement with the Swiss-anchored tithi_engine oracle in CI (<code>masa_oracle_test.dart</code>), dense at the adhika boundaries (May 15–20 and Jun 14–18, 2026).</li>
<li><code>masa_test.dart</code> pins the new-moon instants and the naming anchors on every change; the new moon of Nov 9 2026, 12:47 NPT is exact against the locked lunar corpus.</li>
</ul>
<p><strong>Provenance:</strong> ${current.provenance}</p>
<p><strong>Evidence tier:</strong> ${current.evidenceTier}</p>
<p>Machine-readable: the <a href="${urlBase}api/v1/today.json">today.json</a> <code>masa</code> block carries the current month with adhika/kshaya flags and NPT stamps.</p>
''';
  return _docShell(
      'Masa (lunar months)',
      'Nepal amanta lunar months from the nMiti engine: the month containing today, the coming amanta year, adhika/kshaya detection and every naming rule receipt-anchored.',
      urlBase,
      'masa.html',
      body,
      shortSha);
}

/// The /muhurta page (R6f): today's muhurta windows, the choghadiya
/// and hora tables, and the full convention-collision table with the
/// receipt corpus. Every window is engine-computed from the engine
/// sunrise/sunset; collisions are exposed, never silently picked.
String _muhurtaPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final mu = muhurtaFor(
      year: todayAd.year, month: todayAd.month, day: todayAd.day);
  String dt(DateTime t) =>
      '${_iso(t)} ${_skTwo(t.hour)}:${_skTwo(t.minute)} NPT';
  String row(String label, MuhurtaWindow w) =>
      '<tr><td>$label</td><td>${dt(w.beginsAtNpt)}</td>'
      '<td>${dt(w.endsAtNpt)}</td></tr>';
  final windowsRows = [
    row('Rahu Kalam', mu.rahuKalam),
    row('Yamaganda', mu.yamaganda),
    row('Gulika', mu.gulika),
    row('Abhijit Muhurta', mu.abhijitMuhurta),
    row('Brahma Muhurta (computed, 14th of the night/15)', mu.brahmaMuhurta),
    row('Brahma Muhurta (BhaktiBharat fixed 96/48 min)', mu.brahmaMuhurtaFixed),
  ].join('\n');
  String chogRows(List<ChoghadiyaSlot> slots) => [
        for (final s in slots)
          '<tr><td>${s.type}</td><td>${s.lord}</td>'
          '<td>${dt(s.beginsAtNpt)}</td><td>${dt(s.endsAtNpt)}</td></tr>'
      ].join('\n');
  final horaRows = [
    for (final s in mu.horas)
      '<tr><td>${s.isDaylight ? 'day' : 'night'}</td><td>${s.lord}</td>'
      '<td>${dt(s.beginsAtNpt)}</td><td>${dt(s.endsAtNpt)}</td></tr>'
  ].join('\n');
  final convLabels = <String, String>{
    'rahuYamaGulika': 'Rahu Kalam / Yamaganda / Gulika',
    'brahma': 'Brahma muhurta',
    'abhijit': 'Abhijit muhurta',
    'choghadiya': 'Choghadiya',
    'hora': 'Hora',
    'durMuhurta': 'Dur Muhurtam',
    'varjyamAmrit': 'Varjyam / Amrit Kalam',
  };
  final convRows = [
    for (final k in mu.conventions.keys)
      '<tr><td><code>$k</code> — ${convLabels[k] ?? k}</td>'
      '<td>${mu.conventions[k]}</td></tr>'
  ].join('\n');
  final body = '''
<h1>Muhurta · <span lang="ne">मुहूर्त</span> — today's windows</h1>
<p>Engine-computed from the engine's own USNO sunrise and sunset: Rahu Kalam, Yamaganda and Gulika (weekday parts of daylight/8), Abhijit (the 8th of 15 daylight muhurtas), Brahma muhurta, the day and night choghadiya and the 24 unequal horas. Every rule is receipt-anchored to the BhaktiBharat Kathmandu corpus (Nov 2026, 18 days — Rahu/Yamaganda/Gulika windows reproduce within 0.9 min of the 8-part rule); every convention collision is exposed, never silently picked.</p>
<p><strong>Sunrise:</strong> ${dt(mu.sunriseNpt)} · <strong>Sunset:</strong> ${dt(mu.sunsetNpt)}</p>

<h2 id="muhurta-today">आजका मुहूर्त · Today's windows</h2>
<table>
<tr><th>Window</th><th>Begins</th><th>Ends</th></tr>
$windowsRows
</table>

<h2 id="muhurta-choghadiya">चौघडिया · Choghadiya</h2>
<p>Day parts run sunrise to sunset; night parts run sunset to the next sunrise. Dates are shown because night parts can cross midnight.</p>
<p><strong>Day</strong></p>
<table>
<tr><th>Type</th><th>Lord</th><th>Begins</th><th>Ends</th></tr>
${chogRows(mu.choghadiyaDay)}
</table>
<p><strong>Night</strong></p>
<table>
<tr><th>Type</th><th>Lord</th><th>Begins</th><th>Ends</th></tr>
${chogRows(mu.choghadiyaNight)}
</table>

<h2 id="muhurta-horas">होरा · Horas</h2>
<p>The 24 unequal horas (daylight/12 + night/12, sunrise to the next sunrise) — astronomically consistent, served as the primary convention. The temple-tradition fixed 60-minute hora is a documented collision, not served as truth.</p>
<table>
<tr><th>Part</th><th>Lord</th><th>Begins</th><th>Ends</th></tr>
$horaRows
</table>

<h2 id="muhurta-conventions">नियम · Conventions and collisions</h2>
<table>
<tr><th>Rule</th><th>What we compute (and why)</th></tr>
$convRows
</table>

<h2 id="muhurta-receipts">प्रमाण · Receipts</h2>
<ul>
<li><a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/muhurta_receipts_2026_11.json">muhurta_receipts_2026_11.json</a> — 18 BhaktiBharat Kathmandu days (Nov 5–22 2026) plus a hinducalculator spot day; the weekday part tables, the choghadiya lord cycles and the window arithmetic, all receipt-anchored.</li>
<li><strong>Engine gates:</strong> <code>muhurta_receipts_test.dart</code> (fixture integrity + rule arithmetic) and <code>muhurta_calibration_test.dart</code> (engine windows banded against the receipts) run on every change.</li>
</ul>
<p><strong>Provenance:</strong> ${mu.provenance}</p>
<p><strong>Evidence tier:</strong> ${mu.evidenceTier}</p>
<p>Machine-readable: the <a href="${urlBase}api/v1/today.json">today.json</a> <code>muhurta</code> block carries every window and slot with NPT stamps.</p>
''';
  return _docShell(
      'Muhurta (daily windows)',
      'Nepal muhurta windows from the nMiti engine: Rahu Kalam, Yamaganda, Gulika, Abhijit, Brahma muhurta, choghadiya and horas - receipt-anchored, convention collisions exposed, never guessed.',
      urlBase,
      'muhurta.html',
      body,
      shortSha);
}

String _sitemap(String urlBase) {
  final lastmod = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final urls = [
    for (final p in ['', 'accuracy.html', 'methodology.html', 'data.html', 'docs.html', 'sankranti.html', 'masa.html', 'panchang.html', 'muhurta.html', 'grahan.html', 'festivals.html', 'embed/example.html'])
      '<url><loc>$urlBase$p</loc><lastmod>$lastmod</lastmod></url>'
  ].join('\n');
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
$urls
</urlset>
''';
}

String _llmsTxt(BsCalendar core, BsCalendar tail, String urlBase, BsDate today) {
  final label = '${bsMonthNameEn(today.month)} ${today.day}, ${today.year} BS';
  return '''
# nMiti — open Bikram Sambat (Nepali) calendar data

> Verified, evidence-tagged Bikram Sambat dates for Nepal, rebuilt automatically every day at 00:00 Nepal Time (UTC+05:45).

Today's date (bilingual page): $urlBase
Today's date (JSON), with a panchang block (tithi/nakshatra/yoga/karana at both udaya and madhyahna conventions, sunrise, vriddhi/kshaya flags, provenance, evidence tier, plus a grahan block - today's eclipse/sutak state and the next grahan - and a festivals block: today's observances, the next festival and the 45-day horizon, each naming its day-choosing convention - plus a masa block, the amanta lunar month containing today with adhika/kshaya flags, and a muhurta block: Rahu Kalam, Yamaganda, Gulika, Abhijit and Brahma muhurta, the choghadiya slots and the hora windows): ${urlBase}api/v1/today.json
Calendar for one BS year (JSON): ${urlBase}api/v1/calendar/${today.year}.json (pattern: /api/v1/calendar/<bs_year>.json, BS 1975-2100)
Accuracy and honesty (evidence tiers, known defects, errata): ${urlBase}accuracy.html
Methodology (verification, invariants, calendar layers): ${urlBase}methodology.html
Data dictionary and downloads (CSV, JSON API): ${urlBase}data.html
Documentation pack rendered verbatim (data dictionary, methodology, changelog, errata, provenance manifest): ${urlBase}docs.html
Served CSV copies: ${urlBase}data/calendar_bs_core_1975_2083.csv and ${urlBase}data/calendar_bs_tail_2084_2100.csv
Served sankranti CSV copies: ${urlBase}data/sankranti_moments_1975_2083.csv and ${urlBase}data/sankranti_moments_1975_2100.csv
SHA-256 checksums of every served CSV: ${urlBase}data.html#checksums
Sankranti moments (solar ingress, current rashi, next sankranti): ${urlBase}sankranti.html and ${urlBase}api/v1/sankranti.json
Panchang for today (tithi, nakshatra, yoga, karana, sunrise; engine-computed at build time, both udaya and madhyahna conventions): ${urlBase}panchang.html
Grahan (eclipses) for Kathmandu - next grahan, today's sutak state, upcoming eclipses, conventions and receipts: ${urlBase}grahan.html
Festivals (receipt-pinned battery; today's observances, the next festival, the year's calendar with every convention divergence exposed): ${urlBase}festivals.html
Masa (amanta lunar months, new moon to new moon, with adhika/kshaya detection; engine-computed): ${urlBase}masa.html
Muhurta (Rahu Kalam, Yamaganda, Gulika, Abhijit, Brahma, choghadiya, horas; engine-computed): ${urlBase}muhurta.html
Embeddable today-in-BS widget (free, visible credit required): ${urlBase}embed/example.html
Verified dataset CSVs: https://github.com/namunaONE/nMiti/tree/main/data

Coverage: verified core BS 1975-${core.lastYear}; labeled projection tail BS ${tail.firstYear}-${tail.lastYear}. Only Baisakh 1 2084 (2027-04-14) is officially anchored; BS 2096 carries a known upstream defect (364 days), preserved and labeled.
Today per this build: $label
License: data CC0-1.0, code MIT.
''';
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void _write(File file, String content) {
  file.createSync(recursive: true);
  file.writeAsStringSync(content);
}

String? _arg(List<String> args, String name) {
  for (var i = 0; i + 1 < args.length; i++) {
    if (args[i] == name) return args[i + 1];
  }
  return null;
}
