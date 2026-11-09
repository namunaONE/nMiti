part of 'build_site.dart';

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
  _write(File('${out.path}/bhadra.html'),
      _bhadraPageHtml(todayAd, urlBase, commitSha));
  _write(File('${out.path}/panchak.html'),
      _panchakPageHtml(todayAd, urlBase, commitSha));
  _write(File('${out.path}/chandra-darshan.html'),
      _chandraDarshanPageHtml(todayAd, urlBase, commitSha));
  _write(File('${out.path}/ayanamsa.html'),
      _ayanamsaPageHtml(todayAd, urlBase, commitSha));
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
  // R7a: the served Delta-T at local noon (12:00 NPT = 06:15 UTC), with
  // its source segment and honest uncertainty (hybrid channel, HYA-438).
  final dtValue = deltaTAtJdUt(jdFromDateTimeUtc(
      DateTime.utc(todayAd.year, todayAd.month, todayAd.day, 6, 15)));
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
    "delta_t": {
      "seconds": ${dtValue.seconds.toStringAsFixed(4)},
      "source": "${dtValue.source}",
      "uncertainty_seconds": ${dtValue.uncertaintySeconds.toStringAsFixed(3)},
      "source_span": "${dtValue.sourceSpan}",
      "evaluated_at_npt": "${isoNpt(DateTime.utc(todayAd.year, todayAd.month, todayAd.day, 12, 0))}",
      "note": "hybrid channel (R7a): SMH2021 spline, USNO observed and predicted tables, Espenak-Meeus long-range; joins derived from the vendored tables, declared not blended",
      "details": "${urlBase}methodology.html"
    },
    "provenance": "${p.provenance}",
    "evidence_tier": "${p.evidenceTier}",
    "details": "${urlBase}panchang.html"
  },
  "grahan": ${_grahanBlock(todayAd, urlBase)},
  "festivals": ${_festivalsBlock(full, todayAd, urlBase)},
  "masa": ${_masaBlock(todayAd, urlBase)},
  "muhurta": ${_muhurtaBlock(todayAd, urlBase)},
  "bhadra": ${_bhadraBlock(todayAd, urlBase)},
  "panchak": ${_panchakBlock(todayAd, urlBase)},
  "chandra_darshan": ${_chandraDarshanBlock(todayAd, urlBase)},
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
<p class="nav"><a href="accuracy.html">Accuracy &amp; honesty</a> · <a href="methodology.html">Methodology</a> · <a href="ayanamsa.html">Ayanamsa</a> · <a href="data.html">Data &amp; API</a> · <a href="sankranti.html">Sankranti</a> · <a href="masa.html">Masa</a> · <a href="panchang.html">Panchang</a> · <a href="bhadra.html">Bhadra</a> · <a href="panchak.html">Panchak</a> · <a href="chandra-darshan.html">Chandra Darshan</a> · <a href="muhurta.html">Muhurta</a> · <a href="grahan.html">Grahan</a> · <a href="festivals.html">Festivals</a> · <a href="docs.html">Docs</a></p>
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
