# PR Build Artifact Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Post an auto-updating comment on every PR (including fork PRs) with download links to the Android, macOS, Windows, and Linux build artifacts.

**Architecture:** Two workflows. `ci.yaml` (unchanged trigger `pull_request`) starts uploading its four testable build artifacts on PRs and emits the PR number as a `pr-number` artifact. A new `artifact-links.yml`, triggered on `workflow_run` completion of "CI/CD", runs in the trusted base-repo context, reads the PR number, lists the run's artifacts and jobs, and upserts a single "sticky" comment.

**Tech Stack:** GitHub Actions YAML; first-party actions `actions/upload-artifact@v7`, `actions/download-artifact@v4`, `actions/github-script@v7`.

**Spec:** `docs/superpowers/specs/2026-07-16-pr-artifact-links-design.md`

## Global Constraints

- **First-party actions only** in the write-capable `workflow_run` context — no third-party action (supply-chain rule from `CLAUDE.md`).
- **Pin actions by version tag** (`@v7`, `@v4`), matching the existing `ci.yaml` house style — not by SHA.
- **PR artifact retention: 7 days**, matching the existing main-push `retention-days: 7`.
- **iOS is excluded** — `ios-build` stays `main`-push-only (unsigned, not sideloadable).
- **Sticky-comment marker (exact):** `<!-- submersion-artifact-links -->`
- **Least privilege** for the `workflow_run` job: `contents: read`, `pull-requests: write`, `actions: read`.
- **Workflow the second file listens for (exact):** `CI/CD` (the `name:` of `ci.yaml`).
- All YAML must parse cleanly (`python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))"`).

## File Structure

- **Modify** `.github/workflows/ci.yaml`
  - Widen the `if:` guard on the four testable `upload-artifact` steps so they also upload on PRs.
  - Add one new `pr-number` job that writes `${{ github.event.number }}` to a file and uploads it as the `pr-number` artifact.
- **Create** `.github/workflows/artifact-links.yml`
  - The `workflow_run`-triggered commenter: one `download-artifact` step + one `github-script` step.

---

### Task 1: Wire PR artifact uploads and PR-number emission in `ci.yaml`

**Files:**
- Modify: `.github/workflows/ci.yaml` (four `if:` guards at lines 546, 643, 716, 790; new job inserted before `ci-success:` ~line 804)

**Interfaces:**
- Consumes: nothing.
- Produces: on `pull_request` runs of "CI/CD", the artifacts `android-apk`, `macos-build`, `windows-build`, `linux-build`, and `pr-number` (a text file containing the PR number). These names are consumed by Task 2.

**Note on the guard lines:** the `if:` for the macOS/Android/Linux/Windows uploads currently reads `github.ref == 'refs/heads/main' && github.event_name == 'push'`. The iOS upload (around line 438, `name: ios-build`) uses the **same** string but must be left unchanged — so edit by locating each guard adjacent to the correct `name:` rather than blind find-replace.

- [ ] **Step 1: Write the failing assertion**

Create a throwaway check that the four testable uploads are NOT yet PR-enabled (this fails after we edit, confirming the edit landed). Run:

```bash
cd .github/workflows
# Expect: 5 lines still using the old main-only guard (4 testable + iOS) BEFORE the edit
grep -c "github.ref == 'refs/heads/main' && github.event_name == 'push'" ci.yaml
```

Expected now: `5`. After Step 3 it must become `1` (iOS only).

- [ ] **Step 2: Widen the four testable upload guards**

For each of the four upload steps whose `name:` is `macos-build`, `android-apk`, `linux-build`, and `windows-build`, replace the single-line guard:

```yaml
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```

with:

```yaml
        if: >
          github.event_name == 'pull_request' ||
          (github.ref == 'refs/heads/main' && github.event_name == 'push')
```

Leave the `ios-build` upload's guard exactly as it was.

- [ ] **Step 3: Add the `pr-number` job**

Insert this job into `ci.yaml` immediately before the `ci-success:` job (do NOT add it to any `needs:` list — it is not a gating check):

```yaml
  pr-number:
    name: Record PR number
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - name: Write PR number to file
        run: echo "${{ github.event.number }}" > pr-number.txt
      - name: Upload PR number artifact
        uses: actions/upload-artifact@v7
        with:
          name: pr-number
          path: pr-number.txt
          retention-days: 1
```

- [ ] **Step 4: Verify the edits**

```bash
cd .github/workflows
python3 -c "import yaml,sys; yaml.safe_load(open('ci.yaml')); print('yaml ok')"
# Only iOS keeps the old main-only guard:
grep -c "github.ref == 'refs/heads/main' && github.event_name == 'push'" ci.yaml   # expect 1
# Four widened guards now present:
grep -c "github.event_name == 'pull_request' ||" ci.yaml                            # expect 4
# The new job exists:
grep -c "name: Record PR number" ci.yaml                                            # expect 1
grep -A0 "name: pr-number" ci.yaml                                                  # artifact name present
```

Expected: `yaml ok`, then `1`, `4`, `1`, and the `pr-number` artifact line.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yaml
git commit -m "ci: upload testable build artifacts and PR number on pull requests"
```

---

### Task 2: Create the `artifact-links.yml` commenter workflow

**Files:**
- Create: `.github/workflows/artifact-links.yml`

**Interfaces:**
- Consumes (from Task 1): artifacts `android-apk`, `macos-build`, `windows-build`, `linux-build`, `pr-number`; job names `Build Android`, `Build macOS`, `Build Windows`, `Build Linux`; the workflow name `CI/CD`.
- Produces: a sticky PR comment carrying the marker `<!-- submersion-artifact-links -->`.

- [ ] **Step 1: Write the failing assertion**

```bash
test -f .github/workflows/artifact-links.yml && echo "exists" || echo "missing"
```

Expected now: `missing`.

- [ ] **Step 2: Create the workflow file**

Write `.github/workflows/artifact-links.yml` with exactly this content:

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
    # PR runs only; a run cancelled by cancel-in-progress leaves the last-good
    # comment untouched (the newer run will update it).
    if: >
      github.event.workflow_run.event == 'pull_request' &&
      github.event.workflow_run.conclusion != 'cancelled'
    permissions:
      contents: read
      pull-requests: write
      # PR comments go through the issues-comment API; issues: write avoids a
      # 403 on this post-merge-only path.
      issues: write
      actions: read
    steps:
      # First-party download of the pr-number artifact from the CI run onto disk.
      # github-script has no bundled unzip, so we do not decode the artifact zip
      # inline. continue-on-error so a CI run that died before emitting pr-number
      # does not fail this workflow.
      - name: Download pr-number artifact
        continue-on-error: true
        uses: actions/download-artifact@v4
        with:
          name: pr-number
          run-id: ${{ github.event.workflow_run.id }}
          github-token: ${{ github.token }}
          path: ./pr-meta

      - name: Upsert artifact-links comment
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const run = context.payload.workflow_run;
            const { owner, repo } = context.repo;

            // 1. Resolve the PR number from the downloaded artifact.
            const prPath = './pr-meta/pr-number.txt';
            if (!fs.existsSync(prPath)) {
              core.info('No pr-number artifact; nothing to comment on.');
              return;
            }
            const prNumber = parseInt(fs.readFileSync(prPath, 'utf8').trim(), 10);
            if (!Number.isInteger(prNumber)) {
              core.info('pr-number artifact did not contain a valid integer.');
              return;
            }

            // 1b. Verify the PR corresponds to this run. The pr-number artifact
            // is produced by the untrusted PR run, so a malicious PR could forge
            // a different number to make this trusted job comment on an unrelated
            // PR. Confirm the PR's head SHA matches the run's before trusting it.
            let pr;
            try {
              pr = await github.rest.pulls.get({ owner, repo, pull_number: prNumber });
            } catch (e) {
              core.info(`Could not fetch PR #${prNumber}: ${e.message}`);
              return;
            }
            // Accept head.sha OR merge_commit_sha: pull_request runs may report
            // the test-merge commit as run.head_sha, and refusing those would
            // suppress the comment on every legitimate run.
            const runSha = run.head_sha;
            if (runSha !== pr.data.head.sha && runSha !== pr.data.merge_commit_sha) {
              core.info(
                `PR #${prNumber} (head ${pr.data.head.sha}, merge ` +
                `${pr.data.merge_commit_sha}) does not match run head ${runSha}; ` +
                `refusing to comment (forged pr-number or superseded run).`,
              );
              return;
            }

            // 2. Platform -> job name + artifact name + display label.
            const PLATFORMS = [
              { label: 'Android (APK)', job: 'Build Android', artifact: 'android-apk' },
              { label: 'macOS',         job: 'Build macOS',   artifact: 'macos-build' },
              { label: 'Windows',       job: 'Build Windows', artifact: 'windows-build' },
              { label: 'Linux',         job: 'Build Linux',   artifact: 'linux-build' },
            ];

            // 3. List this run's artifacts and jobs. Both Actions endpoints
            // return { total_count, artifacts|jobs: [...] }; read the namespaced
            // array off .data directly (unambiguous, unlike paginate's response
            // normalization). per_page: 100 covers this run's counts.
            const artifactsResp = await github.rest.actions.listWorkflowRunArtifacts({
              owner, repo, run_id: run.id, per_page: 100,
            });
            const artifactByName = new Map(
              artifactsResp.data.artifacts.map(a => [a.name, a]),
            );

            const jobsResp = await github.rest.actions.listJobsForWorkflowRun({
              owner, repo, run_id: run.id, per_page: 100,
            });
            const jobByName = new Map(jobsResp.data.jobs.map(j => [j.name, j]));

            // 4. Render one row per platform.
            const serverUrl = process.env.GITHUB_SERVER_URL || 'https://github.com';
            const runUrl = `${serverUrl}/${owner}/${repo}/actions/runs/${run.id}`;
            const rows = PLATFORMS.map(p => {
              const artifact = artifactByName.get(p.artifact);
              const job = jobByName.get(p.job);
              let cell;
              if (artifact) {
                cell = `[${p.artifact}](${runUrl}/artifacts/${artifact.id})`;
              } else if (job && job.conclusion === 'failure') {
                cell = `❌ [build failed](${job.html_url})`;
              } else if (job && (job.conclusion === 'cancelled' || job.conclusion === 'skipped')) {
                cell = '⚠️ skipped';
              } else if (job && job.conclusion === 'success') {
                cell = '⚠️ artifact missing';
              } else {
                cell = '⚠️ unavailable';
              }
              return `| ${p.label} | ${cell} |`;
            }).join('\n');

            // Skip entirely if there is nothing useful to report.
            const anyArtifact = PLATFORMS.some(p => artifactByName.has(p.artifact));
            const anyFailure = PLATFORMS.some(p => {
              const j = jobByName.get(p.job);
              return j && j.conclusion === 'failure';
            });
            if (!anyArtifact && !anyFailure) {
              core.info('No build artifacts and no build failures; skipping comment.');
              return;
            }

            // 5. Build the comment body with the hidden sticky marker.
            const MARKER = '<!-- submersion-artifact-links -->';
            const shortSha = run.head_sha.substring(0, 7);
            const body = [
              `**📦 Build artifacts for this PR** · commit \`${shortSha}\``,
              '',
              '| Platform | Download |',
              '| --- | --- |',
              rows,
              '',
              'Artifacts expire in 7 days. Downloading requires being signed in to GitHub. ' +
              'The macOS build is ad-hoc signed — right-click → Open on first launch.',
              '',
              '<sub>Updated automatically on each push.</sub>',
              '',
              MARKER,
            ].join('\n');

            // 6. Upsert: update the existing marked comment, else create one.
            const comments = await github.paginate(
              github.rest.issues.listComments,
              { owner, repo, issue_number: prNumber, per_page: 100 },
            );
            // Match only our own bot's marked comment so a human quoting the
            // marker can never be overwritten.
            const existing = comments.find(c =>
              c.user && c.user.login === 'github-actions[bot]' &&
              c.body && c.body.includes(MARKER),
            );
            if (existing) {
              await github.rest.issues.updateComment({ owner, repo, comment_id: existing.id, body });
              core.info(`Updated comment ${existing.id} on PR #${prNumber}.`);
            } else {
              await github.rest.issues.createComment({ owner, repo, issue_number: prNumber, body });
              core.info(`Created comment on PR #${prNumber}.`);
            }
```

- [ ] **Step 3: Verify the file parses and has the required shape**

```bash
cd .github/workflows
python3 -c "import yaml,sys; d=yaml.safe_load(open('artifact-links.yml')); print('yaml ok')"
# Note: PyYAML parses the top-level `on:` key as boolean True; assert on triggers via grep instead.
grep -q 'workflows: \["CI/CD"\]' artifact-links.yml && echo "trigger ok"
grep -q "pull-requests: write" artifact-links.yml && echo "perm ok"
grep -q "submersion-artifact-links" artifact-links.yml && echo "marker ok"
grep -q "conclusion != 'cancelled'" artifact-links.yml && echo "guard ok"
```

Expected: `yaml ok`, `trigger ok`, `perm ok`, `marker ok`, `guard ok`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/artifact-links.yml
git commit -m "ci: add PR comment with build artifact download links"
```

---

### Task 3: End-to-end validation on GitHub

**Files:** none (live verification).

**Interfaces:** consumes the two committed workflows; produces evidence the feature works.

This is the only place the `workflow_run` path can actually be exercised — it cannot run locally. Push the branch and open a real PR.

> **CRITICAL — `workflow_run` runs from the default branch.** `artifact-links.yml`
> executes the version of itself that exists on `main`, not the version on this PR
> branch. Therefore **the commenter will NOT post on this feature's own introducing
> PR.** On the introducing PR you can only verify the `ci.yaml` half: the four build
> artifacts and the `pr-number` artifact appear on the run's artifacts page. Full
> end-to-end verification (the sticky comment) requires **merging to `main` first**,
> then opening a *subsequent* throwaway PR. Steps 2–4 below apply to that subsequent
> PR, not the introducing one.

- [ ] **Step 1: Push the branch and open a draft PR**

```bash
git push -u origin worktree-pr-artifact-links
gh pr create --draft --fill --base main
```

- [ ] **Step 2: Wait for "CI/CD" to finish, then confirm the comment appears**

```bash
gh pr checks --watch
```

Then verify the PR has a comment containing the marker with four rows:

```bash
gh pr view --json comments --jq '.comments[].body' | grep -c "submersion-artifact-links"   # expect 1
gh pr view --json comments --jq '.comments[].body' | grep -E "android-apk|macos-build|windows-build|linux-build"
```

Expected: one marked comment; four platform links present. Manually click one link (e.g. `android-apk`) and confirm it downloads.

- [ ] **Step 3: Confirm the sticky comment updates in place on a new commit**

```bash
git commit --allow-empty -m "chore: trigger CI to test sticky comment update"
git push
gh pr checks --watch
gh pr view --json comments --jq '[.comments[].body | select(contains("submersion-artifact-links"))] | length'   # expect 1 (not 2)
```

Expected: still exactly **one** marked comment (updated in place, no duplicate), now referencing the newer commit's short SHA.

- [ ] **Step 4: (Optional) Confirm the failure path**

Temporarily break one platform build (e.g., introduce a compile error touched only by the Linux bundle step), push, and confirm that platform's row renders `❌ build failed` linking to the job logs while the others still link. Revert the break afterward.

- [ ] **Step 5: Mark the PR ready and record the result**

Once verified, `gh pr ready`. Note in the PR description that artifact links are posted automatically.

---

## Self-Review

**Spec coverage:**
- Fork-safe two-workflow architecture → Task 1 (`pr-number` artifact) + Task 2 (`workflow_run` trigger). ✓
- Upload four testable platforms on PRs; iOS excluded → Task 1 Step 2 (four guards; iOS untouched). ✓
- `pr-number` handoff across trust boundary → Task 1 Step 3 + Task 2 download step. ✓
- Self-contained first-party `github-script`; no third-party in write context → Task 2. ✓
- Sticky comment via marker; rewrite each push → Task 2 Step 2 (upsert) + Task 3 Step 3 (verified). ✓
- `❌ build failed` linking to job logs → Task 2 render logic. ✓
- Cancelled-run guard → Task 2 job `if:` (`conclusion != 'cancelled'`). ✓
- Least-privilege permissions → Task 2 job `permissions:`. ✓
- 7-day retention → Task 1 (guards reuse existing `retention-days: 7`). ✓
- Testing plan (test PR, second push, failure path) → Task 3. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases"; every code step shows full content. ✓

**Type/name consistency:** Artifact names (`android-apk`, `macos-build`, `windows-build`, `linux-build`, `pr-number`), job names (`Build Android/macOS/Windows/Linux`), workflow name (`CI/CD`), and marker (`<!-- submersion-artifact-links -->`) are identical across Task 1 and Task 2. ✓
