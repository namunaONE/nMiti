# Reliability: defense in depth for main

Layered defense, ordered pre-merge to post-deploy recovery. No single layer
is trusted alone; each catches what the previous one missed. For a date
site, doctrine is **wrongness is worse than downtime**: a plausible wrong
date destroys trust permanently; a 404 costs one visit.

## Layer map (what exists today vs what is phased)

| Layer | Catches | Status |
|---|---|---|
| 1. Branch protection | direct pushes, unapproved merges | runbook below (manual, one-time) |
| 2. Merge queue | concurrent-PR conflicts | CI already handles merge_group; enable queue when bot PRs begin |
| 3. Fail-closed generators | invalid data reaching any artifact | done (invariants + drift check refuse to build) |
| 4. External retries | transient crawl/API failures | applies to the future consensus bot (M1) |
| 5. Environments + approvals | irregular deploys reaching prod | NOT for the static pipeline (freshness wins); for future api/mcp services |
| 6. Post-deploy smoke test | build-succeeded-but-output-wrong | done (N-version, in pages.yml) |
| 7. Auto-revert + alert | the one that got through | done (alert-first; revert PR for push failures) |
| 8. Supply chain pinning | silent action/SDK changes | done (all actions pinned to commit SHAs, Dart 3.13.7 pinned) |
| 9. Freshness canary | silently stopped rebuilds | done (canary.yml, 26h SLA) |
| 10. Keep-alive | GitHub's 60-day cron auto-disable | done (keepalive.yml, monthly empty commit) |

## Layer 1 runbook (Settings -> Branches, one-time)

- Require a pull request before merging; require status checks (CI); require
  branches up to date; require linear history.
- IMPORTANT (solo maintainer): do NOT enable "require 1 approval" together
  with "do not allow bypassing" until a second reviewer exists — that
  combination makes the repository unmergeable by a single owner. Until then,
  the PR + green CI + up-to-date gates do the real work; use admin bypass
  consciously.
- Exact API equivalents (gh CLI, admin token):

      gh api -X PUT repos/namunaONE/nMiti/branches/main/protection -f \
        required_status_checks='{"strict":true,"contexts":[]}' \
        -f enforce_admins=false -f required_pull_request_reviews='{"required_approving_review_count":0}' \
        -f restrictions=null

  (enable_enforce_admins and approval count can be raised once the neutral
  org has a second maintainer; see HYA-361)

## Layer 6 — why the smoke test is N-version

The Dart engine produced the artifact; the smoke test verifies it with a
completely independent Python implementation that reads the raw CSV. Two
languages, two code paths, one truth — the data-product equivalent of a
merge queue proving the combined result. It also asserts:

- the deployed JSON equals the independently computed BS date for today in
  Asia/Kathmandu;
- index.html contains the same answer (page and API must never disagree);
- freshness SLA: generated_at_utc is under 26 hours old;
- HTTP 200 on /, today.json, calendar/<year>.json, llms.txt, robots.txt;
- cache-busting query param so we test the deploy, not a cached ghost
  (Pages CDN can hold content ~10 minutes).

## Layer 7 — alert-first, revert-second

A nightly smoke failure with no new commit cannot be fixed by reverting
(the data did not change). So the universal action is an urgent GitHub
issue with the failing run link; push-triggered failures additionally get
an auto-generated revert PR that a human approves. Never auto-push a
revert to main.

## Layer 9/10 — the two failure modes unique to this project

- GitHub silently DISABLES scheduled workflows after 60 days without repo
  activity. A data repo can go months without commits — that would kill
  the daily /today rebuild without any error. Mitigation: keepalive.yml
  makes a monthly empty commit (counts as activity).
- Scheduled runs can also be delayed or skipped under load. The freshness
  canary (canary.yml) independently checks the live generated_at_utc every
  day at 00:15 NPT and opens an urgent issue if the SLA is breached.

## Failure matrix (external dependencies)

| Failure | Behavior |
|---|---|
| Invariant fails at build time | build_site refuses to emit; deploy never runs |
| Deploy succeeds but output wrong | smoke job fails; urgent issue; revert PR if push-triggered |
| Nightly cron skipped | canary catches staleness within 26h |
| Schedules disabled (inactivity) | keepalive prevents; canary detects if it still happens |
| Action tag moved/compromised | impossible: all actions pinned to commit SHAs |
| SDK drift | Dart pinned at 3.13.7 in CI and Pages |
| Future crawl target down (bot) | fail the job, create no PR (fail closed, never open) |
