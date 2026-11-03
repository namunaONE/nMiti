import 'julian.dart';
import 'solar.dart';

/// Lahiri-family ayanamsa of the Commons Layer 1 artifact, calibrated by
/// the R5 experiment against 48 drikpanchang sidereal ingress moments
/// from 2025-2028. These constants ARE the artifact's definition:
/// changing them requires refitting against the 1,308 published moments
/// and republishing the dataset.
double ayanamsa(double jd) => 23.87508 + 1.36062 * julianCenturies(jd);

/// Apparent sidereal solar longitude in degrees, wrapped to [0, 360):
/// the tropical apparent longitude minus the ayanamsa.
double siderealSolarLongitude(double jd) {
  final tropical = apparentSolarLongitude(julianCenturies(jd));
  final value = (tropical - ayanamsa(jd)) % 360.0;
  return value < 0.0 ? value + 360.0 : value;
}
