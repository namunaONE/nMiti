#!/usr/bin/env dart
// Regenerates the USNO spans vendored in
// packages/nepali_panchang/lib/src/delta_t_data.dart (R7a, HYA-438).
//
// Usage, from the repo root: dart run tools/refresh_delta_t.dart
//
// Fetches deltat.data and deltat.preds from the USNO (a Wayback
// fallback is tried when the host blocks the request), validates them,
// and splices them between the markers in the data file. It refuses to
// write on any anomaly - a month gap, an out-of-envelope value, a
// suspicious row count - so a corrupted upstream file can never
// silently replace the vendored tables. The spline and SMH error
// tables are published numeric tables and are never touched.
//
// The archived text renders with whitespace inside numbers and
// hard-broken lines; the parser strips exotic whitespace and merges
// lines that do not start with a four-digit year into the previous
// line before validating, mirroring the parse that produced the
// current vendored values.
import 'dart:convert';
import 'dart:io';

const String observedUrl = 'https://maia.usno.navy.mil/ser7/deltat.data';
const String predsUrl = 'https://maia.usno.navy.mil/ser7/deltat.preds';
const String dataPath = 'packages/nepali_panchang/lib/src/delta_t_data.dart';

const String observedBegin = '// BEGIN USNO-OBSERVED';
const String observedEnd = '// END USNO-OBSERVED';
const String predsBegin = '// BEGIN USNO-PREDS';
const String predsEnd = '// END USNO-PREDS';

Future<String> fetchText(String url) async {
  final candidates = <String>[
    url,
    'https://web.archive.org/web/2id_/' + url,
  ];
  Object? lastError;
  for (final u in candidates) {
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(u));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200 && text.isNotEmpty) {
        return text;
      }
      lastError = 'HTTP ' + response.statusCode.toString() + ' for ' + u;
    } catch (e) {
      lastError = e;
    } finally {
      client?.close();
    }
  }
  throw StateError('could not fetch ' + url + ': ' + lastError.toString());
}

class ObservedRow {
  final int year;
  final int month;
  final double seconds;
  const ObservedRow(this.year, this.month, this.seconds);
}

List<ObservedRow> parseObserved(String raw) {
  final cleaned = raw.replaceAll(
      RegExp(r'[\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]'),
      '');
  final rawLines = cleaned
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final merged = <String>[];
  for (final line in rawLines) {
    if (RegExp(r'^\d{4}(\s|$)').hasMatch(line)) {
      merged.add(line);
    } else if (merged.isNotEmpty) {
      merged[merged.length - 1] = merged.last + ' ' + line;
    }
  }
  final rowPattern = RegExp(
      r'^(\d{4})\s+(\d{1,2})\s+(\d{1,2})\s+([\d.]+)((?:\s+[\d.]+)*)$');
  final rows = <ObservedRow>[];
  for (final line in merged) {
    final m = rowPattern.firstMatch(line);
    if (m == null) continue;
    final year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final seconds = double.parse(m.group(4)!);
    if (month < 1 || month > 12) {
      throw FormatException('bad month in line: ' + line);
    }
    if (seconds < 40 || seconds > 80) {
      throw FormatException('out-of-envelope value in line: ' + line);
    }
    rows.add(ObservedRow(year, month, seconds));
  }
  for (var i = 1; i < rows.length; i++) {
    final prev = rows[i - 1];
    final cur = rows[i];
    final expectedMonth = prev.month == 12 ? 1 : prev.month + 1;
    final expectedYear = prev.month == 12 ? prev.year + 1 : prev.year;
    if (cur.year != expectedYear || cur.month != expectedMonth) {
      throw FormatException('month gap at ' +
          cur.year.toString() + '-' + cur.month.toString() +
          ' (previous: ' + prev.year.toString() + '-' +
          prev.month.toString() + ')');
    }
  }
  if (rows.length < 600 || rows.length > 4000) {
    throw FormatException('suspicious observed row count: ' +
        rows.length.toString());
  }
  return rows;
}

class PredRow {
  final double mjd;
  final double seconds;
  final double error;
  const PredRow(this.mjd, this.seconds, this.error);
}

List<PredRow> parsePreds(String raw) {
  final cleaned = raw.replaceAll(
      RegExp(r'[\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]'),
      '');
  final rowPattern = RegExp(
      r'^(\d+\.\d+)\s+(\d+\.\d+)\s+(-?[\d.]+)\s*(-?[\d.]*)\s*(-?[\d.]+)$');
  final rows = <PredRow>[];
  for (final line in cleaned.split(RegExp(r'\r?\n'))) {
    final m = rowPattern.firstMatch(line.trim());
    if (m == null) continue;
    final mjd = double.parse(m.group(1)!);
    final seconds = double.parse(m.group(3)!);
    final error = double.parse(m.group(5)!);
    if (seconds < 60 || seconds > 80) {
      throw FormatException('out-of-envelope prediction: ' + line);
    }
    if (error <= 0 || error > 1.001) {
      throw FormatException('out-of-envelope prediction error: ' + line);
    }
    rows.add(PredRow(mjd, seconds, error));
  }
  for (var i = 1; i < rows.length; i++) {
    final step = rows[i].mjd - rows[i - 1].mjd;
    if (step < 88 || step > 95) {
      throw FormatException('prediction rows not quarterly at MJD ' +
          rows[i].mjd.toString());
    }
  }
  if (rows.length < 10 || rows.length > 200) {
    throw FormatException('suspicious prediction row count: ' +
        rows.length.toString());
  }
  return rows;
}

double jdFromCivilYmd(int year, int month, int day) {
  var y = year;
  var m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      day +
      b -
      1524.5;
}

String splice(String text, String begin, String end, String replacement) {
  final b = text.indexOf(begin);
  final e = text.indexOf(end);
  if (b < 0 || e < 0 || e < b) {
    throw FormatException('markers not found: ' + begin + ' / ' + end);
  }
  return text.substring(0, b) + replacement + text.substring(e + end.length);
}

String numbers(List<String> values, int perLine) {
  final out = <String>[];
  for (var i = 0; i < values.length; i += perLine) {
    final chunk = values.sublist(i, i + perLine).join(', ');
    out.add('  ' + chunk + ',');
  }
  return out.join('\n');
}

String observedBlock(List<ObservedRow> rows) {
  final jd = rows.map((r) => jdFromCivilYmd(r.year, r.month, 1).toStringAsFixed(1)).toList();
  final seconds = rows.map((r) => r.seconds.toStringAsFixed(4)).toList();
  return observedBegin + '\n' +
      '/// USNO observed months: JD (UT) of the first of the month.\n' +
      'const List<double> usnoObservedJd = <double>[\n' +
      numbers(jd, 6) + '\n' +
      '];\n\n' +
      '/// USNO observed months: TT-UT1 in seconds.\n' +
      'const List<double> usnoObservedSeconds = <double>[\n' +
      numbers(seconds, 6) + '\n' +
      '];\n' +
      observedEnd + '\n';
}

String predsBlock(List<PredRow> rows) {
  final jd = rows.map((r) => (r.mjd + 2400000.5).toStringAsFixed(1)).toList();
  final seconds = rows.map((r) => r.seconds.toStringAsFixed(2)).toList();
  final errors = rows.map((r) => r.error.toStringAsFixed(3)).toList();
  return predsBegin + '\n' +
      '/// USNO predictions: JD (UT) = MJD + 2400000.5.\n' +
      'const List<double> usnoPredsJd = <double>[\n' +
      numbers(jd, 6) + '\n' +
      '];\n\n' +
      '/// USNO predictions: TT-UT1 in seconds.\n' +
      'const List<double> usnoPredsSeconds = <double>[\n' +
      numbers(seconds, 6) + '\n' +
      '];\n\n' +
      '/// USNO predictions: the file\'s stated error, in seconds.\n' +
      'const List<double> usnoPredsErrorSeconds = <double>[\n' +
      numbers(errors, 6) + '\n' +
      '];\n' +
      predsEnd + '\n';
}

Future<void> main() async {
  final observed = parseObserved(await fetchText(observedUrl));
  final preds = parsePreds(await fetchText(predsUrl));
  final file = File(dataPath);
  if (!file.existsSync()) {
    throw StateError('data file not found at ' + dataPath +
        ' - run from the repo root');
  }
  var text = file.readAsStringSync();
  text = splice(text, observedBegin, observedEnd, observedBlock(observed));
  text = splice(text, predsBegin, predsEnd, predsBlock(preds));
  file.writeAsStringSync(text);
  stdout.writeln('refreshed ' + dataPath + ': ' +
      observed.length.toString() + ' observed rows, ' +
      preds.length.toString() + ' prediction rows');
}
