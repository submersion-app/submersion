# PR Build Artifact Links — Design

- **Date:** 2026-07-16
- **Status:** Approved (pending spec review)
- **Author:** Eric Griffin (with Claude Code)

## Problem

Reviewers and testers have no easy way to grab a runnable build of the change in
a pull request. To test a PR today you must check out the branch and build
locally. We want every PR to carry links to downloadable, testable build
artifacts (Android, macOS, Windows, Linux), automatically kept up to date as new
commits land.

Reference precedent: Subsurface's
[`artifact-links.yml`](https://github.com/subsurface/subsurface/blob/master/.github/workflows/artifact-links.yml)
and an [example PR comment](https://github.com/subsurface/subsurface/pull/4708#issuecomment-3856046243).

## Current-state findings

Established by inspecting `.github/workflows/ci.yaml` (workflow `name: CI/CD`):

- CI is triggered on `push` to `main` and on `pull_request` to `main`.
- The platform build jobs — `build-ios`, `build-macos`, `build-android`,
  `build-linux`, `build-windows` — have **no job-level `if:` guard**, so they
  already **run on every PR** (they `needs: codegen`, nothing more).
- However, each `actions/upload-artifact@v7` step is gated by:

  ```yaml
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  ```

  So on a PR the apps **compile and are then discarded** — the binaries are
  never uploaded.
- Concurrency uses `cancel-in-progress: true`, so a new push cancels the
  in-flight run for that ref.

Consequence: surfacing testable artifacts on PRs costs **almost no new compute** —
the expensive `macos-26` iOS/macOS builds already run on every PR. We only need
to (1) upload the builds on PRs and (2) post the links.

Confirmed names (used later in this spec):

| Job name (`name:`) | Artifact name | PR-testable? |
| --- | --- | --- |
| `Build Android` | `android-apk` | Yes — directly sideloadable |
| `Build macOS` | `macos-build` | Yes — ad-hoc signed; right-click → Open on other Macs |
| `Build Windows` | `windows-build` | Yes — unzip and run |
| `Build Linux` | `linux-build` | Yes — unzip and run |
| `Build iOS` | `ios-build` | **No** — built `--no-codesign`; not sideloadable |

## Goals

- Every PR (including PRs from forks) gets a single comment listing download
  links for the four testable platform builds.
- The comment is a **sticky comment**: updated in place on each new commit, always
  pointing at the newest run's artifacts.
- A platform whose build **failed** shows `❌ build failed` linking to that job's
  logs, rather than silently disappearing.
- Least-privilege, supply-chain-conscious implementation using only first-party
  GitHub actions.

## Non-goals

- Publishing an iOS artifact (unsigned, not sideloadable — deliberately excluded).
- Code-signing / notarizing artifacts for distribution.
- Changing what/when `main`-push uploads produce (those stay exactly as-is).
- Any stable "latest artifact" URL — GitHub artifact URLs are inherently
  run-scoped (see Insight in Section 3).

## Architecture

Two workflows, because a fork's `pull_request` run receives a **read-only**
`GITHUB_TOKEN` and cannot comment. The commenting must happen in the base repo's
trusted context, which is what the `workflow_run` trigger provides.

```
PR opened / updated  (same-repo OR fork)
        │
        ▼
┌───────────────────────────────────────────────┐
│  ci.yaml   (name: "CI/CD")                     │  trigger: pull_request
│  - build-{android,macos,windows,linux} already │    (read-only token on forks)
│    run on PRs today                            │
│  CHANGE 1: upload those 4 artifacts on PRs     │
│  CHANGE 2: new pr-number job emits the PR       │
│            number as a `pr-number` artifact    │
└───────────────────────────────────────────────┘
        │  on: workflow_run "completed"
        ▼
┌───────────────────────────────────────────────┐
│  artifact-links.yml   (NEW)                    │  trigger: workflow_run
│  permissions: pull-requests: write,            │    (trusted base-repo token)
│               actions: read, contents: read    │
│  single actions/github-script step:            │
│   - guard: event=='pull_request',              │
│            conclusion != 'cancelled'           │
│   - read pr-number artifact -> PR number       │
│   - list run artifacts + list run jobs         │
│   - render per-platform status                 │
│   - upsert sticky comment (hidden marker)      │
└───────────────────────────────────────────────┘
```

### Why a `pr-number` artifact instead of the event payload

`github.event.workflow_run.pull_requests` is populated only for **same-repo**
PRs; for forks it is empty. The robust, GitHub-documented pattern is to have the
(untrusted) PR run write its own PR number to a file and upload it as an
artifact, which the (trusted) second workflow downloads and reads. We never
execute fork code in the trusted context, and we only trust a plain integer to
decide *where* to comment.

## Change 1 — `ci.yaml`: upload the four builds on PRs

For each of the four testable upload steps (`android-apk`, `macos-build`,
`windows-build`, `linux-build`), widen the guard so it also fires on PRs:

```yaml
if: >
  github.event_name == 'pull_request' ||
  (github.ref == 'refs/heads/main' && github.event_name == 'push')
```

- **iOS is left unchanged** (`ios-build` stays `main`-push only).
- **Retention:** PR uploads use `retention-days: 7`, matching existing main-push
  retention. (The upload steps already set `retention-days: 7`; widening the
  `if:` reuses the same value — no separate PR retention path.)

## Change 2 — `ci.yaml`: emit the PR number

Add one small job (runs only on PRs; no build dependency; ~5 seconds):

```yaml
pr-number:
  name: Record PR number
  if: github.event_name == 'pull_request'
  runs-on: ubuntu-latest
  steps:
    - run: echo "${{ github.event.number }}" > pr-number.txt
    - uses: actions/upload-artifact@v7
      with:
        name: pr-number
        path: pr-number.txt
        retention-days: 1
```

This job is independent of the `ci-success` gate and does not affect required
checks.

## Change 3 — NEW `.github/workflows/artifact-links.yml`

```yaml
name: PR artifact links

on:
  workflow_run:
    workflows: ["CI/CD"]
    types: [completed]

permissions:
  contents: read

jobs:
  artifact-links:
    name: Post artifact links to PR
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      issues: write
      actions: read
      contents: read
    # PR-only; superseded/cancelled runs leave the last-good comment untouched.
    if: >
      github.event.workflow_run.event == 'pull_request' &&
      github.event.workflow_run.conclusion != 'cancelled'
    steps:
      # First-party download of the pr-number artifact from the OTHER run onto
      # disk (github-script has no bundled unzip, so we do not decode the zip
      # inline). continue-on-error so a CI run that died before emitting
      # pr-number does not hard-fail this workflow.
      - name: Download pr-number artifact
        id: pr_number
        continue-on-error: true
        uses: actions/download-artifact@v4
        with:
          name: pr-number
          run-id: ${{ github.event.workflow_run.id }}
          github-token: ${{ github.token }}
          path: ./pr-meta
      - uses: actions/github-script@v7
        with:
          script: |
            // (logic described below)
```

### `github-script` logic

Given `const run = context.payload.workflow_run;`

1. **Resolve the PR number.**
   - Read `./pr-meta/pr-number.txt` (downloaded by the prior step) with
     `fs.readFileSync` and parse the integer. If the file is missing (the
     download step was skipped/failed), exit quietly — nothing to comment on.
   - **Verify the PR belongs to this run.** The `pr-number` artifact is produced
     by the untrusted PR run, so a fork could forge a different number to make
     this trusted job comment on an unrelated PR. Fetch the PR (`pulls.get`) and
     confirm `run.head_sha` matches `pr.head.sha` **or** `pr.merge_commit_sha`
     (accepting either avoids refusing legitimate runs where the run SHA is the
     test-merge commit); otherwise exit without commenting.
2. **Gather per-platform status.**
   - `actions.listJobsForWorkflowRun(run.id)` → map job `name` → `{conclusion,
     html_url}` for `Build Android`, `Build macOS`, `Build Windows`,
     `Build Linux`.
   - From the artifact list, map artifact `name` → per-artifact download URL:
     `https://github.com/<owner>/<repo>/actions/runs/<run.id>/artifacts/<artifact.id>`.
3. **Render each platform row** (order: Android, macOS, Windows, Linux):

   | Job conclusion | Artifact present | Cell renders |
   | --- | --- | --- |
   | `success` | yes | `[<artifact-name>](<download URL>)` |
   | `failure` | (no) | `❌ [build failed](<job html_url>)` |
   | `cancelled` / `skipped` (single job) | (no) | `⚠️ skipped` |
   | `success` | no (unexpected) | `⚠️ artifact missing` |

4. **Upsert the sticky comment.**
   - Marker: `<!-- submersion-artifact-links -->` (hidden HTML comment).
   - `issues.listComments(pr)` → find the comment **authored by
     `github-actions[bot]`** whose body contains the marker (author-restricted so
     a human quoting the marker cannot be overwritten).
   - If found → `issues.updateComment`; else → `issues.createComment`.

### Rendered comment (approximate)

> **📦 Build artifacts for this PR** &nbsp;·&nbsp; commit `abc1234`
>
> | Platform | Download |
> | --- | --- |
> | Android (APK) | [android-apk](…) |
> | macOS | [macos-build](…) |
> | Windows | ❌ [build failed](…job logs…) |
> | Linux | [linux-build](…) |
>
> Artifacts expire in 7 days. Downloading requires being signed in to GitHub.
> The macOS build is ad-hoc signed — right-click → Open on first launch.
> <sub>Updated automatically on each push.</sub>
>
> `<!-- submersion-artifact-links -->`

### Why the comment is rewritten every push (not left alone)

GitHub artifact download URLs are **run-scoped**: every artifact lives under a
specific `run_id`, and there is no stable "latest artifact for platform X on this
PR" URL. Each new commit produces a new run with new `artifact_id`s and therefore
new URLs, so the whole comment body must be regenerated to keep the links live.

## Error handling & edge cases

- **Fork PRs:** handled by the `pr-number` artifact handoff; no fork code runs in
  the trusted context; the second workflow always runs in the base repo with a
  write token.
- **Superseded run (cancelled by `cancel-in-progress`):** the job-level guard
  `conclusion != 'cancelled'` skips it entirely, leaving the last-good comment
  intact. The newer run will update the comment when it completes.
- **Partial build failure:** the failing platform shows `❌ build failed` linked
  to its job logs; other platforms still show working links.
- **CI fails before any upload / no `pr-number` artifact:** the script exits
  quietly without creating an empty comment.
- **Multiple pushes in quick succession:** each real completion updates the same
  sticky comment; only the latest survives.

## Security considerations

- **Trust boundary:** untrusted PR code runs only in the `pull_request` context
  (read-only token on forks). All write operations occur in the `workflow_run`
  context, which uses the base repo's trusted token and never checks out or
  executes PR code.
- **Least privilege:** the `workflow_run` job requests only
  `pull-requests: write`, `issues: write`, `actions: read`, `contents: read`.
  (`issues: write` is included because PR comments go through the issues-comment
  API; it prevents a 403 on this post-merge-only path.)
- **PR-target binding:** before commenting, the job fetches the PR and requires
  `run.head_sha` to equal `pr.head.sha` or `pr.merge_commit_sha`. This defeats a
  forged `pr-number` from an untrusted PR run trying to redirect the comment to
  an unrelated PR (an attacker cannot make their run's SHA equal an unrelated
  PR's head or merge SHA), while accepting the test-merge SHA that some
  `pull_request` runs report.
- **Author-restricted upsert:** only a comment authored by `github-actions[bot]`
  and carrying the marker is updated, so a human comment quoting the marker is
  never overwritten.
- **First-party only:** commenting uses `actions/github-script@v7` (GitHub-
  maintained) — no third-party action in the write-capable context. This matches
  the repo convention of referencing actions by version tag and satisfies the
  project's supply-chain caution (`CLAUDE.md` Security rules).
- **Data trusted across the boundary:** only a parsed integer (the PR number)
  from the `pr-number` artifact.

## Testing / validation

CI infra is validated on GitHub, not locally:

1. Lint both YAML files (`actionlint` if available; otherwise YAML syntax check).
2. Open a throwaway **same-repo** test PR → confirm the sticky comment appears
   with four working links.
3. Push a second commit → confirm the **same** comment updates in place (no
   duplicate) and links point at the newer run.
4. Induce a single-platform build failure (temporary) → confirm that platform
   renders `❌ build failed` linking to the job logs while others still link.
5. If feasible, a **fork** PR smoke test to confirm the fork path comments
   correctly.

## Rollout

- Purely additive to CI: one new workflow file, one widened `if:` on four upload
  steps, one small new job. No change to existing `main`-push behavior or to
  required status checks.
- Reversible by reverting the two files.
- **`workflow_run` runs from the default branch.** `artifact-links.yml` executes
  the copy of itself on `main`, so it does **not** comment on its own introducing
  PR. The `ci.yaml` changes (uploads + `pr-number`) do run on the introducing PR,
  but the sticky comment only begins appearing on PRs opened **after** this merges
  to `main`. Plan for a post-merge test PR to confirm end-to-end behavior.
