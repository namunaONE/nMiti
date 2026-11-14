part of 'build_site.dart';

/// The dasha display layer (Wave 2, HYA-451 PR-B): the today.json
/// dasha block and the /dasha page. Everything engine-side renders the
/// shipped Vimshottari engine (PR #85) - no new astronomy, no
/// recomputed truth.
///
/// Conventions stated, never silently resolved:
///   reference instant = NPT noon of today (the madhyahna family),
///     exposed as reference_instant_npt;
///   the block is TODAY-ANCHORED: an ILLUSTRATIVE birth at the
///     reference instant, exercising the full dasha arithmetic daily -
///     a build-time page cannot know a visitor birth, so the
///     birth-query surface is the page calculator, not this block;
///   dasha year        = 365.25 days SERVED (the common software
///     convention); the classical 360-day count is the stated
///     alternative - the ~629-day drift across the 120-year cycle is
///     the open receipt;
///   ayanamsa frame    = the receipts-measured Swiss-Lahiri reference
///     line (the graha display channel);
///   the birth-query calculator is a small, honestly labeled
///     CLIENT-SIDE MIRROR of the engine arithmetic (the user-approved
///     exception to the zero-JS rule) - the Dart engine remains
///     canonical.

/// NPT ISO stamp of a TT Julian Day (the dasha block convention).
String _dashaIsoNpt(double jdTt) {
  final wall = dateTimeUtcFromJd(jdUtFromJdTt(jdTt)).add(nepalTimeOffset);
  return _iso(wall) + 'T' + _skTwo(wall.hour) + ':' + _skTwo(wall.minute) +
      ':00+05:45';
}

/// The dasha block of today.json (Wave 2 display): the TODAY-ANCHORED
/// Vimshottari state - an illustrative birth at the exposed NPT-noon
/// reference instant. The keys - "dasha", "birth_moon", "balance",
/// "mahadashas", "year_days" - always serialize on every build, so the
/// site-contract markers are date-stable.
String _dashaBlock(DateTime todayAd, String urlBase) {
  final jdTt = _grahaNoonJdTt(todayAd);
  final ay = ayanamsaSwissLahiriReference(jdTt);
  final moonDeg = moonSiderealInFrameDeg(jdTt, ay);
  final bal = vimshottariBalanceFromMoonDeg(moonDeg,
      yearDays: vimshottariYearDaysSolar);
  final mahas = vimshottariMahadashasFromMoonDeg(
      moonDeg: moonDeg, birthJdTt: jdTt, yearDays: vimshottariYearDaysSolar);
  final mahaItems = [
    for (var i = 0; i < mahas.length; i++)
      '      {"lord": "' +
          mahas[i].lord +
          '", "begins_at": "' +
          _dashaIsoNpt(mahas[i].startJdTt) +
          '", "ends_at": "' +
          _dashaIsoNpt(mahas[i].endJdTt) +
          '", "days": ' +
          mahas[i].spanDays.toStringAsFixed(2) +
          '}'
  ].join(',\n');
  return '{\n'
      '    "note": "Vimshottari dasha (Wave 2): TODAY-ANCHORED - an illustrative birth at the reference instant below, exercising the full dasha arithmetic daily; a build-time block cannot know a visitor birth, so the birth-query surface is the dasha.html calculator",\n'
      '    "reference_instant_npt": "' +
      _iso(todayAd) +
      'T12:00+05:45",\n'
      '    "birth_moon": {\n'
      '      "sidereal_deg": ' +
      moonDeg.toStringAsFixed(4) +
      ',\n'
      '      "nakshatra": "' +
      nakshatraNames[bal.nakshatraIndex] +
      '",\n'
      '      "nakshatra_index": ' +
      bal.nakshatraIndex.toString() +
      ',\n'
      '      "elapsed_fraction": ' +
      bal.nakshatraElapsedFraction.toStringAsFixed(6) +
      '\n'
      '    },\n'
      '    "balance": {\n'
      '      "lord": "' +
      vimshottariLords[bal.lordIndex] +
      '",\n'
      '      "lord_index": ' +
      bal.lordIndex.toString() +
      ',\n'
      '      "balance_days": ' +
      bal.balanceDays.toStringAsFixed(2) +
      ',\n'
      '      "balance_years_solar": ' +
      (bal.balanceDays / vimshottariYearDaysSolar).toStringAsFixed(4) +
      '\n'
      '    },\n'
      '    "mahadashas": [\n' +
      mahaItems +
      '\n    ],\n'
      '    "year_days": ' +
      vimshottariYearDaysSolar.toStringAsFixed(2) +
      ',\n'
      '    "conventions": {\n'
      '      "year_days": "365.25 days per dasha year (the common software convention) is SERVED; the classical 360-day count is the stated alternative - they drift about 629 days across the 120-year cycle; dated publisher receipts are pending (the load-bearing open receipt)",\n'
      '      "ayanamsa_frame": "the birth moon is the apparent sidereal longitude on the receipts-measured Swiss-Lahiri reference line 23.85709 deg + 1.398024 deg per Julian century (the graha display channel)",\n'
      '      "levels": "the mahadasha chain opens at the birth instant with the balance remainder; antardasha and pratyantardasha are the nine proportional children of BPHS ch. 46, each opening with the parent own lord",\n'
      '      "window": "nine mahadashas (120 years) are served; queries before the birth instant or beyond the window are errors, never silent wraps"\n'
      '    },\n'
      '    "provenance": "the nMiti nepali_panchang Vimshottari dasha engine (Wave 2, HYA-451) on the ELP2000-82B moon + nutation",\n'
      '    "evidence_tier": "runtime-computed, self-consistency-gated in CI (chain, sums, balance, convention-parameter visibility); NO publisher dasha receipt corpus gates it yet",\n'
      '    "details": "' +
      urlBase +
      'dasha.html"\n'
      '  }';
}

/// The client-side Vimshottari calculator (the dasha.html birth-query
/// form). An honestly labeled MIRROR of the engine arithmetic: the
/// full 60-term Meeus ch. 47 moon (the pre-ELP engine series, about 10
/// arcsec class), the 4-term nutation, the same Swiss-Lahiri reference
/// line and the same 365.25-day solar dasha year as the served block.
/// The Dart engine remains canonical. No template literals, no
/// external requests; results are written to the URL as date/time/tz
/// params so a computed chart is shareable as a plain link.
String _dashaCalcJs() {
  return r'''(function () {
  'use strict';
  var LORDS = ['Ketu', 'Venus', 'Sun', 'Moon', 'Mars', 'Rahu', 'Jupiter', 'Saturn', 'Mercury'];
  var YEARS = [7, 20, 6, 10, 7, 18, 16, 19, 17];
  var YEAR_DAYS = 365.25;
  var SPAN = 360 / 27;
  var NAKS = ['Ashwini','Bharani','Krittika','Rohini','Mrigashira','Ardra','Punarvasu','Pushya','Ashlesha','Magha','Purva Phalguni','Uttara Phalguni','Hasta','Chitra','Swati','Vishakha','Anuradha','Jyeshtha','Mula','Purva Ashadha','Uttara Ashadha','Shravana','Dhanishta','Shatabhisha','Purva Bhadrapada','Uttara Bhadrapada','Revati'];
  var T47A = [[0,0,1,0,6288774],[2,0,-1,0,1274027],[2,0,0,0,658314],[0,0,2,0,213618],[0,1,0,0,-185116],[0,0,0,2,-114332],[2,0,-2,0,58793],[2,-1,-1,0,57066],[2,0,1,0,53322],[2,-1,0,0,45758],[0,1,-1,0,-40923],[1,0,0,0,-34720],[0,1,1,0,-30383],[2,0,0,-2,15327],[0,0,1,2,-12528],[0,0,1,-2,10980],[4,0,-1,0,10675],[0,0,3,0,10034],[4,0,-2,0,8548],[2,1,-1,0,-7888],[2,1,0,0,-6766],[1,0,-1,0,-5163],[1,1,0,0,4987],[2,-1,1,0,4036],[2,0,2,0,3994],[4,0,0,0,3861],[2,0,-3,0,3665],[0,1,-2,0,-2689],[2,0,-1,2,-2602],[2,-1,-2,0,2390],[1,0,1,0,-2348],[2,-2,0,0,2236],[0,1,2,0,-2120],[0,2,0,0,-2069],[2,-2,-1,0,2048],[2,0,1,-2,-1773],[2,0,0,2,-1595],[4,-1,-1,0,1215],[0,0,2,2,-1110],[3,0,-1,0,-892],[2,1,1,0,-810],[4,-1,-2,0,759],[0,2,-1,0,-713],[2,2,-1,0,-700],[2,1,-2,0,691],[2,-1,0,-2,596],[4,0,1,0,549],[0,0,4,0,537],[4,-1,0,0,520],[1,0,-2,0,-487],[2,1,0,-2,-399],[0,0,2,-2,-381],[1,1,1,0,351],[3,0,-2,0,-340],[4,0,-3,0,330],[2,-1,2,0,327],[0,2,1,0,-323],[1,1,-1,0,299],[2,0,3,0,294],[2,0,-1,-2,0]];
  var D2R = Math.PI / 180;
  var J2000 = 2451545.0;
  var DT_YEARS = [1900, 1920, 1940, 1950, 1960, 1970, 1980, 1990, 2000, 2010, 2015];
  var DT_SECS = [-2.7, 21.1, 24.3, 29.2, 33.2, 40.2, 50.5, 56.9, 63.8, 66.1, 67.6];
  function norm360(x) { return ((x % 360) + 360) % 360; }
  function deltaT(y) {
    var t, u;
    if (y >= 2050) { u = (y - 2000 - 182) / 100; return -20 + 32 * u * u - 0.5628 * (2150 - (y - 2000)); }
    if (y >= 2005) { t = y - 2000; return 62.92 + 0.32217 * t + 0.005589 * t * t; }
    if (y <= DT_YEARS[0]) { return DT_SECS[0]; }
    var i;
    for (i = 1; i < DT_YEARS.length; i++) {
      if (y <= DT_YEARS[i]) {
        var f = (y - DT_YEARS[i - 1]) / (DT_YEARS[i] - DT_YEARS[i - 1]);
        return DT_SECS[i - 1] + f * (DT_SECS[i] - DT_SECS[i - 1]);
      }
    }
    return DT_SECS[DT_SECS.length - 1];
  }
  function nutationDeg(jd) {
    var t = (jd - J2000) / 36525.0;
    var om = (125.04452 - 1934.136261 * t) * D2R;
    var L = (280.4665 + 36000.7698 * t) * D2R;
    var Lp = (218.3164477 + 481267.88123421 * t) * D2R;
    var dps = -17.20 * Math.sin(om) - 1.32 * Math.sin(2 * L) - 0.23 * Math.sin(2 * Lp) + 0.21 * Math.sin(2 * om);
    return dps / 3600.0;
  }
  function moonLonTt(jd) {
    var t = (jd - J2000) / 36525.0;
    var t2 = t * t, t3 = t2 * t, t4 = t2 * t2;
    var lp = 218.3164477 + 481267.88123421 * t - 0.0015786 * t2 + t3 / 538841 - t4 / 65194000;
    var D = 297.8501921 + 445267.1114034 * t - 0.0018819 * t2 + t3 / 545868 - t4 / 113065000;
    var M = 357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000;
    var Mp = 134.9633964 + 477198.8675055 * t + 0.0087414 * t2 + t3 / 69699 - t4 / 14712000;
    var F = 93.2720950 + 483202.0175233 * t - 0.0036539 * t2 - t3 / 3526000 + t4 / 863310000;
    var e = 1 - 0.002516 * t - 0.0000074 * t2;
    var sl = 0.0;
    var i, r, arg, c, am;
    for (i = 0; i < T47A.length; i++) {
      r = T47A[i];
      arg = (r[0] * D + r[1] * M + r[2] * Mp + r[3] * F) * D2R;
      c = r[4];
      am = r[1] < 0 ? -r[1] : r[1];
      if (am === 1) { c = c * e; } else if (am === 2) { c = c * e * e; }
      sl += c * Math.sin(arg);
    }
    var a1 = 119.75 + 131.849 * t;
    var a2 = 53.09 + 479264.290 * t;
    sl += 3958 * Math.sin(a1 * D2R) + 1962 * Math.sin((lp - F) * D2R) + 318 * Math.sin(a2 * D2R);
    return norm360(lp + sl / 1e6);
  }
  function moonSid(jd) {
    var ay = 23.85709 + 1.398024 * (jd - J2000) / 36525.0;
    return norm360(moonLonTt(jd) + nutationDeg(jd) - ay);
  }
  function jdFromMs(ms) { return ms / 86400000 + 2440587.5; }
  function balanceOf(moonDeg) {
    var nak = Math.floor(moonDeg / SPAN) % 27;
    var frac = (moonDeg - nak * SPAN) / SPAN;
    var lord = nak % 9;
    return { nak: nak, lord: lord, frac: frac, days: (1 - frac) * YEARS[lord] * YEAR_DAYS };
  }
  function mahadashasOf(moonDeg, birthJd) {
    var b = balanceOf(moonDeg);
    var out = [];
    var start = birthJd;
    var k, lord, days;
    for (k = 0; k < 9; k++) {
      lord = (b.lord + k) % 9;
      days = (k === 0) ? b.days : YEARS[lord] * YEAR_DAYS;
      out.push({ lord: LORDS[lord], start: start, end: start + days });
      start += days;
    }
    return out;
  }
  function subPeriodsOf(parent) {
    var li = LORDS.indexOf(parent.lord);
    var out = [];
    var start = parent.start;
    var k, lord, days;
    for (k = 0; k < 9; k++) {
      lord = (li + k) % 9;
      days = YEARS[lord] / 120 * (parent.end - parent.start);
      out.push({ lord: LORDS[lord], start: start, end: start + days });
      start += days;
    }
    return out;
  }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function fmt(jd, tzMin) {
    var d = new Date((jd - 2440587.5) * 86400000 + tzMin * 60000);
    return d.getUTCFullYear() + '-' + pad(d.getUTCMonth() + 1) + '-' + pad(d.getUTCDate()) + ' ' + pad(d.getUTCHours()) + ':' + pad(d.getUTCMinutes());
  }
  function tzMinutes(tz) {
    var neg = tz.charAt(0) === '-';
    var s = neg ? tz.slice(1) : tz.replace('+', '');
    var parts = s.split(':');
    var m = parseInt(parts[0], 10) * 60 + (parts.length > 1 ? parseInt(parts[1], 10) : 0);
    return neg ? -m : m;
  }
  function esc(s) { var d = document.createElement('div'); d.textContent = s; return d.innerHTML; }
  function compute(dateStr, timeStr, tz) {
    var dp = dateStr.split('-');
    var tp = timeStr.split(':');
    var y = parseInt(dp[0], 10), mo = parseInt(dp[1], 10), d = parseInt(dp[2], 10);
    var hh = parseInt(tp[0], 10), mi = parseInt(tp[1], 10);
    if (!(y > 0 && mo >= 1 && mo <= 12 && d >= 1 && d <= 31 && hh >= 0 && hh < 24 && mi >= 0 && mi < 60)) {
      return { error: 'Please provide a valid birth date (YYYY-MM-DD) and time (HH:MM).' };
    }
    var tzMin = tzMinutes(tz);
    var birthJdUt = jdFromMs(Date.UTC(y, mo - 1, d, hh, mi) - tzMin * 60000);
    var birthJdTt = birthJdUt + deltaT(y) / 86400;
    var moonDeg = moonSid(birthJdTt);
    var bal = balanceOf(moonDeg);
    var mahas = mahadashasOf(moonDeg, birthJdTt);
    var nowMs = Date.now();
    var nowY = new Date(nowMs).getUTCFullYear();
    var nowJdTt = jdFromMs(nowMs) + deltaT(nowY) / 86400;
    var stack = null;
    var i, j, k;
    if (nowJdTt >= birthJdTt && nowJdTt < birthJdTt + 120 * YEAR_DAYS) {
      for (i = 0; i < mahas.length; i++) {
        if (nowJdTt >= mahas[i].start && nowJdTt < mahas[i].end) {
          var antars = subPeriodsOf(mahas[i]);
          for (j = 0; j < antars.length; j++) {
            if (nowJdTt >= antars[j].start && nowJdTt < antars[j].end) {
              var prats = subPeriodsOf(antars[j]);
              for (k = 0; k < prats.length; k++) {
                if (nowJdTt >= prats[k].start && nowJdTt < prats[k].end) {
                  stack = { maha: mahas[i], antar: antars[j], prat: prats[k] };
                  break;
                }
              }
              break;
            }
          }
          break;
        }
      }
    }
    var rows = '';
    var r2;
    for (r2 = 0; r2 < mahas.length; r2++) {
      rows += '<tr><td>' + (r2 + 1) + '</td><td>' + esc(mahas[r2].lord) + '</td><td>' + fmt(mahas[r2].start, tzMin) + '</td><td>' + fmt(mahas[r2].end, tzMin) + '</td><td>' + (mahas[r2].end - mahas[r2].start).toFixed(1) + '</td></tr>';
    }
    var stackHtml;
    if (stack) {
      stackHtml = '<p><strong>Running now:</strong> ' + esc(stack.maha.lord) + ' mahadasha &rarr; ' + esc(stack.antar.lord) + ' antardasha &rarr; ' + esc(stack.prat.lord) + ' pratyantardasha (until ' + fmt(stack.prat.end, tzMin) + ').</p>';
    } else if (nowJdTt < birthJdTt) {
      stackHtml = '<p>The birth instant is after this browser clock; the running-period line appears once the birth instant has passed.</p>';
    } else {
      stackHtml = '<p>The 120-year Vimshottari window from this birth has closed (or the browser clock is off). Out-of-window queries are errors, never silent wraps - no running period is served.</p>';
    }
    var head = '<p>Birth moon: <strong>' + esc(NAKS[bal.nak]) + '</strong> at ' + moonDeg.toFixed(3) + '&deg; sidereal (Swiss-Lahiri reference line), ' + (bal.frac * 100).toFixed(1) + '% elapsed.</p>'
      + '<p><strong>Balance at birth:</strong> ' + esc(LORDS[bal.lord]) + ' mahadasha, ' + bal.days.toFixed(1) + ' days (' + (bal.days / YEAR_DAYS).toFixed(3) + ' solar dasha years of ' + YEARS[bal.lord] + ').</p>';
    return { html: head + stackHtml + '<table><tr><th>#</th><th>Mahadasha lord</th><th>Begins</th><th>Ends</th><th>Days</th></tr>' + rows + '</table>' };
  }
  function run() {
    var out = document.getElementById('dasha-calc-out');
    if (!out) { return; }
    var dateStr = document.getElementById('dasha-date').value;
    var timeStr = document.getElementById('dasha-time').value;
    var tz = document.getElementById('dasha-tz').value;
    var res = compute(dateStr, timeStr, tz);
    if (res.error) { out.innerHTML = '<p><em>' + esc(res.error) + '</em></p>'; return; }
    out.innerHTML = res.html;
    if (window.history && window.history.replaceState) {
      window.history.replaceState(null, '', '?date=' + encodeURIComponent(dateStr) + '&time=' + encodeURIComponent(timeStr) + '&tz=' + encodeURIComponent(tz));
    }
  }
  function init() {
    var params = new URLSearchParams(window.location.search);
    var d = params.get('date');
    var t = params.get('time');
    var z = params.get('tz');
    if (d) { document.getElementById('dasha-date').value = d; }
    if (t) { document.getElementById('dasha-time').value = t; }
    if (z) { document.getElementById('dasha-tz').value = z; }
    var btn = document.getElementById('dasha-calc-btn');
    if (btn) { btn.addEventListener('click', run); }
    if (d && t) { run(); }
  }
  if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', init); } else { init(); }
})();''';
}

/// The /dasha page (Wave 2 display, HYA-451): the today-anchored
/// engine illustration, the birth-query calculator, the conventions
/// record, the receipts/honesty status and the meta section.
String _dashaPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final jdTt = _grahaNoonJdTt(todayAd);
  final ay = ayanamsaSwissLahiriReference(jdTt);
  final moonDeg = moonSiderealInFrameDeg(jdTt, ay);
  final bal = vimshottariBalanceFromMoonDeg(moonDeg,
      yearDays: vimshottariYearDaysSolar);
  final mahas = vimshottariMahadashasFromMoonDeg(
      moonDeg: moonDeg, birthJdTt: jdTt, yearDays: vimshottariYearDaysSolar);
  final nakName = nakshatraNames[bal.nakshatraIndex];
  final lord = vimshottariLords[bal.lordIndex];
  final mahaRows = [
    for (var i = 0; i < mahas.length; i++)
      '<tr><td>' +
          (i + 1).toString() +
          '</td><td>' +
          mahas[i].lord +
          '</td><td>' +
          _dashaIsoNpt(mahas[i].startJdTt) +
          '</td><td>' +
          _dashaIsoNpt(mahas[i].endJdTt) +
          '</td><td>' +
          mahas[i].spanDays.toStringAsFixed(1) +
          '</td></tr>'
  ].join('\n');
  final body = '''
<h1>Dasha <span lang="ne">· दशा</span> — the Vimshottari periods</h1>
<p>The Vimshottari dasha — the 120-year nine-lord period system of BPHS ch. 46 — is arithmetic on the Moon's nakshatra at the birth instant, and the nMiti engine computes it on the same calibrated moon (ELP2000-82B + nutation) that serves every limb: the nine lords Ketu, Venus, Sun, Moon, Mars, Rahu, Jupiter, Saturn, Mercury (7+20+6+10+7+18+16+19+17 = 120 years), the balance of the first mahadasha from the elapsed nakshatra fraction, and the proportional antardasha/pratyantardasha nesting below it. <strong>Honesty status:</strong> no publisher receipt corpus gates the dasha dates yet — the deterministic dasha calculators are client-side forms — so the two load-bearing conventions (the dasha-year length and the ayanamsa frame) are served as stated parameters, never silent choices.</p>

<h2 id="dasha-today">आजको अंश · Today-anchored illustration</h2>
<p>Reference instant: <strong>NPT noon of ${_iso(todayAd)}</strong> (${_iso(todayAd)}T12:00+05:45). What follows is an <strong>illustrative birth at that instant</strong> — it exercises the full dasha arithmetic on today's calibrated moon and changes daily; it is not a prediction and not tied to any visitor. Birth moon: <strong>$nakName</strong> at ${moonDeg.toStringAsFixed(3)}&deg; sidereal (Swiss-Lahiri reference line), ${(bal.nakshatraElapsedFraction * 100.0).toStringAsFixed(1)}% of the nakshatra elapsed.</p>
<p><strong>Balance at birth:</strong> $lord mahadasha — ${bal.balanceDays.toStringAsFixed(1)} days (${(bal.balanceDays / vimshottariYearDaysSolar).toStringAsFixed(3)} solar dasha years of the lord's full ${vimshottariYears[bal.lordIndex]}).</p>
<table>
<tr><th>#</th><th>Mahadasha lord</th><th>Begins (NPT)</th><th>Ends (NPT)</th><th>Days</th></tr>
$mahaRows
</table>

<h2 id="dasha-calculator">जन्म प्रश्न · Birth-query calculator</h2>
<p><strong>Honest label:</strong> this form runs a small CLIENT-SIDE MIRROR of the engine arithmetic in your browser — the one deliberate exception to nMiti's zero-JS rule, because a build-time page cannot know a birth. The mirror uses the full 60-term Meeus ch. 47 moon (about 10&prime;&prime; class), the 4-term nutation, the same Swiss-Lahiri reference line and the same 365.25-day solar dasha year as the served block; the Dart engine remains canonical and the mirror should agree with it to seconds of nakshatra fraction. A computed result is written into the URL (date, time, tz) so it is shareable as a plain link — with or without JavaScript.</p>
<p>
<label>Date (AD): <input type="date" id="dasha-date" value="2000-01-01"></label>
<label>Time: <input type="time" id="dasha-time" value="12:00"></label>
<label>Time zone: <select id="dasha-tz">
<option value="+05:45" selected>UTC+05:45 (Nepal)</option>
<option value="+05:30">UTC+05:30 (India)</option>
<option value="+00:00">UTC+00:00</option>
<option value="-05:00">UTC-05:00</option>
<option value="-08:00">UTC-08:00</option>
</select></label>
<button type="button" id="dasha-calc-btn">Compute</button>
</p>
<div id="dasha-calc-out"><p>The balance and the mahadasha table appear here after you compute — or on arrival with date and time in the URL.</p></div>
''' +
      _dashaCalcJs() +
      '''
<h2 id="dasha-conventions">नियम · Conventions</h2>
<p>Every rule below is stated, never silently resolved. Where a convention is provisional, the page says so.</p>
<table>
<tr><th>Rule</th><th>What nMiti serves and why</th></tr>
<tr><td>Dasha-year length</td><td><strong>365.25 days</strong> per dasha year (the common software convention) is SERVED; the classical 360-day count is the stated alternative. The two differ by ~629 days across the 120-year cycle — the single largest convention risk in the system. Dated publisher receipts are pending (the deterministic calculators are client-side forms); the parameter stays explicit until they decode it.</td></tr>
<tr><td>Ayanamsa frame</td><td>the birth moon is the apparent sidereal longitude on the receipts-measured Swiss-Lahiri reference line — 23.85709&deg; + 1.398024&deg; per Julian century, the same display channel the <a href="${urlBase}graha.html">graha</a> layer prints. The engine base profile and the per-source publisher profiles remain available as crosscheck channels.</td></tr>
<tr><td>Level nesting</td><td>the mahadasha chain opens at the birth instant with the balance remainder; antardasha and pratyantardasha are the nine proportional children of BPHS ch. 46 — each child spans years[lord]/120 of its parent and opens with the parent's own lord. Half-open [start, end) intervals; a query exactly at a boundary resolves to the following period.</td></tr>
<tr><td>Window</td><td>nine mahadashas (120 years) are served. Queries before the birth instant or beyond the window are ERRORS, never silent wraps — the calculator says so instead of inventing a period.</td></tr>
<tr><td>Seed limb</td><td>the balance comes from the Moon's nakshatra (13&deg;20&prime; sectors from Ashwini; the lord of the nakshatra opens the cycle) — the same sector arithmetic the panchang nakshatra limb serves.</td></tr>
</table>

<h2 id="dasha-receipts">प्रमाण · Receipts and honesty status</h2>
<ul>
<li><strong>No publisher dasha receipt corpus gates the dates yet.</strong> The reconnaissance (recorded on HYA-451, 2026-11-12) found every deterministic Vimshottari calculator to be a client-side form; the one GET-parameterized server-rendered candidate (prokerala.com) rate-limited the crawl (429, retried 2026-11-13). Until dated receipts land, the served dates carry their convention label and the dasha-year parameter stays explicit.</li>
<li><strong>What IS gated today:</strong> the arithmetic is self-consistency-gated in CI on every push — the lord/years tables pinned (9 lords, 120-year total, BPHS order), the balance cases (full, half-elapsed, wrap), the chain (opens at birth, chains, totals 120&times;365.25 days), the antardasha order and sums, the pratyantar sums, and the integration with the Meeus 47.a epoch moon.</li>
<li><strong>The birth moon is calibrated:</strong> the same ELP2000-82B moon + nutation the panchang serves — nakshatra boundaries at ~51 s mean vs Swiss Lahiri (the ayanamsa convention gap, measured in CI), so the dasha seed is as good as the panchang itself.</li>
<li><strong>Named absence:</strong> other dasha systems (Yogini, Ashtottari, Chara) are not served — receipt-justified extensions, not silent skips.</li>
</ul>

<h2 id="dasha-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> the nMiti nepali_panchang Vimshottari dasha engine (Wave 2, HYA-451) — pure arithmetic on the calibrated sidereal moon; the today-anchored block above is computed at build time by the Dart engine.</li>
<li><strong>Calculator:</strong> the form is a labeled client-side mirror (Meeus ch. 47 moon, 4-term nutation, the Swiss-Lahiri line, the 365.25-day year) — the Dart engine remains canonical.</li>
<li><strong>Machine-readable:</strong> the <a href="${urlBase}api/v1/today.json">today.json</a> <code>dasha</code> block carries the today-anchored birth moon, balance, mahadasha table and conventions.</li>
<li><strong>Related:</strong> <a href="${urlBase}graha.html">graha (the planets)</a> · <a href="${urlBase}lagna.html">lagna (the ascendant)</a> · <a href="${urlBase}ayanamsa.html">ayanamsa (the sidereal reference)</a> · <a href="${urlBase}panchang.html">today's limbs</a>.</li>
</ul>
''';
  return _docShell(
      'Dasha (Vimshottari)',
      'The Vimshottari dasha from the nMiti engine: the today-anchored balance and mahadasha table, a birth-query calculator (labeled client-side mirror), the dasha-year and ayanamsa conventions stated, and the honest no-receipts-yet status.',
      urlBase,
      'dasha.html',
      body,
      shortSha);
}
