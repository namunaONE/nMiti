/// Open, verified sidereal solar ingress (sankranti) engine.
///
/// Pure Dart: no dart:io, no web imports, no third-party dependencies
/// beyond [nepali_date] for the fixed Nepal Time offset. Reproduces the
/// nMiti Commons Layer 1 sankranti-moments artifact (BS 1975-2083, and
/// the extended 1975-2100 dataset).
library;

export 'src/ayanamsa.dart';
export 'src/ingress.dart';
export 'src/julian.dart';
export 'src/moments.dart';
export 'src/solar.dart';
