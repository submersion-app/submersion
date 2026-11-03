# Hosted Web App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every stable release deploys its web bundle, with Submersion's Google web client built in, to `https://web.submersion.app` on GitHub Pages.

**Architecture:** The release build passes the Google client to `scripts/build_web.sh` from a repository variable. A reusable workflow, `deploy-web.yml`, fetches a stable release's `Web.zip`, stages it with a tested Python script (bundle check, client warning, `CNAME`, `.nojekyll`, older-version guard), and force-pushes one orphan commit to `submersion-app/web` over SSH with a deploy key. `promote.yml` and the legacy `release.yml` path call it.

**Tech Stack:** GitHub Actions, Python 3 (stdlib `unittest`, `zipfile`, `json`), git over SSH, GitHub Pages.

**Spec:** `docs/design/specs/2026-11-03-hosted-web-app-design.md`

## Global Constraints

- Site address: `https://web.submersion.app`; custom domain `web.submersion.app`.
- Pages repository: `submersion-app/web`, branch `main`, root.
- Repository variable `GOOGLE_WEB_CLIENT_ID` (public, a variable not a secret); secret `WEB_DEPLOY_KEY` (SSH private key).
- Deploy only stable tags: a tag containing `-` is refused.
- A bundle without the client deploys anyway, with a `::warning::` annotation (spec decision 7).
- A bundle older than the deployed one is refused unless `force` (spec decision 8). Equal versions redeploy.
- No deploy key: notice and success, never a failure (anti-goal: a release failing because setup is unfinished).
- No em dashes, no AI attribution anywhere in repo text or commits.

## Review Focus

1. A zip member whose path escapes the output folder (`../x`, absolute path): staging must refuse it, not write outside.
2. An output folder that already holds files (a re-run in the same workspace): staging refuses, so stale files never ship.
3. A deployed `version.json` that is missing, unparsable or lacks `build_number`: treated as "nothing to compare", the deploy proceeds with a printed note; the staged bundle's own `version.json` being unreadable is a failure.
4. Redeploying the same release (equal version and build): allowed without `force`.
5. A client id that is in the bundle but built for another origin: warns, because Google would refuse it on the site.

Each has a named test in Task 1.

---

### Task 1: The staging script

**Files:**
- Create: `scripts/web/stage_hosted_site.py`
- Create: `scripts/web/stage_hosted_site_test.py`
- Modify: `.github/workflows/ci.yaml` (Script Tests job: add `scripts/web/stage_hosted_site.py` to `guards=`, and a `coverage run --append` line for the test after `scripts/web/serve_bundle_test.py`)

**Interfaces:**
- Consumes: `check_web_bundle.check_bundle(bundle_dir, lock_path) -> list[str]` and `check_web_bundle.check_sample_logbook(bundle_dir) -> list[str]` (load by path with `importlib`, as `serve_bundle_test.py` loads its module).
- Produces (CLI, used by Task 2):
  - `stage_hosted_site.py stage ZIP OUT --domain DOMAIN --client-id ID [--lock LOCK]`: exit 0 on success (prints each warning as `::warning::<text>` and `OK: staged <OUT>`), exit 1 with `FAIL: <reason>` lines.
  - `stage_hosted_site.py check-newer STAGED_VERSION_JSON CURRENT_VERSION_JSON [--force]`: exit 0 when the deploy may go ahead, 1 when refused. `CURRENT_VERSION_JSON` may name a file that does not exist.
- Produces (Python, for the tests):
  - `class StageError(Exception)`
  - `stage_site(zip_path: str, out_dir: str, domain: str, client_id: str, lock_path: str) -> list[str]` (returns warnings, raises `StageError`)
  - `client_warnings(bundle_dir: str, client_id: str, origin: str) -> list[str]`
  - `read_version(path: str) -> tuple[int, ...] | None` (`"1.8.3"` + `"9095"` gives `(1, 8, 3, 9095)`)
  - `may_deploy(staged: tuple[int, ...], current: tuple[int, ...] | None, force: bool) -> bool`

- [ ] **Step 1: Write the failing tests** in `stage_hosted_site_test.py`, a `unittest.TestCase` per area. Fixture: a fake bundle zip holding every `check_web_bundle.REQUIRED` file, a `sqlite3.wasm` whose sha256 a temp lock file pins (as `check_web_bundle_test.py` does), `version.json` `{"app_name":"submersion","version":"1.8.3","build_number":"9095","package_name":"submersion"}`, and `main.dart.js` containing `"123-abc.apps.googleusercontent.com"` and `"https://web.submersion.app"`.
  - `test_stages_the_bundle_with_cname_and_nojekyll`: `stage_site(...)` returns `[]`; `OUT/CNAME` reads `web.submersion.app\n`; `OUT/.nojekyll` exists; `OUT/index.html` equals the zip's.
  - `test_a_bundle_that_fails_the_bundle_check_is_refused`: zip without `drift_worker.js` raises `StageError` whose text contains `missing drift_worker.js`.
  - `test_a_zip_member_outside_the_folder_is_refused` (Review Focus 1): members `../evil.txt` and `/abs.txt` each raise `StageError`; nothing is written outside `OUT`.
  - `test_a_non_empty_output_folder_is_refused` (Review Focus 2): `OUT` holding `stale.txt` raises `StageError`.
  - `test_no_client_id_warns`: `client_warnings(bundle, "", origin)` returns one warning mentioning `GOOGLE_WEB_CLIENT_ID`.
  - `test_a_bundle_without_the_client_warns`: `main.dart.js` lacking the id returns one warning naming the id; staging still succeeds.
  - `test_a_client_built_for_another_origin_warns` (Review Focus 5): id present, origin absent returns one warning naming `https://web.submersion.app`.
  - `test_read_version`: the fixture gives `(1, 8, 3, 9095)`; a missing file, invalid JSON, or no `build_number` gives `None` (Review Focus 3).
  - `test_may_deploy`: `(1,8,4,9300)` over `(1,8,3,9095)` is `True`; equal is `True` (Review Focus 4); `(1,8,3,9095)` over `(1,8,4,9300)` is `False`, and `True` with `force=True`; any staged over `None` is `True`.
  - `test_check_newer_cli`: `main(["check-newer", staged, current])` returns 1 for an older staged version, 0 with `--force`, 0 when `current` does not exist; `main(["check-newer", missing, current])` returns 1 (staged unreadable).

- [ ] **Step 2: Run them to see them fail**

Run: `python3.14 scripts/web/stage_hosted_site_test.py`
Expected: errors loading `stage_hosted_site.py` (file not found).

- [ ] **Step 3: Implement `stage_hosted_site.py`**

Module docstring in the style of `check_web_bundle.py` (what, why, usage). `stage_site` checks `OUT` is absent or empty, extracts with `zipfile`, refusing any member whose resolved path is not under `OUT`, runs both bundle checks (failures joined into the `StageError`), writes `CNAME` and `.nojekyll`, and returns `client_warnings(OUT, client_id, "https://" + domain)`. `client_warnings` reads `main.dart.js` as text and checks plain substrings. `read_version` parses `version` as dot-separated ints plus `build_number`. `main(argv)` with `argparse` subcommands; `check-newer` prints which version is deployed, which is staged, and on refusal says to rerun with `force` and why (returning visitors' databases are already on the newer schema). `if __name__ == "__main__": sys.exit(main())`.

- [ ] **Step 4: Run the tests to see them pass**

Run: `python3.14 scripts/web/stage_hosted_site_test.py`
Expected: `OK`.

- [ ] **Step 5: Wire into CI** (`ci.yaml` Script Tests, the two edits above) and check the YAML still parses: `python3.14 -c "import yaml,sys;yaml.safe_load(open('.github/workflows/ci.yaml'))"`. Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add scripts/web/stage_hosted_site.py scripts/web/stage_hosted_site_test.py .github/workflows/ci.yaml
git commit -m "feat(web): stage a release bundle for Submersion's own site"
```

### Task 2: The deploy workflow, its callers and the build

**Files:**
- Create: `.github/workflows/deploy-web.yml`
- Modify: `.github/workflows/build-all.yml` (`build-web` job, "Build the web bundle" step)
- Modify: `.github/workflows/promote.yml` (new `deploy-web` job; add it to `notify-failures.needs`)
- Modify: `.github/workflows/release.yml` (new `deploy-web` job after `create-release`)

**Interfaces:**
- Consumes: the Task 1 CLI.
- Produces: `deploy-web.yml` with `workflow_call` inputs `tag` (string, required) and `force` (boolean, default `false`), secret `WEB_DEPLOY_KEY` (required: false); `workflow_dispatch` with the same two inputs.

- [ ] **Step 1: Build step.** In `build-all.yml`, give "Build the web bundle" an `env:` with `GOOGLE_WEB_CLIENT_ID: ${{ vars.GOOGLE_WEB_CLIENT_ID }}` and `GOOGLE_WEB_CLIENT_ORIGINS: https://web.submersion.app`, with a comment: empty variable builds without the client (forks, before setup); the client is used only at that origin, so the same zip serves self-hosters (spec decision 4).

- [ ] **Step 2: `deploy-web.yml`.** Header comment pointing at the spec. `permissions: contents: read`; `concurrency: {group: deploy-web, cancel-in-progress: false}`; one job, `ubuntu-latest`, `timeout-minutes: 20`. Steps:
  1. **Configured?** (`id: configured`): with `WEB_DEPLOY_KEY` in `env`, empty means `::notice::` that the site is not set up (link `docs/developer/web-site-setup.md`) and `deploy=false`; else `deploy=true`. Every later step has `if: steps.configured.outputs.deploy == 'true'`.
  2. Refuse a tag containing `-` (`::error::`, exit 1).
  3. `actions/checkout@v7` with `sparse-checkout` of `scripts/check_web_bundle.py`, `scripts/web/stage_hosted_site.py`, `scripts/web/sqlite3_wasm.lock` (`sparse-checkout-cone-mode: false`), at `ref: ${{ inputs.tag }}` so the lock matches the release.
  4. `gh release download "$TAG" --repo ${{ github.repository }} --pattern "Submersion-${TAG}-Web.zip" --dir dl` with `GH_TOKEN: ${{ github.token }}`; when it finds nothing, `::error::` that the release has no web bundle (releases before PR #4142).
  5. `python3 scripts/web/stage_hosted_site.py stage "dl/Submersion-${TAG}-Web.zip" site --domain web.submersion.app --client-id "$CLIENT_ID"` with `CLIENT_ID: ${{ vars.GOOGLE_WEB_CLIENT_ID }}`.
  6. SSH: write the key to `$RUNNER_TEMP/deploy_key` (mode 600); pin `github.com` host keys from `gh api meta --jq '.ssh_keys[]'` into a known_hosts file; export `GIT_SSH_COMMAND="ssh -i <key> -o IdentitiesOnly=yes -o UserKnownHostsFile=<file> -o StrictHostKeyChecking=yes"` through `$GITHUB_ENV`.
  7. Fetch the deployed `version.json`: `git init -q current && git -C current fetch --depth 1 git@github.com:submersion-app/web.git main` and `git -C current show FETCH_HEAD:version.json > current-version.json`, each tolerated to fail (empty repo or no file).
  8. `python3 scripts/web/stage_hosted_site.py check-newer site/version.json current-version.json` plus `--force` when `inputs.force`.
  9. Publish from `site/`: `git init -q -b main`, identity `github-actions[bot]` / `41898929+github-actions[bot]@users.noreply.github.com`, `git add -A`, `git commit -q -m "Deploy Submersion ${TAG}"`, `git push --force git@github.com:submersion-app/web.git main`; then `echo` the address to `$GITHUB_STEP_SUMMARY`.
  Pass `inputs.*` to shell through `env:`, never inline in `run:`.

- [ ] **Step 3: Callers.** `promote.yml`: job `deploy-web`, `needs: promote`, `uses: ./.github/workflows/deploy-web.yml`, `with: {tag: ${{ needs.promote.outputs.tag }}}`, `secrets: {WEB_DEPLOY_KEY: ${{ secrets.WEB_DEPLOY_KEY }}}`; add `deploy-web` to `notify-failures.needs` and its issue body's list of independent jobs. `release.yml`: job `deploy-web`, `needs: [create-release]`, `if: ${{ !cancelled() && needs.create-release.result == 'success' && !contains(github.ref_name, '-') }}`, same `uses`/`secrets`, `tag: ${{ github.ref_name }}`.

- [ ] **Step 4: Check the workflows.** Run `actionlint .github/workflows/deploy-web.yml .github/workflows/promote.yml .github/workflows/release.yml .github/workflows/build-all.yml` if installed (else a `yaml.safe_load` of each), then `python3.14 scripts/check_ci_success_gate.py` and `python3.14 scripts/check_flutter_setup_retried.py`. Expected: no new errors.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/deploy-web.yml .github/workflows/build-all.yml .github/workflows/promote.yml .github/workflows/release.yml
git commit -m "feat(web): deploy each stable release to web.submersion.app"
```

### Task 3: The Pages repository

Outward-facing, approved by the owner (spec decision 5).

- [ ] **Step 1:** `gh repo create submersion-app/web --public --description "Submersion in a browser, served at https://web.submersion.app. Deployed from submersion-app/submersion; do not edit."` and add a `README.md` on `main` through `gh api -X PUT repos/submersion-app/web/contents/README.md` saying the same and linking the setup doc.
- [ ] **Step 2:** Turn on Pages from `main` at `/` (`gh api -X POST repos/submersion-app/web/pages -f 'source[branch]=main' -f 'source[path]=/'`), then try `gh api -X PUT repos/submersion-app/web/pages -f cname=web.submersion.app`. Expected: Pages enabled; the custom domain may be refused until DNS exists, which the setup doc covers.
- [ ] **Step 3:** Verify with `gh api repos/submersion-app/web/pages`.

### Task 4: Docs

**Files:**
- Create: `docs/developer/web-site-setup.md`
- Modify: `docs/developer/README.md`, `docs/developer/release-secrets-setup.md`, `docs/developer/web.md`, `docs/user/web-app.md`, `web_hosting/HOSTING.md`

- [ ] **Step 1:** `web-site-setup.md`: the spec's five one-time steps, in that order, each saying who does it, with exact commands (`ssh-keygen -t ed25519 -N "" -C web-deploy -f web_deploy_key`, `gh repo deploy-key add web_deploy_key.pub --repo submersion-app/web --allow-write --title "Deploy from submersion-app/submersion"`, `gh secret set WEB_DEPLOY_KEY --repo submersion-app/submersion < web_deploy_key`, `gh variable set GOOGLE_WEB_CLIENT_ID --repo submersion-app/submersion --body <id>`, then delete the local key files); how to deploy by hand and roll back (`gh workflow run deploy-web.yml -f tag=<tag>`, `-f force=true` with the schema warning); what a run without a key or without the client does.
- [ ] **Step 2:** Index it in `docs/developer/README.md` beside "The Web Build"; one line in `release-secrets-setup.md` naming `WEB_DEPLOY_KEY` and `GOOGLE_WEB_CLIENT_ID` with a link.
- [ ] **Step 3:** `web.md`: a short "Submersion's own site" section after "Building" (the build variable, the deploy workflow, the guard, the link). `docs/user/web-app.md`: the intro and "Opening it" lead with `https://web.submersion.app`, self-hosting second; the Google Drive section names the address. `HOSTING.md`: one sentence near the top that Submersion hosts its own copy there.
- [ ] **Step 4:** `python3.14 scripts/check_docs_links.py`. Expected: OK. Scan every touched file for em dashes: `grep -nP "\x{2014}" <files>` gives nothing new.
- [ ] **Step 5: Commit**

```bash
git add docs/developer docs/user/web-app.md web_hosting/HOSTING.md
git commit -m "docs(web): Submersion's own site at web.submersion.app"
```
