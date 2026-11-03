import 'dart:io';

import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_date_data/nepali_date_data.dart';
import 'package:nepali_sankranti/nepali_sankranti.dart';

const _adMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _adMonthNamesNp = [
  'जनवरी', 'फेब्रुअरी', 'मार्च', 'अप्रिल', 'मे', 'जुन',
  'जुलाई', 'अगस्ट', 'सेप्टेम्बर', 'अक्टोबर', 'नोभेम्बर', 'डिसेम्बर',
];

/// Short AD month names for the per-cell Gregorian sub-label ("Nov 1").
const _adMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
  _write(File('${out.path}/sankranti.html'),
      _sankrantiPageHtml(sankrantiRows, urlBase, commitSha));
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

/// The premium answer-first homepage. The design system (tokens.css, inlined
/// via _designCss()) carries the look; the CONTENT carries the answer. The
/// guard contract ids (ans-en, ans-ne, cal-heading, cal-grid, tier-note) and
/// the exact answer sentence formats are load-bearing: the client-side guard
/// rewrites them at Nepal midnight, so they must match its own output.
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
  final coreYears = full.years.where((y) => y <= 2083).length;
  final verifiedCells = coreYears * 12;
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
<meta name="theme-color" content="#f8fafc" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0d1220" media="(prefers-color-scheme: dark)">
<script type="application/ld+json">{"@context":"https://schema.org","@type":"WebSite","name":"nMiti - Today's date in Nepal","url":"$urlBase","inLanguage":["ne","en"]}</script>
<style>
${_designCss()}
</style>
</head>
<body>
<a class="skip" href="#answer">Skip to today's date</a>
<header class="site-head">
<div class="wrap">
<a class="wordmark" href="$urlBase">nMiti <span class="tagline" lang="ne">· आजको मिति</span></a>
<nav aria-label="Site">
<a href="${urlBase}accuracy.html">Accuracy</a>
<a href="${urlBase}methodology.html">Methodology</a>
<a href="${urlBase}data.html">Data &amp; API</a>
<a href="${urlBase}sankranti.html">Sankranti</a>
<a href="${urlBase}embed/example.html">Embed</a>
</nav>
</div>
</header>
<main class="wrap">
<section class="hero" id="answer" aria-labelledby="page-title">
<p class="kicker">Open Bikram Sambat calendar commons</p>
<h1 id="page-title"><span lang="ne">आजको मिति</span> <span class="dot">·</span> Today's date in Nepal</h1>
<p class="answer" id="ans-en">Today is <strong>$monthNameEn ${today.day}, ${today.year} BS</strong> (<span lang="ne">$monthNameNp $dayNp, $yearNp</span>)<br>— <strong>$adLabel</strong> (Gregorian).</p>
<p class="answer" lang="ne" id="ans-ne">आज <strong>$adLabelNp</strong> विक्रम संवत् अनुसार <strong>$monthNameNp $dayNp, $yearNp</strong> हो।</p>
<p class="tier" id="tier-note">$tierNote</p>
<ul class="chips">
<li>Zero-JS semantic HTML</li>
<li>Machine-verified dataset</li>
<li>CC0 data · MIT code</li>
</ul>
</section>
<section class="cal-card" aria-labelledby="cal-heading">
<div class="cal-head">
<h2 id="cal-heading"><span lang="ne">$monthNameNp</span> · $monthNameEn ${today.year}</h2>
<p class="legend"><span class="sw" aria-hidden="true"></span>Weekend days in red <span lang="ne">(आइतबार, शनिबार)</span></p>
</div>
<div class="cal-tablewrap">
${_monthGrid(full, today)}
</div>
<p class="cal-note">Each cell shows the BS day in Devanagari numerals with its Gregorian date beneath. Nepali convention colors only शनिबार; nMiti colors both weekend days — a documented deviation (ADR-0001).</p>
</section>
<section class="stats" aria-label="Why trust this date">
<div class="stat"><strong>$coreYears</strong><span>verified core years (R12 cross-validation)</span></div>
<div class="stat"><strong>${_comma(verifiedCells)}</strong><span>month cells diffed against an independent table — all identical</span></div>
<div class="stat"><strong>5</strong><span>historically disputed years resolved with evidence</span></div>
<div class="stat"><strong>46,000+</strong><span>days round-trip converted on every CI run</span></div>
</section>
<aside class="panel">
<h2>Machine-readable</h2>
<ul>
<li><a href="api/v1/today.json">api/v1/today.json</a> — today as JSON</li>
<li><a href="api/v1/calendar/${today.year}.json">api/v1/calendar/${today.year}.json</a> — the full BS ${today.year} table</li>
<li><a href="llms.txt">llms.txt</a> — the whole site, written for AI agents</li>
<li><a href="https://github.com/namunaONE/nMiti">Dataset and source code on GitHub</a></li>
</ul>
<p>BS ${today.year} began on Baisakh 1, <strong>${_iso(b1)}</strong> (${row.weekday}). This page is rebuilt automatically from the verified dataset — no hand-typed dates anywhere.</p>
</aside>
</main>
<footer class="site-foot">
<div class="wrap">
<p>nMiti — open Bikram Sambat calendar commons · data CC0-1.0 · code MIT · rebuilt daily around 00:00 Nepal Time (UTC+05:45) · built $builtAt UTC from $shortSha</p>
<p class="creed">Every date on this page is in the HTML itself, for crawlers and no-JS browsers included. Exactly one script ships: the documented client-side guard that corrects the date at Nepal midnight if a scheduled rebuild is dropped.</p>
</div>
</footer>
<script>
${_clientGuardJs(full, today, g)}
</script>
</body>
</html>
''';
}

/// The month grid: a boxed single-rule lattice. Each data cell carries the
/// BS day in Devanagari numerals plus its Gregorian date beneath; weekend
/// columns (Sun/Sat per ADR-0001) render in holiday red. The client-side
/// guard rewrites this table at Nepal midnight with IDENTICAL markup - keep
/// the formats in sync with the guard's grid block below.
String _monthGrid(BsCalendar full, BsDate today) {
  final first = full.toGregorian(BsDate(today.year, today.month, 1));
  final length = full.monthLength(today.year, today.month);
  final startCol = first.weekday % 7; // Sunday-first grid
  final cells = <String>[];
  for (var i = 0; i < startCol; i++) {
    cells.add('<td class="pad" aria-hidden="true"></td>');
  }
  for (var d = 1; d <= length; d++) {
    final ad = full.toGregorian(BsDate(today.year, today.month, d));
    final off = ad.weekday == DateTime.saturday || ad.weekday == DateTime.sunday;
    final isToday = d == today.day;
    final cls = 'cell${off ? ' off' : ''}${isToday ? ' today' : ''}';
    final todayAttr = isToday ? ' aria-current="date"' : '';
    final adTxt = ad.day == 1
        ? '${_adMonthShort[ad.month - 1]} ${ad.day}'
        : '$ad.day';
    cells.add('<td class="$cls"$todayAttr>'
        '<span class="d">${toNepaliDigits(d.toString())}</span>'
        '<span class="ad">$adTxt</span></td>');
  }
  while (cells.length % 7 != 0) {
    cells.add('<td class="pad" aria-hidden="true"></td>');
  }
  final heads = [
    for (var i = 0; i < 7; i++)
      '<th scope="col"${i == 0 || i == 6 ? ' class="off"' : ''}>'
      '<span lang="ne">${_gridHeadsNp[i]}</span>'
      '<span class="ad">${_gridHeadsEn[i]}</span></th>'
  ].join();
  final body = [
    for (var i = 0; i < cells.length; i += 7)
      '<tr>${cells.sublist(i, i + 7).join()}</tr>'
  ].join();
  return '''
<table id="cal-grid" class="patro" aria-labelledby="cal-heading">
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
  // Grid rewrite: markup IDENTICAL to the build-time _monthGrid (boxed
  // lattice, Devanagari + Gregorian per cell, weekend red, today ring), so
  // a midnight correction is visually seamless.
  var grid = document.getElementById('cal-grid');
  if (grid) {
    var row = null;
    for (var i2 = 0; i2 < ROWS.length; i2++) { if (ROWS[i2][0] === nowBs.y) { row = ROWS[i2]; } }
    if (row) {
      var before = 0;
      for (var j2 = 0; j2 < nowBs.m - 1; j2++) { before += row[2][j2]; }
      var firstMs = parseIso(row[1]) + before * 86400000;
      var startCol = weekdayOf(isoOf(firstMs));
      var len = row[2][nowBs.m - 1];
      var cells = [];
      var c;
      for (c = 0; c < startCol; c++) { cells.push('<td class="pad" aria-hidden="true"></td>'); }
      for (c = 1; c <= len; c++) {
        var dayMs = firstMs + (c - 1) * 86400000;
        var dd = new Date(dayMs);
        var dw = dd.getUTCDay();
        var cls = 'cell' + ((dw === 0 || dw === 6) ? ' off' : '') + (c === nowBs.d ? ' today' : '');
        var adTxt = (dd.getUTCDate() === 1) ? AD_EN[dd.getUTCMonth()].slice(0, 3) + ' 1' : String(dd.getUTCDate());
        cells.push('<td class="' + cls + '"' + (c === nowBs.d ? ' aria-current="date"' : '') + '><span class="d">' + npNum(c) + '</span><span class="ad">' + adTxt + '</span></td>');
      }
      while (cells.length % 7 !== 0) { cells.push('<td class="pad" aria-hidden="true"></td>'); }
      var heads = '';
      var h;
      for (h = 0; h < 7; h++) {
        heads += '<th scope="col"' + (h === 0 || h === 6 ? ' class="off"' : '') + '><span lang="ne">' + H_NP[h] + '</span><span class="ad">' + H_EN[h] + '</span></th>';
      }
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

/// The shared design-system stylesheet, kept as a real CSS file
/// (packages/nmiti_cli/design/tokens.css) so it can be diffed and reused,
/// then inlined into every page at build time: zero extra requests on the
/// zero-JS content pages, one source of truth for the whole site.
String _designCss() {
  for (final path in [
    'packages/nmiti_cli/design/tokens.css',
    'design/tokens.css',
  ]) {
    final f = File(path);
    if (f.existsSync()) return f.readAsStringSync();
  }
  throw StateError('Design system stylesheet not found: design/tokens.css');
}

/// Shared shell for the honesty-layer documentation pages: skip link,
/// site header + nav, the design system, and the site footer.
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
<meta name="theme-color" content="#f8fafc" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0d1220" media="(prefers-color-scheme: dark)">
<style>
${_designCss()}
</style>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="site-head">
<div class="wrap">
<a class="wordmark" href="$urlBase">nMiti <span class="tagline" lang="ne">· आजको मिति</span></a>
<nav aria-label="Site">
<a href="$urlBase">Today</a>
<a href="${urlBase}accuracy.html">Accuracy</a>
<a href="${urlBase}methodology.html">Methodology</a>
<a href="${urlBase}data.html">Data &amp; API</a>
<a href="${urlBase}sankranti.html">Sankranti</a>
<a href="${urlBase}embed/example.html">Embed</a>
</nav>
</div>
</header>
<main id="main" class="wrap doc">
$body
</main>
<footer class="site-foot">
<div class="wrap">
<p>nMiti — open Bikram Sambat calendar commons · data CC0-1.0 · code MIT · built $builtAt UTC from $shortSha</p>
</div>
</footer>
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
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#f8fafc" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0d1220" media="(prefers-color-scheme: dark)">
<title>Not found | nMiti</title>
<style>
${_designCss()}
</style>
</head>
<body>
<main class="wrap nf">
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

String _sitemap(String urlBase) {
  final lastmod = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final urls = [
    for (final p in ['', 'accuracy.html', 'methodology.html', 'data.html', 'sankranti.html', 'embed/example.html'])
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
Sankranti moments (solar ingress, current rasi, next sankranti): ${urlBase}sankranti.html and ${urlBase}api/v1/sankranti.json
Served sankranti CSV: ${urlBase}data/sankranti_moments_1975_2100.csv
Embeddable today-in-BS widget (free, visible credit required): ${urlBase}embed/example.html
Verified dataset CSVs: https://github.com/namunaONE/nMiti/tree/main/data

Coverage: verified core BS 1975-${core.lastYear}; labeled projection tail BS ${tail.firstYear}-${tail.lastYear}. Only Baisakh 1 2084 (2027-04-14) is officially anchored; BS 2096 carries a known upstream defect (364 days), preserved and labeled.
Today per this build: $label
License: data CC0-1.0, code MIT.
''';
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Thousands separator for the stat tiles (e.g. 1308 -> "1,308").
String _comma(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
}

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
