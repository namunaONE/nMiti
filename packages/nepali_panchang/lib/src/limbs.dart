import 'ayanamsa.dart';
import 'moon.dart';
import 'sun.dart';

/// Lunar panchang limbs: angles, sector indices and canonical names
/// (R6a-1 step 3, HYA-403).
///
/// Conventions (validated against the Nov 2026 golden-fixture corpus;
/// frames made consistent by the R10.5 rung B frame audit, HYA-445):
///   tithi      = norm360(moon - separation sun), 12 deg sectors (30) -
///                the SEPARATION frame ([sunLongitudeForSeparationDeg]):
///                nutation cancels between the two bodies, each body's
///                light-time stays (the solar aberration). The former
///                convention subtracted the nutated apparent sun from
///                the geometric moon, rotating the sun alone by the
///                nutation (up to +-17.2 arcsec, ~16 s of boundary time
///                in late 2026) - the systematic the audit found;
///   nakshatra  = norm360(apparent moon - ayanamsa), 13 deg 20' sectors
///                (27) - the publishers' apparent-sidereal convention:
///                nutation applied to the moon like the sun;
///   yoga       = norm360((apparent moon - ayanamsa) + (apparent sun -
///                ayanamsa)), 27 sectors - the ayanamsa is subtracted from
///                EACH body, never once from the sum (a sum-only slip
///                shifts the chain +1.8 sectors and mislabels every
///                position while tithi/nakshatra still pass);
///   karana     = half-tithi, 6 deg sectors of the elongation, 1..60.

/// Sector span of the tithi limb, degrees.
const double tithiSpanDeg = 12.0;

/// Sector span of the nakshatra limb, degrees (360/27).
const double nakshatraSpanDeg = 360.0 / 27.0;

/// Sector span of the yoga limb, degrees (360/27).
const double yogaSpanDeg = 360.0 / 27.0;

/// Sector span of the karana limb, degrees (half a tithi).
const double karanaSpanDeg = 6.0;

/// Elongation moon minus sun in the separation frame, degrees in
/// [0, 360).
///
/// This is the tithi angle; karana uses the same angle with 6 deg
/// sectors. Both bodies sit in the mean-equinox-of-date frame with the
/// light-time terms kept and no nutation (a common rotation cancels in
/// a separation; the moon's ~0.7 arcsec light-time is a named skipped
/// contributor, see [sunLongitudeForSeparationDeg]).
double elongationDeg(double jdTt) {
  final moon = moonPosition(jdTt).longitudeDeg;
  return _norm360(moon - sunLongitudeForSeparationDeg(jdTt));
}

/// Apparent sidereal longitude of the moon at [jdTt], degrees in
/// [0, 360) - the publishers' convention: the nutation-corrected
/// (apparent) longitude minus the ayanamsa. The moon's own light-time
/// (~0.7 arcsec, ~1.4 s of boundary time) is a named skipped
/// contributor.
double moonSiderealDeg(double jdTt, double sourceDelta) {
  final moon =
      moonPosition(jdTt).longitudeDeg + nutationInLongitudeDeg(jdTt);
  return _norm360(moon - ayanamsaTotal(jdTt, sourceDelta));
}

/// Yoga angle at [jdTt], degrees in [0, 360).
///
/// Both bodies apparent-sidereal (each minus the ayanamsa); the moon
/// side carries the nutation like the sun side since the R10.5 rung B
/// frame audit.
double yogaSiderealDeg(double jdTt, double sourceDelta) {
  final ay = ayanamsaTotal(jdTt, sourceDelta);
  final moon = _norm360(moonPosition(jdTt).longitudeDeg +
      nutationInLongitudeDeg(jdTt) -
      ay);
  final sun = _norm360(sunApparentLongitude(jdTt) - ay);
  return _norm360(moon + sun);
}

/// Angle of [limb] ('tithi', 'nakshatra', 'yoga' or 'karana') at [jdTt].
double limbAngle(String limb, double jdTt, double sourceDelta) {
  switch (limb) {
    case 'tithi':
    case 'karana':
      return elongationDeg(jdTt);
    case 'nakshatra':
      return moonSiderealDeg(jdTt, sourceDelta);
    case 'yoga':
      return yogaSiderealDeg(jdTt, sourceDelta);
    default:
      throw ArgumentError('unknown limb: $limb');
  }
}

/// Sector span of [limb] in degrees.
double limbSpanDeg(String limb) {
  switch (limb) {
    case 'tithi':
      return tithiSpanDeg;
    case 'nakshatra':
      return nakshatraSpanDeg;
    case 'yoga':
      return yogaSpanDeg;
    case 'karana':
      return karanaSpanDeg;
    default:
      throw ArgumentError('unknown limb: $limb');
  }
}

/// Sector index of [limb] at [jdTt]: tithi 0..29, nakshatra/yoga 0..26.
/// For karana this is the karana number minus one, 0..59.
int limbIndex(String limb, double jdTt, double sourceDelta) {
  return (limbAngle(limb, jdTt, sourceDelta) / limbSpanDeg(limb)).floor();
}

/// The 27 nakshatra names in sector order from Ashwini.
const List<String> nakshatraNames = [
  'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra',
  'Punarvasu', 'Pushya', 'Ashlesha', 'Magha', 'Purva Phalguni',
  'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha',
  'Jyeshtha', 'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana',
  'Dhanishta', 'Shatabhisha', 'Purva Bhadrapada', 'Uttara Bhadrapada',
  'Revati',
];

/// The 27 yoga names in sector order from Vishkambha.
const List<String> yogaNames = [
  'Vishkambha', 'Priti', 'Ayushman', 'Saubhagya', 'Shobhana', 'Atiganda',
  'Sukarma', 'Dhriti', 'Shula', 'Ganda', 'Vriddhi', 'Dhruva', 'Vyaghata',
  'Harshana', 'Vajra', 'Siddhi', 'Vyatipata', 'Variyana', 'Parigha',
  'Shiva', 'Siddha', 'Sadhya', 'Shubha', 'Shukla', 'Brahma', 'Indra',
  'Vaidhriti',
];

const List<String> _tithiBaseNames = [
  'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', 'Shashthi',
  'Saptami', 'Ashtami', 'Navami', 'Dashami', 'Ekadashi', 'Dwadashi',
  'Trayodashi', 'Chaturdashi',
];

/// Canonical tithi name for index 0..29, e.g. 'Shukla Pratipada',
/// 'Purnima', 'Krishna Chaturthi', 'Amavasya'.
String tithiName(int index) {
  if (index == 14) return 'Purnima';
  if (index == 29) return 'Amavasya';
  final paksha = index < 15 ? 'Shukla' : 'Krishna';
  return '$paksha ${_tithiBaseNames[index % 15]}';
}

/// Inverse of [tithiName]: index 0..29 for a canonical tithi name.
/// Returns -1 when [name] is not a canonical tithi name.
int tithiIndexFromName(String name) {
  for (var i = 0; i < 30; i++) {
    if (tithiName(i) == name) return i;
  }
  return -1;
}

/// Karana number 1..60 at [jdTt]: floor(elongation / 6) + 1.
int karanaNumber(double jdTt) {
  return (elongationDeg(jdTt) / karanaSpanDeg).floor() + 1;
}

const List<String> _movableKaranaNames = [
  'Bava', 'Balava', 'Kaulava', 'Taitila', 'Garaja', 'Vanija', 'Vishti',
];

/// Canonical karana name for karana number [n] in 1..60: Kimstughna opens
/// the lunar month, the seven movable karanas cycle eight times, and
/// Shakuni, Chatushpada and Naga close it.
String karanaName(int n) {
  if (n < 1 || n > 60) {
    throw ArgumentError('karana number out of range: $n');
  }
  if (n == 1) return 'Kimstughna';
  if (n == 58) return 'Shakuni';
  if (n == 59) return 'Chatushpada';
  if (n == 60) return 'Naga';
  return _movableKaranaNames[(n - 2) % 7];
}

double _norm360(double deg) => deg % 360.0;
