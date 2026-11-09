part of 'build_site.dart';

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

/// The /ayanamsa page (R6g, HYA-437): the sidereal reference - what
/// ayanamsa is, the engine's fitted model and per-source profiles,
/// today's computed values, what the choice shifts per limb, and the
/// Nepal divergence record with the evidence tier of every claim.
/// Stated, never absorbed.
String _ayanamsaPageHtml(DateTime todayAd, String urlBase, String commitSha) {
  final shortSha = commitSha == 'local' ? 'local' : commitSha.substring(0, 7);
  final noonUtc = DateTime.utc(todayAd.year, todayAd.month, todayAd.day, 12);
  final jdTt = jdTtFromJdUt(jdFromDateTimeUtc(noonUtc));
  final base = ayanamsaBase(jdTt);
  final bb = ayanamsaTotal(jdTt, ayanamsaDeltaBhaktiBharat);
  final hp = ayanamsaTotal(jdTt, ayanamsaDeltaHamroPatro);
  final tropical = sunApparentLongitude(jdTt);
  final sidereal = ((tropical - base) % 360.0 + 360.0) % 360.0;
  final rasi = (sidereal / 30.0).truncate() + 1;
  final rasiNames = [
    'Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya',
    'Tula', 'Vrishchika', 'Dhanu', 'Makara', 'Kumbha', 'Meena',
  ];
  final rasiName = rasiNames[rasi - 1];
  final nextEdgeDeg = 30 * rasi;
  final toNextEdge = nextEdgeDeg.toDouble() - sidereal;
  String dms(double deg) {
    final d = deg.floor();
    final mFull = (deg - d) * 60.0;
    final m = mFull.floor();
    final s = ((mFull - m) * 60.0).round();
    return d.toString() + '° ' + m.toString().padLeft(2, '0') + '′ ' + s.toString().padLeft(2, '0') + '″';
  }
  final body = '''
<h1>Ayanamsa · <span lang="ne">अयनांश</span> — the sidereal reference</h1>
<p>Every Nepali panchang is sidereal: tithi, nakshatra, yoga and sankranti are measured against the fixed stars, not the moving equinox. Ayanamsa is the single number that converts between the two frames — and every honest panchang has to say which one it uses. This page states ours exactly, shows what the choice shifts, and documents where Nepal's own traditions diverge, with the evidence tier of every claim.</p>

<h2 id="ayanamsa-what">अयनांश के हो? · What ayanamsa is</h2>
<p>Earth's axis precesses: the equinox drifts roughly 50.3 arc-seconds per year along the ecliptic, so <em>sayana</em> (tropical, equinox-anchored) and <em>nirayana</em> (sidereal, star-anchored) longitudes drift apart about one degree every 72 years. <strong>Ayanamsa = sayana longitude − nirayana longitude</strong> at a given instant. Modern ephemerides work in tropical coordinates; subtracting the ayanamsa yields the sidereal positions a panchang needs. The Bikram Sambat solar months are sidereal by definition: a masa begins at the sankranti, the Sun's ingress into a sidereal rashi — and where that ingress falls depends entirely on which ayanamsa anchors the rashi circle.</p>

<h2 id="ayanamsa-ours">हाम्रो आधार · Our reference, exactly</h2>
<p>The nMiti engine uses a fitted linear model in Terrestrial Time:</p>
<p><code>ayanamsa(JD_TT) = 23.87508° + 1.36062° × (JD_TT − 2451545.0) / 36525</code></p>
<p>It was fitted to the verified Commons Layer 1 sankranti artifact and calibrated on 48 drikpanchang ingress moments AD 2025–2028: <strong>mean error 3.7 minutes, max 8.6 minutes, 48/48 correct NPT dates</strong>. The same VSOP87D apparent sun on the same constants also drives the <a href="${urlBase}masa.html">masa layer</a> and the <a href="${urlBase}sankranti.html">sankranti tables</a> — one sidereal reference everywhere, no per-page re-tuning.</p>
<p>The locked receipt corpus proved a single universal value cannot reproduce both publishers, so the engine keeps per-source <strong>profiles</strong> — small fitted offsets on the base:</p>
<table>
<tr><th>Profile</th><th>Delta (deg)</th><th>Meaning</th><th>Evidence</th></tr>
<tr><td>base</td><td>0</td><td>the calibrated reference itself — sankranti, masa and this page</td><td>48-ingress calibration, CI-pinned (R5)</td></tr>
<tr><td>BhaktiBharat</td><td>−0.0795</td><td>reconciles the BhaktiBharat sidereal limb convention</td><td>corpus fit, Oct–Nov 2026 receipts</td></tr>
<tr><td>Hamro Patro</td><td>−0.0117</td><td>reconciles the Hamro Patro sidereal limb convention</td><td>corpus fit, Nov 2026 receipts</td></tr>
</table>

<h2 id="ayanamsa-value">आजको मान · Today's computed values</h2>
<p>Computed by the engine at build time, NPT noon of ${_iso(todayAd)}:</p>
<ul>
<li><strong>Base ayanamsa:</strong> ${base.toStringAsFixed(5)}° (${dms(base)})</li>
<li><strong>BhaktiBharat profile:</strong> ${bb.toStringAsFixed(5)}°</li>
<li><strong>Hamro Patro profile:</strong> ${hp.toStringAsFixed(5)}°</li>
<li><strong>The Sun right now:</strong> sayana ${tropical.toStringAsFixed(3)}° → nirayana ${sidereal.toStringAsFixed(3)}° — rashi ${rasi} of 12 (${rasiName}), ${toNextEdge.toStringAsFixed(2)}° short of the next 30° ingress edge at ${nextEdgeDeg}°</li>
</ul>
<p>That edge-crossing is the next sankranti — the arithmetic every BS month boundary runs on.</p>

<h2 id="ayanamsa-limbs">कुन अङ्गमा के फरक? · What the choice shifts, per limb</h2>
<table>
<tr><th>Limb</th><th>Ayanamsa sensitivity</th><th>Measured vs Swiss Ephemeris in CI (mean)</th></tr>
<tr><td>tithi</td><td>none — pure Moon−Sun elongation; the ayanamsa cancels</td><td>14.3 s (post-R7a re-measure — the Meeus Ch.47 truncation, exposed once the pre-R7a ΔT error stopped partially canceling it)</td></tr>
<tr><td>karana</td><td>none — half a tithi, the same cancellation</td><td>14.3 s (post-R7a re-measure)</td></tr>
<tr><td>nakshatra</td><td>direct — it shifts the Moon's sidereal longitude</td><td>66.2 s vs Swiss Lahiri — the convention gap plus the −6.5 s R7a ΔT shift</td></tr>
<tr><td>yoga</td><td>direct — it shifts Moon + Sun together</td><td>110.8 s vs Swiss Lahiri — the convention gap plus the −6.5 s R7a ΔT shift</td></tr>
<tr><td>sankranti / masa</td><td>defining — the rashi edges ARE the ayanamsa</td><td>3.7 min mean vs the 48 drikpanchang receipts</td></tr>
</table>
<p>The near-constant nakshatra/yoga offsets are the fitted-base-versus-Lahiri convention gap, measured by the Swiss-truth scoreboard on every push: <strong>stated, never absorbed</strong> — an informative number, not noise. Full scoreboard and band rationale: <a href="${urlBase}methodology.html">methodology</a>.</p>

<h2 id="ayanamsa-nepal">नेपालको विचलन · The Nepal divergence record</h2>
<p>Nepal's official panchang is not computed on a modern ephemeris. The Nepal Panchang Nirnayak Samiti (NPNS) — publishing the official patro since 2078 BS — computes the five limbs on the <strong>Surya Siddhanta</strong> panchang khand and the planets on Ketkar's <strong>Ketaki Grahaganitam</strong> (tier: <em>reported</em>, from Samiti statements and Nepali press coverage). In December 2025 the Samiti moved the full computation to the Ketaki system and rolled the move back within weeks after public dates broke — a live demonstration that mixing siddhantas is fragile.</p>
<ul>
<li><strong>The printed patros sit ahead of the modern reference:</strong> press investigation of the printed panchangs reports an ayanamsa roughly 21 kala (21 arc-minutes) ahead of the Chitra-pakshiya (Lahiri-class) convention, putting sankranti instants up to 15+ hours away from drik-ganita (ephemeris) computation. Tier: <em>press-reported</em> — the exact per-patro figure awaits print verification against the R8 printed panchangs held in this project.</li>
<li><strong>Why it usually goes unnoticed:</strong> a constant offset shifts the sankranti clock, not usually the date. It becomes visible when an ingress or a vriddhi tithi lands near midnight — then one observance can split across two printed days.</li>
<li><strong>The 2083 case is the canonical example:</strong> Maha Ashtami was printed on both Kartik 1 and Kartik 2, 2083 by different patros. The physical cause is a vriddhi (extended) tithi of 26.39 hours, which this engine reproduces independently; which day the observance takes is a convention call the committee adjudicates. We publish the elongation and both sunrises — see <a href="${urlBase}festivals.html">festivals</a> for the divergence table.</li>
</ul>
<p>We do not adjudicate; we compute and show receipts. Where the print record exists it wins (the top rung of the <a href="${urlBase}methodology.html">verification ladder</a>) — and where traditions disagree, the disagreement itself is data.</p>

<h2 id="ayanamsa-receipts">प्रमान · Receipts and evidence tiers</h2>
<table>
<tr><th>Claim on this page</th><th>Tier</th><th>Where verified</th></tr>
<tr><td>the model constants and profiles</td><td><em>computed</em> — engine source, CI-pinned</td><td>the ayanamsa module; corpus calibration tests on every push</td></tr>
<tr><td>today's values</td><td><em>computed</em> at build time</td><td>this page regenerates on every build; the same engine serves the masa block in <a href="${urlBase}api/v1/today.json">today.json</a></td></tr>
<tr><td>Swiss-truth limb gaps</td><td><em>measured</em> in CI on every push</td><td>the Swiss cross-check scoreboard (HYA-369)</td></tr>
<tr><td>NPNS method, Ketaki rollback</td><td><em>reported</em></td><td>Samiti statements, Nepali press, 2025–2026</td></tr>
<tr><td>~21 kala / 15+ h printed-patro offsets</td><td><em>press-reported</em>, print verification pending</td><td>press investigation; R8 print spot-verification queue</td></tr>
<tr><td>2083 two-day Maha Ashtami / 26.39 h vriddhi</td><td><em>computed + receipt</em></td><td>engine reproduces the vriddhi; festival receipts corpus in CI</td></tr>
</table>
<p><strong>Provenance:</strong> nMiti nepali_panchang ayanamsa module — base 23.87508° + 1.36062° per Julian century (TT), per-source fitted profiles; every displayed value computed at build time, no copied tables.</p>
<p><strong>Evidence tier:</strong> model constants corpus-fit and CI-pinned; today's values runtime-computed; the Nepal divergence record press-reported and labeled as such — stated, never absorbed.</p>
<p>Related: <a href="${urlBase}sankranti.html">sankranti tables</a> · <a href="${urlBase}masa.html">masa</a> · <a href="${urlBase}panchang.html">today's limbs</a> · <a href="${urlBase}accuracy.html">accuracy &amp; honesty</a> · <a href="${urlBase}methodology.html">methodology</a>.</p>
''';
  return _docShell(
      'Ayanamsa (the sidereal reference)',
      'The ayanamsa behind nMiti: the fitted sidereal reference, per-source publisher profiles, what the choice shifts per limb, and the Nepal divergence record (NPNS, printed patros, the 2083 two-day Ashtami) with every claim evidence-tiered.',
      urlBase,
      'ayanamsa.html',
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
    for (final p in ['', 'accuracy.html', 'methodology.html', 'ayanamsa.html', 'data.html', 'docs.html', 'sankranti.html', 'masa.html', 'panchang.html', 'bhadra.html', 'panchak.html', 'chandra-darshan.html', 'lagna.html', 'muhurta.html', 'grahan.html', 'festivals.html', 'embed/example.html'])
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
Today's date (JSON), with a panchang block (tithi/nakshatra/yoga/karana at both udaya and madhyahna conventions, sunrise, vriddhi/kshaya flags, provenance, evidence tier, plus a grahan block - today's eclipse/sutak state and the next grahan - and a festivals block: today's observances, the next festival and the 45-day horizon, each naming its day-choosing convention - plus a masa block, the amanta lunar month containing today with adhika/kshaya flags, and a muhurta block: Rahu Kalam, Yamaganda, Gulika, Abhijit and Brahma muhurta, the choghadiya slots and the hora windows, plus a bhadra block - the Bhadra (Vishti karana) window touching today and the next Bhadra - plus a panchak block - the Panchak window touching today, its weekday type and the next Panchak - plus a chandra_darshan block - today's Chandra Darshan saait (sunset to moonset) or null, with the next darshan - plus a lagna block - the rising sign now with its ascendant degree, and the twelve-window day table anchored at today's sunrise frame - plus a delta_t honesty block - the served Delta T with its source segment, uncertainty and span): ${urlBase}api/v1/today.json
Calendar for one BS year (JSON): ${urlBase}api/v1/calendar/${today.year}.json (pattern: /api/v1/calendar/<bs_year>.json, BS 1975-2100)
Accuracy and honesty (evidence tiers, known defects, errata): ${urlBase}accuracy.html
Methodology (verification, invariants, calendar layers): ${urlBase}methodology.html
Ayanamsa (the sidereal reference - our fitted model, the per-source publisher profiles, what the choice shifts per limb, and the Nepal divergence record with evidence tiers): ${urlBase}ayanamsa.html
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
Bhadra (the eight Vishti karana windows per lunar month, with mukha/puchha spans and the loka table; engine-computed): ${urlBase}bhadra.html
Panchak (the five-nakshatra windows, Dhanishta's last two padas through Revati, with the weekday types and the prohibited-activity canon; engine-computed): ${urlBase}panchak.html
Chandra Darshan (the young-crescent sighting after each new moon, saait = sunset to moonset of the darshan evening, the 39-minute linger day rule; engine-computed): ${urlBase}chandra-darshan.html
Lagna (the rising sign / ascendant: the sign on the eastern horizon now with its degree, and the twelve-window day table anchored at the sunrise frame; engine-computed): ${urlBase}lagna.html
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
