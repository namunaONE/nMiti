import 'dart:io';

import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_sankranti/nepali_sankranti.dart';

/// Regenerates data/sankranti_moments_1975_2100.csv from the canonical
/// calendar CSVs and the R5 artifact:
///
///     dart run nepali_sankranti:generate [output-path]
///
/// Without an argument the CSV is printed to stdout. CI verifies the
/// committed file on every run via test/published_table_test.dart.
File _find(String rel) {
  for (final path in [rel, '../../' + rel]) {
    final f = File(path);
    if (f.existsSync()) return f;
  }
  throw StateError('Required data file not found: ' + rel);
}

void main(List<String> args) {
  final core = _find('data/calendar_bs_core_1975_2083.csv').readAsStringSync();
  final tail = _find('data/calendar_bs_tail_2084_2100.csv').readAsStringSync();
  final artifactCsv =
      _find('data/sankranti_moments_1975_2083.csv').readAsStringSync();
  final calendar = BsCalendar([
    ...parseBsCalendarCsv(core),
    ...parseBsCalendarCsv(tail),
  ]);
  final rows = generateSankrantiTable(
    calendar: calendar,
    artifact: parseSankrantiMomentsCsv(artifactCsv),
  );
  final csv = sankrantiTableCsv(rows);
  if (args.isEmpty) {
    stdout.write(csv);
  } else {
    File(args[0]).writeAsStringSync(csv);
  }
}
