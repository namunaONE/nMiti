import 'dart:io';

import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_date_data/nepali_date_data.dart';

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

  final fatal = [
    ...validateCore(core),
    ...validateTail(core, tail).where((v) => !v.knownDefect),
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
  final npt = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));
  final todayAd = DateTime.utc(npt.year, npt.month, npt.day);
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
  _write(File('${out.path}/accuracy.html'),
      _accuracyPageHtml(core, tail, urlBase, commitSha));
  _write(File('${out.path}/methodology.html'),
      _methodologyPageHtml(urlBase, commitSha));
  _write(File('${out.path}/data.html'),
      _dataPageHtml(core, tail, urlBase, commitSha));
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
<p class="nav"><a href="accuracy.html">Accuracy &amp; honesty</a> · <a href="methodology.html">Methodology</a> · <a href="data.html">Data &amp; API</a></p>
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
<p class="nav"><a href="$urlBase">आजको मिति · Today</a> · <a href="${urlBase}accuracy.html">Accuracy &amp; honesty</a> · <a href="${urlBase}methodology.html">Methodology</a> · <a href="${urlBase}data.html">Data &amp; API</a></p>
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
<li><strong>Checked continuously:</strong> CI enforces structural invariants on every build, and an independent Python implementation re-derives the deployed date from the raw CSVs after every deploy.</li>
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
<li><strong>Festivals and tithi are not covered.</strong> nMiti serves the civil solar calendar only. Festival dates can legitimately differ between panchangs (Kojagrat Purnima 2083: printed Oct 25 in one panchang, adjudicated Oct 26 by others). That layer is planned with per-source attribution - we will not guess.</li>
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
<p>Not a panchang: no tithi, no festivals, no muhurta - only the civil Bikram Sambat calendar, the date layer every source agrees on. A sankranti-moments dataset (precise solar ingress timestamps, BS 1975-2100) is planned so every month boundary becomes independently checkable against the sun. Until a claim is on this site with evidence, we do not make it.</p>
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
<li><strong>Continuous invariants, enforced by CI on every build:</strong> month lengths 29-32; core year lengths 365-366; chain continuity; every Baisakh 1 falls on April 11-15; the weekday column matches the baisakh1 date; no run of 3+ identical consecutive rows; the tail chains from the official 2084 anchor.</li>
<li><strong>Independent re-derivation:</strong> after every deploy, a Python implementation - not the Dart engine that built the site - recomputes today's date straight from the raw CSVs and compares it against the deployed JSON. A 4-times-daily canary repeats the check against the live site.</li>
</ol>

<h2 id="layers">Calendar layers: why today's date is unambiguous but festivals are not</h2>
<p>The Bikram Sambat calendar is solar: every month begins at a precise solar ingress (sankranti). The panchang adds a lunar layer - the tithi - which can change <em>during the afternoon</em>, and festival dates depend on rules layered on both. Two correct panchangs can therefore print different festival dates while agreeing perfectly on today's civil date. nMiti Layer 1 serves only the civil solar layer - the one every source agrees on. The tithi and festival layer is deliberately out of scope until it can be served with per-source attribution.</p>

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
  final body = '''
<h1>Data &amp; API <span lang="ne">· डाटा र एपीआई</span></h1>
<p>Two canonical CSVs are the single source of truth for everything nMiti ships - the site, the JSON API, the Dart SDK. Nothing downstream may hard-code a date. Data license: <strong>CC0-1.0</strong> (public domain).</p>

<h2 id="downloads">Downloads</h2>
<ul>
<li><a href="data/calendar_bs_core_1975_2083.csv">calendar_bs_core_1975_2083.csv</a> - verified core, ${core.years.length} years (BS 1975-${core.lastYear}), served as an exact copy of the repository file</li>
<li><a href="data/calendar_bs_tail_2084_2100.csv">calendar_bs_tail_2084_2100.csv</a> - labeled projection tail, ${tail.years.length} years (BS ${tail.firstYear}-${tail.lastYear})</li>
<li>Canonical source and full history: <a href="https://github.com/namunaONE/nMiti/tree/main/data">github.com/namunaONE/nMiti/tree/main/data</a></li>
</ul>

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
<li><code><a href="api/v1/today.json">api/v1/today.json</a></code> - today in BS and AD, weekday and month names in Nepali and English, the evidence tier, plus a <code>tomorrow</code> object so consumers can self-correct at their own midnight. Stamped with the commit and build run.</li>
<li><code>api/v1/calendar/{bs_year}.json</code> - one BS year: baisakh1, weekday, days, the 12 month lengths, month names, evidence tier (BS 1975-2100). Example: <a href="api/v1/calendar/2083.json">api/v1/calendar/2083.json</a></li>
<li><code><a href="api/v1/meta.json">api/v1/meta.json</a></code> - dataset metadata: coverage, evidence summary, license.</li>
</ul>

<h2 id="cite">Using and citing</h2>
<p>CC0 means no permission is needed for the data and no attribution is required - though it is always welcome: <em>"Data: nMiti - open Bikram Sambat dataset (CC0), namunaone.github.io/nMiti."</em> For reproducibility, pin a commit SHA; <code>today.json</code> carries the current one. The code is MIT-licensed.</p>
<script type="application/ld+json">{"@context":"https://schema.org","@type":"Dataset","name":"nMiti Bikram Sambat calendar dataset","description":"Open, verified, evidence-tagged Bikram Sambat (Nepali) calendar data, BS 1975-2100.","license":"https://creativecommons.org/publicdomain/zero/1.0/","creator":{"@type":"Organization","name":"nMiti"},"distribution":[{"@type":"DataDownload","encodingFormat":"text/csv","contentUrl":"${urlBase}data/calendar_bs_core_1975_2083.csv"},{"@type":"DataDownload","encodingFormat":"text/csv","contentUrl":"${urlBase}data/calendar_bs_tail_2084_2100.csv"}]}</script>
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

String _sitemap(String urlBase) {
  final lastmod = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final urls = [
    for (final p in ['', 'accuracy.html', 'methodology.html', 'data.html', 'embed/example.html'])
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
Today's date (JSON): ${urlBase}api/v1/today.json
Calendar for one BS year (JSON): ${urlBase}api/v1/calendar/${today.year}.json (pattern: /api/v1/calendar/<bs_year>.json, BS 1975-2100)
Accuracy and honesty (evidence tiers, known defects, errata): ${urlBase}accuracy.html
Methodology (verification, invariants, calendar layers): ${urlBase}methodology.html
Data dictionary and downloads (CSV, JSON API): ${urlBase}data.html
Served CSV copies: ${urlBase}data/calendar_bs_core_1975_2083.csv and ${urlBase}data/calendar_bs_tail_2084_2100.csv
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
