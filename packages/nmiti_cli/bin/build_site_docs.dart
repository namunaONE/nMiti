part of 'build_site.dart';

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
<p class="nav"><a href="$urlBase">आजको मिति · Today</a> · <a href="${urlBase}accuracy.html">Accuracy &amp; honesty</a> · <a href="${urlBase}methodology.html">Methodology</a> · <a href="${urlBase}ayanamsa.html">Ayanamsa</a> · <a href="${urlBase}data.html">Data &amp; API</a> · <a href="${urlBase}sankranti.html">Sankranti</a> · <a href="${urlBase}masa.html">Masa</a> · <a href="${urlBase}panchang.html">Panchang</a> · <a href="${urlBase}muhurta.html">Muhurta</a> · <a href="${urlBase}grahan.html">Grahan</a> · <a href="${urlBase}festivals.html">Festivals</a> · <a href="${urlBase}docs.html">Docs</a></p>
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

<h2 id="delta-t">Delta T - the hybrid channel (R7a)</h2>
<p>Delta T = TT − UT1, the gap between dynamical time (which the ephemerides speak) and Earth's rotation (which clocks and calendars speak). Every limb boundary the engine solves is a pure TT event; the served wall-clock time depends entirely on which Delta T converts it. Since R7a the engine serves the hybrid Delta-T channel instead of the Espenak-Meeus (2006 forecast) polynomial, which read 75.62 s for November 2026 where the USNO observed value is 69.13 s - a ~6.5 s systematic that no longer exists.</p>
<table>
<tr><th>Segment</th><th>Span</th><th>Source</th><th>Uncertainty</th></tr>
<tr><td>Spline</td><td>AD -720 .. 1973-02</td><td>Stephenson, Morrison &amp; Hohenkerk (2016) / Morrison et al. (2021) cubic spline, Table S15 (Royal Society supplement, CC BY 4.0) - published pre-1974 segments only</td><td>published error table (15 s at 1600, 0.05 s from 1870)</td></tr>
<tr><td>Observed</td><td>1973-02 .. 2026-04</td><td>USNO deltat.data - monthly observed TT-UT1</td><td>0.05 s</td></tr>
<tr><td>Predictions</td><td>2026-04 .. 2033-10</td><td>USNO deltat.preds - quarterly, bridged from the last observation; observations shadow predictions inside their span</td><td>the file's own error column, interpolated (0.05 .. 1 s)</td></tr>
<tr><td>Long-range</td><td>2033-10 .. 2150</td><td>Espenak-Meeus 2005-2050 / 2050-2150 branches</td><td>declared envelope: 1 s at the join, 6 s at 2050, 12 s at 2100, 20 s at 2150</td></tr>
</table>
<p>Join steps are <strong>declared, never blended</strong>: +0.228 s where the spline hands over to the USNO observations (1973-02-01), continuous across the observed-to-prediction bridge, and +8.91 s where the USNO stops predicting and the polynomial long-range takes over (2033-10-01) - the USNO's own end of record, left visible. The vendored values were validated three ways: three Wayback snapshots of the USNO files, the independently vendored hyper-calendar copy (C04-identity-checked to 0.002 s), and the IERS-derived astronomia monthly series. This supersedes the HYA-406 (2026-11-06) decision to keep Espenak-Meeus; re-measured on the merge (CI #146): the Swiss-vs-engine Delta-T residual collapsed from ~6.8 s to mean -0.30 s (max 0.31 s, n=233), every TT limb band shifted by the -6.5 s Delta-T wall-clock correction and stays inside its published ceiling - tithi/karana 14.3 s mean (the named Meeus Ch.47 truncation, exposed once the pre-R7a Delta-T error stopped partially canceling it), nakshatra 66.2 s, yoga 110.8 s, sunrise 11.3 s unchanged (UT-direct). The tables are regenerated by <code>tools/refresh_delta_t.dart</code> (monthly workflow; it refuses to write on any anomaly), and the freshness canary asserts the observed table stays current.</p>

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
<li><code><a href="api/v1/today.json">api/v1/today.json</a></code> - today in BS and AD, weekday and month names in Nepali and English, the evidence tier, plus a <code>tomorrow</code> object so consumers can self-correct at their own midnight, and a <code>panchang</code> block - tithi, nakshatra, yoga, karana at both udaya (sunrise) and madhyahna (noon) reference moments, sunrise, vriddhi/kshaya/borderline flags, provenance and evidence tier - plus a <code>grahan</code> block: the eclipse or sutak window touching today, whether sutak is active, and the next grahan with its Nepali name and honesty fields, plus a <code>festivals</code> block: today's festival observances, the next festival and the 45-day horizon, each naming its day-choosing convention and any convention divergence - plus a <code>masa</code> block (the amanta lunar month containing today, with adhika/kshaya flags) and a <code>muhurta</code> block (Rahu Kalam, Yamaganda, Gulika, Abhijit and Brahma muhurta, the choghadiya slots and the 24 horas), and a <code>delta_t</code> honesty block - the served Delta T with its source segment, uncertainty and span. Engine-computed at build time. Stamped with the commit and build run.</li>
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
