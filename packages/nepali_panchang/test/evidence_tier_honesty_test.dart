import 'dart:convert';
import 'dart:io';

import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// Evidence-tier honesty gate (2026-11-08 daily audit finding).
///
/// The served [PanchangDay.evidenceTier] string states how many boundary
/// receipts the locked golden corpora hold. That number was written by
/// hand when the Nov corpus (117 boundaries) was the whole corpus; the
/// Oct (109) and Dec (181) corpora later took the true count to 407 and
/// the string went stale, serving "226 boundary receipts". This gate
/// derives the count from the fixtures themselves and compares it to the
/// served string, so a future corpus addition that forgets the string
/// fails CI instead of silently serving a stale honesty field. The count
/// is never hand-pinned here - the fixtures are the single source of
/// truth.

const _corporaFiles = <String>[
  'lunar_receipts_2026_10.json',
  'lunar_receipts_2026_11.json',
  'lunar_receipts_2026_12.json',
];

Map<String, dynamic> _loadFixture(String fileName) {
  final file = File('test/fixtures/$fileName');
  if (file.existsSync()) {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  // CI runs from the package root; also try the repo-root variant.
  final alt =
      File('packages/nepali_panchang/test/fixtures/$fileName');
  return jsonDecode(alt.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  test('the served evidence tier states the true boundary-receipt count',
      () {
    var total = 0;
    final perCorpus = <String, int>{};
    for (final fileName in _corporaFiles) {
      final data = _loadFixture(fileName);
      final boundaries =
          (data['boundaries'] as List).cast<Map<String, dynamic>>();
      perCorpus[fileName] = boundaries.length;
      total += boundaries.length;
    }
    expect(perCorpus, isNotEmpty);
    expect(total, greaterThan(0));

    final day = panchangFor(year: 2026, month: 11, day: 8);
    final match = RegExp(r'\((\d+) boundary receipts,')
        .firstMatch(day.evidenceTier);
    expect(match, isNotNull,
        reason: 'the served evidenceTier no longer states a '
            'boundary-receipt count: ${day.evidenceTier}');
    final stated = int.parse(match!.group(1)!);
    expect(stated, total,
        reason: 'the served evidenceTier states $stated boundary receipts '
            'but the locked corpora hold $total ($perCorpus) - update the '
            'string in panchang_day.dart to match the fixtures');
  });
}
