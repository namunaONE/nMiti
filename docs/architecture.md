# nMiti architecture — decisions from day one

This document records the bottlenecks of Flutter and Dart that apply to this
project, and the rules we follow to avoid them from the beginning.

## The bottlenecks, and our rules

**1. Flutter Web renders to a canvas, not to HTML.**
Content drawn by CanvasKit/skwasm is invisible to search engines and AI
crawlers, payloads reach 1.5-2.5 MB, first paint is slow, accessibility and
text selection are weak. This would kill the AEO/GEO strategy (being the
source AI models cite for today's Nepali date).
Rule: Flutter never touches the website. The website is pre-rendered
semantic HTML. Flutter is only for the patro app (mobile/desktop) later.

**2. dart2js / wasm output is large even for small interactivity.**
Rule: zero client-side JavaScript on content pages. Every page must carry
its full answer in the HTML itself. Interactive islands (converter) come
later as a separate, deferred component - measured before shipping.

**3. build_runner / codegen tax.**
Rule: zero code generation. Data is embedded as const strings; there is no
json_serializable, no freezed, no build_runner in CI. This keeps CI fast and
removes stale-generated-code bugs entirely.

**4. dart:io coupling.**
Rule: the core engine (packages/nepali_date) is pure Dart with zero
third-party dependencies. It runs on the command line, on a server, inside
Flutter, and compiled to JS/WASM for the browser, unchanged.

**5. Server-side Dart cold start.**
Rule: static-first. Everything that can be pre-computed is pre-computed.
GitHub Pages serves static files; there is no runtime to start. A hosted
API (if ever needed) is earned by traffic, not assumed.

**6. Data staleness — the 1 bug class that plagues Nepali date sites.**
Two live sites were found running corrupted BS tables in the R12 crawl.
Rules: (a) one canonical dataset; (b) every invariant checked in CI before
anything ships; (c) the site is rebuilt from data daily at 00:00 Nepal
Time; (d) projections are labeled, never presented as verified; (e) the
known BS 2096 upstream defect is preserved and labeled, not silently fixed.

## GitHub Pages constraints (and how we design around them)

- Static-only: no runtime server. "Server rendering" here means build-time
  pre-rendering, which delivers the same benefit (crawlable HTML) with
  better performance.
- The Site workflow rebuilds every 6 hours (00:15/06:15/12:15/18:15 UTC
  = 00:00/06:00/12:00/18:00 NPT approximately). The 18:15 UTC run lands
  exactly on 00:00 NPT, so the new day is published at midnight.
- No custom headers: we cannot set Cache-Control; GitHub's CDN handles
  caching. Static JSON makes that safe.
- Base path is /nMiti/ until a custom domain exists: all canonical URLs
  use the full GitHub Pages URL; internal links are relative.
- A .nojekyll file is published so GitHub Pages serves files as-is.

## Package naming (SEO/AEO/GEO)

The pub.dev package is named **nepali_date** — verified unclaimed on
pub.dev on 2026-11-02. It is the exact head term users and AI models use
for this category; the package name is lifted verbatim by answer engines.
The brand/project remains nMiti. The dataset remains neutral CC0 data.

## Distribution strategy (beyond Dart)

- Tier 1: pub.dev package (nepali_date) — source of truth.
- Tier 2: WASM bridge to npm (Dart compiles to wasm; tools such as
  medz/napi generate npm packages with TypeScript bindings from Dart).
  The same wasm binary serves Python/Java/Go via Wasmtime.
- Tier 3 (only if a hard native .so/.dll requirement appears): a tiny
  Rust/C core with WeaveFFI-generated bindings. Dart cannot export a C
  ABI (no @ffi.Export), so this is the only honest path.
- Prior art: the npdatetime Rust crate (Python/Django/JS-WASM bindings).

## Performance discipline

- Zero third-party runtime dependencies in all packages.
- Zero client JS on content pages; Lighthouse targets: 100 performance,
  100 accessibility, 100 SEO.
- .pubignore and a publish dry-run size gate before any pub.dev release.
- Every interactive addition must ship a size budget measured in CI.

## Design system

The UI follows a written rulebook, not taste: docs/design-system/RULES.md.
Design inherits the same discipline as code: tokens are the only source of
visual values, WCAG 2.2 AA is the accessibility floor, every design change
ships through the PR checklist in the rulebook, and token changes follow
SemVer with a changelog (docs/design-system/CHANGELOG.md). Deliberate
deviations are recorded as ADRs (docs/design-system/adr/) — never made
silently.
