/// English transliterations of the twelve BS months (index 0 = Baisakh).
const List<String> bsMonthNamesEn = [
  'Baisakh',
  'Jestha',
  'Ashadh',
  'Shrawan',
  'Bhadra',
  'Ashwin',
  'Kartik',
  'Mangsir',
  'Poush',
  'Magh',
  'Falgun',
  'Chaitra',
];

/// Devanagari names of the twelve BS months (index 0 = बैशाख).
const List<String> bsMonthNamesNp = [
  'बैशाख',
  'जेठ',
  'असार',
  'साउन',
  'भदौ',
  'असोज',
  'कात्तिक',
  'मंसिर',
  'पुस',
  'माघ',
  'फागुन',
  'चैत',
];

/// English weekday names indexed by [DateTime.weekday] (1 = Monday .. 7 = Sunday).
const List<String> weekdayNamesEn = [
  '',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Devanagari weekday names indexed by [DateTime.weekday] (1 = सोमबार .. 7 = आइतबार).
const List<String> weekdayNamesNp = [
  '',
  'सोमबार',
  'मङ्गलबार',
  'बुधबार',
  'बिहीबार',
  'शुक्रबार',
  'शनिबार',
  'आइतबार',
];

const List<String> _devanagariDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];

/// Converts ASCII digits in [text] to Devanagari digits.
String toNepaliDigits(String text) => text.replaceAllMapped(
      RegExp(r'\d'),
      (match) => _devanagariDigits[int.parse(match.group(0)!)],
    );

/// English name of BS month [month] (1-12).
String bsMonthNameEn(int month) {
  if (month < 1 || month > 12) {
    throw ArgumentError('BS month must be 1..12, got $month.');
  }
  return bsMonthNamesEn[month - 1];
}

/// Devanagari name of BS month [month] (1-12).
String bsMonthNameNp(int month) {
  if (month < 1 || month > 12) {
    throw ArgumentError('BS month must be 1..12, got $month.');
  }
  return bsMonthNamesNp[month - 1];
}
