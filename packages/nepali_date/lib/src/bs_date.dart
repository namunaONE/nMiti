/// A date in the Bikram Sambat (BS) calendar.
///
/// Months are 1-12 (Baisakh..Chaitra). Values are not range-checked here;
/// the [BsCalendar] a date is used with performs validation.
class BsDate implements Comparable<BsDate> {
  final int year;
  final int month;
  final int day;

  const BsDate(this.year, this.month, this.day);

  int get _key => (year * 12 + (month - 1)) * 32 + day;

  @override
  int compareTo(BsDate other) => _key.compareTo(other._key);

  @override
  bool operator ==(Object other) => other is BsDate && _key == other._key;

  @override
  int get hashCode => _key;

  @override
  String toString() =>
      '$year-${_pad2(month)}-${_pad2(day)}';
}

String _pad2(int value) => value < 10 ? '0$value' : '$value';
