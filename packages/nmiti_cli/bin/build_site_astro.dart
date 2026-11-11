part of 'build_site.dart';

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
/// computed at BUILD TIME by the open nepali_panchang engine (ELP2000-82B
/// moon, VSOP87D sun, hybrid Delta T, per-source
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
<li><strong>Accuracy:</strong> minute-level parity with the locked BhaktiBharat and Hamro Patro golden corpora, enforced by CI on every change. See <a href="${urlBase}methodology.html">methodology</a> and <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a>.</li>
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


/// R10.1 display state (HYA-441): the Bhadra windows touching the given
/// NPT civil day. A window that begins late in the evening spans two
/// civil days, so the query unions bhadraNear over the previous, current
/// and next civil day and deduplicates by begins instant. The date-label
/// convention (the NPT civil day the window begins) is the engine's own
/// named convention, restated in the block note.
class _BhadraDayState {
  final List<BhadraWindow> touching;
  const _BhadraDayState(this.touching);
}

_BhadraDayState _bhadraDayState(DateTime todayAd) {
  final dayStart = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final seen = <String>{};
  final touching = <BhadraWindow>[];
  for (final delta in [-1, 0, 1]) {
    final d = dayStart.add(Duration(days: delta));
    final w = bhadraNear(year: d.year, month: d.month, day: d.day);
    if (w == null) continue;
    if (!seen.add(w.beginsAtNpt.toIso8601String())) continue;
    if (w.beginsAtNpt.isBefore(dayEnd) && w.endsAtNpt.isAfter(dayStart)) {
      touching.add(w);
    }
  }
  return _BhadraDayState(touching);
}

/// One Bhadra window as a JSON object body. Every key is always emitted
/// (both mukha/puchha rule families, neither absorbed) so the site
/// contract markers stay date-stable on Bhadra days and quiet days
/// alike.
String _bhadraWindowJson(String ind, BhadraWindow w) {
  String isoNpt(DateTime t) =>
      '${_iso(t)}T${_skTwo(t.hour)}:${_skTwo(t.minute)}:00+05:45';
  final segs = [
    for (final s in w.lokaSegments)
      '{"begins_at": "${isoNpt(s.beginsAtNpt)}", "rasi": ${s.rasi}, '
      '"rasi_name": "${bhadraRasiNames[s.rasi - 1]}", '
      '"loka": "${s.loka.name}"}'
  ].join(',\n$ind  ');
  return [
    '$ind"begins_at": "${isoNpt(w.beginsAtNpt)}",',
    '$ind"ends_at": "${isoNpt(w.endsAtNpt)}",',
    '$ind"date_iso": "${_iso(w.beginsAtNpt)}",',
    '$ind"karana_number": ${w.karanaNumber},',
    '$ind"tithi": "${tithiName(w.tithiIndex)}",',
    '$ind"tithi_half": "${w.firstHalfOfTithi ? 'first' : 'second'}",',
    '$ind"duration_minutes": ${w.durationNpt.inMinutes},',
    '$ind"mukha": {"rule": "ghati", "begins_at": "${isoNpt(w.beginsAtNpt)}", "ends_at": "${isoNpt(w.mukhaEndsAtNpt)}"},',
    '$ind"puchha": {"rule": "ghati", "begins_at": "${isoNpt(w.puchhaBeginsAtNpt)}", "ends_at": "${isoNpt(w.endsAtNpt)}"},',
    '$ind"mukha_fraction": {"rule": "fraction", "begins_at": "${isoNpt(w.beginsAtNpt)}", "ends_at": "${isoNpt(w.mukhaEndsAtNptFractional)}"},',
    '$ind"puchha_fraction": {"rule": "fraction", "begins_at": "${isoNpt(w.puchhaBeginsAtNptFractional)}", "ends_at": "${isoNpt(w.endsAtNpt)}"},',
    '$ind"loka_segments": [\n$ind  $segs\n$ind],',
    '$ind"evidence_tier": "${w.evidenceTier}"',
  ].join('\n');
}

/// The bhadra block of today.json (R10.1, HYA-441). The keys - "bhadra",
/// "today", "bhadra_active", "next" - always serialize on every build,
/// so the site contract markers are date-stable on Bhadra days and on
/// quiet days alike.
String _bhadraBlock(DateTime todayAd, String urlBase) {
  final state = _bhadraDayState(todayAd);
  final nowNpt = DateTime.now().toUtc().add(nepalTimeOffset);
  final next = nextBhadraAfter(nowNpt);
  final today = state.touching.isEmpty ? null : state.touching.first;
  var active = false;
  if (today != null &&
      !today.beginsAtNpt.isAfter(nowNpt) &&
      nowNpt.isBefore(today.endsAtNpt)) {
    active = true;
  }
  final todayJson = today == null
      ? 'null'
      : '{\n${_bhadraWindowJson('      ', today)}\n    }';
  final nextJson = '{\n${_bhadraWindowJson('      ', next)}\n    }';
  return '{\n'
      '    "note": "engine-computed at build time; the window is the Vishti karana half-tithi itself - the Bhadra date is the NPT civil day the window begins",\n'
      '    "today": $todayJson,\n'
      '    "bhadra_active": $active,\n'
      '    "next": $nextJson,\n'
      '    "provenance": "${next.provenance}",\n'
      '    "evidence_tier": "${next.evidenceTier}",\n'
      '    "details": "${urlBase}bhadra.html"\n'
      '  }';
}

/// The /bhadra page (R10.1, HYA-441): today's Bhadra state, the next
/// window, the upcoming windows, the rashi-to-loka table with its named
/// contiguous variant, and the full conventions map - receipt-anchored,
/// every collision exposed, never silently picked.
String _bhadraPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final state = _bhadraDayState(todayAd);
  final today = state.touching.isEmpty ? null : state.touching.first;
  final nowNpt = DateTime.now().toUtc().add(nepalTimeOffset);
  final next = nextBhadraAfter(nowNpt);
  final dayStart = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final upcoming = bhadraWindows(
      start: dayStart, end: dayStart.add(const Duration(days: 62)));
  String hm(DateTime t) => '${_skTwo(t.hour)}:${_skTwo(t.minute)}';
  String dt(DateTime t) => '${_iso(t)} ${hm(t)} NPT';
  String segList(BhadraWindow w) => [
        for (final s in w.lokaSegments)
          '${bhadraRasiNames[s.rasi - 1]} (${s.loka.name}) from ${hm(s.beginsAtNpt)}'
      ].join(', ');
  final String todayCard;
  if (today == null) {
    todayCard = '<p>No Bhadra window touches today.</p>';
  } else {
    final activeNow = !today.beginsAtNpt.isAfter(nowNpt) &&
        nowNpt.isBefore(today.endsAtNpt);
    todayCard = [
      '<p><strong>भद्रा · Bhadra touches today</strong> - active at this build: ${activeNow ? 'yes' : 'no'}.</p>',
      '<ul>',
      '<li><strong>आरम्भ · Begins:</strong> ${dt(today.beginsAtNpt)}</li>',
      '<li><strong>अन्त्य · Ends:</strong> ${dt(today.endsAtNpt)}</li>',
      '<li><strong>तिथि · Tithi:</strong> ${tithiName(today.tithiIndex)}, ${today.firstHalfOfTithi ? 'first' : 'second'} half (Vishti karana no. ${today.karanaNumber})</li>',
      '<li><strong>लोक · Loka:</strong> ${segList(today)}</li>',
      '</ul>',
    ].join('\n');
  }
  final nextCard = [
    '<p>The next Bhadra window runs on the <strong>${tithiName(next.tithiIndex)}</strong> - ${next.firstHalfOfTithi ? 'first' : 'second'} half (Vishti karana no. ${next.karanaNumber}).</p>',
    '<ul>',
    '<li><strong>मिति · Date (begins):</strong> ${_iso(next.beginsAtNpt)}</li>',
    '<li><strong>आरम्भ · Begins:</strong> ${dt(next.beginsAtNpt)} · <strong>अन्त्य · Ends:</strong> ${dt(next.endsAtNpt)} (${next.durationNpt.inMinutes} min)</li>',
    '<li><strong>मुख · Mukha (ghati rule, discarded):</strong> ${dt(next.beginsAtNpt)} to ${dt(next.mukhaEndsAtNpt)}</li>',
    '<li><strong>पुच्छा · Puchha (ghati rule, auspicious):</strong> ${dt(next.puchhaBeginsAtNpt)} to ${dt(next.endsAtNpt)}</li>',
    '<li><strong>लोक · Loka:</strong> ${segList(next)}</li>',
    '</ul>',
  ].join('\n');
  final upcomingRows = [
    for (final w in upcoming)
      '<tr><td>${_iso(w.beginsAtNpt)}</td>'
      '<td>${hm(w.beginsAtNpt)}-${hm(w.endsAtNpt)}</td>'
      '<td>${tithiName(w.tithiIndex)} (${w.firstHalfOfTithi ? 'first' : 'second'} half)</td>'
      '<td>${segList(w)}</td></tr>'
  ].join('\n');
  final lokaRows = [
    for (var r = 1; r <= 12; r++)
      '<tr><td>${bhadraRasiNames[r - 1]}</td>'
      '<td>${bhadraLokaByRasi[r]!.name}</td>'
      '<td>${bhadraLokaByRasiContiguousVariant[r]!.name}${bhadraLokaByRasi[r]! == bhadraLokaByRasiContiguousVariant[r]! ? '' : ' (disagrees)'}</td></tr>'
  ].join('\n');
  final convLabels = <String, String>{
    'identity': 'Identity',
    'window_frame': 'Window frame',
    'date_label': 'Date label',
    'mukha_puchha_primary': 'Mukha / Puchha (ghati rule, primary)',
    'mukha_puchha_fraction': 'Mukha / Puchha (fraction rule)',
    'loka_canonical': 'Loka (canonical table)',
    'loka_variant': 'Loka (contiguous variant)',
    'unreconciled_source': 'Unreconciled source',
  };
  final convRows = [
    for (final k in convLabels.keys)
      '<tr><td>${convLabels[k]}</td><td>${bhadraConventions[k] ?? '(not recorded)'}</td></tr>'
  ].join('\n');
  final body = '''
<h1>Bhadra <span lang="ne">· भद्रा</span></h1>
<p>Bhadra is the Vishti karana - the inauspicious half-tithi that recurs eight times per lunar month, computed here from the karana limb the engine already serves (the same sector boundaries the locked golden corpora pin to the minute). The window is a global instant pair; Indian pages print the same moments in IST (NPT minus 15 minutes). The first part of a window is the <strong>mukha</strong> (discarded) and the last part the <strong>puchha</strong> (auspicious); two published rule families exist and both are computed, neither absorbed.</p>

<h2 id="bhadra-today">आज · Today</h2>
$todayCard

<h2 id="bhadra-next">अर्को भद्रा · Next Bhadra</h2>
$nextCard

<h2 id="bhadra-upcoming">आउँदै भद्रा · Upcoming windows</h2>
<p>Every window beginning in the next 62 days.</p>
<table>
<tr><th>Begins (AD)</th><th>Window (NPT)</th><th>Tithi half</th><th>Loka path</th></tr>
$upcomingRows
</table>

<h2 id="bhadra-loka">लोक तालिका · The rashi-to-loka table</h2>
<p>The moon's rashi during the window maps to the abode Swarga, Prithvi or Patala. The canonical table (BhaktiBharat, PanchangBodh and the Swarnsiddhi live windows agree) is served; the contiguous-arc variant (bhaktivoice) is shown beside it with disagreements flagged - never silently resolved.</p>
<table>
<tr><th>Rashi</th><th>Canonical loka</th><th>Contiguous variant</th></tr>
$lokaRows
</table>

<h2 id="bhadra-conventions">नियम · Conventions</h2>
<p>Every rule below is receipt-anchored; where publishers disagree, the collision is decoded and shown, never silently picked.</p>
<table>
<tr><th>Rule</th><th>What nMiti serves and why</th></tr>
$convRows
</table>

<h2 id="bhadra-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> ${next.provenance}</li>
<li><strong>Evidence:</strong> ${next.evidenceTier}</li>
<li><strong>Verification:</strong> the window edges are karana-limb boundaries, pinned to the minute by the locked BhaktiBharat and Hamro Patro golden corpora and band-checked against Swiss Ephemeris in CI; the dedicated Bhadra gate (<code>bhadra_test.dart</code>) runs on every change. See <a href="${urlBase}methodology.html">methodology</a> and <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a>.</li>
<li><strong>Receipts:</strong> <a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/bhadra_receipts_2026.json">bhadra_receipts_2026.json</a> - the Swarnsiddhi windows, BhaktiBharat rule text and date lists, with the golden-corpus edge pins and the bhaktivoice caveat.</li>
<li><strong>Machine-readable:</strong> the <a href="${urlBase}api/v1/today.json">today.json</a> <code>bhadra</code> block carries the window touching today, the active flag and the next window with both rule families.</li>
</ul>
''';
  return _docShell(
      'Bhadra (Vishti karana windows)',
      'Nepal Bhadra windows from the nMiti engine: today window, the mukha/puchha spans under both published rules, the loka table and the next Bhadra - receipt-anchored, never copied.',
      urlBase,
      'bhadra.html',
      body,
      shortSha);
}
/// The Panchak window touching the NPT civil day [dayStart, dayEnd) -
/// covering the day start or beginning inside the day - or null.
PanchakWindow? _panchakTouching(DateTime dayStart, DateTime dayEnd) {
  final covering = panchakOn(dayStart);
  if (covering != null) return covering;
  final up = nextPanchakAfter(dayStart);
  if (up.beginsAtNpt.isBefore(dayEnd)) return up;
  return null;
}

/// One Panchak window as a JSON object body. Every key is always
/// emitted so the site contract markers stay date-stable on Panchak
/// days and quiet days alike.
String _panchakWindowJson(String ind, PanchakWindow w) {
  String isoNpt(DateTime t) =>
      '${_iso(t)}T${_skTwo(t.hour)}:${_skTwo(t.minute)}:00+05:45';
  final segs = [
    for (final s in w.nakshatraSegments)
      '{"name": "${s.name}", "begins_at": "${isoNpt(s.beginsAtNpt)}"}'
  ].join(',\n$ind  ');
  return [
    '$ind"date_iso": "${_iso(w.beginsAtNpt)}",',
    '$ind"begins_at": "${isoNpt(w.beginsAtNpt)}",',
    '$ind"ends_at": "${isoNpt(w.endsAtNpt)}",',
    '$ind"type": "${w.type.name}",',
    '$ind"type_name": "${w.typeName}",',
    '$ind"weekday": ${w.beginsWeekdayNpt},',
    '$ind"duration_minutes": ${w.durationNpt.inMinutes},',
    '$ind"nakshatras": [\n$ind  $segs\n$ind],',
    '$ind"evidence_tier": "${w.evidenceTier}"',
  ].join('\n');
}

/// The panchak block of today.json (R10.1 layer 2, HYA-441). The keys -
/// "panchak", "today", "panchak_active", "next" - always serialize on
/// every build, so the site contract markers are date-stable on Panchak
/// days and on quiet days alike.
String _panchakBlock(DateTime todayAd, String urlBase) {
  final dayStart = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final nowNpt = DateTime.now().toUtc().add(nepalTimeOffset);
  final today = _panchakTouching(dayStart, dayEnd);
  final next = nextPanchakAfter(nowNpt);
  var active = false;
  if (today != null &&
      !today.beginsAtNpt.isAfter(nowNpt) &&
      nowNpt.isBefore(today.endsAtNpt)) {
    active = true;
  }
  final todayJson = today == null
      ? 'null'
      : '{\n${_panchakWindowJson('      ', today)}\n    }';
  final nextJson = '{\n${_panchakWindowJson('      ', next)}\n    }';
  return '{\n'
      '    "note": "engine-computed at build time; the window is the Moon\'s 300-360 deg sidereal transit - the Panchak date is the NPT civil day the window begins",\n'
      '    "today": $todayJson,\n'
      '    "panchak_active": $active,\n'
      '    "next": $nextJson,\n'
      '    "provenance": "${next.provenance}",\n'
      '    "evidence_tier": "${next.evidenceTier}",\n'
      '    "details": "${urlBase}panchak.html"\n'
      '  }';
}

/// The /panchak page (R10.1 layer 2, HYA-441): today's Panchak state,
/// the next window, the upcoming windows with their weekday types, and
/// the full conventions map - receipt-anchored, every collision
/// exposed, never silently picked.
String _panchakPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final dayStart = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final nowNpt = DateTime.now().toUtc().add(nepalTimeOffset);
  final today = _panchakTouching(dayStart, dayEnd);
  final next = nextPanchakAfter(nowNpt);
  final upcoming = panchakWindows(
      start: dayStart, end: dayStart.add(const Duration(days: 400)));
  String hm(DateTime t) => '${_skTwo(t.hour)}:${_skTwo(t.minute)}';
  String dt(DateTime t) => '${_iso(t)} ${hm(t)} NPT';
  String days(Duration d) => (d.inMinutes / 1440.0).toStringAsFixed(2);
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String segList(PanchakWindow w) => [
        for (final s in w.nakshatraSegments)
          '${s.name} from ${dt(s.beginsAtNpt)}'
      ].join(' · ');
  final String todayCard;
  if (today == null) {
    todayCard =
        '<p>No Panchak window touches today. Panchak is the Moon\'s position, not a local event - a quiet day is not an anomaly; the next window is below.</p>';
  } else {
    final activeNow = !today.beginsAtNpt.isAfter(nowNpt) &&
        nowNpt.isBefore(today.endsAtNpt);
    todayCard = [
      '<p><strong>पञ्चक · Panchak touches today</strong> - active at this build: ${activeNow ? 'yes' : 'no'}.</p>',
      '<ul>',
      '<li><strong>प्रकार · Type:</strong> ${today.typeName}</li>',
      '<li><strong>आरम्भ · Begins:</strong> ${dt(today.beginsAtNpt)}</li>',
      '<li><strong>अन्त्य · Ends:</strong> ${dt(today.endsAtNpt)} (${today.durationNpt.inMinutes} min, ${days(today.durationNpt)} days)</li>',
      '<li><strong>नक्षत्रहरू · Nakshatras:</strong> ${segList(today)}</li>',
      '</ul>',
    ].join('\n');
  }
  final nextCard = [
    '<p>The next Panchak window is <strong>${next.typeName}</strong>.</p>',
    '<ul>',
    '<li><strong>मिति · Date (begins):</strong> ${_iso(next.beginsAtNpt)} (${wd[next.beginsWeekdayNpt - 1]})</li>',
    '<li><strong>आरम्भ · Begins:</strong> ${dt(next.beginsAtNpt)} · <strong>अन्त्य · Ends:</strong> ${dt(next.endsAtNpt)}</li>',
    '<li><strong>अवधि · Duration:</strong> ${next.durationNpt.inMinutes} min (${days(next.durationNpt)} days)</li>',
    '<li><strong>नक्षत्रहरू · Nakshatras:</strong> ${segList(next)}</li>',
    '</ul>',
  ].join('\n');
  final upcomingRows = [
    for (final w in upcoming)
      '<tr><td>${_iso(w.beginsAtNpt)}</td>'
      '<td>${wd[w.beginsWeekdayNpt - 1]}</td>'
      '<td>${w.type.name}</td>'
      '<td>${dt(w.beginsAtNpt)} - ${dt(w.endsAtNpt)}</td>'
      '<td>${days(w.durationNpt)} d</td></tr>'
  ].join('\n');
  final convLabels = <String, String>{
    'identity': 'Identity',
    'window_frame': 'Window frame',
    'date_label': 'Date label',
    'type_rule': 'Type rule',
    'type_naming_collision': 'Type naming collision (Wed/Thu)',
    'dec_midnight_knife_edge': 'Dec 2026 midnight knife-edge',
    'prohibited': 'Traditionally cautioned activities',
    'unreconciled_source': 'Unreconciled sources',
  };
  final convRows = [
    for (final k in convLabels.keys)
      '<tr><td>${convLabels[k]}</td><td>${panchakConventions[k] ?? '(not recorded)'}</td></tr>'
  ].join('\n');
  final body = '''
<h1>Panchak <span lang="ne">· पञ्चक</span></h1>
<p>Panchak is the Moon's sidereal transit of the last five nakshatras: Dhanishta's last two padas (from sidereal 300 deg), then Shatabhisha, Purva Bhadrapada, Uttara Bhadrapada and Revati (to 360 deg) - about 4.5 days per window, once per sidereal month, 13 windows in 2026. The window is a global instant pair; Indian pages print the same moments in IST (NPT minus 15 minutes). The type is the weekday of the begin: Rog (Sunday), Rajya (Monday), Agni (Tuesday), Madhyam (Wednesday/Thursday), Chor (Friday), Mrityu (Saturday).</p>

<h2 id="panchak-today">आज · Today</h2>
$todayCard

<h2 id="panchak-next">अर्को पञ्चक · Next Panchak</h2>
$nextCard

<h2 id="panchak-upcoming">आउँदै पञ्चक · Upcoming windows</h2>
<p>Every window beginning in the next 400 days - the weekday type comes from the engine, not from any publisher table.</p>
<table>
<tr><th>Begins (AD)</th><th>Weekday</th><th>Type</th><th>Window (NPT)</th><th>Duration</th></tr>
$upcomingRows
</table>

<h2 id="panchak-conventions">नियम · Conventions</h2>
<p>Every rule below is receipt-anchored; where publishers disagree, the collision is decoded and shown, never silently picked.</p>
<table>
<tr><th>Rule</th><th>What nMiti serves and why</th></tr>
$convRows
</table>

<h2 id="panchak-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> ${next.provenance}</li>
<li><strong>Evidence:</strong> ${next.evidenceTier}</li>
<li><strong>Verification:</strong> the 300 deg begin and 360 deg end are solved by a dedicated wrap-safe bisection with a Newton cross-check on the same apparent-sidereal moon as the nakshatra limb; the end IS the Revati/Ashwini boundary the golden corpora pin. The gate (<code>panchak_test.dart</code>) bands all 13 Swarnsiddhi and 13 PanchangBodh windows, the BhaktiBharat current window and date lists and the corpus Revati-end pins on every change. See <a href="${urlBase}methodology.html">methodology</a> and <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a>.</li>
<li><strong>Receipts:</strong> <a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/panchak_receipts_2026.json">panchak_receipts_2026.json</a> - the Swarnsiddhi and PanchangBodh tables, the BhaktiBharat window and date lists, golden-corpus edge pins; the fabricated bhaktivoice table is excluded from every gate. Publishers: <a href="https://swarnsiddhi.com/panchak/2026">Swarnsiddhi</a>, <a href="https://panchangbodh.com/panchak-yoga-dates-timings">PanchangBodh</a>, <a href="https://www.bhaktibharat.com/en/festival/panchak">BhaktiBharat</a>.</li>
<li><strong>Machine-readable:</strong> the <a href="${urlBase}api/v1/today.json">today.json</a> <code>panchak</code> block carries the window touching today, the active flag and the next window with its type and nakshatra segments.</li>
</ul>
''';
  return _docShell(
      'Panchak (five-nakshatra windows)',
      'Nepal Panchak windows from the nMiti engine: today window, the next Panchak with its weekday type, the upcoming table and every convention decoded - receipt-anchored, never copied.',
      urlBase,
      'panchak.html',
      body,
      shortSha);
}

/// One Chandra Darshan window as a JSON object body. Every key is
/// always emitted so the site contract markers stay date-stable on
/// darshan evenings and quiet evenings alike.
String _chandraDarshanWindowJson(String ind, ChandraDarshanWindow w) {
  String isoNpt(DateTime t) =>
      '${_iso(t)}T${_skTwo(t.hour)}:${_skTwo(t.minute)}:00+05:45';
  String f1(double v) => v.toStringAsFixed(1);
  return [
    '$ind"date_iso": "${_iso(w.darshanDayNpt)}",',
    '$ind"new_moon": "${isoNpt(w.newMoonNpt)}",',
    '$ind"saait_begins": "${isoNpt(w.saaitBeginsNpt)}",',
    '$ind"saait_ends": "${isoNpt(w.saaitEndsNpt)}",',
    '$ind"day_index_after_new_moon": ${w.dayIndexAfterNewMoon},',
    '$ind"moon_age_hours_at_saait_begins": ${f1(w.moonAgeHoursAtSaaitBegins)},',
    '$ind"elongation_deg_at_saait_begins": ${f1(w.elongationDegAtSaaitBegins)},',
    '$ind"moon_altitude_deg_at_saait_begins": ${f1(w.moonAltitudeDegAtSaaitBegins)},',
    '$ind"moonset_lag_minutes": ${f1(w.moonsetLagMinutes)},',
    '$ind"tithi_at_saait_begins": "${w.tithiAtSaaitBegins}",',
    '$ind"saait_duration_minutes": ${w.saaitDurationNpt.inMinutes},',
    '$ind"evidence_tier": "${w.evidenceTier}"',
  ].join('\n');
}

/// The chandra_darshan block of today.json (R10.1 layer 3, HYA-441).
/// The keys - "chandra_darshan", "today", "next" - always serialize on
/// every build, so the site contract markers are date-stable on
/// darshan evenings and on quiet evenings alike.
String _chandraDarshanBlock(DateTime todayAd, String urlBase) {
  final today = chandraDarshanOn(
      year: todayAd.year, month: todayAd.month, day: todayAd.day);
  final next = nextChandraDarshanAfter(
      afterNpt: DateTime.now().toUtc().add(nepalTimeOffset));
  final todayJson = today == null
      ? 'null'
      : '{\n${_chandraDarshanWindowJson('      ', today)}\n    }';
  final nextJson = '{\n${_chandraDarshanWindowJson('      ', next)}\n    }';
  return '{\n'
      '    "note": "engine-computed at build time; saait = [sunset, moonset] of the darshan evening; the darshan day is the first civil evening at or after the conjunction whose moonset-minus-sunset lag reaches 39.0 min",\n'
      '    "today": $todayJson,\n'
      '    "next": $nextJson,\n'
      '    "provenance": "${next.provenance}",\n'
      '    "evidence_tier": "${next.evidenceTier}",\n'
      '    "details": "${urlBase}chandra-darshan.html"\n'
      '  }';
}

/// The /chandra-darshan page (R10.1 layer 3, HYA-441): today's
/// darshan state, the next saait, the upcoming windows with their
/// day-rule evidence, and the full conventions map - receipt-anchored,
/// every collision exposed, never silently picked.
String _chandraDarshanPageHtml(
    DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final dayStart = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final nowNpt = DateTime.now().toUtc().add(nepalTimeOffset);
  final today = chandraDarshanOn(
      year: todayAd.year, month: todayAd.month, day: todayAd.day);
  final next = nextChandraDarshanAfter(afterNpt: nowNpt);
  final upcoming = chandraDarshanWindows(
      start: dayStart, end: dayStart.add(const Duration(days: 400)));
  String hm(DateTime t) => '${_skTwo(t.hour)}:${_skTwo(t.minute)}';
  String dt(DateTime t) => '${_iso(t)} ${hm(t)} NPT';
  String f1(double v) => v.toStringAsFixed(1);
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String evidence(ChandraDarshanWindow w) =>
      'Moon ${f1(w.moonAgeHoursAtSaaitBegins)} h old, elongation '
      '${f1(w.elongationDegAtSaaitBegins)} deg, altitude '
      '${f1(w.moonAltitudeDegAtSaaitBegins)} deg at saait begins, '
      'moonset lags sunset by ${f1(w.moonsetLagMinutes)} min; tithi '
      '${w.tithiAtSaaitBegins}';
  final String todayCard;
  if (today == null) {
    todayCard =
        '<p>Today is not a darshan evening. The young crescent is sighted once per lunation - a quiet evening is not an anomaly; the next saait is below.</p>';
  } else {
    todayCard = [
      '<p><strong>चन्द्र दर्शन · Chandra Darshan today</strong> - the young crescent Moon is sightable in tonight\'s saait.</p>',
      '<ul>',
      '<li><strong>साइत · Saait:</strong> ${dt(today.saaitBeginsNpt)} - ${dt(today.saaitEndsNpt)} (${today.saaitDurationNpt.inMinutes} min, sunset to moonset)</li>',
      '<li><strong>नयाँ चन्द्र · New moon:</strong> ${dt(today.newMoonNpt)} (${today.dayIndexAfterNewMoon} day(s) after the conjunction)</li>',
      '<li><strong>दर्शन प्रमाण · Evidence:</strong> ${evidence(today)}</li>',
      '</ul>',
    ].join('\n');
  }
  final nextCard = [
    '<p>The next Chandra Darshan is on <strong>${_iso(next.darshanDayNpt)}</strong>.</p>',
    '<ul>',
    '<li><strong>मिति · Darshan day:</strong> ${_iso(next.darshanDayNpt)} (${wd[next.darshanDayNpt.weekday - 1]})</li>',
    '<li><strong>साइत · Saait:</strong> ${dt(next.saaitBeginsNpt)} - ${dt(next.saaitEndsNpt)} (${next.saaitDurationNpt.inMinutes} min)</li>',
    '<li><strong>नयाँ चन्द्र · New moon:</strong> ${dt(next.newMoonNpt)} (${next.dayIndexAfterNewMoon} day(s) after the conjunction)</li>',
    '<li><strong>दर्शन प्रमाण · Evidence:</strong> ${evidence(next)}</li>',
    '</ul>',
  ].join('\n');
  final upcomingRows = [
    for (final w in upcoming)
      '<tr><td>${_iso(w.darshanDayNpt)}</td>'
      '<td>${wd[w.darshanDayNpt.weekday - 1]}</td>'
      '<td>${dt(w.saaitBeginsNpt)} - ${dt(w.saaitEndsNpt)}</td>'
      '<td>${f1(w.moonsetLagMinutes)}</td>'
      '<td>${f1(w.moonAgeHoursAtSaaitBegins)}</td>'
      '<td>${w.tithiAtSaaitBegins}</td></tr>'
  ].join('\n');
  final convLabels = <String, String>{
    'identity': 'Identity',
    'saait_window': 'Saait window',
    'day_rule': 'Day rule (the linger)',
    'linger_altitude_equivalence': 'Linger vs altitude equivalence',
    'conj_day': 'Conjunction-day darshan',
    'tithi_refuted': 'Tithi rule refuted',
    'drik_divergence': 'drikpanchang divergences',
    'young_moon_note': 'Young-moon note',
    'hamro_patro_absence': 'Hamro Patro absence',
    'location': 'Location',
  };
  final convRows = [
    for (final k in convLabels.keys)
      '<tr><td>${convLabels[k]}</td><td>${chandraDarshanConventions[k] ?? '(not recorded)'}</td></tr>'
  ].join('\n');
  final body = '''
<h1>Chandra Darshan <span lang="ne">· चन्द्र दर्शन</span></h1>
<p>Chandra Darshan is the first sighting of the young crescent Moon after a new moon. The sighting window - the saait - runs from sunset to moonset of the darshan evening, one darshan per lunation (12-13 per year). The darshan day is the first civil evening at or after the conjunction whose moonset lags sunset by 39.0 minutes or more - the linger, not a tithi: a conjunction-day darshan is real (May 17 2026, Moon ~17 h old), while "Dwitiya at sunset" is refuted. Computed for the nMiti Kathmandu anchor; Indian pages print the same evenings in IST (NPT minus 15 min).</p>

<h2 id="cd-today">आज · Today</h2>
$todayCard

<h2 id="cd-next">अर्को दर्शन · Next Chandra Darshan</h2>
$nextCard

<h2 id="cd-upcoming">आउँदै दर्शन · Upcoming windows</h2>
<p>Every darshan evening in the next 400 days - the saait edges come from the engine's own sunset and moonset solvers, not from any publisher table.</p>
<table>
<tr><th>Darshan day (AD)</th><th>Weekday</th><th>Saait (NPT)</th><th>Moonset lag (min)</th><th>Moon age (h)</th><th>Tithi</th></tr>
$upcomingRows
</table>

<h2 id="cd-conventions">नियम · Conventions</h2>
<p>Every rule below is receipt-anchored; where publishers disagree, the collision is decoded and shown, never silently picked.</p>
<table>
<tr><th>Rule</th><th>What nMiti serves and why</th></tr>
$convRows
</table>

<h2 id="cd-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> ${next.provenance}</li>
<li><strong>Evidence:</strong> ${next.evidenceTier}</li>
<li><strong>Verification:</strong> the saait edges are the engine's own sunset and moonset solutions (the Meeus eq. 15.1 target, the setting twin of the moonrise solver); the gate (<code>chandra_darshan_test.dart</code>) bands all 13 nepaljyotish Kathmandu windows at 2 min, the BhaktiBharat day-calls, the drikpanchang Delhi rows (23/25 agree, both divergences asserted) and the binding band, on every change. See <a href="${urlBase}methodology.html">methodology</a> and <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a>.</li>
<li><strong>Receipts:</strong> <a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/chandra_darshan_receipts_2026.json">chandra_darshan_receipts_2026.json</a> - the nepaljyotish Kathmandu table, the BhaktiBharat day-calls, the drikpanchang Delhi corpus with both divergences recorded, the rules block and the caveats.</li>
<li><strong>Machine-readable:</strong> the <a href="${urlBase}api/v1/today.json">today.json</a> <code>chandra_darshan</code> block carries today's saait (or null) and the next darshan with the day-rule evidence.</li>
</ul>
''';
  return _docShell(
      'Chandra Darshan (young-crescent sighting)',
      'Nepal Chandra Darshan from the nMiti engine: today saait, the next darshan, the upcoming table and every convention decoded - receipt-anchored, never copied.',
      urlBase,
      'chandra-darshan.html',
      body,
      shortSha);
}
/// R10.2 display state (HYA-441): one window of the sunrise-anchored
/// lagna day table - the sign, its true rising instant and the next
/// boundary. Plain jdUt doubles so the JSON layer and the page layer
/// format independently.
class _LagnaDayWindow {
  final int rashiIndex;
  final double beginsJdUt;
  final double endsJdUt;
  const _LagnaDayWindow(this.rashiIndex, this.beginsJdUt, this.endsJdUt);
}

/// R10.2 display state: the engine sunrise and the twelve-window day
/// table anchored at it.
class _LagnaDayState {
  final DateTime sunriseNpt;
  final List<_LagnaDayWindow> windows;
  const _LagnaDayState(this.sunriseNpt, this.windows);
}

/// The sunrise-anchored lagna day table (R10.2, HYA-441): one full
/// lagna cycle from the TRUE rising instant of the window containing
/// today's engine sunrise - the frame convention the publishers print
/// (Swarnsiddhi starts at the true instant; nepaljyotish re-anchors
/// row 1 at the sunrise itself). The frame start is SOLVED by walking
/// back from the sunrise, never scanned from a fixed hour (the
/// documented Mumbai 03:06 misalignment). Twelve windows; the twelfth
/// ends at the frame close, and the build refuses to deploy if the
/// frame does not close on the same sign.
_LagnaDayState _lagnaDayState(DateTime todayAd) {
  final p = panchangFor(
      year: todayAd.year, month: todayAd.month, day: todayAd.day);
  final sunriseJdUt =
      jdFromDateTimeUtc(p.sunriseNpt.subtract(nepalTimeOffset));
  final frameStart = previousLagnaBoundaryBefore(
      jdUt: sunriseJdUt, latitudeDeg: 27.7172, longitudeDeg: 85.324);
  final crossings = lagnaBoundariesBetween(
      jdUtStart: frameStart.jdUt,
      jdUtEnd: frameStart.jdUt + 1.05,
      latitudeDeg: 27.7172,
      longitudeDeg: 85.324);
  if (crossings.length < 12 ||
      crossings[11].rashiIndex != frameStart.rashiIndex) {
    throw StateError('lagna day table did not close its frame: ' +
        crossings.length.toString() +
        ' crossings from jdUt ' +
        frameStart.jdUt.toStringAsFixed(3));
  }
  final windows = <_LagnaDayWindow>[
    _LagnaDayWindow(
        frameStart.rashiIndex, frameStart.jdUt, crossings[0].jdUt),
    for (var k = 1; k < 12; k++)
      _LagnaDayWindow(
          crossings[k - 1].rashiIndex, crossings[k - 1].jdUt, crossings[k].jdUt),
  ];
  return _LagnaDayState(p.sunriseNpt, windows);
}

/// One lagna day-table window as a JSON object body. Every key is
/// always emitted so the site contract markers stay date-stable.
String _lagnaWindowJson(String ind, _LagnaDayWindow w) {
  String isoNpt(double jdUt) {
    final wall = dateTimeUtcFromJd(jdUt).add(nepalTimeOffset);
    return '${_iso(wall)}T${_skTwo(wall.hour)}:${_skTwo(wall.minute)}:00+05:45';
  }
  return [
    '$ind"rashi_index": ${w.rashiIndex},',
    '$ind"rashi_name": "${lagnaRashiNames[w.rashiIndex]}",',
    '$ind"rashi_name_np": "${lagnaRashiNamesNepali[w.rashiIndex]}",',
    '$ind"begins_at": "${isoNpt(w.beginsJdUt)}",',
    '$ind"ends_at": "${isoNpt(w.endsJdUt)}",',
    '$ind"duration_minutes": '
        '${((w.endsJdUt - w.beginsJdUt) * 1440.0).toStringAsFixed(1)}',
  ].join('\n');
}

/// The lagna block of today.json (R10.2 display, HYA-441). The keys -
/// "lagna", "rising_now", "day_table" - always serialize on every
/// build, so the site contract markers stay date-stable on boundary
/// days and quiet days alike.
String _lagnaBlock(DateTime todayAd, String urlBase) {
  final state = _lagnaDayState(todayAd);
  final running = lagnaAtNpt(DateTime.now().toUtc().add(nepalTimeOffset));
  String isoNpt(DateTime t) =>
      '${_iso(t)}T${_skTwo(t.hour)}:${_skTwo(t.minute)}:00+05:45';
  final windowsJson = [
    for (final w in state.windows)
      '{\n${_lagnaWindowJson('        ', w)}\n      }'
  ].join(',\n      ');
  return '{\n'
      '    "note": "engine-computed at build time; the day table is one '
      'full lagna cycle from the true rising instant of the window '
      'containing today\'s engine sunrise (the Swarnsiddhi frame; '
      'nepaljyotish re-anchors row 1 at the sunrise itself)",\n'
      '    "rising_now": {\n'
      '      "rashi_index": ${running.rashiIndex},\n'
      '      "rashi_name": "${running.rashiName}",\n'
      '      "rashi_name_np": "${running.rashiNameNepali}",\n'
      '      "ascendant_deg": ${running.ascendantDeg.toStringAsFixed(2)},\n'
      '      "degree_in_rashi": '
      '${running.degreeInRashi.toStringAsFixed(2)},\n'
      '      "begins_at": "${isoNpt(running.beginsAtNpt)}",\n'
      '      "next_boundary_at": "${isoNpt(running.nextBoundaryAtNpt)}"\n'
      '    },\n'
      '    "sunrise_npt": "${isoNpt(state.sunriseNpt)}",\n'
      '    "day_table": [\n      $windowsJson\n    ],\n'
      '    "provenance": "${running.provenance}",\n'
      '    "evidence_tier": "${running.evidenceTier}",\n'
      '    "details": "${urlBase}lagna.html"\n'
      '  }';
}

/// The /lagna page (R10.2, HYA-441): the rising sign now with its
/// degree, today's twelve-window day table anchored at the sunrise
/// frame, the cycle law, and the full conventions map -
/// receipt-anchored, every collision exposed, never silently picked.
String _lagnaPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final state = _lagnaDayState(todayAd);
  final running = lagnaAtNpt(DateTime.now().toUtc().add(nepalTimeOffset));
  String hm(DateTime t) => '${_skTwo(t.hour)}:${_skTwo(t.minute)}';
  String dt(DateTime t) => '${_iso(t)} ${hm(t)} NPT';
  String dtJd(double jdUt) => dt(dateTimeUtcFromJd(jdUt).add(nepalTimeOffset));
  String mins(_LagnaDayWindow w) =>
      ((w.endsJdUt - w.beginsJdUt) * 1440.0).toStringAsFixed(1);
  String dms(double deg) {
    final d = deg.floor();
    final m = ((deg - d) * 60.0).floor();
    return '$d\u00b0 ${m.toString().padLeft(2, '0')}\u2032';
  }
  final nextName = lagnaRashiNames[(running.rashiIndex + 1) % 12];
  final tableRows = [
    for (final w in state.windows)
      '<tr><td>${lagnaRashiNames[w.rashiIndex]} \u00b7 '
      '${lagnaRashiNamesNepali[w.rashiIndex]}</td>'
      '<td>${dtJd(w.beginsJdUt)}</td>'
      '<td>${dtJd(w.endsJdUt)}</td>'
      '<td>${mins(w)} min</td></tr>'
  ].join('\n');
  final convLabels = <String, String>{
    'identity': 'Identity',
    'frame': 'Day-table frame',
    'day_rule': 'Page-date rule',
    'ayanamsa': 'Ayanamsa',
    'nj_anchor': 'nepaljyotish anchor',
    'rising_now': 'Rising-now degree',
    'pb_ist_seam': 'PanchangBodh IST seam',
    'pb_jun16_resolved': 'PanchangBodh Jun 16 row (resolved)',
    'scan_alignment': 'Frame alignment',
    'unreconciled_source': 'Unreconciled sources',
    'location': 'Location',
  };
  final convRows = [
    for (final k in convLabels.keys)
      '<tr><td>${convLabels[k]}</td>'
      '<td>${lagnaConventions[k] ?? '(not recorded)'}</td></tr>'
  ].join('\n');
  final body = '''
<h1>Lagna <span lang="ne">\u00b7 \u0932\u0917\u094d\u0928</span></h1>
<p>The lagna - the ascendant, the rising sign - is the sidereal zodiac sign occupying the eastern horizon at a given instant and place: the anchor of every muhurta window and every janma chart. One sign rises at a time; the twelve-sign cycle takes one sidereal day (1436.07 min, about four minutes shorter than the clock day), so every day's table drifts about four minutes earlier. Computed at build time for the nMiti Kathmandu anchor (27.7172 N, 85.324 E), NPT (UTC+05:45) - no copied tables, no client JavaScript.</p>

<h2 id="lagna-now">\u0905\u0939\u093f\u0932\u0947 \u00b7 Rising now</h2>
<p>At this build: <strong>${running.rashiName}</strong> (${running.rashiNameNepali}) lagna at <strong>${dms(running.degreeInRashi)}</strong> of the sign - ascendant ${running.ascendantDeg.toStringAsFixed(2)} deg sidereal. This window began ${dt(running.beginsAtNpt)}; the next sign to rise is <strong>$nextName</strong> at ${dt(running.nextBoundaryAtNpt)}.</p>

<h2 id="lagna-today">\u0906\u091c\u0915\u094b \u0924\u093e\u0932\u093f\u0915\u093e \u00b7 Today's day table</h2>
<p>One full lagna cycle from the true rising instant of the window containing today's engine sunrise (${dt(state.sunriseNpt)}) - the frame convention the publishers print. Window lengths vary with the sign and the season (roughly 60-240 min at Kathmandu's latitude): signs of short ascension rise fast, and the whole frame shifts about four minutes earlier each day.</p>
<table>
<tr><th>Rising sign</th><th>Begins (NPT)</th><th>Ends (NPT)</th><th>Duration</th></tr>
$tableRows
</table>

<h2 id="lagna-conventions">\u0928\u093f\u092f\u092e \u00b7 Conventions</h2>
<p>Every rule below is receipt-anchored (Swarnsiddhi, nepaljyotish, PanchangBodh - the 2026-11 lagna corpus); where publishers disagree, the collision is decoded and shown, never silently picked.</p>
<table>
<tr><th>Rule</th><th>What nMiti serves and why</th></tr>
$convRows
</table>

<h2 id="lagna-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> ${running.provenance}</li>
<li><strong>Evidence:</strong> ${running.evidenceTier}</li>
<li><strong>Verification:</strong> the gate (<code>lagna_test.dart</code>) bands all 78 Swarnsiddhi boundary receipts (six cities, twelve boundaries plus the frame close each) within 0.05 min, the six live rising-now degrees within 0.19 deg, all twelve nepaljyotish Kathmandu interior boundaries within 2.28 min (their minute-rounded print) and nine of nine PanchangBodh sunrise-sign day-calls exactly, on every change. See <a href="${urlBase}methodology.html">methodology</a> and <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a>.</li>
<li><strong>Receipts:</strong> <a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/lagna_receipts_2026_11.json">lagna_receipts_2026_11.json</a> - the Swarnsiddhi six-city tables with frame closes and rising-now degrees, the nepaljyotish Kathmandu table, the PanchangBodh day-calls, the rules block and the recorded absences.</li>
<li><strong>Machine-readable:</strong> the <a href="${urlBase}api/v1/today.json">today.json</a> <code>lagna</code> block carries the rising sign at the build instant (with its degree and the next boundary) and the twelve-window day table.</li>
</ul>
''';
  return _docShell(
      'Lagna (the rising sign)',
      'Nepal lagna from the nMiti engine: the rising sign now with its degree, today\'s twelve-window day table anchored at the sunrise frame, and every publisher convention decoded - receipt-anchored, never copied.',
      urlBase,
      'lagna.html',
      body,
      shortSha);
}

/// One vrat day as a JSON object body. Every key is always emitted so
/// the site contract markers stay date-stable on vrat days and quiet
/// days alike.
String _vratDayJson(String ind, VratDay d) {
  String isoNpt(DateTime t) =>
      '${_iso(t)}T${_skTwo(t.hour)}:${_skTwo(t.minute)}:00+05:45';
  return [
    '$ind"family": "${d.familyName}",',
    '$ind"family_np": "${d.familyNameNepali}",',
    '$ind"tithi": "${d.tithiName}",',
    '$ind"tithi_index": ${d.tithiIndex},',
    '$ind"date": "${_iso(d.dateNpt)}",',
    '$ind"tithi_begins_npt": "${isoNpt(d.tithiBeginsNpt)}",',
    '$ind"tithi_ends_npt": "${isoNpt(d.tithiEndsNpt)}",',
    '$ind"reference_kind": "${d.referenceKind}",',
    '$ind"reference_instant_npt": "${isoNpt(d.referenceInstantNpt)}",',
    '$ind"day_rule": "${d.dayRule}",',
    '$ind"borderline": ${d.borderline},',
    '$ind"borderline_reason": "${d.borderlineReason}"',
  ].join('\n');
}

/// The vrat horizon of the today.json vrat block (days).
const int _vratWindowDays = 45;

/// The vrat block of today.json (R10.3 display, HYA-441): the recurring
/// vrat days observed today, the next vrat day and the 45-day horizon -
/// every entry naming its day-choosing rule, the reference instant that
/// pinned it and the borderline state. The keys - "vrat", "today",
/// "next", "upcoming", "vrat_window_days" - always serialize on every
/// build, so the site contract markers are date-stable on vrat days and
/// quiet days alike.
String _vratBlock(DateTime todayAd, String urlBase) {
  final today = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final horizon = today.add(const Duration(days: _vratWindowDays));
  final scanned = vratDays(startNpt: today, endNpt: horizon);
  final todayOnes = scanned.where((d) => d.dateNpt == today).toList();
  final upcoming = scanned.where((d) => d.dateNpt.isAfter(today)).toList();
  String one(String ind, VratDay d) =>
      '{\n${_vratDayJson(ind + '  ', d)}\n$ind}';
  final todayJson = todayOnes.isEmpty
      ? '[]'
      : '[\n${[for (final d in todayOnes) one('      ', d)].join(',\n')}\n    ]';
  final nextJson = upcoming.isEmpty ? 'null' : one('      ', upcoming.first);
  final upcomingJson = upcoming.isEmpty
      ? '[]'
      : '[\n${[for (final d in upcoming) one('      ', d)].join(',\n')}\n    ]';
  final provenance = scanned.isEmpty
      ? 'nMiti nepali_panchang vrat calendar layer on the runtime lunar engine'
      : scanned.first.provenance;
  final evidence = scanned.isEmpty
      ? 'runtime-computed; day identity pinned by the vrat receipts corpus'
      : scanned.first.evidenceTier;
  return '{\n'
      '    "note": "engine-computed at build time; every entry names its day-choosing rule, the reference instant that pinned it and the borderline state",\n'
      '    "today": $todayJson,\n'
      '    "next": $nextJson,\n'
      '    "upcoming": $upcomingJson,\n'
      '    "vrat_window_days": $_vratWindowDays,\n'
      '    "provenance": "$provenance",\n'
      '    "evidence_tier": "$evidence",\n'
      '    "details": "${urlBase}vrat.html"\n'
      '  }';
}

/// The /vrat page (R10.3 display, HYA-441): today's vrat days, the next
/// vrat, the five families with every day rule decoded, the 400-day
/// year grid, and the full conventions map - receipt-anchored, every
/// collision exposed, never silently picked.
String _vratPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final today = DateTime.utc(todayAd.year, todayAd.month, todayAd.day);
  final yearEnd = today.add(const Duration(days: 400));
  final grid = vratDays(startNpt: today, endNpt: yearEnd);
  final todayOnes = grid.where((d) => d.dateNpt == today).toList();
  final upcoming = grid.where((d) => d.dateNpt.isAfter(today)).toList();
  String hm(DateTime t) => '${_skTwo(t.hour)}:${_skTwo(t.minute)}';
  String dt(DateTime t) => '${_iso(t)} ${hm(t)} NPT';
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const familyTitles = {
    'sankashti_chaturthi': 'Sankashti Chaturthi',
    'pradosham': 'Pradosham',
    'ekadashi': 'Ekadashi',
    'purnima': 'Purnima',
    'amavasya': 'Amavasya',
  };
  final counts = <String, int>{};
  for (final d in grid) {
    final k = d.familyName;
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final borderlineCount = grid.where((d) => d.borderline).length;
  final next = upcoming.isEmpty ? null : upcoming.first;
  String title(VratDay d) => familyTitles[d.familyName] ?? d.familyName;
  final todaySection = todayOnes.isEmpty
      ? '<p>No recurring vrat day falls on ${_iso(today)}. The five families ride the tithi chain - a quiet day is not an anomaly; the next vrat is below.</p>'
      : [
          for (final d in todayOnes)
            '<p><strong>${title(d)} <span lang="ne">${d.familyNameNepali}</span></strong> is observed today - ${d.tithiName}, the run ${dt(d.tithiBeginsNpt)} to ${dt(d.tithiEndsNpt)}. Day rule: ${d.dayRule}${d.borderline ? ' - borderline (${d.borderlineReason})' : ''}.</p>'
        ].join('\n');
  final String nextCard;
  if (next == null) {
    nextCard = '<p>No vrat day is computed within the next 400 days.</p>';
  } else {
    nextCard = [
      '<p><strong>${title(next)} <span lang="ne">${next.familyNameNepali}</span></strong> - ${next.tithiName}</p>',
      '<ul>',
      '<li><strong>मिति · Date:</strong> ${_iso(next.dateNpt)} (${wd[next.dateNpt.weekday - 1]})</li>',
      '<li><strong>तिथि · Tithi run:</strong> ${dt(next.tithiBeginsNpt)} to ${dt(next.tithiEndsNpt)}</li>',
      '<li><strong>नियम · Day rule:</strong> ${next.dayRule}</li>',
      '<li><strong>साक्षी · Reference:</strong> ${next.referenceKind} at ${dt(next.referenceInstantNpt)}</li>',
      '<li><strong>Borderline:</strong> ${next.borderline ? 'yes - ${next.borderlineReason}' : 'no'}</li>',
      '</ul>',
    ].join('\n');
  }
  final gridRows = [
    for (final d in grid)
      '<tr><td>${_iso(d.dateNpt)}<br><small>${wd[d.dateNpt.weekday - 1]}</small></td>'
      '<td>${title(d)}<br><span lang="ne">${d.familyNameNepali}</span></td>'
      '<td>${d.tithiName}</td>'
      '<td>${dt(d.tithiBeginsNpt)} - ${dt(d.tithiEndsNpt)}</td>'
      '<td>${d.referenceKind}<br><small>${dt(d.referenceInstantNpt)}</small></td>'
      '<td>${d.borderline ? 'yes - ${d.borderlineReason}' : '-'}</td></tr>'
  ].join('\n');
  final convLabels = <String, String>{
    'identity': 'Identity',
    'ekadashi_rule': 'Ekadashi rule',
    'pradosham_rule': 'Pradosham rule',
    'sankashti_rule': 'Sankashti rule',
    'purnima_amavasya_rule': 'Purnima / Amavasya rule',
    'borderline_rule': 'Borderline semantics',
    'moonrise_dependency': 'Moonrise dependency',
    'hp_bb_sankashti_absence': 'Publisher absence (Nov 27 2026)',
    'hp_flagged_panel_shift': 'Hamro Patro panel-label shift',
    'ist_convention_divergence': 'IST convention divergence',
    'amanta_month_naming': 'Amanta month naming',
    'publisher_divergence': 'Publisher divergence',
    'corroboration': 'Corroboration',
    'location': 'Location',
  };
  final convRows = [
    for (final k in convLabels.keys)
      '<tr><td>${convLabels[k]}</td><td>${vratConventions[k] ?? '(not recorded)'}</td></tr>'
  ].join('\n');
  final body = '''
<h1>Vrat <span lang="ne">· व्रत</span></h1>
<p>Vrat days are the recurring lunar observances of the ritual calendar - Sankashti Chaturthi, Pradosham, Ekadashi, Purnima and Amavasya - each riding a tithi of the engine lunar chain. Because a tithi can begin and end at any hour, the civil day a vrat is printed on depends on a day-choosing convention; this page serves the decoded rule for every day and flags every convention-sensitive (borderline) choice. Computed at build time for the nMiti Kathmandu anchor (27.7172 N, 85.324 E), NPT (UTC+05:45) - no copied tables, no client JavaScript.</p>

<h2 id="vrat-today">आज · Today</h2>
$todaySection

<h2 id="vrat-next">अर्को व्रत · Next vrat</h2>
$nextCard

<h2 id="vrat-families">पाँच थरि व्रत · The five families</h2>
<p>Every family rides the tithi chain of the shipped lunar engine; what differs is the day-choosing rule - which reference instant (sunrise, noon, sunset or moonrise) pins the tithi run to a civil day. The rules were decoded from the 2026 receipt corpus and are stated per day, never silently picked.</p>
<table>
<tr><th>Family</th><th>Rides</th><th>Day rule</th></tr>
<tr><td>Sankashti Chaturthi <span lang="ne">संकष्टी चतुर्थी</span></td><td>Krishna Chaturthi</td><td>chandrodaya-vyapti - the day whose moonrise falls inside the run; when no moonrise falls inside, the day whose moonrise lies nearest the run</td></tr>
<tr><td>Pradosham <span lang="ne">प्रदोष</span></td><td>Shukla and Krishna Trayodashi</td><td>trayodashi vyapta at sunset - the pradosh kala anchor</td></tr>
<tr><td>Ekadashi <span lang="ne">एकादशी</span></td><td>Shukla and Krishna Ekadashi</td><td>madhyahna-vyapini - the last civil day whose noon falls inside the run</td></tr>
<tr><td>Purnima <span lang="ne">पूर्णिमा</span></td><td>Purnima</td><td>the udaya day (the sunrise inside the run); on vriddhi the first</td></tr>
<tr><td>Amavasya <span lang="ne">औंसी</span></td><td>Amavasya</td><td>the udaya day; on vriddhi the first</td></tr>
</table>

<h2 id="vrat-year">वर्ष तालिका · The year grid</h2>
<p>Every vrat day from ${_iso(today)} through ${_iso(yearEnd)} - ${grid.length} days: sankashti ${counts['sankashti_chaturthi'] ?? 0}, pradosham ${counts['pradosham'] ?? 0}, ekadashi ${counts['ekadashi'] ?? 0}, purnima ${counts['purnima'] ?? 0}, amavasya ${counts['amavasya'] ?? 0}; ${borderlineCount} flagged borderline. Every day comes from the engine's own tithi runs and reference instants, not from any publisher table.</p>
<table>
<tr><th>Date (AD)</th><th>Family</th><th>Tithi</th><th>Tithi run (NPT)</th><th>Reference</th><th>Borderline</th></tr>
$gridRows
</table>

<h2 id="vrat-conventions">नियम · Conventions</h2>
<p>Every rule below is receipt-anchored (Hamro Patro, BhaktiBharat, astrologger, bhaktiras - the 2026-11/12 vrat corpus); where publishers disagree, the collision is decoded and shown, never silently picked.</p>
<table>
<tr><th>Rule</th><th>What nMiti serves and why</th></tr>
$convRows
</table>

<h2 id="vrat-meta">How this is computed</h2>
<ul>
<li><strong>Engine:</strong> ${grid.isEmpty ? 'the nMiti nepali_panchang vrat calendar layer on the runtime lunar engine' : grid.first.provenance}</li>
<li><strong>Evidence:</strong> ${grid.isEmpty ? 'runtime-computed; day identity pinned by the vrat receipts corpus' : grid.first.evidenceTier}</li>
<li><strong>Verification:</strong> the gate (<code>vrat_calendar_test.dart</code>) bands every corpus boundary (13 BhaktiBharat tithi edges at the locked 1.5-min band, 13 Hamro Patro at 12 min, 8 astrologger IST rows at the +15-min NPT seam), checks run contiguity, day identity on every receipt row, the moonrise memberships (Nov 27 inside the run; the Dec 26 nearest-moonrise fallback vs Dec 27), the family bindings and the BS-2083 year-grid structure on every change. See <a href="${urlBase}methodology.html">methodology</a> and <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a>.</li>
<li><strong>Receipts:</strong> <a href="https://github.com/namunaONE/nMiti/blob/main/packages/nepali_panchang/test/fixtures/vrat_receipts_2026_11_12.json">vrat_receipts_2026_11_12.json</a> - the tithi-boundary corpus, the named-vrat identity rows, the BhaktiBharat moonrise receipts and the caveats, including the documented Dec 26 sink case.</li>
<li><strong>Machine-readable:</strong> the <a href="${urlBase}api/v1/today.json">today.json</a> <code>vrat</code> block carries today's vrat days, the next vrat and the 45-day horizon with every day rule and borderline state.</li>
</ul>
''';
  return _docShell(
      'Vrat (the recurring vrat days)',
      'Nepal vrat calendar from the nMiti engine: Sankashti Chaturthi, Pradosham, Ekadashi, Purnima and Amavasya days with every day-choosing rule decoded - receipt-anchored, never copied.',
      urlBase,
      'vrat.html',
      body,
      shortSha);
}
