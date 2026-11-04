/// Evidence tiers for nMiti BS calendar rows (tag vocabulary: data/README.md).
///
/// The tier is derived deterministically from the row's evidence tags so that
/// every surface (SDK, site, API, apps) reports the same honesty for the same
/// row. Surfaces never re-derive tiers from year numbers.
enum BsEvidenceTier {
  /// Machine-verified core row (tag `r12-verified`), or the officially
  /// anchored tail start (tag `official-anchor`).
  verified,

  /// Engine-computed projection row (tag `projection`); month starts carry a
  /// declared +/-1 day uncertainty and must never be presented as fact.
  projection,

  /// Labeled upstream defect inside the projection tail (BS 2096, tag
  /// `projection-defect`); preserved and surfaced, never silently fixed.
  projectionDefect,

  /// The tags were not recognized. Never guessed upward: surfaces must treat
  /// unknown as "no claim" and show the raw tags.
  unknown,
}

/// The evidence answer for one BS year: its derived [tier] plus the raw,
/// comma-separated tags verbatim from the canonical CSV row.
class BsEvidence {
  /// The derived evidence tier.
  final BsEvidenceTier tier;

  /// The raw comma-separated evidence tags, verbatim from the row.
  final String tags;

  const BsEvidence._(this.tier, this.tags);

  /// Derives the tier from raw comma-separated tags. Deterministic and never
  /// guessed upward: unrecognized tags yield [BsEvidenceTier.unknown].
  factory BsEvidence.fromTags(String tags) {
    final t = tags.trim().toLowerCase();
    if (t.contains('projection-defect')) {
      return BsEvidence._(BsEvidenceTier.projectionDefect, tags);
    }
    if (t.contains('projection')) {
      return BsEvidence._(BsEvidenceTier.projection, tags);
    }
    if (t.contains('r12-verified') || t.contains('official-anchor')) {
      return BsEvidence._(BsEvidenceTier.verified, tags);
    }
    return BsEvidence._(BsEvidenceTier.unknown, tags);
  }

  /// Whether the raw tags include [tag] (case-insensitive, trimmed).
  bool hasTag(String tag) => tags
      .toLowerCase()
      .split(',')
      .map((s) => s.trim())
      .contains(tag.toLowerCase());

  @override
  String toString() => 'BsEvidence(${tier.name}: $tags)';
}
