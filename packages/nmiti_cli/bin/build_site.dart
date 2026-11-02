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
</style>
</head>
<body>
<main>
<h1>आजको मिति · Today's date in Nepal</h1>
<p class="answer">Today is <strong>$monthNameEn ${today.day}, ${today.year} BS</strong> (<span lang="ne">$monthNameNp $dayNp, $yearNp</span>)<br>— <strong>$adLabel</strong> (Gregorian).</p>
<p class="answer" lang="ne">आज <strong>$adLabelNp</strong> विक्रम संवत् अनुसार <strong>$monthNameNp $dayNp, $yearNp</strong> हो।</p>
<p class="tier">$tierNote</p>
<h2><span lang="ne">$monthNameNp</span> · $monthNameEn ${today.year}</h2>
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
<table>
<thead><tr>$heads</tr></thead>
<tbody>
$body
</tbody>
</table>''';
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

String _sitemap(String urlBase) => '''
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
<url><loc>$urlBase</loc><lastmod>${DateTime.now().toUtc().toIso8601String().substring(0, 10)}</lastmod></url>
</urlset>
''';

String _llmsTxt(BsCalendar core, BsCalendar tail, String urlBase, BsDate today) {
  final label = '${bsMonthNameEn(today.month)} ${today.day}, ${today.year} BS';
  return '''
# nMiti — open Bikram Sambat (Nepali) calendar data

> Verified, evidence-tagged Bikram Sambat dates for Nepal, rebuilt automatically every day at 00:00 Nepal Time (UTC+05:45).

Today's date (bilingual page): $urlBase
Today's date (JSON): ${urlBase}api/v1/today.json
Calendar for one BS year (JSON): ${urlBase}api/v1/calendar/${today.year}.json (pattern: /api/v1/calendar/<bs_year>.json, BS 1975-2100)
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
