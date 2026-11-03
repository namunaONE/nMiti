# nMiti Design System — the Rulebook

Design inherits the same discipline as code. This file is the law the UI
follows; it is written for a stranger (or future you) who has never heard
the reasoning. If taste conflicts with a rule here, the rule wins until
this file is changed.

Scope: the nMiti site UI today (nmiti_cli-generated static HTML) and the
patro app later. Everything a user can see on screen is in scope.

Laws are written RFC-style: MUST / MUST NOT / SHOULD / MAY.

## The six laws at a glance

| # | Law | Governs |
| - | --- | ------- |
| 0 | Foundations | architecture rules that bind design |
| 1 | Usage | tokens, patterns, do / don't |
| 2 | Accessibility | WCAG 2.2 AA floor, contrast contract |
| 3 | Content | bilingual wording, numerals, terminology |
| 4 | Change | SemVer, changelog, migration notes |
| 5 | Governance | PR checklist, ADRs, deviations |
| 6 | Documentation | pattern entries, docs images |

## 0. Foundations — architecture rules that bind design

From docs/architecture.md, with their design consequences:

| Architecture rule | Design consequence |
| ----------------- | ------------------- |
| Flutter never touches the website | Design targets semantic HTML + CSS. No component needs a JS runtime to render. |
| Zero client JS on content pages | Interactivity = links, `<details>`, forms. Motion is CSS-only. Anything a user can do MUST work without JS. |
| Zero codegen | Tokens are hand-authored CSS custom properties in one file (`tokens.css`, shipping with the M3 site work). |
| Static-first | Light and dark themes are both pre-computed; theme switching is `prefers-color-scheme` only. No runtime theme machinery. |
| Lighthouse 100/100/100 | Performance is a design constraint: CI size budgets apply to CSS bytes too. |
| One canonical dataset | No hand-typed dates, ever. Calendar UI renders from the dataset or not at all. |

## 1. Usage law — tokens, patterns, do / don't

### Tokens
- All color, spacing, and type-scale values MUST come from the token
  file. No hard-coded hex, rgb(), or magic px values outside `tokens.css`
  (exceptions: the token file itself, and test fixtures).
- Token names are namespaced `--nm-**`: global tiers first (color, space,
  type, motion), component tokens after. New tokens follow this naming
  before they ship.
- The calendar card MUST use container queries, not viewport media
  queries: a card's layout answers its container, not the window.
- Body text uses the fluid clamp() type scale. Fixed px font sizes MUST
  NOT be used for content text.

### The lattice (calendar grid)
- Cell borders follow the single-rule lattice: the grid draws top + left
  borders, cells draw right + bottom. Doubled borders are a defect.

### Do / Don't — the core examples

| Do | Don't |
| -- | ----- |
| Mark holidays with `--holiday` red AND a text label | Mark holidays with color alone (color-blind users cannot differentiate) |
| `tabular-nums` for all date numerals in tables and grids | proportional figures in tabular data |
| Devanagari numerals on Nepali UI, Latin numerals on English UI | mixing scripts inside one value |
| One border rule per edge (single-rule lattice) | naive `border` on both grid and cell producing doubled lines |
| Honor `prefers-reduced-motion` with a static fallback | infinite or purely decorative animation |

### Motion
- Motion budget: 100–500 ms across three tiers (enter / exit / ambient).
- Motion MUST be CSS-only on the site.

## 2. Accessibility law — WCAG 2.2 AA is the floor

The floor is WCAG 2.2 AA (W3C Recommendation since 2023-10-05: nine new
success criteria; SC 4.1.1 Parsing is deprecated — stop auditing for it).

Binding criteria, checked per change:

| SC | Rule | Where it bites nMiti |
| -- | ---- | -------------------- |
| 2.5.8 Target Size (AA) | interactive targets at least 24×24 CSS px | calendar day cells at the smallest breakpoint |
| 2.4.11 Focus Not Obscured (AA) | focus never hidden behind sticky UI | sticky month/year headers over the grid |
| 3.2.6 Consistent Help (A) | help link in the same place on every page | site-wide footer/nav |
| 3.3.7 Redundant Entry (A) | never re-ask information already given | the converter flow (M3) |
| 1.4.3 / 1.4.11 Contrast | text 4.5:1, UI components 3:1 | every token pairing |

### The contrast contract (verified values)

Any change to these values MUST re-verify the ratio and record it in
CHANGELOG.md. Ratios are against white (light theme) and the dark theme
card surface.

| Token | Light | Ratio | Dark | Ratio |
| ----- | ----- | ----- | ---- | ----- |
| Accent (blue) | #2563eb | 5.17:1 | #60a5fa | 7.31:1 |
| Holiday (red) | #dc2626 | 4.83:1 | #f87171 | 6.75:1 |

- blue-500 (#3b82f6) at 3.68:1 on white FAILS AA: it MUST NOT carry text
  or meaningful icons in the light theme.
- Overlapping states (holiday AND weekend) MUST differ by more than
  color: weight, label, or badge.

### Semantics first
- Semantic HTML is the default; ARIA only where HTML cannot express it.
- When interactive islands ship, keyboard behavior follows the W3C ARIA
  Authoring Practices Guide pattern for that widget.
- An image of text MUST NOT carry information unavailable as real text
  on the same page.

## 3. Content law — the interface's grammar

Full text: docs/design-system/CONTENT.md. The short version:

- Sentence-style capitalization for headings, labels, buttons (English).
- Nepali UI text in Devanagari, English UI text in Latin — never mixed
  inside one value.
- Month and festival romanization follows the SDK (`bsMonthNameEn` is
  the source of truth; variants are banned).
- Projections are labeled, never presented as verified.

## 4. Change law — SemVer

The design system (tokens + documented patterns + this rulebook) is
versioned:

- MAJOR — a token is renamed or removed; a documented pattern changes in
  a way consumers must migrate for; any accessibility downgrade (never
  allowed — revert instead).
- MINOR — a new token or pattern, documented.
- PATCH — a value adjustment that keeps AA contrast and visual intent.

Every design PR MUST include a CHANGELOG.md entry. A breaking change
without a migration note is not a release, it is an ambush.

## 5. Governance law — the solo model

nMiti is a one-maintainer, grassroots system (Sparkbox stage 1 → 2). The
governance model is shrunk, not skipped:

- Every design change ships as a PR satisfying the checklist below. The
  checklist is the review committee.
- A decision that bends a rule MUST be recorded as an ADR in
  docs/design-system/adr/. Documented deviations are allowed; silent ones
  are not.
- Multi-team governance, contribution boards, adoption dashboards are
  deliberately deferred until a second contributor exists.

### The PR checklist (copy into every design PR)

- [ ] No hard-coded colors/spacing/type outside the token file
- [ ] Every page or pattern citing a changed token updated in the same PR
- [ ] CHANGELOG.md entry included
- [ ] Contrast contract (§2) still holds — ratios re-verified if colors moved
- [ ] WCAG 2.2 AA criteria in §2 checked for the touched UI
- [ ] No new client-side JavaScript
- [ ] Lighthouse / size budgets still green in CI
- [ ] Any rule broken? ADR written — or the change reverted

## 6. Documentation law — the system's constitution

Every documented pattern (starting with the calendar card, the
highest-traffic component) follows this entry anatomy on /docs:

1. What it is (one line)
2. When to use / when not to use
3. Do / Don't examples
4. Tokens referenced
5. Code snippet — the real HTML/CSS, not a paraphrase
6. Accessibility requirements specific to the pattern

Docs images: SVG for diagrams and line art; PNG only for raster evidence
and never carrying text-only information; GIF only for motion examples.
Image sizes: 290 (half), 604 (full), 894 (wide).

Docs are versioned with the system and covered by the same changelog.

## 7. Maturity — honest scope

Stage 1 (Building Version One) completes when tokens.css ships with the
M3 site; stage 2 (Growing Adoption) begins when /today, /converter, /data
and /docs all consume the same tokens. Deliberately NOT built now:
contribution review boards, adoption dashboards, multi-brand theming.
Deferred is not forgotten — revisit at the first second contributor.
