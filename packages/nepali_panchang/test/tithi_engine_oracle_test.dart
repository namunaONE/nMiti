import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';
import 'package:tithi_engine/tithi_engine.dart';
import 'package:tithi_engine/data/all.dart';

/// tithi_engine (misrilibrary, Apache-2.0) as an independent tithi oracle
/// (HYA-418). Their engine is anchored to Swiss Ephemeris .se1 files (all
/// 74,582 tithi transitions 1900-2100 within 30 s of .se1) and Kathmandu is
/// a registry city in the same 0.1-degree cell as our anchor, so agreement
/// with them is effectively a Swiss-parity cross-check of our tithi limb
/// ahead of the full SWEPH comparison (HYA-369). Dev-dependency only: no
/// production coupling, no data taken from them - methods and oracles,
/// never data.
///
/// Bands are provisional for the first scoreboard run; tighten them once
/// the actual deltas are recorded (follow-up on HYA-369).

const _npt = Duration(hours: 5, minutes: 45);

/// UTC instant of an NPT wall-clock value stored as UTC fields.
DateTime _utcOfNptWall(DateTime nptWall) => nptWall.subtract(_npt);

void main() {
  final oracle = Panchang([registerAllCities]);
  final kathmandu = City.of('Kathmandu');

  test('day-tithi labels agree with tithi_engine across the window', () {
    // The Dashain-Tihar receipt window (Kartik 2083) plus the Nov corpus.
    for (var d = 0; d < 44; d++) {
      final date = DateTime.utc(2026, 10, 18).add(Duration(days: d));
      final ours = panchangFor(
              year: date.year, month: date.month, day: date.day)
          .tithiAtUdaya;
      final ourPaksha = ours.index < 15 ? 'shukla' : 'krishna';
      final ourTithi = (ours.index % 15) + 1;

      final info = oracle.tithiOnDate(date, kathmandu);
      final theirPaksha =
          info.paksha.toString().split('.').last.toLowerCase();
      final theirTithi = info.tithiInPaksha;

      expect(theirPaksha, ourPaksha,
          reason: 'paksha mismatch on $date: ours $ourPaksha');
      expect(theirTithi, ourTithi,
          reason: 'day-tithi mismatch on $date: ours index ${ours.index}');
    }
  });

  test('tithi transition instants agree with tithi_engine', () {
    // Their engine reports every tithi segment in a UTC window directly.
    final segments = oracle.tithiSegments(
        DateTime.utc(2026, 10, 16), DateTime.utc(2026, 12, 2), kathmandu,
        offset: _npt);
    final theirs = <DateTime>[
      for (final s in segments) s.startUtc,
      segments.last.endUtc,
    ];

    // Our boundaries: the udaya and noon tithi runs of every day in the
    // window. Their union covers every transition, including kshaya runs
    // that never touch an udaya but span a noon.
    final ours = <DateTime>{};
    for (var d = 0; d < 44; d++) {
      final date = DateTime.utc(2026, 10, 18).add(Duration(days: d));
      final day =
          panchangFor(year: date.year, month: date.month, day: date.day);
      ours.add(_utcOfNptWall(day.tithiAtUdaya.beginsAtNpt));
      ours.add(_utcOfNptWall(day.tithiAtUdaya.endsAtNpt));
      ours.add(_utcOfNptWall(day.tithiAtNoon.beginsAtNpt));
      ours.add(_utcOfNptWall(day.tithiAtNoon.endsAtNpt));
    }

    // Trim to the interior so window edges (clipped segments, missing
    // neighbor days) cannot produce false mismatches.
    final lo = DateTime.utc(2026, 10, 19);
    final hi = DateTime.utc(2026, 11, 29);
    final theirTrimmed = (theirs..sort())
        .where((t) => t.isAfter(lo) && t.isBefore(hi))
        .toList();
    final ourTrimmed = (ours.toList()..sort())
        .where((t) => t.isAfter(lo) && t.isBefore(hi))
        .toList();

    // Every one of their transitions must have a distinct matching one of
    // ours close by, and vice versa (counts may differ only by edge runs no
    // udaya/noon element covers).
    expect(ourTrimmed.length, greaterThanOrEqualTo(theirTrimmed.length),
        reason: 'our transition set is missing entries '
            '(${ourTrimmed.length} ours vs ${theirTrimmed.length} theirs)');
    expect(ourTrimmed.length, lessThanOrEqualTo(theirTrimmed.length + 1),
        reason: 'our transition set has unexpected extra entries '
            '(${ourTrimmed.length} ours vs ${theirTrimmed.length} theirs)');

    const hardBandSeconds = 240; // provisional; tighten after first run
    const meanBandSeconds = 120; // provisional; tighten after first run
    final deltas = <int>[];
    var j = 0;
    for (final t in theirTrimmed) {
      while (j < ourTrimmed.length - 1 &&
          (ourTrimmed[j + 1].difference(t)).abs() <
              (ourTrimmed[j].difference(t)).abs()) {
        j++;
      }
      final delta = ourTrimmed[j].difference(t).inSeconds.abs();
      expect(
        delta,
        lessThan(hardBandSeconds),
        reason:
            'transition near $t off by ${delta}s (ours ${ourTrimmed[j]})',
      );
      deltas.add(delta);
    }
    final mean = deltas.reduce((a, b) => a + b) / deltas.length;
    final maxDelta = deltas.reduce((a, b) => a > b ? a : b);
    // ignore: avoid_print
    print('tithi_engine oracle scoreboard: n=${deltas.length} '
        'mean=${mean.toStringAsFixed(1)}s max=${maxDelta}s');
    expect(mean, lessThan(meanBandSeconds),
        reason: 'systematic tithi offset vs tithi_engine (HYA-369 signal)');
  });
}
