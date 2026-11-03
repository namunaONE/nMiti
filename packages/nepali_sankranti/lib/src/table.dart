import 'dart:convert';

import 'package:nepali_date/nepali_date.dart';

import 'ingress.dart';
import 'moments.dart';

/// One row of the published sankranti dataset (BS 1975-2100).
class SankrantiTableRow {
  final int bsYear;

  /// 1..12. Month 1 is Baisakh, the Mesha ingress at 0 deg.
  final int monthNo;
  final String monthEn;
  final String rashiEn;
  final String rashiNe;

  /// The ingress instant (UTC), minute-rounded.
  final DateTime ingressUtc;
  final String weekdayNpt;

  /// BS month-start NPT date minus ingress NPT date:
  /// 0 = same day, 1 = next day, -1 = before (see [eraLaw]).
  final int startsOnDelta;
  final String eraLaw;
  final bool dateProvisional;
  final String evidence;

  const SankrantiTableRow({
    required this.bsYear,
    required this.monthNo,
    required this.monthEn,
    required this.rashiEn,
    required this.rashiNe,
    required this.ingressUtc,
    required this.weekdayNpt,
    required this.startsOnDelta,
    required this.eraLaw,
    required this.dateProvisional,
    required this.evidence,
  });

  String get key => bsYear.toString() + '-' + monthNo.toString();
}

const List<String> kMonthNamesEn = [
  'Baisakh', 'Jestha', 'Ashar', 'Shrawan', 'Bhadra', 'Asoj',
  'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra',
];

const List<String> kRashiNamesEn = [
  'Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya',
  'Tula', 'Vrischika', 'Dhanu', 'Makara', 'Kumbha', 'Meena',
];

const List<String> kRashiNamesNe = [
  'मेष', 'वृषभ', 'मिथुन', 'कर्क', 'सिंह', 'कन्या',
  'तुला', 'वृश्चिक', 'धनु', 'मकर', 'कुम्भ', 'मीन',
];

const List<String> kWeekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The 24 cataloged before-sankranti rows (all pre-2036 consensus class,
/// per the R5 experiment). This list IS the era-law exception allowlist.
const Set<String> kBeforeSankrantiAllowlist = {
  '1976-1', '1976-11', '1977-2', '1977-12', '1980-1', '1980-11',
  '1984-1', '1984-11', '1988-1', '1988-11', '1992-1', '1992-12',
  '1996-1', '1996-2', '1996-12', '2000-2', '2000-12', '2004-2',
  '2004-12', '2008-12', '2015-11', '2019-1', '2023-1', '2035-12',
};

/// The six projection-tail rows whose month starts fall before their
/// ingress. These are upstream projection defects in the BS 2084-2100
/// month lengths, preserved and pinned by test - the same policy as the
/// BS 2096 364-day defect. Do not silently fix them.
const Set<String> kProjectionWindowDefects = {
  '2084-7', '2084-8', '2084-10', '2086-2', '2090-2', '2098-12',
};

DateTime _roundToMinute(DateTime t) {
  final ms = t.millisecondsSinceEpoch;
  final rounded = (ms / 60000).round() * 60000;
  return DateTime.fromMillisecondsSinceEpoch(rounded, isUtc: true);
}

String _two(int n) => n < 10 ? '0' + n.toString() : n.toString();

String _utcStamp(DateTime t) =>
    t.year.toString() + '-' + _two(t.month) + '-' + _two(t.day) +
    'T' + _two(t.hour) + ':' + _two(t.minute) + ':00Z';

String _nptStamp(DateTime t) {
  final wall = t.add(nepalTimeOffset);
  return wall.year.toString() + '-' + _two(wall.month) + '-' + _two(wall.day) +
      'T' + _two(wall.hour) + ':' + _two(wall.minute) + ':00+05:45';
}

/// Generates the full 1975-2100 dataset from the calendar + artifact.
///
/// For every BS month the engine solves the rasi ingress inside a four-day
/// bracket around the month start, rounds to the minute, and derives the
/// window delta, era law and provisional-date flag. Evidence for BS
/// 1975-2083 rows is carried over from the R5 artifact; tail rows are
/// marked derived. Throws [StateError] if a delta falls outside -1..1:
/// that must be investigated, never published.
List<SankrantiTableRow> generateSankrantiTable({
  required BsCalendar calendar,
  required List<SankrantiMoment> artifact,
}) {
  final evidenceBy = <String, String>{
    for (final a in artifact)
      a.bsYear.toString() + '-' + a.monthNo.toString(): a.evidence,
  };
  final rows = <SankrantiTableRow>[];
  for (final year in calendar.years) {
    final row = calendar.row(year);
    var start = calendar.baisakh1(year);
    for (var m = 1; m <= 12; m++) {
      if (m > 1) start = start.add(Duration(days: row.months[m - 2]));
      final ingress = _roundToMinute(ingressUtc(
        rasiIndex: m,
        utcLo: start.subtract(const Duration(days: 2)),
        utcHi: start.add(const Duration(days: 2)),
      ));
      final nptDate = todayInNepalTime(nowUtc: ingress);
      final delta = start.difference(nptDate).inDays;
      String era;
      if (delta == 0 || delta == 1) {
        era = 'ok';
      } else if (delta == -1) {
        era = year < 2036 ? 'pre_2036_exception' : 'projection_defect';
      } else {
        throw StateError('BS ' + year.toString() + ' month ' + m.toString() +
            ' has delta ' + delta.toString() +
            ' - outside the sankranti window; investigate instead of publishing.');
      }
      final wall = ingress.add(nepalTimeOffset);
      final minutes = wall.hour * 60 + wall.minute;
      final provisional = minutes >= 23 * 60 + 15 || minutes <= 45;
      final key = year.toString() + '-' + m.toString();
      final evidence = year <= 2083
          ? (evidenceBy[key] ??
              (throw StateError('No artifact evidence for ' + key + '.')))
          : 'derived';
      rows.add(SankrantiTableRow(
        bsYear: year,
        monthNo: m,
        monthEn: kMonthNamesEn[m - 1],
        rashiEn: kRashiNamesEn[m - 1],
        rashiNe: kRashiNamesNe[m - 1],
        ingressUtc: ingress,
        weekdayNpt: kWeekdayNames[nptDate.weekday - 1],
        startsOnDelta: delta,
        eraLaw: era,
        dateProvisional: provisional,
        evidence: evidence,
      ));
    }
  }
  return rows;
}

/// The full published CSV: provenance comments, header, 1,512 rows.
String sankrantiTableCsv(List<SankrantiTableRow> rows) {
  final buffer = StringBuffer(kTableProvenance);
  buffer.writeln('bs_year,month_no,month_en,rashi_en,rashi_ne,ingress_utc,');
  buffer.writeln('ingress_npt,weekday_npt,starts_on_delta,era_law,');
  buffer.writeln('date_provisional,evidence');
  for (final r in rows) {
    buffer.write(r.bsYear.toString());
    buffer.write(',');
    buffer.write(r.monthNo.toString());
    buffer.write(',');
    buffer.write(r.monthEn);
    buffer.write(',');
    buffer.write(r.rashiEn);
    buffer.write(',');
    buffer.write(r.rashiNe);
    buffer.write(',');
    buffer.write(_utcStamp(r.ingressUtc));
    buffer.write(',');
    buffer.write(_nptStamp(r.ingressUtc));
    buffer.write(',');
    buffer.write(r.weekdayNpt);
    buffer.write(',');
    buffer.write(r.startsOnDelta.toString());
    buffer.write(',');
    buffer.write(r.eraLaw);
    buffer.write(',');
    buffer.write(r.dateProvisional ? 'true' : 'false');
    buffer.write(',');
    buffer.write(r.evidence);
    buffer.writeln();
  }
  return buffer.toString();
}

/// Parses the published 1975-2100 table CSV. Lines starting with a hash
/// are provenance comments; the header line starts with bs_year.
List<SankrantiTableRow> parseSankrantiTableCsv(String csv) {
  final rows = <SankrantiTableRow>[];
  for (final rawLine in const LineSplitter().convert(csv)) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final cols = line.split(',');
    if (cols[0] == 'bs_year') continue;
    if (cols.length < 12) {
      throw FormatException('Expected 12 columns, got ' +
          cols.length.toString() +
          ': "' +
          line +
          '"');
    }
    rows.add(SankrantiTableRow(
      bsYear: int.parse(cols[0]),
      monthNo: int.parse(cols[1]),
      monthEn: cols[2],
      rashiEn: cols[3],
      rashiNe: cols[4],
      ingressUtc: DateTime.parse(cols[5]).toUtc(),
      weekdayNpt: cols[7],
      startsOnDelta: int.parse(cols[8]),
      eraLaw: cols[9],
      dateProvisional: cols[10] == 'true',
      evidence: cols.sublist(11).join(','),
    ));
  }
  return rows;
}

const String kTableProvenance = '''
# nMiti Commons Layer 1 - Sankranti moments, BS 1975-2100 (1,512 rows).
# Sidereal solar ingress per rasi, computed by the nepali_sankranti engine:
# Meeus Ch.25 solar longitude + the R5-calibrated Lahiri-family ayanamsa
# (ayan(J) = 23.87508 + 1.36062*(J-2451545)/36525 deg), solved to under a
# second, minute-rounded. Declared accuracy vs published panchang sources:
# ~15s mean / ~31s max residual (see /methodology.html). NPT is UTC+05:45.
# starts_on_delta = BS month-start NPT date minus ingress NPT date:
# 0 = same day, 1 = the day after, -1 = BEFORE the ingress (see era_law).
# era_law: ok | pre_2036_exception (24 cataloged rows) | projection_defect
# (tail years only: upstream month-length defect, pinned by test; replace
# with official data when Nepal publishes the BS 2084+ calendar).
# date_provisional = ingress within 45 min of NPT midnight (conservative
# flag under the declared ~31s tolerance, not a known error).
# Evidence: verified/consensus from the R5 artifact (BS 1975-2083);
# derived for the BS 2084-2100 projection tail.
# License: CC0-1.0 (data). Regenerate: dart run nepali_sankranti:generate.
# CI re-computes every row on every run (test/published_table_test.dart).
''';
