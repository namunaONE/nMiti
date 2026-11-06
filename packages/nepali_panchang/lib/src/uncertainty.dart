/// Published uncertainty (error bars) for the lunar engine's served
/// values (HYA-423). Every number the site and API serve carries an honest
/// band derived from recorded evidence - never an aspiration.
///
/// Two anchors:
/// - publisher parity: the locked receipt corpora (226 limb boundaries +
///   76 karana/sunrise receipts, BhaktiBharat + Hamro Patro, Oct-Nov 2026)
///   gate CI on every push, and the bands are honest ceilings over the
///   observed maxima;
/// - ephemeris parity: the Swiss-anchored tithi_engine oracle in CI (PR #30)
///   - all day-tithi labels agree, transition instants mean < 2 min;
/// - Swiss-truth scoreboard (HYA-369, PR #42, 2026-11-06): every CI run
///   re-solves the served window with Swiss Ephemeris (Moshier) - tithi
///   and karana boundaries mean 7.9 s max 19 s, moonrise mean 0.3 s max
///   1 s, sunrise mean 11.3 s max 12 s; the nakshatra/yoga deltas (~60/
///   ~104 s) are the ayanamsa convention gap, stated, not absorbed.
///
/// Publisher-vs-publisher divergence (BhaktiBharat and Hamro Patro agree
/// within 2-13 min on the same boundaries) is a measured fact about Nepali
/// publishing, not an engine error: stated, never absorbed.
///
/// Named systematic contributors: the Delta-T source gap (Espenak-Meeus
/// 75.6 s vs observed ~69 s for 2026 => ~6.6 s of boundary time) and Meeus
/// Ch.47 truncation (~10 arcsec moon => ~20 s of boundary time).

/// One published uncertainty band.
class UncertaintyBand {
  /// 'tithi', 'nakshatra', 'yoga', 'karana', 'sunrise' or 'moonrise'.
  final String limb;

  /// Honest ceiling of |engine - reference| in clock minutes. Karana is
  /// convention-anchored (exact identity at the pinned reference moment),
  /// so its band is 0.
  final double plusMinusMinutes;

  /// Human-readable basis: where this number comes from.
  final String basis;

  const UncertaintyBand({
    required this.limb,
    required this.plusMinusMinutes,
    required this.basis,
  });
}

/// The published bands (BhaktiBharat-profile anchor, the corpus profile
/// with the tightest calibration bands). Documented in docs/methodology.md;
/// the CI test guards that these values stay honest ceilings over the
/// recorded scoreboards.
const List<UncertaintyBand> publishedErrorBars = [
  UncertaintyBand(
    limb: 'tithi',
    plusMinusMinutes: 1.5,
    basis: 'Receipt corpus: |engine - BhaktiBharat| max ~1.0 min (226 '
        'boundaries, Oct-Nov 2026); Swiss-anchored tithi_engine oracle '
        '(PR #30): all day labels agree, transitions mean < 2 min; '
        'Swiss-truth scoreboard (PR #42): boundary instants mean 7.9 s, '
        'max 19 s (n=47).',
  ),
  UncertaintyBand(
    limb: 'nakshatra',
    plusMinusMinutes: 2.0,
    basis: 'Receipt corpus: typical <= 0.94 min, observed max 1.7 min near '
        'lunar perigee (Nov 2026); BhaktiBharat ayanamsa profile '
        '(delta -0.0795 deg). Published ceiling covers perigee days. '
        'Swiss-truth cross-check reads a near-constant ~60 s (n=45) - '
        'the ayanamsa convention gap vs Swiss Lahiri, stated not '
        'absorbed.',
  ),
  UncertaintyBand(
    limb: 'yoga',
    plusMinusMinutes: 2.0,
    basis: 'Receipt corpus: max ~0.97 min after the ayanamsa fit (both '
        'corpora); Hamro Patro divergence up to ~13 min is publisher data, '
        'not engine error. Swiss-truth cross-check reads a near-constant '
        '~104 s (n=48) - the ayanamsa convention gap vs Swiss Lahiri, '
        'stated not absorbed.',
  ),
  UncertaintyBand(
    limb: 'karana',
    plusMinusMinutes: 0,
    basis: 'Convention-anchored: 76/76 exact identity on the receipt corpus '
        'at the pinned reference moment (BhaktiBharat noon, Hamro Patro '
        'engine-sunrise udaya). The served value stays convention-exact; '
        'Swiss-truth boundary parity (PR #42): mean 7.9 s, max 19 s '
        '(n=93).',
  ),
  UncertaintyBand(
    limb: 'sunrise',
    plusMinusMinutes: 1.0,
    basis: 'Geometric solver: within ~1 min of the NOAA-style rise time for '
        'Kathmandu. BhaktiBharat prints sunrise ~4.5 min later than the '
        'geometric time (constant convention, range 3.5-4.6 min) - a '
        'convention offset we expose, not an error band. Swiss-truth '
        'scoreboard (PR #42): mean +11.3 s, max 12 s (n=45) at the same '
        '-0.8333 deg geometric target.',
  ),
  UncertaintyBand(
    limb: 'moonrise',
    plusMinusMinutes: 12.0,
    basis: 'PROVISIONAL (HYA-417): JPL Horizons topocentric rise receipts '
        'vs the served Meeus 15.1 geocentric target observed up to '
        '~12 min - a rise-convention gap, not an ephemeris gap: the '
        'Swiss-truth scoreboard (PR #42) reads mean 0.3 s, max 1 s '
        '(n=44) at the identical target.',
  ),
];
