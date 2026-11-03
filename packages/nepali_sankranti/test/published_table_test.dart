import 'dart:io';

import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_sankranti/nepali_sankranti.dart';
import 'package:test/test.dart';

File _find(String rel) {
  for (final path in [rel, '../../' + rel]) {
    final f = File(path);
    if (f.existsSync()) return f;
  }
  throw StateError('Required data file not found: ' + rel);
}

void main() {
  final core = _find('data/calendar_bs_core_1975_2083.csv').readAsStringSync();
  final tail = _find('data/calendar_bs_tail_2084_2100.csv').readAsStringSync();
  final artifact = parseSankrantiMomentsCsv(
      _find('data/sankranti_moments_1975_2083.csv').readAsStringSync());
  final committed = parseSankrantiTableCsv(
      _find('data/sankranti_moments_1975_2100.csv').readAsStringSync());
  final calendar = BsCalendar([
    ...parseBsCalendarCsv(core),
    ...parseBsCalendarCsv(tail),
  ]);

  test('shape receipt: 1,512 rows, BS 1975-2100, 12 per year', () {
    expect(committed, hasLength(1512));
    expect(committed.first.bsYear, 1975);
    expect(committed.last.bsYear, 2100);
    final years = committed.map((r) => r.bsYear).toSet();
    expect(years, hasLength(126));
    for (final y in years) {
      expect(committed.where((r) => r.bsYear == y), hasLength(12));
    }
  });

  test('distribution receipts: deltas, era law, provisional dates', () {
    expect(committed.where((r) => r.startsOnDelta == 0), hasLength(1142));
    expect(committed.where((r) => r.startsOnDelta == 1), hasLength(340));
    expect(committed.where((r) => r.startsOnDelta == -1), hasLength(30));
    expect(committed.where((r) => r.eraLaw == 'ok'), hasLength(1476));
    final pre = committed
        .where((r) => r.eraLaw == 'pre_2036_exception')
        .map((r) => r.key)
        .toSet();
    expect(pre, kBeforeSankrantiAllowlist);
    final proj = committed
        .where((r) => r.eraLaw == 'projection_defect')
        .map((r) => r.key)
        .toSet();
    expect(proj, kProjectionWindowDefects);
    expect(committed.where((r) => r.dateProvisional), hasLength(95));
    expect(
        committed.where((r) => r.bsYear >= 2084).map((r) => r.evidence),
        everyElement('derived'));
  });

  test('DETERMINISM RECEIPT: committed CSV equals engine regen', () {
    final regen =
        generateSankrantiTable(calendar: calendar, artifact: artifact);
    expect(regen, hasLength(committed.length));
    final failures = <String>[];
    for (var i = 0; i < committed.length; i++) {
      final a = committed[i];
      final b = regen[i];
      if (a.bsYear != b.bsYear ||
          a.monthNo != b.monthNo ||
          a.monthEn != b.monthEn ||
          a.rashiEn != b.rashiEn ||
          a.rashiNe != b.rashiNe ||
          a.weekdayNpt != b.weekdayNpt ||
          a.startsOnDelta != b.startsOnDelta ||
          a.eraLaw != b.eraLaw ||
          a.dateProvisional != b.dateProvisional ||
          a.evidence != b.evidence) {
        if (failures.length < 10) failures.add(a.key + ': field mismatch');
      }
      final driftMs =
          a.ingressUtc.difference(b.ingressUtc).inMilliseconds.abs();
      if (driftMs > 60000) {
        if (failures.length < 10) {
          failures.add(a.key + ': ingress drift ' + driftMs.toString() + 'ms');
        }
      }
    }
    expect(failures, isEmpty,
        reason: 'the committed dataset must recompute exactly (dates,'
            ' deltas, era_law, provisional flags, evidence, weekday); ingress'
            ' times agree within the 60s cross-runtime rounding tolerance');
  });

  test('ARTIFACT CHAIN: core rows match the R5 artifact dates within 2 min', () {
    final byKey = <String, SankrantiMoment>{
      for (final a in artifact)
        a.bsYear.toString() + '-' + a.monthNo.toString(): a,
    };
    final failures = <String>[];
    for (final r in committed.where((x) => x.bsYear <= 2083)) {
      final a = byKey[r.key];
      if (a == null) {
        failures.add(r.key + ': no artifact row');
        continue;
      }
      final tableNpt = todayInNepalTime(nowUtc: r.ingressUtc);
      final artifactNpt = todayInNepalTime(nowUtc: a.utc);
      if (tableNpt != artifactNpt) {
        if (failures.length < 10) failures.add(r.key + ': NPT date differs');
      }
      final drift = r.ingressUtc.difference(a.utc).inMilliseconds.abs();
      if (drift > 120000) {
        if (failures.length < 10) {
          failures.add(r.key + ': drift ' + (drift / 1000).toString() + 's');
        }
      }
    }
    expect(failures, isEmpty);
  });
}
