# Reliability: defense in depth for main

Layered defense, ordered pre-merge to post-deploy recovery. No single layer
is trusted alone; each catches what the previous one missed. For a date
site, doctrine is **wrongness is worse than downtime**: a plausible wrong
date destroys trust permanently; a 404 costs one visit.

## Layer map (what exists today vs what is phased)

| Layer | Catches | Status |
|---|---|---|
| 1. Branch protection | direct pushes, unapproved merges | runbook below (manual, one-time) |
| 2. Merge queue | concurrent-PR conflicts | CI handles merge_group; queue GA, enable when bot PRs begin |
| 3. Fail-closed generators | invalid data reaching any artifact | done (invariants + drift check refuse to build) |
| 4. External retries | transient crawl/API failures | applies to the future consensus bot (M1) |
| 5. Environments + approvals | irregular deploys reaching prod | NOT for the static pipeline (freshness wins); for future api/mcp |
| 6. Post-deploy smoke test | build-succeeded-but-output-wrong | done (N-version, retry-hardened) |
| 7. Auto-revert + alert | the one that got through | done (alert-first; revert PR for push failures) |
| 8. Supply chain pinning | silent action/SDK changes | done (actions pinned to commit SHAs, Dart 3.13.7 pinned) |
| 9. Freshness canary | silently stopped rebuilds | done (canary.yml, 26h SLA, retry-hardened) |
| 10. Keep-alive | GitHub's 60-day cron auto-disable | done (keepalive.yml, monthly empty commit) |

## GitHub-verified platform behaviors we design around

These are documented behaviors, not folklore (checked 2026-11-02 against
docs.github.com and public incident reports):

1. **Scheduled workflows auto-disable after 60 days of repo inactivity**
   (public repos), and the disable sends no notification. A rarely-committed
   data repo WILL hit this. Mitigation: keepalive.yml monthly commit +
   canary detects it anyway.
2. **Scheduled runs are delayed under load, and queued jobs may be dropped.**
   Documented high-load window includes the top of every hour — so all our
   crons run at :15/:30 offsets. Real-world reports (Oct 2026) show multi-hour
   delays. Mitigation: 6-hourly rebuild redundancy + a midnight guard run
   (19:15 UTC = 01:00 NPT) so a dropped rollover run heals within an hour +
   canary backstop at 26h.
3. **Scheduled workflows run only from the default branch.** Our Site
   workflow activates after PR #1 merges to main; before that, no cron runs
   at all. Merge first, then expect the first rebuild at the next cron slot.
4. **GitHub Pages limits:** sites up to 1 GB, soft 100 GB/month bandwidth,
   soft 10 builds/hour. We do ~5 tiny builds/day — orders of magnitude of
   headroom. Pages is also not licensed for commercial hosting; nMiti is an
   open data commons, and any future commercial surface moves to a real host.
5. **Public repo = free, unlimited standard-runner Actions minutes.** The
   repository is public, so this pipeline costs exactly zero.
6. **Pages CDN propagation can lag a deploy by minutes.** Smoke and canary
   fetches use unique cache-busting query strings plus 3 attempts with
   backoff, so we verify the deployment, not a cached ghost, and transient
   5xx never raise false alarms.
7. **Failure notification gap:** workflow failure emails go to the person
   who triggered the run — for scheduled runs, the committer of the workflow
   file. Make sure the maintainer account watches this repository with
   notifications on, so the urgent-issue alerts are seen.

## Layer 1 runbook (Settings -> Branches, one-time)

- Require a pull request before merging; require status checks (CI); require
  branches up to date; require linear history.
- IMPORTANT (solo maintainer): do NOT enable "require 1 approval" together
  with "do not allow bypassing" until a second reviewer exists — that
  combination makes the repository unmergeable by a single owner. Until then,
  the PR + green CI + up-to-date gates do the real work; use admin bypass
  consciously.
- Exact API equivalent (gh CLI, admin token):

      gh api -X PUT repos/namunaONE/nMiti/branches/main/protection -f \
        required_status_checks='{"strict":true,"contexts":[]}' \
        -f enforce_admins=false -f required_pull_request_reviews='{"required_approving_review_count":0}' \
        -f restrictions=null

  (raise enforce_admins and approval count once the neutral org has a second
  maintainer; see HYA-361)

- Merge queue (GA): Settings -> Branches -> Merge queue, require for main.
  CI already handles merge_group events.

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
- cache-busting query param + 3 retries so we test the deploy, not a cached
  or transiently-failing ghost.

## Layer 7 — alert-first, revert-second

A nightly smoke failure with no new commit cannot be fixed by reverting
(the data did not change). So the universal action is an urgent GitHub
issue with the failing run link; push-triggered failures additionally get
an auto-generated revert PR that a human approves. Never auto-push a
revert to main.

## Failure matrix (external dependencies)

| Failure | Behavior |
|---|---|
| Invariant fails at build time | build_site refuses to emit; deploy never runs |
| Deploy succeeds but output wrong | smoke job fails; urgent issue; revert PR if push-triggered |
| Midnight cron dropped/delayed | 01:00 NPT guard run rebuilds within the hour |
| Nightly cron skipped entirely | canary catches staleness within 26h |
| Schedules disabled (inactivity) | keepalive prevents; canary detects if it still happens |
| CDN propagation lag | cache-busting + retries; no false alarms |
| Action tag moved/compromised | impossible: all actions pinned to commit SHAs |
| SDK drift | Dart pinned at 3.13.7 in CI and Pages |
| Future crawl target down (bot) | fail the job, create no PR (fail closed, never open) |
