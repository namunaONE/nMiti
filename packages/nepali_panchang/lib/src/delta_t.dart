/// Delta T = TT - UT in seconds for a civil date, Espenak-Meeus polynomials.
///
/// Source: F. Espenak, "Polynomial Expressions for Delta T" (NASA, 2004),
/// fitting the Morrison & Stephenson (2004) values. Following the source, the
/// fractional year is taken at the middle of [month] (1-12). Valid for AD
/// 1600 through AD 2150 - nMiti's BS 1975-2100+ range (AD 1918-2044) is well
/// inside; earlier or later dates throw an [ArgumentError] because the
/// polynomials are not defined there.
double deltaTSeconds(int year, int month) {
  final y = year + (month - 0.5) / 12.0;
  if (y < 1600 || y >= 2150) {
    throw ArgumentError('deltaTSeconds: year $year is outside AD 1600-2150');
  }
  if (y < 1700) {
    final u = y - 1600;
    return 120 - 0.9808 * u - 0.01532 * u * u + u * u * u / 7129;
  }
  if (y < 1800) {
    final u = y - 1700;
    return 8.83 +
        0.1603 * u -
        0.0059285 * u * u +
        0.00013336 * u * u * u -
        u * u * u * u / 1174000;
  }
  if (y < 1860) {
    final u = y - 1800;
    return 13.72 -
        0.332447 * u +
        0.0068612 * u * u +
        0.0041116 * u * u * u -
        0.00037436 * u * u * u * u;
  }
  if (y < 1900) {
    final u = y - 1860;
    return 7.62 + 0.5737 * u - 0.251754 * u * u + 0.01680668 * u * u * u;
  }
  if (y < 1920) {
    final u = y - 1900;
    return -2.79 +
        1.494119 * u -
        0.0598939 * u * u +
        0.0061966 * u * u * u -
        0.000197 * u * u * u * u;
  }
  if (y < 1941) {
    final u = y - 1920;
    return 21.20 + 0.84493 * u - 0.076100 * u * u + 0.0020936 * u * u * u;
  }
  if (y < 1961) {
    final u = y - 1950;
    return 29.07 + 0.407 * u - u * u / 233 + u * u * u / 2547;
  }
  if (y < 1986) {
    final u = y - 1975;
    return 45.45 + 1.067 * u - u * u / 260 - u * u * u / 718;
  }
  if (y < 2005) {
    final u = y - 2000;
    final u2 = u * u;
    final u3 = u2 * u;
    final u4 = u2 * u2;
    final u5 = u4 * u;
    return 63.86 +
        0.3345 * u -
        0.060374 * u2 +
        0.0017275 * u3 +
        0.000651814 * u4 +
        0.00002373599 * u5;
  }
  if (y < 2050) {
    final u = y - 2000;
    return 62.92 + 0.32217 * u + 0.005589 * u * u;
  }
  final u = (y - 1820) / 100.0;
  return -20 + 32 * u * u - 0.5628 * (2150 - y);
}
