import 'dart:io';

import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_sankranti/nepali_sankranti.dart';
import 'package:test/test.dart';

/// The 24 cataloged before-sankranti rows (all pre-1980 consensus-class,
/// per the R5 experiment). This list IS the era-law exception allowlist.
const Set<String> kBeforeSankrantiAllowlist = {
  '1976-1', '1976-11', '1977-2', '1977-12', '1980-1', '1980-11',
  '1984-1', '1984-11', '1988-1', '1988-11', '1992-1', '1992-12',
  '1996-1', '1996-2', '1996-12', '2000-2', '2000-12', '2004-2',
  '2004-12', '2008-12', '2015-11', '2019-1', '2023-1', '2035-12',
};

File _artifactFile() {
  for (final path in [
    'data/sankranti_moments_1975_2083.csv',
    '../../data/sankranti_moments_1975_2083.csv',
  ]) {
    final f = File(path);
    if (f.existsSync()) return f;
  }
  throw StateError('Commons Layer 1 artifact CSV not found.');
}

void main() {
  final moments = parseSankrantiMomentsCsv(_artifactFile().readAsStringSync());

  test('artifact shape receipt: 1,308 moments, BS 1975-2083, 12 per year', () {
    expect(moments, hasLength(1308));
    expect(moments.first.bsYear, 1975);
    expect(moments.last.bsYear, 2083);
    final years = moments.map((m) => m.bsYear).toSet();
    expect(years, hasLength(109));
    for (final y in years) {
      expect(moments.where((m) => m.bsYear == y), hasLength(12));
    }
    for (final m in moments) {
      expect(m.monthNo, inInclusiveRange(1, 12));
      expect(m.delta, inInclusiveRange(-1, 1));
      expect(m.evidence, isNotEmpty);
    }
    // The R5 delta distribution, as a receipt.
    expect(moments.where((m) => m.delta == 0), hasLength(998));
    expect(moments.where((m) => m.delta == 1), hasLength(286));
  });

  test('the 24 before-sankranti rows are exactly the cataloged allowlist', () {
    final neg = moments.where((m) => m.delta == -1).toList();
    expect(neg, hasLength(24));
    for (final m in neg) {
      expect(m.bsYear, lessThanOrEqualTo(2035));
      final key = m.bsYear.toString() + '-' + m.monthNo.toString();
      expect(kBeforeSankrantiAllowlist.contains(key), isTrue,
          reason: 'uncataloged before-sankranti row: ' + key);
    }
  });

  test('REGRESSION WALL: the engine reproduces all 1,308 published moments within the scope tolerance', () {
    final failures = <String>[];
    var worstSec = 0.0;
    var sumSec = 0.0;
    for (final m in moments) {
      final engine = ingressUtc(
        rasiIndex: m.monthNo,
        utcLo: m.utc.subtract(const Duration(days: 2)),
        utcHi: m.utc.add(const Duration(days: 2)),
      );
      final diffSec =
          engine.difference(m.utc).inMilliseconds.abs() / 1000.0;
      sumSec += diffSec;
      if (diffSec > worstSec) worstSec = diffSec;
      final label = 'BS ' + m.bsYear.toString() + ' month ' + m.monthNo.toString();
      if (diffSec > 120.0 && failures.length < 10) {
        failures.add(label + ': artifact vs engine differs by ' +
            diffSec.toStringAsFixed(1) + 's');
      }
      // The published NPT civil date must survive a faithful re-computation.
      final engineNpt = todayInNepalTime(nowUtc: engine);
      final artifactNpt = todayInNepalTime(nowUtc: m.utc);
      if (engineNpt != artifactNpt && failures.length < 10) {
        failures.add(label + ': NPT civil date flipped on re-computation');
      }
    }
    final meanSec = sumSec / moments.length;
    expect(failures, isEmpty,
        reason: 'mean residual ' +
            meanSec.toStringAsFixed(1) +
            's, worst ' +
            worstSec.toStringAsFixed(1) +
            's');
    expect(worstSec, lessThan(120.0));
    expect(meanSec, lessThan(60.0),
        reason: 'a faithful re-implementation should be near-exact');
  });

  test('live fixture: Dhanu sankranti is Wednesday 2026-12-16, Poush 1 2083', () {
    final engine = ingressUtc(
      rasiIndex: 9,
      utcLo: DateTime.utc(2026, 12, 13),
      utcHi: DateTime.utc(2026, 12, 19),
    );
    final npt = todayInNepalTime(nowUtc: engine);
    expect(DateTime.utc(npt.year, npt.month, npt.day),
        DateTime.utc(2026, 12, 16));
    expect(DateTime.utc(npt.year, npt.month, npt.day).weekday,
        DateTime.wednesday);
    // The artifact row 2083/9 is 2026-12-16T10:48 Nepal Time.
    final artifact = moments
        .firstWhere((m) => m.bsYear == 2083 && m.monthNo == 9);
    expect(engine.difference(artifact.utc).inSeconds.abs(), lessThan(120));
  });
}
