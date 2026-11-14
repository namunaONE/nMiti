import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:nepali_date/nepali_date.dart';
import 'package:nepali_date_data/nepali_date_data.dart';
import 'package:nepali_sankranti/nepali_sankranti.dart';
import 'package:nepali_panchang/nepali_panchang.dart';

// The site builder is one library split into part files, one per page
// family, so each file stays small and independently reviewable.
part 'build_site_json.dart';
part 'build_site_docs.dart';
part 'build_site_md.dart';
part 'build_site_astro.dart';
part 'build_site_festivals.dart';
part 'build_site_masa.dart';
part 'build_site_saait.dart';
part 'build_site_graha.dart';
part 'build_site_dasha.dart';

const _adMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _adMonthNamesNp = [
  'जनवरी', 'फेब्रुअरी', 'मार्च', 'अप्रिल', 'मे', 'जुन',
  'जुलाई', 'अगस्ट', 'सेप्टेम्बर', 'अक्टोबर', 'नोभेम्बर', 'डिसेम्बर',
];

const _gridHeadsNp = ['आइत', 'सोम', 'मङ्गल', 'बुध', 'बिही', 'शुक्र', 'शनि'];
const _gridHeadsEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
