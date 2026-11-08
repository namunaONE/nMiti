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
