# Repository Structure Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Group every script in `scripts/` into purpose folders, fold `tools/`
into `tool/`, remove unused root folders, and add a CI guard plus an index so
the layout stays findable.

**Architecture:** A guard (`scripts/checks/check_scripts_index.py`) is written
first and fails against today's tree; each later task moves one folder group
with `git mv`, rewrites every reference to the moved paths with a throwaway
manifest-driven rewriter, fixes the handful of scripts that locate the repo
root or their data relative to themselves, and runs the moved tests from their
new paths. The last tasks write `scripts/README.md`, wire the guard into CI and
open the PRs.

**Tech Stack:** Python 3 (unittest), bash, GitHub Actions YAML, git.

**Spec:** `docs/design/specs/2026-11-27-repo-structure-cleanup-design.md`

## Global Constraints

- Never write the em-dash character (U+2014), nor an en-dash as prose
  punctuation, in any file, commit message, PR or issue text.
- No mention of Claude, Claude Code or Anthropic in any commit, PR, issue or
  file; no `Co-Authored-By` or session trailers.
- Moves use `git mv`. File names never change; only folders do.
- Dated design records (`docs/design/specs`, `docs/design/plans`,
  `docs/design/findings`) and `CHANGELOG.md` keep their old paths. Everything
  else that names a moved path is updated in the same commit as the move.
- Python edits preserve line endings: open files with `newline=''`.
- Stage explicit paths, never `git add -A` or `git add -u` (a sibling worktree's
  edits or a stale submodule pointer can be swept in). Run
  `git submodule update --init --recursive` before the first commit.
- Local test runs: only test files this work wrote or moved, by path. Never a
  folder or the whole Flutter suite (the pre-push hook and CI run the rest).
- Folder names are fixed by the spec: `checks/`, `testing/`, `ci/`, `release/`,
  `bots/`, `codegen/`, `artwork/`, `datasets/`; `tool/perf/` for the files from
  `tools/`.
- Only `README.md`, `setup.sh` and `requirements.txt` may sit at the top of
  `scripts/`.
- Target release v1.8.7. The PR body links the issue with `Closes #<n>`.

## Review Focus

1. **Pushing a branch cut before the move.** The pre-push hook runs the pushed
   tree's `run_all_tests.sh`. A branch cut before this lands still has it at
   `scripts/run_all_tests.sh`; the hook must find it at either path and still
   bundle. Pinned by a new case in Task 5.
2. **A workflow path written behind a variable** (`$GITHUB_WORKSPACE/scripts/x.py`
   or `"${REPO_ROOT}/scripts/x.py"`) is still checked by the guard, while
   `../scripts/x.sh` and `packages/foo/tool/x.dart` are not. Pinned in Task 1.
3. **An open PR adds a new script at the top of `scripts/` after this merges.**
   The guard's message must name the file and tell its author to move it into a
   purpose folder and index it. Pinned in Task 1.
4. **A generator run from outside the repo root** (a different working
   directory) must still read and write the same files. Pinned by running each
   moved root-resolving script's check mode from `/` in Tasks 9 and 10.
5. **Data files read beside a script** (chamber overlay parts, the soname map,
   the support-matrix rules) must be found after nesting. Pinned by the moved
   tests and a real-file run in Tasks 7, 8 and 11.

---

## The rewriter (used by Tasks 3 to 12)

Not committed. Create it once at
`$SCRATCH/rewrite_paths.py`, where `$SCRATCH` is this session's scratchpad
(any folder outside the repository works). Each task writes a manifest
`$SCRATCH/manifest-<task>.tsv` of `old<TAB>new` lines, repository-relative, and
runs the moves and the rewrite from it:

```bash
while IFS=$'\t' read -r old new; do
  mkdir -p "$(dirname "$new")" && git mv "$old" "$new"
done < "$SCRATCH/manifest-<task>.tsv"
python3 "$SCRATCH/rewrite_paths.py" "$SCRATCH/manifest-<task>.tsv"
```

`rewrite_paths.py MANIFEST [--dry-run]` behaviour:

- Reads every `git ls-files` text file except `docs/design/**` and
  `CHANGELOG.md`; skips files that do not decode as UTF-8.
- For each manifest line, longest `old` first, replaces `old` with `new` where
  the character before `old` is not one of `[A-Za-z0-9_.-]` (a `/` before it is
  allowed, so `$REPO_ROOT/scripts/x.py` and `../scripts/x.sh` are rewritten) and
  the character after it is not one of `[A-Za-z0-9_-]` (so a folder entry such
  as `tool/figure` also rewrites `tool/figure/manifest.json`).
- Writes with `newline=''`; prints `path: N replacements` per changed file.

It cannot see paths split into string pieces (`os.path.join(ROOT, "scripts",
"x.py")`, `ROOT / "tool" / "figure"`) or bare sibling names; each task lists
the ones known from recon, and its sweep step finds any others.

Each move task ends with the same sweep, which must print nothing:

```bash
cut -f1 "$SCRATCH/manifest-<task>.tsv" | while read -r old; do
  git grep -n -F "$old" -- . ':!docs/design' ':!CHANGELOG.md'
done
```

A hit preceded by a path segment that is not part of the moved path (for
example `lib/features/agent_access/data/tools/`) is a false match; leave it.

---

### Task 0: Issue, branch and spec

**Files:**
- Commit: `docs/design/specs/2026-11-27-repo-structure-cleanup-design.md`,
  `docs/design/plans/2026-11-27-repo-structure-cleanup.md`

- [ ] **Step 1: Prepare the worktree**

Run: `git submodule update --init --recursive && flutter pub get`
Expected: both exit 0.

- [ ] **Step 2: Open the issue**

`gh issue create --repo submersion-app/submersion` titled
`Reorganize scripts/ into purpose folders and remove unused root folders`, body
summarising the spec's Goals and linking the spec path. Set its Issue Type to
Task over REST (`gh api -X PATCH repos/submersion-app/submersion/issues/<n> -f type=Task`),
add it to project 5 (`gh project item-add 5 --owner submersion-app --url <issue url>`)
and set the project's text field `Release` to `v1.8.7`
(`gh project field-list 5 --owner submersion-app` gives the field id).
Expected: the issue shows Type Task and Release v1.8.7.

- [ ] **Step 3: Commit the spec and plan**

```bash
git add docs/design/specs/2026-11-27-repo-structure-cleanup-design.md docs/design/plans/2026-11-27-repo-structure-cleanup.md
git commit -m "docs: design and plan for the repository structure cleanup (#<n>)"
```

---

### Task 1: The guard, test first

**Files:**
- Create: `scripts/checks/check_scripts_index.py`
- Test: `scripts/checks/check_scripts_index_test.py`

**Interfaces:**
- Produces: `find_problems(root: str, files: list[str]) -> list[str]`, where
  `files` are repository-relative tracked paths and `root` is used only to read
  their contents; `main(argv: list[str] | None = None) -> int` collects `files`
  from `git ls-files` at the repository root (three levels above the script,
  overridable with `--root`), prints each problem on its own line, and returns
  1 when any exist. Constants `TOP_LEVEL_ALLOWED = {"README.md", "setup.sh",
  "requirements.txt"}` and `RETIRED = ("tools/", "codemaps/", ".reports/",
  "scripts/data/", "scripts/fixtures/")`.

Rules `find_problems` enforces (each one problem string naming the file and the
fix):

1. A script under `scripts/` or `tool/` that `scripts/README.md` does not name.
   A script is a `.py`, `.sh` or `.rb` file, or a `.dart` file declaring a
   top-level `main(`; not a script: names ending `_test.<ext>`, `conftest.py`,
   `__init__.py`, and anything under a `fixtures/` folder. Fix text:
   `add it to scripts/README.md`.
2. A path in a backtick code span of `scripts/README.md` starting with
   `scripts/` or `tool/` that is not in `files` and is not a folder prefix of
   one. Fix text: `remove or correct the index entry`.
3. A file directly under `scripts/` whose name is not in `TOP_LEVEL_ALLOWED`.
   Fix text: `move it into a purpose folder (see scripts/README.md) and index it`.
4. Any file under a `RETIRED` folder. Fix text names the folder and says it was
   retired by the cleanup.
5. In every file under `.github/` and in `hooks/pre-push`, a token
   `(scripts|tool)/<path>.(py|sh|rb|dart|json|txt)` that is not in `files`.
   The token counts at the start of a word, or right after `$NAME/` or
   `${NAME}/`; it does not count after `../` or after another path segment.
   Fix text: `the file moved or was deleted; update the path`.

- [ ] **Step 1: Write the failing tests** in `check_scripts_index_test.py`,
  loading the guard with `importlib.util.spec_from_file_location` as
  `scripts/check_docs_links_test.py` does, and building each case in a
  `tempfile.TemporaryDirectory` with a `write(root, rel, content)` helper:

  - `test_clean_tree_has_no_problems`: `scripts/README.md` naming
    `scripts/checks/a.py`; files README, `scripts/checks/a.py`,
    `scripts/checks/a_test.py` -> `[]`.
  - `test_unindexed_script_is_reported`: same tree without the README entry ->
    one problem containing `scripts/checks/a.py` and `add it to scripts/README.md`.
  - `test_tests_conftest_and_fixtures_are_exempt`: unindexed
    `scripts/web/conftest.py`, `scripts/web/x_test.py`,
    `scripts/web/fixtures/y.py` -> `[]`.
  - `test_dart_entry_point_needs_index_but_library_does_not`: `tool/a.dart`
    with `void main() {}` and `tool/src/b.dart` without `main` -> exactly one
    problem, naming `tool/a.dart`.
  - `test_dangling_index_entry_is_reported`: README names `scripts/gone.py` ->
    one problem containing `scripts/gone.py` and `remove or correct`.
  - `test_index_folder_entry_is_not_dangling`: README names `scripts/brand/`
    and `scripts/brand/x.py` exists -> no dangling problem.
  - `test_loose_top_level_file_is_reported`: `scripts/new_thing.py`, indexed ->
    one problem containing `scripts/new_thing.py` and `move it into a purpose folder`.
  - `test_allowed_top_level_files_pass`: `scripts/setup.sh` (indexed) and
    `scripts/requirements.txt` -> `[]`.
  - `test_retired_folder_is_reported`: one file each under `tools/` and
    `scripts/data/` -> two problems naming those folders.
  - `test_missing_workflow_path_is_reported`: `.github/workflows/w.yml`
    containing `run: python3 scripts/checks/gone.py` -> one problem naming
    `.github/workflows/w.yml` and `scripts/checks/gone.py`.
  - `test_variable_prefixed_paths_are_checked`: a workflow line
    `python3 "$GITHUB_WORKSPACE/scripts/gone.py"` and a hook line
    `. "${REPO_ROOT}/scripts/gone2.sh"` -> two problems.
  - `test_relative_and_nested_paths_are_ignored`: a workflow line naming
    `../scripts/gone.sh` and `packages/foo/tool/gone.dart` -> `[]`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 scripts/checks/check_scripts_index_test.py`
Expected: FAIL, the guard module does not exist.

- [ ] **Step 3: Implement `find_problems` and `main`** in
  `scripts/checks/check_scripts_index.py`, with a module docstring in the style
  of the other `check_*.py` files (what it verifies, why, issue number).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 scripts/checks/check_scripts_index_test.py`
Expected: OK, 12 tests.

- [ ] **Step 5: Run the guard against the real tree**

Run: `python3 scripts/checks/check_scripts_index.py`
Expected: exit 1 with many problems (every unindexed script, every loose
top-level script, the retired `tools/`, `scripts/data/` and `scripts/fixtures/`).
This list is the progress meter for Tasks 2 to 13: it reaches zero in Task 13.

- [ ] **Step 6: Commit**

```bash
git add scripts/checks/check_scripts_index.py scripts/checks/check_scripts_index_test.py
git commit -m "feat(scripts): guard that every script is indexed and every workflow path exists (#<n>)"
```

---

### Task 2: Root folders and files

**Files:**
- Delete: `codemaps/` (3 files), `.reports/codemap-diff.txt`
- Move: `codecov.yml` -> `.github/codecov.yml`
- Delete: `flutter_launcher_icons.yaml`; Modify: `pubspec.yaml` (append its
  `flutter_launcher_icons:` block verbatim as a top-level section)
- Modify: `.github/workflows/beta.yml:122`, `.github/workflows/ci.yaml:129`
  (the docs-only path patterns: `codecov.yml` becomes `.github/codecov.yml`),
  `ci.yaml:377-379` comments, `scripts/filter_trivial_coverage.py:33` comment,
  `scripts/brand/README.md:22`, `docs/developer/play-production-access.md:730`
  (each names the new location: `.github/codecov.yml`, or the
  `flutter_launcher_icons` section of `pubspec.yaml`)

- [ ] **Step 1: Make the moves and edits** with `git rm -r` and `git mv`.
- [ ] **Step 2: Verify**

Run: `flutter pub get && git grep -n -E "codemaps/|\.reports/|(^|[^/])codecov\.yml|flutter_launcher_icons\.yaml" -- . ':!docs/design' ':!CHANGELOG.md'`
Expected: `pub get` exits 0; the grep prints only lines naming `.github/codecov.yml`.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml .github/codecov.yml .github/workflows/beta.yml .github/workflows/ci.yaml scripts/filter_trivial_coverage.py scripts/brand/README.md docs/developer/play-production-access.md
git commit -m "chore: drop stale codemaps, move codecov config to .github, fold launcher icon config into pubspec (#<n>)"
```
(`git rm` and `git mv` already staged the deletions and the move.)

---

### Task 3: Retire the Statistics to Insights rename script

**Files:**
- Delete: `scripts/rename_statistics_to_insights.py`,
  `scripts/rename_statistics_to_insights_test.py`
- Modify: `.github/workflows/ci.yaml` (remove the step "Run Statistics to
  Insights rename script tests and checks", around line 848)

- [ ] **Step 1: Delete and edit.**
- [ ] **Step 2: Verify**

Run: `git grep -n rename_statistics_to_insights -- . ':!docs/design' ':!CHANGELOG.md'`
Expected: no output.

- [ ] **Step 3: Commit** (`git commit -m "chore(ci): retire the Statistics to Insights rename guard (#<n>)"`).

---

### Task 4: `scripts/checks/`

**Files:**
- Move: every `scripts/check_*.py` (17 guards and 16 tests) to
  `scripts/checks/`.
- Modify (root depth, one more level up): `check_docs_links.py:88`
  (`DEFAULT_ROOT`), `check_dependabot_gemfiles.py:271`,
  `check_ruby_versions.py:110`, `check_jni_local_refs_test.py:23` (`_REPO_ROOT`),
  and any other hit of the sweep in Step 3.
- Modify (split path): `scripts/web/stage_hosted_site.py:43` builds
  `dirname(_HERE)/check_web_bundle.py`; it becomes
  `scripts/checks/check_web_bundle.py`. `scripts/web/test_web.sh:48` is handled
  by the rewriter.

- [ ] **Step 1: Write the manifest** (`ls scripts/check_*.py` gives the rows;
  `new` is `scripts/checks/<name>`), **run the moves and the rewriter.**
- [ ] **Step 2: Fix the split paths listed above.**
- [ ] **Step 3: Find other root-relative code**

Run: `git grep -n -E "__file__|dirname \"\\\$0\"|BASH_SOURCE|parent\.parent|os\.pardir|parents\[" -- scripts/checks`
Expected: every hit that derives the repository root now goes up two levels
from `scripts/checks/`; hits that only find a sibling file are unchanged.

- [ ] **Step 4: Run the moved tests and the old-path sweep**

Run: `for t in scripts/checks/*_test.py scripts/web/stage_hosted_site_test.py; do python3 "$t" || echo "FAIL $t"; done`, then the sweep.
Expected: no `FAIL` line; the sweep prints nothing. Also run
`python3 scripts/checks/check_docs_links.py` and
`python3 scripts/checks/check_ruby_versions.py`: both exit 0, proving the root
resolves from the new depth.

- [ ] **Step 5: Commit** the moved files and every file the rewriter printed:
  `git commit -m "chore(scripts): move CI guards into scripts/checks (#<n>)"`.

---

### Task 5: `scripts/testing/` and the pre-push hook

**Files:**
- Move to `scripts/testing/`: `bundle_tests.py`, `bundle_tests_test.py`,
  `run_all_tests.sh`, `run_all_tests_test.sh`, `run_perf_tests.sh`,
  `test_concurrency.sh`, `report_inherited_failures.py`,
  `report_inherited_failures_test.py`, `filter_trivial_coverage.py`,
  `filter_trivial_coverage_test.py`, `pre_push_hook_test.sh`,
  `run_color_encode_it.sh`, and `tool/generate_scrubber_sample_dives.py`.
- Modify (root depth): `run_all_tests.sh:54`, `run_all_tests_test.sh:13`,
  `pre_push_hook_test.sh:17`, `run_color_encode_it.sh:20`
  (`dirname "$0"/..` becomes `/../..`), `generate_scrubber_sample_dives.py:18`.
- Modify: `run_all_tests_test.sh:61` and the `cp` lines in
  `pre_push_hook_test.sh` (106, 358, 675-677, 685, 874, 1121, 1135) build fake
  trees; their destinations become `scripts/testing/<name>` (the rewriter fixes
  the `$REPO_ROOT/scripts/...` sources; check the destinations by hand).
- Modify: `hooks/pre-push:442-451` and `:585-602`.

**Interfaces:**
- Produces in `hooks/pre-push`: a helper `pushed_run_all_tests()` that prints
  `scripts/testing/run_all_tests.sh` when that file exists, else
  `scripts/run_all_tests.sh` when that exists, else nothing.
  `selection_bundles` and `run_selected` use it instead of the literal path.
  The concurrency source tries `$HOOK_SCRIPTS/testing/test_concurrency.sh`,
  then `$HOOK_SCRIPTS/test_concurrency.sh`, then the existing fallback of 6.

- [ ] **Step 1: Write the failing hook test.** In `pre_push_hook_test.sh`,
  following its existing case layout, add
  `test_bundles_a_branch_cut_before_the_move`: a fake pushed tree with
  `run_all_tests.sh` only at `scripts/run_all_tests.sh` (old layout) and a
  selection at or above `TEST_BUNDLE_MIN_FILES`; assert the hook ran that
  script with `TEST_FILES_FROM` set. Add the mirror case
  `test_bundles_a_branch_with_the_new_layout` (script only at
  `scripts/testing/run_all_tests.sh`).
- [ ] **Step 2: Run it before any move to verify the new-layout case fails**

Run: `bash scripts/pre_push_hook_test.sh`
Expected: `test_bundles_a_branch_with_the_new_layout` FAILS (the hook looks
only at `scripts/run_all_tests.sh`); the old-layout case passes.

- [ ] **Step 3: Write the manifest, run the moves and the rewriter, make the
  root-depth and `cp` destination edits, and implement `pushed_run_all_tests`
  and the two-path concurrency source in `hooks/pre-push`.**
- [ ] **Step 4: Run the changed tests**

Run: `bash scripts/testing/pre_push_hook_test.sh && bash scripts/testing/run_all_tests_test.sh && python3 scripts/testing/bundle_tests_test.py && python3 scripts/testing/report_inherited_failures_test.py && python3 scripts/testing/filter_trivial_coverage_test.py`
Expected: all pass, including both new hook cases.

- [ ] **Step 5: Run the Dart test that reads a moved script**

Run: `flutter test test/architecture/coverage_filter_mask_parity_test.dart`
Expected: PASS (it reads `scripts/testing/filter_trivial_coverage.py`).

- [ ] **Step 6: Sweep, then commit**
  (`git commit -m "chore(scripts): move test tooling into scripts/testing; hook reads either layout (#<n>)"`).

---

### Task 6: `scripts/ci/` and `scripts/web/build_web.sh`

**Files:**
- Move to `scripts/ci/`: `apt_mirror.py`, `apt_mirror_test.py`,
  `fix_macho_symbol_order.py`, `fix_macho_symbol_order_test.py`.
- Move: `scripts/build_web.sh` -> `scripts/web/build_web.sh`; modify its line
  30 (`dirname "$0"/..` becomes `/../..`) and its calls to sibling web scripts
  if they assume `scripts/` as the base.

- [ ] **Step 1: Manifest, moves, rewriter, the `build_web.sh` root edit.**
- [ ] **Step 2: Verify**

Run: `python3 scripts/ci/apt_mirror_test.py && python3 scripts/ci/fix_macho_symbol_order_test.py && bash -n scripts/web/build_web.sh`, then the sweep.
Expected: all pass; the sweep prints nothing.

- [ ] **Step 3: Commit** (`chore(scripts): move runner and build fixes into scripts/ci (#<n>)`).

---

### Task 7: `scripts/release/` additions

**Files:**
- Move to `scripts/release/`: `generate_appcast.sh`,
  `generate_appcast_beta.sh`, `generate_appcast_beta_test.sh`,
  `generate_release_notes_html.sh`, `generate_release_notes_html_test.sh`,
  `linux_package_deps.py`, `linux_package_deps_test.py`, `gen_udev_rules.py`,
  `gen_udev_rules_test.py`, and `scripts/data/linux_soname_map.json` ->
  `scripts/release/linux_soname_map.json`.
- Modify: `linux_package_deps.py:32` (the map now sits beside the script, no
  `data` segment); `release/stage_linux_package.py:34`
  (`os.path.join(REPO_ROOT, "scripts", "gen_udev_rules.py")` becomes
  `..., "scripts", "release", "gen_udev_rules.py"`).

- [ ] **Step 1: Manifest, moves, rewriter, the two edits.**
- [ ] **Step 2: Verify**

Run: `bash scripts/release/generate_appcast_beta_test.sh && bash scripts/release/generate_release_notes_html_test.sh && python3 scripts/release/linux_package_deps_test.py && python3 scripts/release/gen_udev_rules_test.py && python3 scripts/release/stage_linux_package_test.py && bash scripts/release/generate_changelog_test.sh`, then the sweep.
Expected: all pass (the deps test reads the real soname map); the sweep prints nothing.

- [ ] **Step 3: Commit** (`chore(scripts): gather the remaining release steps in scripts/release (#<n>)`).

---

### Task 8: `scripts/bots/`

**Files:**
- Move to `scripts/bots/`: `beta_failure_alert.py`, `beta_failure_alert_test.py`,
  `beta_failure_alert_timeout_test.py`, `dependabot_failure_alert.py`,
  `dependabot_failure_alert_test.py`, `demo_package_age_alert.py`,
  `demo_package_age_alert_test.py`, `snapshot_downloads.py`,
  `snapshot_downloads_test.py`, `wiki_howto_index.py`, `wiki_howto_index_test.py`,
  `export_support_matrix_catalog.py`, `export_support_matrix_catalog_test.py`,
  and `scripts/data/support_matrix_platform_rules.json` ->
  `scripts/bots/support_matrix_platform_rules.json`.
- Modify: `export_support_matrix_catalog.py:21` onwards (`_ROOT` goes up two
  levels; the default rules path loses its `data` segment).

- [ ] **Step 1: Manifest, moves, rewriter, the export edits.**
- [ ] **Step 2: Verify**

Run: `for t in scripts/bots/*_test.py; do python3 "$t" || echo "FAIL $t"; done`, then the sweep.
Expected: no `FAIL`; the sweep prints nothing.

- [ ] **Step 3: Commit** (`chore(scripts): move scheduled alert and publishing bots into scripts/bots (#<n>)`).

---

### Task 9: `scripts/codegen/`

**Files:**
- Move to `scripts/codegen/`: `gen_embedded_ca_bundle.py`,
  `gen_query_error_codes.py`, `gen_query_label_lookup.py`,
  `generate_eff_wordlist.py`, `generate_crypto_test_vectors.py`.
- Modify (root depth): `gen_embedded_ca_bundle.py:35`,
  `gen_query_error_codes.py:18`, `gen_query_label_lookup.py:18` (`parent.parent`
  becomes `parents[2]`), and any root or output path in the other two found by
  the Task 4 sweep command pointed at `scripts/codegen`.
- Modify: the generated-file headers in `lib/` that name the generator
  (rewriter), for example `lib/core/network/embedded_ca_bundle.dart:2`.

- [ ] **Step 1: Manifest, moves, rewriter, root edits.**
- [ ] **Step 2: Prove the generators still target the same files**

Run, from `/`: `python3 <repo>/scripts/codegen/gen_query_error_codes.py` and
`python3 <repo>/scripts/codegen/gen_query_label_lookup.py` (use each script's
check or dry-run mode if it has one), then `git -C <repo> status --short lib/`.
Expected: no change under `lib/` beyond the header comments the rewriter
edited: the regenerated output is byte-identical.

- [ ] **Step 3: Sweep, then commit** (`chore(scripts): move code generators into scripts/codegen (#<n>)`).

---

### Task 10: `scripts/artwork/`

**Files:**
- Move: `tool/build_equipment_icon_font.py`, `tool/equipment_glyphs.py`,
  `tool/build_figure_artwork.py` -> `scripts/artwork/`; `tool/figure/` ->
  `scripts/artwork/figure/`.
- Modify: `build_equipment_icon_font.py:39` (`REPO` up two levels);
  `build_figure_artwork.py:28-29` (`ROOT = ...parents[2]`,
  `SRC = ROOT / "scripts" / "artwork" / "figure"`) and its usage docstring;
  `lib/core/icons/submersion_icons.dart` comments (rewriter).

- [ ] **Step 1: Manifest, moves, rewriter, the two root edits.**
- [ ] **Step 2: Verify from outside the repo**

Run, from `/`: `python3 <repo>/scripts/artwork/build_figure_artwork.py --verify`
Expected: exit 0 (sources found, Dart file current).
Run: `python3 <repo>/scripts/artwork/build_equipment_icon_font.py` in its
check mode if it has one, otherwise run it and confirm `git status` shows no
change to the generated font or Dart file.

- [ ] **Step 3: Sweep, then commit** (`chore(scripts): move artwork builders and their sources into scripts/artwork (#<n>)`).

---

### Task 11: `scripts/datasets/`

**Files:**
- `scripts/datasets/chambers/`: `chamber_geocode.py`, `chamber_harvester.py`,
  `chamber_harvester_test.py`, `chamber_sources.py`, `chamber_sources_test.py`,
  `chamber_leads.json`, `.chamber_geocode_cache.json`,
  `scripts/data/chamber_coordinates.json`, `scripts/data/chambers_overlay.json`,
  `scripts/data/overlay_parts/` -> `chambers/overlay_parts/`,
  `scripts/fixtures/chambers/` -> `chambers/fixtures/`.
- `scripts/datasets/dive_sites/`: `dive_site_harvester.py`, its test.
- `scripts/datasets/sea_areas/`: `sea_area_harvester.py`, its test.
- `scripts/datasets/site_catalogue/`: `site_catalogue_intake.py`, its test.
- `scripts/geography/` -> `scripts/datasets/geography/`;
  `scripts/tide/` -> `scripts/datasets/tide/`.
- Modify: `chamber_harvester.py:24-30` (`PROJECT_ROOT` up three levels; overlay,
  overlay parts and fixtures paths lose their `data`/`fixtures/chambers`
  prefixes and become `SCRIPT_DIR`-relative `chambers_overlay.json`,
  `overlay_parts`, `fixtures`); `chamber_geocode.py:82` (`chamber_coordinates.json`
  beside the script); `dive_site_harvester.py:40`, `sea_area_harvester.py:50`,
  `site_catalogue_intake.py:25` (root up three levels); the geography and tide
  scripts' root resolution (sweep command on `scripts/datasets`).
- Modify (rewriter): `test/features/safety/data/chambers_dataset_test.dart`,
  `test/features/dive_sites/data/services/bundled_osm_asset_metadata_test.dart`,
  `test/features/dive_sites/data/catalogue/site_catalogue_contract_test.dart`,
  `lib/core/services/geocoding/sea_area_*.dart` comments,
  `.github/workflows/site-catalogue-release.yml`, `ci.yaml`.

- [ ] **Step 1: Manifest, moves, rewriter, root and data-path edits.** After it,
  `scripts/data/` and `scripts/fixtures/` hold no tracked files.
- [ ] **Step 2: Verify**

Run: `for t in $(git ls-files 'scripts/datasets/*_test.py'); do python3 "$t" || echo "FAIL $t"; done`
Expected: no `FAIL` (the chamber tests read the real overlay parts and fixtures).
Run: `flutter test test/features/safety/data/chambers_dataset_test.dart test/features/dive_sites/data/services/bundled_osm_asset_metadata_test.dart test/features/dive_sites/data/catalogue/site_catalogue_contract_test.dart`
Expected: PASS (only if the rewriter changed them; skip any it did not touch).

- [ ] **Step 3: Sweep, then commit** (`chore(scripts): group dataset harvesters with their data in scripts/datasets (#<n>)`).

---

### Task 12: `tools/` into `tool/perf/`

**Files:**
- Move: `tools/db_bench.dart`, `tools/synth_fixture.dart`, `tools/vmcap.dart` ->
  `tool/perf/`. Their usage lines (`dart run tools/...`) are rewritten by the
  rewriter, as is `lib/core/database/performance_indexes.dart:15`.

- [ ] **Step 1: Manifest, moves, rewriter.**
- [ ] **Step 2: Verify**

Run: `dart analyze tool/perf && dart run tool/perf/synth_fixture.dart`
Expected: no analyzer issues; the second prints its usage line naming
`tool/perf/synth_fixture.dart`.

- [ ] **Step 3: Sweep, then commit** (`chore(tool): fold tools/ into tool/perf (#<n>)`).

---

### Task 13: Index, CLAUDE.md and CI wiring

**Files:**
- Create: `scripts/README.md`
- Modify: `CLAUDE.md` (Code Organization), `.github/workflows/ci.yaml`

- [ ] **Step 1: Write `scripts/README.md`.** Opening paragraph states the rule
  (non-Dart scripts here by purpose, tests beside their script, Dart tools in
  `tool/`, only `README.md`, `setup.sh` and `requirements.txt` at the top, the
  guard enforces it). Then one `##` section per folder, in the order of the
  spec's layout table, then `## tool/`. Each section opens with one sentence on
  what belongs there, followed by one bullet per script:
  `` - `scripts/checks/check_docs_links.py`: keeps links into docs/ resolvable. ``
  Take each line from the script's own docstring or header comment. Existing
  folder READMEs (`brand/`, `deco_golden/`, `readme/`, `tide/`,
  `demo_data/`) are linked from their section, not repeated.
- [ ] **Step 2: Run the guard until it is clean**

Run: `python3 scripts/checks/check_scripts_index.py`
Expected: exit 0, no output. Fix every remaining problem by indexing or moving
the file, never by loosening the guard.

- [ ] **Step 3: Add one line to `CLAUDE.md`** under Critical Rules, Code
  Organization: `- Scripts live in scripts/<purpose>/ (Python, shell) and tool/ (Dart); scripts/README.md indexes every one, and check_scripts_index.py fails CI on a loose or unindexed script.`
- [ ] **Step 4: Wire the guard into `ci.yaml`.** A step
  `Check every script is indexed and every workflow path exists`, placed after
  `Check every apt install repoints the mirror first`, running
  `python3 scripts/checks/check_scripts_index.py`, with a comment naming the
  issue. Add `scripts/checks/check_scripts_index.py` to the `guards` coverage
  list and a `coverage run --append` line for its test.
- [ ] **Step 5: Verify**

Run: `python3 scripts/checks/check_scripts_index.py && python3 scripts/checks/check_scripts_index_test.py && python3 scripts/checks/check_ci_success_gate.py && python3 scripts/checks/check_docs_links.py && python3 -c "import yaml,glob; [yaml.safe_load(open(f)) for f in glob.glob('.github/workflows/*.y*ml')]"`
Expected: all exit 0.

- [ ] **Step 6: Commit** (`docs(scripts): index every script and enforce it in CI (#<n>)`).

---

### Task 14: Final check, PRs and merge

- [ ] **Step 1: Whole-change sweep.** Concatenate every manifest and run the
  sweep over all of them. Expected: no output.
- [ ] **Step 2: Em-dash scan.** `git diff main | grep "^+" | grep $'\xe2\x80\x94'`
  prints nothing: no added line carries an em-dash.
- [ ] **Step 3: Push** (the pre-push hook runs format, analyze and the affected
  tests) and open the PR against `main`: title
  `Reorganize scripts/ into purpose folders`, body with a Summary of the moves,
  `Closes #<n>`, a note that `lib/core/icons/` and other `lib/` hits are
  comment-only, and "No visible UI change" ticked with that reason.
- [ ] **Step 4: Open the website PR.** In a scratch clone of
  `submersion-app/submersion-website`, change
  `tools/support-matrix/SWEEP.md` so `scripts/export_support_matrix_catalog.py`
  reads `scripts/bots/export_support_matrix_catalog.py`; branch, commit, push,
  open a PR whose body says it must merge right after
  `submersion-app/submersion#<pr>` and `Refs submersion-app/submersion#<n>`.
- [ ] **Step 5: Merge timing (maintainer).** Merge the main PR only when
  `gh run list --repo submersion-app/submersion --branch main --status in_progress`
  prints nothing, and merge nothing else to `main` until this PR's CI and the
  beta it triggers have finished. Ask the maintainer before merging either PR;
  the website PR merges right after the main one.
