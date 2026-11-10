import 'package:nepali_panchang/nepali_panchang.dart';
import 'package:test/test.dart';

/// HYA-369: the receipts-measured Swiss-Lahiri reference line of the
/// engine ayanamsa module - convention/display surface only. Pins the
/// constants, the J2000 anchor, the drift, the two-route measured
/// window-mid offset (+28.607 arcsec at JD_TT 2461352.5008, bracketed
/// by the nakshatra +28.37 arcsec and yoga +28.84 arcsec routes), and
/// that NO served value changes on its account (the base and the
/// per-source profiles stay).
void main() {
  test('reference constants are pinned', () {
    expect(ayanamsaSwissLahiriReferenceJ2000, closeTo(23.85709, 1e-9));
    expect(ayanamsaSwissLahiriReferenceRatePerCy,
        closeTo(1.398024, 1e-9));
  });

  test('J2000 anchor', () {
    expect(
        ayanamsaSwissLahiriReference(2451545.0), closeTo(23.85709, 1e-12));
  });

  test('drift is the general-precession class, ~50.329 arcsec/year', () {
    final perYear =
        ayanamsaSwissLahiriReferenceRatePerCy / 100.0 * 3600.0;
    expect(perYear, closeTo(50.329, 0.0005));
  });

  test('base sits +28.607 arcsec from the reference at the fit epoch '
      '(two-route measured: +28.37 nakshatra / +28.84 yoga)', () {
    final jdMidTt = 2461352.5 + 69.112 / 86400.0;
    final off = (ayanamsaBase(jdMidTt) -
            ayanamsaSwissLahiriReference(jdMidTt)) *
        3600.0;
    expect(off, closeTo(28.607, 0.01));
  });

  test('no served value changes: the base and profiles stay', () {
    expect(ayanamsaDeltaBhaktiBharat, closeTo(-0.0795, 1e-9));
    expect(ayanamsaDeltaHamroPatro, closeTo(-0.0117, 1e-9));
    // The reference line is never added into ayanamsaTotal.
    final jd = 2461352.5;
    expect(ayanamsaTotal(jd, 0.0), ayanamsaBase(jd));
  });
}
