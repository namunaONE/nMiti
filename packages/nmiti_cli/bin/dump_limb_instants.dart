import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';

/// HYA-369 (prep): dump every lunar limb boundary and Kathmandu sunrise
/// instant in a window, as computed by the MIT lunar engine, for the
/// independent Swiss-truth harness (tools/sweph/sweph_crosscheck.py) to
/// re-solve and score (HYA-369 deliverable 1: quantify the reconstruction
/// gap at knife-edge boundaries). HYA-417 adds the day's moonrise per the
/// Meeus eq. 15.1 solver, scored by the same harness.
///
/// Facts out, license clean: this command depends only on the MIT engine
/// and emits plain numeric facts (instants). The sidereal limbs use the
/// BASE ayanamsa profile (source delta 0.0) so the harness measures the
/// engine-vs-Swiss ayanamsa gap itself; the per-source publisher profiles
/// stay in the published engine outputs and are not dumped here.
///
/// HYA-369 alignment: every boundary row also carries the engine BASE
/// ayanamsa and the receipts-measured Swiss-Lahiri reference line at
/// that instant (ayanamsa_deg / ayanamsa_reference_deg), so the Swiss
/// harness can score the ayanamsa convention gap separately from
/// ephemeris parity without duplicating engine constants.
///
/// ELP2000-82B spike (HYA-369 follow-up): every boundary row also
/// carries the engine's geometric moon longitude at that instant
/// (moon_deg), so tools/sweph/elp_spike.py can measure what a
/// NASA-canon-class moon (truncated ELP82B) would do to the
/// tithi/karana bands by substitution - predicted bands and floors,
/// without touching the engine.
void main(List<String> args) {
  final startIso = _arg(args, '--start');
  final endIso = _arg(args, '--end');
  final outPath = _arg(args, '--out') ?? 'build/limb_instants.json';
  if (startIso == null || endIso == null) {
    stderr.writeln('usage: dump_limb_instants --start YYYY-MM-DD '
        '--end YYYY-MM-DD [--out file.json]');
    exitCode = 1;
    return;
  }
  final start = _parseIso(startIso);
  final end = _parseIso(endIso);
  if (start == null || end == null) {
    exitCode = 1;
    return;
  }
  if (end.isBefore(start)) {
    stderr.writeln('dump_limb_instants: --end must not precede --start');
    exitCode = 1;
    return;
  }

  final jdStartUt =
      julianDayFromCivil(start.year, start.month, start.day.toDouble());
  final jdEndUt =
      julianDayFromCivil(end.year, end.month, end.day.toDouble());
  final jdStartTt = jdStartUt + _deltaTFor(jdStartUt) / 86400.0;
  final jdEndTt = jdEndUt + _deltaTFor(jdEndUt) / 86400.0;

  // Limb -> sourceDelta. Tithi and karana are elongation-based (the
  // ayanamsa never enters); nakshatra and yoga use the base profile.
  const limbSpecs = <String, double>{
    'tithi': 0.0,
    'karana': 0.0,
    'nakshatra': 0.0,
    'yoga': 0.0,
  };

  final boundaries = <String, List<Map<String, Object?>>>{};
  for (final spec in limbSpecs.entries) {
    final rows = <Map<String, Object?>>[];
    var cursor = jdStartTt;
    while (true) {
      final b = nextLimbBoundaryJdTt(spec.key, cursor, spec.value);
      if (b > jdEndTt) break;
      final dt = _deltaTFor(b);
      rows.add(<String, Object?>{
        'jd_tt': b,
        'jd_ut': b - dt / 86400.0,
        'delta_t_s': dt,
        'utc': _isoUtcOfJdUt(b - dt / 86400.0),
        'ayanamsa_deg': ayanamsaBase(b),
        'ayanamsa_reference_deg': ayanamsaSwissLahiriReference(b),
        'moon_deg': moonPosition(b).longitudeDeg,
      });
      cursor = b;
    }
    boundaries[spec.key] = rows;
  }

  final sunrises = <Map<String, Object?>>[];
  final moonrises = <Map<String, Object?>>[];
  var moonriseDaysWithoutRise = 0;
  final lastDay = DateTime.utc(end.year, end.month, end.day);
  for (var d = DateTime.utc(start.year, start.month, start.day);
      !d.isAfter(lastDay);
      d = d.add(const Duration(days: 1))) {
    final jdUt = sunriseJdUt(year: d.year, month: d.month, day: d.day);
    sunrises.add(<String, Object?>{
      'date': _isoDateOf(d),
      'jd_ut': jdUt,
      'utc': _isoUtcOfJdUt(jdUt),
    });
    final moonJdUt = moonriseJdUt(year: d.year, month: d.month, day: d.day);
    if (moonJdUt == null) {
      // Roughly one day per lunar month the rise falls into a
      // neighbouring civil day; the count is dumped for the harness.
      moonriseDaysWithoutRise++;
    } else {
      moonrises.add(<String, Object?>{
        'date': _isoDateOf(d),
        'jd_ut': moonJdUt,
        'utc': _isoUtcOfJdUt(moonJdUt),
      });
    }
  }

  final doc = <String, Object?>{
    'window': <String, String>{'start': startIso, 'end': endIso},
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'engine': 'nepali_panchang (Meeus Ch.47 moon, VSOP87D sun, '
        'Espenak-Meeus delta T, base ayanamsa profile, HYA-417 '
        'Meeus 15.1 moonrise)',
    'ayanamsa_profile': 'base (source delta 0.0)',
    'limb_spans_deg': <String, double>{
      'tithi': tithiSpanDeg,
      'karana': karanaSpanDeg,
      'nakshatra': nakshatraSpanDeg,
      'yoga': yogaSpanDeg,
    },
    'boundaries': boundaries,
    'sunrises': sunrises,
    'moonrises': moonrises,
    'moonrise_days_without_rise': moonriseDaysWithoutRise,
  };
  File(outPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(doc));
  final counts = [
    for (final key in boundaries.keys)
      key + '=' + boundaries[key]!.length.toString()
  ].join(' ');
  stdout.writeln('dumped: ' +
      counts +
      ' sunrises=' +
      sunrises.length.toString() +
      ' moonrises=' +
      moonrises.length.toString() +
      ' (no-rise days: ' +
      moonriseDaysWithoutRise.toString() +
      ') -> ' +
      outPath);
}

/// Espenak-Meeus Delta T at [jdTt], seconds: estimate the UT date from
/// the TT instant, then read the polynomial at that (year, month). The
/// month-granularity error is far below a second inside any CI window.
double _deltaTFor(double jdTt) {
  final approxUt = jdTt - 70.0 / 86400.0;
  final d = _utcOfJdUt(approxUt);
  return deltaTSeconds(d.year, d.month);
}

/// UTC instant of a UT Julian Day (Meeus, Astronomical Algorithms ch. 7,
/// the inverse of [julianDayFromCivil]).
DateTime _utcOfJdUt(double jdUt) {
  final z = jdUt + 0.5;
  var a = z.floorToDouble();
  if (a >= 2299161.0) {
    final alpha = ((a - 1867216.25) / 36524.25).floorToDouble();
    a = a + 1.0 + alpha - (alpha / 4.0).floorToDouble();
  }
  final b = a + 1524.0;
  final c = ((b - 122.1) / 365.25).floorToDouble();
  final d = (365.25 * c).floorToDouble();
  final e = ((b - d) / 30.6001).floorToDouble();
  final dayFrac = b - d - (30.6001 * e).floorToDouble() + (z - z.floor());
  final month = e < 14.0 ? (e - 1.0).toInt() : (e - 13.0).toInt();
  final year = month > 2 ? (c - 4716.0).toInt() : (c - 4715.0).toInt();
  final day = dayFrac.floor();
  var secs = ((dayFrac - day) * 86400.0).round();
  var date = DateTime.utc(year, month, day);
  if (secs >= 86400) {
    date = date.add(const Duration(days: 1));
    secs -= 86400;
  }
  return date.add(Duration(seconds: secs));
}

String _isoUtcOfJdUt(double jdUt) {
  final t = _utcOfJdUt(jdUt);
  return _isoDateOf(t) +
      'T' + _two(t.hour) + ':' + _two(t.minute) + ':' + _two(t.second) + 'Z';
}

String _isoDateOf(DateTime t) =>
    t.year.toString().padLeft(4, '0') + '-' + _two(t.month) + '-' + _two(t.day);

String _two(int n) => n < 10 ? '0$n' : '$n';

DateTime? _parseIso(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) {
    stderr.writeln('dump_limb_instants: bad date "$s" (want YYYY-MM-DD)');
    return null;
  }
  return DateTime.utc(
      int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

String? _arg(List<String> args, String name) {
  for (var i = 0; i + 1 < args.length; i++) {
    if (args[i] == name) return args[i + 1];
  }
  return null;
}
