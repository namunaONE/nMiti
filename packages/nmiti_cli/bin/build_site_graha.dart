part of 'build_site.dart';

/// The graha display layer (Wave 1, HYA-450 PR-B): the today.json
/// graha block, the /graha page and the Guru/Shukra asta season flags
/// the saait grid carries (v1.5). Everything here renders the shipped
/// graha engine (PR #83) - no new astronomy, no recomputed truth.
///
/// Conventions stated, never silently resolved:
///   reference instant = NPT noon of today (the madhyahna family), and
///   it is EXPOSED in the block (`reference_instant_npt`) - the
///   publisher-print lesson: expose, never silently resolve;
///   display channel   = the apparent geocentric sidereal longitude on
///   the receipts-measured Swiss-Lahiri reference line (the frame the
///   graha publisher corpus prints), not the engine base profile;
///   Rahu              = the mean node (the classical Rahu; the true
///   node is the named skip); Ketu exactly opposite;
///   combust           = the engine's PROVISIONAL classical limits,
///   stated - the BPHS ch. 9 citation is an open receipt; not defined
///   for Rahu/Ketu;
///   rise/set          = the engine's Kathmandu solvers (center at
///   -34 arcmin; semidiameter and topocentric parallax are named
///   skips); not served for Rahu/Ketu.

/// The graha page's station horizon, days - the same 45-day window
/// family the vrat, festival and saait blocks use.
const int _grahaHorizonDays = 45;

/// English display names of the five visible grahas, indexed by
/// [GrahaBody.values] order (mercury .. saturn).
const List<String> _grahaNamesEn = [
  'Mercury',
  'Venus',
  'Mars',
  'Jupiter',
  'Saturn',
];

/// Devanagari names, the same order.
const List<String> _grahaNamesNp = [
  'बुध',
  'शुक्र',
  'मंगल',
  'बृहस्पति',
  'शनि',
];

double _grahaNorm360(double deg) => ((deg % 360.0) + 360.0) % 360.0;

/// The graha reference instant of an AD civil day: NPT noon, TT domain.
double _grahaNoonJdTt(DateTime day) {
  final jdUt = julianDayFromCivil(day.year, day.month, day.day.toDouble()) +
      6.25 / 24.0;
  return jdTtFromJdUt(jdUt);
}

/// "HH:MM" NPT wall clock of a UT Julian Day, or null.
String? _grahaHmNpt(double? jdUt) {
  if (jdUt == null) return null;
  final wall = dateTimeUtcFromJd(jdUt).add(nepalTimeOffset);
  return _skTwo(wall.hour) + ':' + _skTwo(wall.minute);
}

/// Full "yyyy-MM-dd HH:MM NPT" stamp of a UT Julian Day, or '-'.
String _grahaDtNpt(double jdUt) {
  final wall = dateTimeUtcFromJd(jdUt).add(nepalTimeOffset);
  return _iso(wall) + ' ' + _skTwo(wall.hour) + ':' + _skTwo(wall.minute) +
      ' NPT';
}

/// Sidereal longitude as D deg M arcmin S arcsec - the receipt format
/// the lagna page prints.
String _grahaDms(double deg) {
  final d = deg.floor();
  final mFull = (deg - d) * 60.0;
  final m = mFull.floor();
  final s = ((mFull - m) * 60.0).round();
  return d.toString() +
      '\u00b0 ' +
      m.toString().padLeft(2, '0') +
      '\u2032 ' +
      s.toString().padLeft(2, '0') +
      '\u2033';
}

/// Rashi index 0..11 (Aries = 0) of a sidereal longitude.
int _grahaRashiIndex(double sid) => (sid / 30.0).floor();

/// Nakshatra index 0..26 (Ashwini = 0) of a sidereal longitude.
int _grahaNakshatraIndex(double sid) => (sid / (360.0 / 27.0)).floor();

/// Pada 1..4 of a sidereal longitude inside its nakshatra.
int _grahaPada(double sid) {
  final within = sid - _grahaNakshatraIndex(sid) * (360.0 / 27.0);
  return (within / (360.0 / 108.0)).floor() + 1;
}

/// Whether [body] is asta (combust) on the NPT civil day [day],
/// evaluated at the day's NPT-noon reference instant - the stated
/// display v1.5 convention behind the saait grid flags. The engine
/// limits are PROVISIONAL (see the graha conventions); callers expose
/// the flag, never filter on it.
bool _grahaAstaOn(GrahaBody body, DateTime day) {
  return grahaIsCombust(body, _grahaNoonJdTt(day));
}

/// The shared JSON body of one graha entry (the five planets and
/// Rahu/Ketu, which pass null for the undefined channels). Every key
/// always serializes - nulls are emitted, never omitted (the
/// site-contract marker rule).
String _grahaEntryJson(
  double sid, {
  required bool retrograde,
  required bool? combust,
  required double speed,
  required double? distanceAu,
  required String? riseNpt,
  required String? setNpt,
}) {
  final ri = _grahaRashiIndex(sid);
  final ni = _grahaNakshatraIndex(sid);
  return '{\n'
      '      "sidereal_deg": ' +
      sid.toStringAsFixed(4) +
      ',\n'
      '      "sidereal_dms": "' +
      _grahaDms(sid) +
      '",\n'
      '      "rashi": "' +
      lagnaRashiNames[ri] +
      '",\n'
      '      "rashi_np": "' +
      lagnaRashiNamesNepali[ri] +
      '",\n'
      '      "rashi_index": ' +
      ri.toString() +
      ',\n'
      '      "degree_in_rashi": ' +
      (sid - ri * 30.0).toStringAsFixed(2) +
      ',\n'
      '      "nakshatra": "' +
      nakshatraNames[ni] +
      '",\n'
      '      "nakshatra_index": ' +
      ni.toString() +
      ',\n'
      '      "nakshatra_pada": ' +
      _grahaPada(sid).toString() +
      ',\n'
      '      "retrograde": ' +
      (retrograde ? 'true' : 'false') +
      ',\n'
      '      "combust": ' +
      (combust == null ? 'null' : (combust ? 'true' : 'false')) +
      ',\n'
      '      "speed_deg_per_day": ' +
      speed.toStringAsFixed(3) +
      ',\n'
      '      "distance_au": ' +
      (distanceAu == null ? 'null' : distanceAu.toStringAsFixed(3)) +
      ',\n'
      '      "rise_npt": ' +
      (riseNpt == null ? 'null' : '"' + riseNpt + '"') +
      ',\n'
      '      "set_npt": ' +
      (setNpt == null ? 'null' : '"' + setNpt + '"') +
      '\n'
      '    }';
}

/// One visible graha as a JSON entry at the reference instant [jdTt].
String _grahaBodyJson(GrahaBody body, double jdTt, DateTime todayAd) {
  final p = grahaPosition(body, jdTt);
  final rate = grahaLongitudeRateDegPerDay(body, jdTt);
  final rise = _grahaHmNpt(grahaRiseJdUt(
      body: body,
      year: todayAd.year,
      month: todayAd.month,
      day: todayAd.day));
  final set = _grahaHmNpt(grahaSetJdUt(
      body: body,
      year: todayAd.year,
      month: todayAd.month,
      day: todayAd.day));
  return _grahaEntryJson(
    p.siderealLongitudeDeg,
    retrograde: rate < 0.0,
    combust: grahaIsCombust(body, jdTt),
    speed: rate,
    distanceAu: p.distanceAu,
    riseNpt: rise,
    setNpt: set,
  );
}

/// The graha block of today.json (Wave 1 display): the five visible
/// grahas plus Rahu/Ketu at the NPT-noon reference instant - sidereal
/// on the Swiss-Lahiri reference line with rashi, nakshatra and pada,
/// the retrograde and combust flags, speed, distance and the
/// Kathmandu rise/set, with every convention stated.
String _grahaBlock(DateTime todayAd, String urlBase) {
  final jdTt = _grahaNoonJdTt(todayAd);
  final planetEntries = [
    for (final b in GrahaBody.values)
      '    "' + b.name + '": ' + _grahaBodyJson(b, jdTt, todayAd)
  ].join(',\n');
  final rahuSid = _grahaNorm360(
      rahuMeanLongitudeDeg(jdTt) - ayanamsaSwissLahiriReference(jdTt));
  final rahuRate = (rahuMeanLongitudeDeg(jdTt + 0.5) -
          rahuMeanLongitudeDeg(jdTt - 0.5)) /
      1.0;
  final nodeEntries = [
    '    "rahu": ' +
        _grahaEntryJson(rahuSid,
            retrograde: true,
            combust: null,
            speed: rahuRate,
            distanceAu: null,
            riseNpt: null,
            setNpt: null),
    '    "ketu": ' +
        _grahaEntryJson(_grahaNorm360(rahuSid + 180.0),
            retrograde: true,
            combust: null,
            speed: rahuRate,
            distanceAu: null,
            riseNpt: null,
            setNpt: null),
  ].join(',\n');
  return '{\n'
      '    "note": "the five visible grahas (Mercury-Saturn) plus Rahu and Ketu, apparent geocentric sidereal on the Swiss-Lahiri reference line; the reference instant is stated below, never silently resolved",\n'
      '    "reference_instant_npt": "' +
      _iso(todayAd) +
      'T12:00+05:45",\n'
      '    "bodies": {\n' +
      planetEntries +
      ',\n' +
      nodeEntries +
      '\n    },\n'
      '    "conventions": {\n'
      '      "frame": "apparent geocentric longitude (light-time + first-order aberration, true equinox of date) minus the receipts-measured Swiss-Lahiri ayanamsa line 23.85709 deg + 1.398024 deg per Julian century - the frame the graha publisher corpus prints",\n'
      '      "reference_instant": "NPT noon of today - the same madhyahna reference family the panchang limbs use; exposed, never silently resolved",\n'
      '      "rahu_ketu": "Rahu is the mean node (the classical Rahu; the true node is the named skip), always retrograde at about -0.053 deg/day; Ketu exactly opposite",\n'
      '      "retrograde": "the sign of the apparent-longitude rate (central difference, 0.05 d)",\n'
      '      "combust": "PROVISIONAL classical limits - mercury 14, venus 10, mars 17, jupiter 11, saturn 15 deg apparent separation from the Sun; the BPHS ch. 9 citation is an open receipt; null for Rahu/Ketu (not defined)",\n'
      '      "rise_set": "the center at -34 arcmin (standard horizon refraction), Kathmandu 27.7172 N / 85.324 E; semidiameter and topocentric parallax are named skips; null for Rahu/Ketu (not served)",\n'
      '      "sectors": "rashi and nakshatra by fixed-sector arithmetic on the sidereal longitude (30 deg rashi, 13 deg 20 min nakshatra, pada quarter) - stated display conventions, not publisher-matched labels"\n'
      '    },\n'
      '    "provenance": "the nMiti nepali_panchang graha engine (Wave 1, HYA-450) on the vendored VSOP87D table (Mercury-Saturn); Rahu/Ketu on the Meeus ch. 47.7 mean node",\n'
      '    "evidence_tier": "runtime-computed; gated by the JPL Horizons DE441 receipt fixture (test/fixtures/graha_receipts_2026_11.json; bands apparent longitude hard 5 arcsec / mean 1.5 arcsec, latitude hard 5 arcsec; post-fix measured class 0.35-0.58 arcsec) and scored against Swiss Ephemeris in the CI verify on every push",\n'
      '    "details": "' +
      urlBase +
      'graha.html"\n'
      '  }';
}

/// One visible-graha row of the page's positions table.
String _grahaRowHtml(GrahaBody body, double jdTt, DateTime todayAd) {
  final i = body.index;
  final p = grahaPosition(body, jdTt);
  final rate = grahaLongitudeRateDegPerDay(body, jdTt);
  final retro = rate < 0.0;
  final combust = grahaIsCombust(body, jdTt);
  final flags = [
    if (retro) 'retrograde',
    if (combust) 'combust',
  ];
  final rise = _grahaHmNpt(grahaRiseJdUt(
      body: body,
      year: todayAd.year,
      month: todayAd.month,
      day: todayAd.day));
  final set = _grahaHmNpt(grahaSetJdUt(
      body: body,
      year: todayAd.year,
      month: todayAd.month,
      day: todayAd.day));
  return '<tr><td>' +
      _grahaNamesEn[i] +
      ' <span lang="ne">' +
      _grahaNamesNp[i] +
      '</span></td>' +
      '<td>' +
      p.siderealLongitudeDeg.toStringAsFixed(4) +
      '<br><small>' +
      _grahaDms(p.siderealLongitudeDeg) +
      '</small></td>' +
      '<td>' +
      lagnaRashiNames[_grahaRashiIndex(p.siderealLongitudeDeg)] +
      ' <span lang="ne">' +
      lagnaRashiNamesNepali[_grahaRashiIndex(p.siderealLongitudeDeg)] +
      '</span><br><small>' +
      (p.siderealLongitudeDeg -
              _grahaRashiIndex(p.siderealLongitudeDeg) * 30.0)
          .toStringAsFixed(2) +
      '&deg; in</small></td>' +
      '<td>' +
      nakshatraNames[_grahaNakshatraIndex(p.siderealLongitudeDeg)] +
      '<br><small>pada ' +
      _grahaPada(p.siderealLongitudeDeg).toString() +
      '</small></td>' +
      '<td>' +
      rate.toStringAsFixed(3) +
      '&deg;/d</td>' +
      '<td>' +
      (flags.isEmpty ? '-' : flags.join(' + ')) +
      '</td>' +
      '<td>' +
      (rise == null && set == null
          ? '-'
          : (rise ?? '-') + ' / ' + (set ?? '-')) +
      '</td></tr>';
}

/// The /graha page (Wave 1 display, HYA-450): today's graha positions
/// with rashi, nakshatra, retrograde and combustion state, the
/// Kathmandu rise/set and the stations ahead, the full conventions
/// record, the Horizons/Swiss receipts and the meta section. Zero
/// client JavaScript; every value computed at build time by the shipped
/// graha engine.
String _grahaPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final jdTt = _grahaNoonJdTt(todayAd);
  final rows = [
    for (final b in GrahaBody.values) _grahaRowHtml(b, jdTt, todayAd)
  ].join('\n');
  final rahuSid = _grahaNorm360(
      rahuMeanLongitudeDeg(jdTt) - ayanamsaSwissLahiriReference(jdTt));
  final ketuSid = _grahaNorm360(rahuSid + 180.0);
  String nodeRow(String key, String nameEn, String nameNp, double sid) =>
      '<tr><td>' +
      nameEn +
      ' <span lang="ne">' +
      nameNp +
      '</span></td>' +
      '<td>' +
      sid.toStringAsFixed(4) +
      '<br><small>' +
      _grahaDms(sid) +
      '</small></td>' +
      '<td>' +
      lagnaRashiNames[_grahaRashiIndex(sid)] +
      ' <span lang="ne">' +
      lagnaRashiNamesNepali[_grahaRashiIndex(sid)] +
      '</span></td>' +
      '<td>' +
      nakshatraNames[_grahaNakshatraIndex(sid)] +
      '<br><small>pada ' +
      _grahaPada(sid).toString() +
      '</small></td>' +
      '<td>-0.053&deg;/d</td>' +
      '<td>retrograde (mean node)</td>' +
      '<td>-</td></tr>';
  final stationRows = <String>[];
  for (final b in GrahaBody.values) {
    final s = grahaStationJdTt(b,
        startJdTt: jdTt, endJdTt: jdTt + _grahaHorizonDays);
    if (s == null) continue;
    final before = grahaLongitudeRateDegPerDay(b, s - 2.0);
    final after = grahaLongitudeRateDegPerDay(b, s + 2.0);
    final direction =
        after < 0.0 ? 'turns retrograde' : 'turns direct';
    stationRows.add('<tr><td>' +
        _grahaNamesEn[b.index] +
        '</td><td>' +
        _grahaDtNpt(jdUtFromJdTt(s)) +
        '</td><td>' +
        direction +
        ' (rate ' +
        before.toStringAsFixed(3) +
        '&deg;/d before, ' +
        after.toStringAsFixed(3) +
        '&deg;/d after)</td></tr>');
  }
  final stationTableRows = stationRows.isEmpty
      ? '<tr><td colspan="3">No graha station falls within the next ' +
          _grahaHorizonDays.toString() +
          ' days.</td></tr>'
      : stationRows.join('\n');
  final body = '''
<h1>Graha <span lang="ne">· ग्रह</span> — the planets today</h1>
<p>The five visible grahas - Mercury, Venus, Mars, Jupiter, Saturn - plus Rahu and Ketu, computed at build time by the nMiti graha engine: geocentric apparent places on the vendored VSOP87D table (light-time by iteration, first-order aberration, the shared 4-term nutation), rendered on the receipts-measured Swiss-Lahiri sidereal reference line with rashi, nakshatra and pada, the retrograde and combustion flags, and the Kathmandu rise/set. No copied tables, no client JavaScript.</p>

<h2 id="graha-today">आजका ग्रह · Today's graha</h2>
<p>Reference instant: <strong>NPT noon of ${_iso(todayAd)}</strong> (${_iso(todayAd)}T12:00+05:45) - the madhyahna reference family, stated, never silently resolved. Speed is the apparent sidereal rate; the state column names retrograde and combust motion; rise/set is the body's center at &minus;34&prime; at the Kathmandu anchor (27.7172 N, 85.324 E).</p>
<table>
<tr><th>Graha</th><th>Sidereal</th><th>Rashi</th><th>Nakshatra (pada)</th><th>Speed</th><th>State</th><th>Rise / Set (NPT)</th></tr>
$rows
${nodeRow('rahu', 'Rahu', 'राहु', rahuSid)}
${nodeRow('ketu', 'Ketu', 'केतु', ketuSid)}
</table>
<p>Rahu and Ketu are the mean lunar node and its opposite point (position only): combustion, distance and rise/set are not defined for them and are served as null in the JSON. The combustion limits are PROVISIONAL - see the conventions below.</p>

<h3>Stations ahead</h3>
<p>Every retrograde/direct station within the next ${_grahaHorizonDays} days, engine-solved (a 0.5-day rate-sign scan plus 60 bisections):</p>
<table>
<tr><th>Graha</th><th>Station (NPT)</th><th>Direction</th></tr>
$stationTableRows
</table>

<h2 id="graha-conventions">नियम · Conventions</h2>
<p>Every rule below is stated, never silently resolved. Where a convention is provisional, the page says so.</p>
<table>
<tr><th>Rule</th><th>What nMiti serves and why</th></tr>
<tr><td>Sidereal frame</td><td>the apparent geocentric longitude (light-time + first-order aberration, true equinox of date) minus the receipts-measured Swiss-Lahiri reference line - 23.85709&deg; + 1.398024&deg; per Julian century, the frame the graha publisher corpus prints. The engine base profile stays available as the crosscheck channel.</td></tr>
<tr><td>Rahu and Ketu</td><td>Rahu is the mean node on the Meeus ch. 47.7 polynomial (the classical Rahu; the true node is the named skip), always retrograde at about &minus;0.053&deg;/day; Ketu is exactly opposite. Not physical bodies: combust, distance and rise/set are not defined.</td></tr>
<tr><td>Reference instant</td><td>NPT noon of the build day - the madhyahna reference family the panchang limbs use, exposed as <code>reference_instant_npt</code> in the JSON. A build-time page cannot know your "now": the convention is stated, never silently resolved.</td></tr>
<tr><td>Retrograde</td><td>the sign of the apparent-longitude rate (central difference, &plusmn;0.05 d); stations come from the engine's rate-sign scan solver.</td></tr>
<tr><td>Combustion (asta)</td><td>PROVISIONAL classical limits - Mercury 14&deg;, Venus 10&deg;, Mars 17&deg;, Jupiter 11&deg;, Saturn 15&deg; apparent separation from the Sun. The BPHS ch. 9 citation is an open receipt and the retro variants (Mercury 12, Venus 8) are deliberately not used until the source is pinned. The saait grid flags the Guru/Shukra asta seasons on these limits - flagged, never filtered.</td></tr>
<tr><td>Rise / set</td><td>the body's center reaching &minus;34 arcmin (standard horizon refraction) at the Kathmandu anchor; semidiameter and topocentric parallax are named skips (planets are pointlike at this class).</td></tr>
<tr><td>Rashi / nakshatra</td><td>fixed-sector arithmetic on the sidereal longitude - 30&deg; rashi sectors (names shared with the lagna layer), 13&deg;20&prime; nakshatra sectors with pada quarters (names shared with the limb layer). Stated display conventions, not publisher-matched labels.</td></tr>
</table>

<h2 id="graha-receipts">प्रमाण · Receipts and verification</h2>
<ul>
<li><a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/graha_receipts_2026_11.json">graha_receipts_2026_11.json</a> - a fresh JPL Horizons DE441 fixture (schema nmiti-graha-receipts/1): dense daily rows 2026-10-16..12-03 for all five grahas plus 2-hour station-refinement windows that deliberately span a full Mercury retrograde loop, the Venus retrograde minimum, Saturn's retrograde and Jupiter decelerating toward its December station. Apparent longitude/latitude gated at hard 5&prime;&prime; / mean 1.5&prime;&prime; and latitude hard 5&prime;&prime;; the station solver is gated against the receipt &lambda;-minima (Mercury direct station at JD 2461358.17, Venus at JD 2461358.5) and rise/set self-consistency is checked.</li>
<li>Post-fix measured class: mercury 0.35&prime;&prime;/0.49&prime;&prime; and venus 0.42&prime;&prime;/0.58&prime;&prime; mean/max against Horizons - the first-CI 6.259&prime;&prime;/16.251&prime;&prime; class was a double EMB&rarr;Earth moon correction, removed once the CI measures pinned that the vendored Earth series behave Earth-center (the receipts proved it against Horizons CENTER 500 geocentric).</li>
<li><a href="https://github.com/namunaONE/nMiti/blob/main/tools/sweph/graha_crosscheck.py">graha_crosscheck.py</a> scores the engine daily against Swiss Ephemeris (MOSEPH, Lahiri) in the CI verify on every push - hard 120&prime;&prime;/mean 60&prime;&prime; bands carrying the measured +28.607&prime;&prime; base-vs-Swiss-Lahiri convention gap: stated, never absorbed (the five-planet mean sits near 29.3&prime;&prime; with ~0.2&prime;&prime; engine spread - a frame convention, not an ephemeris error).</li>
<li>Named skips: light deflection, aberration beyond first order, topocentric parallax, semidiameters, and the true node (the classical Rahu is the mean node).</li>
</ul>

<h2 id="graha-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> the nMiti nepali_panchang graha engine (Wave 1, HYA-450) on the vendored VSOP87D table - generated by <code>tools/sweph/graha_build_table.py</code>, regen-gated byte-diff by CI on every run; Rahu/Ketu on the Meeus ch. 47.7 mean node.</li>
<li><strong>Evidence:</strong> runtime-computed; gated by the JPL Horizons DE441 receipt fixture and scored against Swiss Ephemeris in the CI verify on every push (see <a href="${urlBase}methodology.html">methodology</a> and <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a>).</li>
<li><strong>Coverage, stated honestly:</strong> the five visible grahas plus Rahu/Ketu only - the outer planets (Uranus, Neptune) and the true node are named absences, not silent skips.</li>
<li><strong>Machine-readable:</strong> the <a href="${urlBase}api/v1/today.json">today.json</a> <code>graha</code> block carries every entry above with NPT stamps and the stated conventions.</li>
<li><strong>Related:</strong> <a href="${urlBase}lagna.html">lagna</a> · <a href="${urlBase}panchang.html">today's limbs</a> · <a href="${urlBase}ayanamsa.html">ayanamsa (the sidereal reference)</a> · <a href="${urlBase}saait.html">saait (the Guru/Shukra asta grid flags)</a>.</li>
</ul>
''';
  return _docShell(
      'Graha (the planets today)',
      'Nepal graha positions from the nMiti engine: the five visible planets Mercury-Saturn plus Rahu and Ketu - sidereal positions with rashi and nakshatra, retrograde and combustion flags, Kathmandu rise/set and the stations ahead - Horizons-receipt-anchored, conventions stated.',
      urlBase,
      'graha.html',
      body,
      shortSha);
}
