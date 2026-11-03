/// Open, verified sidereal solar ingress (sankranti) engine.
///
/// Pure Dart: no dart:io, no web imports, no third-party dependencies
/// beyond [nepali_date] for the fixed Nepal Time offset. Reproduces the
/// nMiti Commons Layer 1 sankranti-moments artifact (BS 1975-2083),
/// generates the extended 1975-2100 dataset, and enforces the sankranti
/// window law (HYA-358) over the canonical calendar.
library;

export 'src/ayanamsa.dart';
export 'src/ingress.dart';
export 'src/julian.dart';
export 'src/moments.dart';
export 'src/solar.dart';
export 'src/table.dart';
export 'src/window.dart';
