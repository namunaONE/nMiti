import 'dart:io';

import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_date_data/nepali_date_data.dart';

void main(List<String> args) {
  final corePath = _arg(args, '--core') ?? 'data/calendar_bs_core_1975_2083.csv';
  final tailPath = _arg(args, '--tail') ?? 'data/calendar_bs_tail_2084_2100.csv';
  final coreCsv = File(corePath).readAsStringSync();
  final tailCsv = File(tailPath).readAsStringSync();

  final problems = <String>[];
  if (coreCsv.trim() != calendarBsCoreCsv.trim()) {
    problems.add('core CSV in $corePath differs from the embedded copy in nepali_date_data; regenerate both together.');
  }
  if (tailCsv.trim() != calendarBsTailCsv.trim()) {
    problems.add('tail CSV in $tailPath differs from the embedded copy in nepali_date_data; regenerate both together.');
  }

  final core = BsCalendar.fromCsv(coreCsv);
  final tail = BsCalendar.fromCsv(tailCsv);
  final violations = validateCore(core);
  final tailViolations = validateTail(core, tail);
  final known = tailViolations.where((v) => v.knownDefect).toList();
  violations.addAll(tailViolations.where((v) => !v.knownDefect));

  stdout.writeln('core: BS ${core.firstYear}-${core.lastYear}, ${core.years.length} years');
  stdout.writeln('tail: BS ${tail.firstYear}-${tail.lastYear}, ${tail.years.length} years');
  for (final v in known) {
    stdout.writeln('known defect (preserved and labeled): $v');
  }

  if (violations.isEmpty && problems.isEmpty) {
    stdout.writeln('OK: all invariants hold (${known.length} known defect(s) reported above).');
    return;
  }
  for (final p in problems) {
    stdout.writeln('problem: $p');
  }
  for (final v in violations) {
    stdout.writeln('$v');
  }
  exitCode = 1;
}

String? _arg(List<String> args, String name) {
  for (var i = 0; i + 1 < args.length; i++) {
    if (args[i] == name) return args[i + 1];
  }
  return null;
}
