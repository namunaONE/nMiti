# Design system changelog

All notable changes to the nMiti design system — tokens, the rulebook
(RULES.md), the content law (CONTENT.md), and documented patterns.
Format: Keep a Changelog. Versioning: SemVer.

The token file (tokens.css) ships with the M3 site work; its values are
governed by this changelog from now on.

## [0.2.0] - 2026-11-03

### Added
- tokens.css v0.2.0 shipped as `packages/nmiti_cli/design/tokens.css`,
  inlined into every page at build time; the site now runs on the system.
- Answer-first premium homepage: sticky header + nav, hero with kicker and
  the bilingual answers, boxed calendar lattice with per-cell Gregorian
  dates, weekend-red legend (ADR-0001), verification stat tiles, a
  machine-readable panel that now also links `llms.txt`, and a footer that
  names the one script the page ships and why.

### Fixed
- Dark-mode AA contrast: the old accent `#0a72c4` (3.73:1 on dark) is
  retired; pages now use the token accent `#2563eb` light (5.17:1) /
  `#60a5fa` dark (7.31:1).

### Changed
- The client-side guard now rewrites the calendar with markup identical
  to the build-time grid (Devanagari + Gregorian per cell, weekend red,
  boxed lattice), so a midnight correction is visually seamless.

## [0.1.0] - 2026-11-03

### Added
- The rulebook: usage, accessibility, content, change, governance, and
  documentation law (RULES.md).
- The bilingual content law (CONTENT.md).
- Governance: the solo model — PR checklist as review committee, ADR
  folder, SemVer + this changelog.
- WCAG 2.2 AA adopted as the written accessibility floor.
- Contrast contract established and verified:
  - accent blue #2563eb light (5.17:1 on white) / #60a5fa dark (7.31:1)
  - holiday red #dc2626 light (4.83:1 on white) / #f87171 dark (6.75:1)
  - blue-500 #3b82f6 (3.68:1 on white) banned for text in the light theme

### Decisions
- ADR-0001: आइतबार (Sunday) and शनिबार (Saturday) both render in holiday
  red — a deliberate, documented deviation from Nepali convention.

## [Unreleased]
- tokens.css lands with the M3 site work (accent, holiday, surface, type,
  space, motion tokens).
