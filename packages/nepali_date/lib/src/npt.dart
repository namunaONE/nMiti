/// Nepal Time (NPT) helpers.
///
/// Nepal Standard Time is a fixed UTC+05:45 offset - no daylight saving,
/// ever. That makes "today in Nepal" a pure function of the instant: the
/// Bikram Sambat day rolls over at Nepal midnight, 18:15:00 UTC, every
/// day of every year.

/// Fixed offset of Nepal Time from UTC: +05:45.
const Duration nepalTimeOffset = Duration(hours: 5, minutes: 45);

/// The calendar date it currently is in Nepal: a date-only UTC [DateTime]
/// whose year/month/day are the Nepal Time wall date at [nowUtc] (or now,
/// if omitted). nMiti's "today" is always this value - never the build
/// machine's local date, and never UTC alone: at 18:15:00 UTC it is
/// already the next day in Nepal.
DateTime todayInNepalTime({DateTime? nowUtc}) {
  final shifted = (nowUtc ?? DateTime.now()).toUtc().add(nepalTimeOffset);
  return DateTime.utc(shifted.year, shifted.month, shifted.day);
}
