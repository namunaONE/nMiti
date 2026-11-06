/// Published uncertainty (error bars) for the lunar engine's served
/// values (HYA-423). Every number the site and API serve carries an honest
/// band derived from recorded evidence - never an aspiration.
///
/// Three anchors:
/// - publisher parity: the locked receipt corpora (226 limb boundaries +
///   76 karana/sunrise receipts, BhaktiBharat + Hamro Patro, Oct-Nov 2026)
///   gate CI on every push, and the bands are honest ceilings over the
///   observed maxima;
/// - ephemeris parity: the Swiss-anchored tithi_engine oracle in CI (PR #30)
///   - all day-tithi labels agree, transition instants mean < 2 min;
/// - Swiss-truth scoreboard (HYA-369, PR #42, 2026-11-06; re-measured
///   post-R7a on merge ff8b3ae, CI #146): every CI run re-solves the
///   served window with Swiss Ephemeris (Moshier) - tithi and karana
///   boundaries mean 14.3 s max 26 s (the named Meeus Ch.47 truncation,
///   exposed once the pre-R7a Delta-T error stopped partially canceling
///   it), moonrise mean 0.2 s, sunrise mean 11.3 s max 12 s (UT-direct,
///   unchanged by R7a); the nakshatra/yoga deltas (~66/~111 s) are the
///   ayanamsa convention gap plus the -6.5 s R7a Delta-T wall-clock
///   shift, stated, not absorbed. The Swiss-vs-engine Delta-T residual
///   collapsed from ~6.6 s to mean -0.30 s max 0.31 s (n=233).
///
/// Publisher-vs-publisher divergence (BhaktiBharat and Hamro Patro agree
/// within 2-13 min on the same boundaries) is a measured fact about Nepali
/// publishing, not an engine error: stated, never absorbed.
///
/// Named systematic contributor: Meeus Ch.47 truncation (~10 arcsec moon
/// => ~20 s of boundary time).
///
/// Delta-T history: HYA-406 (2026-11-06) first adjudicated the
/// Espenak-Meeus gap (75.6 s vs observed ~69 s for 2026 => ~6.6 s of
/// boundary time) as KEEP. R7a (HYA-438) supersedes that adjudication:
/// the engine now serves the hybrid Delta-T channel - the
/// SMH2016/Morrison2021 spline before 1973, USNO observed monthly
/// through 2026-04, USNO quarterly predictions through 2033-10 and
/// Espenak-Meeus long-range beyond, joins declared not blended - which
/// closes the ~6.5 s systematic. Re-measured post-R7a (CI #146, merge
/// ff8b3ae): the Swiss-vs-engine Delta-T residual is mean -0.30 s max
/// 0.31 s (n=233); every TT limb band shifted by the -6.5 s Delta-T
/// wall-clock correction and stays inside its published ceiling -
/// tithi/karana 14.3 s mean, nakshatra 66.2 s, yoga 110.8 s, sunrise
/// 11.3 s unchanged. The bands above stay as published.

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
        'Swiss-truth scoreboard (PR #42, re-measured post-R7a): boundary '
        'instants mean 14.3 s, max 26 s (n=47) - the named Meeus Ch.47 '
        'truncation, exposed once the pre-R7a Delta-T error stopped '
        'partially canceling it.',
  ),
  UncertaintyBand(
    limb: 'nakshatra',
    plusMinusMinutes: 2.0,
    basis: 'Receipt corpus: typical <= 0.94 min, observed max 1.7 min near '
        'lunar perigee (Nov 2026); BhaktiBharat ayanamsa profile '
        '(delta -0.0795 deg). Published ceiling covers perigee days. '
        'Swiss-truth cross-check reads a near-constant ~66 s (n=45) - '
        'the ayanamsa convention gap vs Swiss Lahiri plus the -6.5 s '
        'R7a Delta-T wall-clock shift, stated not absorbed.',
  ),
  UncertaintyBand(
    limb: 'yoga',
    plusMinusMinutes: 2.0,
    basis: 'Receipt corpus: max ~0.97 min after the ayanamsa fit (both '
        'corpora); Hamro Patro divergence up to ~13 min is publisher data, '
        'not engine error. Swiss-truth cross-check reads a near-constant '
        '~111 s (n=48) - the ayanamsa convention gap vs Swiss Lahiri '
        'plus the -6.5 s R7a Delta-T wall-clock shift, stated not '
        'absorbed.',
  ),
  UncertaintyBand(
    limb: 'karana',
    plusMinusMinutes: 0,
    basis: 'Convention-anchored: 76/76 exact identity on the receipt corpus '
        'at the pinned reference moment (BhaktiBharat noon, Hamro Patro '
        'engine-sunrise udaya). The served value stays convention-exact; '
        'Swiss-truth boundary parity (PR #42, re-measured post-R7a): '
        'mean 14.3 s, max 26 s (n=93) - the named Meeus Ch.47 '
        'truncation, exposed once the pre-R7a Delta-T error stopped '
        'partially canceling it.',
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
        'Swiss-truth scoreboard (PR #42, re-measured post-R7a) reads '
        'mean 0.2 s, max 0 s (n=44) at the identical target.',
  ),
];
