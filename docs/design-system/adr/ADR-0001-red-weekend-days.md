# ADR-0001: आइतबार and शनिबार both render in holiday red

- Status: Accepted (2026-11-03)
- Rules affected: RULES.md §1 (holiday marking), §2 (contrast contract)

## Context

Nepali convention marks Saturday (शनिबार) as the weekly holiday; the
original design followed that convention. The product owner requested
Sunday (आइतबार) marked in holiday red as well, for audiences who read both
Sunday and Saturday as rest days.

## Decision

Both आइतबार and शनिबार — the weekday headers and their day cells — render
in the `--holiday` red token (light #dc2626, dark #f87171), alongside —
never instead of — a text label.

## Consequences

- Positive: diaspora and international users read both rest days at a
  glance; the request is honored visibly.
- Negative: deviates from the convention a Nepali audience expects
  (Saturday only) on Nepali-locale pages.
- Revisit if Nepali-locale users report confusion. Alternatives
  considered: Saturday-only (convention), a second shade for Sunday
  (rejected — extra token complexity and another contrast pair to verify).
