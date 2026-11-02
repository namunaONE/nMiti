import 'package:nepali_date/nepali_date.dart';

import 'src/calendar_bs_core.dart';
import 'src/calendar_bs_tail.dart';

export 'src/calendar_bs_core.dart' show calendarBsCoreCsv;
export 'src/calendar_bs_tail.dart' show calendarBsTailCsv;

/// The verified core table (BS 1975-2083, R12 cross-validation).
final BsCalendar coreCalendar = BsCalendar.fromCsv(calendarBsCoreCsv);

/// The labeled projection tail (BS 2084-2100).
/// Only Baisakh 1 2084 (Wed 2027-04-14) is officially anchored.
final BsCalendar tailCalendar = BsCalendar.fromCsv(calendarBsTailCsv);

/// Combined lookup spanning BS 1975-2100 (verified core + labeled projection).
final BsCalendar fullCalendar = BsCalendar([...coreCalendar.rows, ...tailCalendar.rows]);
