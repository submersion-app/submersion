# Docs Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize `docs/` by audience, consolidate design records under `docs/design/`, retire stale documents, and add a CI guard that keeps doc links, code-to-docs references and the retired folders in check.

**Architecture:** Pure `git mv` renames first (one commit, no content), then a one-off scripted reference rewrite that derives its old-to-new map from that rename commit, then hand-written content merges, then a stdlib Python guard wired into the `Script Tests` CI job.

**Tech Stack:** git, Python 3 stdlib (`unittest`, `tempfile`, `re`, `os`), GitHub Actions YAML, Markdown.

**Spec:** `docs/superpowers/specs/2026-10-06-docs-restructure-design.md` (Task 1 moves it to `docs/design/specs/2026-10-06-docs-restructure-design.md`; this plan moves to `docs/design/plans/2026-10-06-docs-restructure.md`).

**Worktree:** `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/build-feature-1584-b48cc1`, branch `ericgriffin/docs-restructure` (no upstream; never push to `main`). Run every command from the worktree root. The Bash tool's shell is zsh: wrap loops in `bash -c '...'`.

## Global Constraints

- No em-dash (U+2014) and no en-dash (U+2013) as sentence punctuation in any file, commit message or PR text.
- No mention of Claude, Claude Code or Anthropic in any commit, PR, issue or file.
- `docs/releases/` and `docs/assets/` keep their paths.
- `CHANGELOG.md` is never edited.
- Design records under `docs/design/` keep their content; only their cross-references to other design records (`docs/superpowers/...`, `docs/plans/...`) are rewritten.
- The spec and this plan are excluded from the scripted rewrite (they describe the move and must keep naming the old paths).
- Every PR must link an issue with `Closes #N`.
- Paths in Python code are built with `os.path.join`; temp space comes from `tempfile`, never a literal `/tmp`.
- Stage explicit paths only; never `git add -A` or `git add .`.

## Review Focus

1. **A link that already works must keep working.** `developer/building.md` links `../../README.md`, which is file-relative and correct today; the relink pass must not rewrite it into something else. Pinned by Task 2 Step 5 (the pass resolves file-relative candidates before docsify-root candidates) and by the guard in Task 8.
2. **A wrapped path in a code comment** (`docs/superpowers/specs/2026-07-10-` then a newline) must still be rewritten. Prefix mapping handles `docs/superpowers/`; Task 2 Step 6 greps for leftovers, including the two known wrapped comments.
3. **A docsify `?id=` query link** (`guide/multi-device-sync.md?id=what-syncs-between-devices` in `developer/database.md`) must become a GitHub anchor (`#what-syncs-between-devices`), not a broken path. Pinned by Task 2 Step 6.
4. **A branch created before this merge** that adds `docs/superpowers/specs/x.md` must fail CI with a message naming the new folder. Pinned by `test_retired_folder_present_fails` in Task 8.
5. **The guard's own test fixtures** contain deliberately broken `docs/...` paths; the guard must not flag its own test file when it scans `scripts/`. Pinned by `test_guard_test_file_is_not_scanned` in Task 8.

---

### Task 0: Prepare the worktree

**Files:** none changed.

- [ ] **Step 1: Initialize submodules and packages**

```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Expected: build_runner ends with `Succeeded after ...`. This is needed only so `flutter analyze` and the pre-push hook can run; the restructure itself touches no Dart code beyond comments.

- [ ] **Step 2: Confirm the starting point**

```bash
git status --short
git log -2 --format='%h %s'
```

Expected: a clean tree, HEAD is the plan commit, HEAD~1 is the spec commit. Record the HEAD sha as `BASE` (used in Task 2).

- [ ] **Step 3: Open the tracking issue**

```bash
gh issue create --repo submersion-app/submersion \
  --title "Reorganize docs/ by audience and consolidate design records" \
  --body "docs/ mixes audiences at its top level, keeps design records in two places (docs/plans/ and docs/superpowers/), carries several stale documents (ARCHITECTURE.md at schema v4, REMAINING_TASKS.md, CODE_OPTIMIZATION_PLAN.md), and has docsify-style links that are broken when read on GitHub.

Reorganize into user/, developer/ (with reference/), contributing/, design/{specs,plans,findings}/, releases/ and assets/; merge or remove the stale documents; and add a CI guard for doc links, docs paths cited from code, and the retired folders.

Design: docs/design/specs/2026-10-06-docs-restructure-design.md"
```

Record the number as `ISSUE`. `gh issue create` leaves the Issue Type empty; set it:

```bash
gh api -X PATCH repos/submersion-app/submersion/issues/$ISSUE -f type=Task
```

---

### Task 1: Renames only (commit 1)

**Files:**
- Move: `docs/superpowers/**` to `docs/design/**`
- Move: `docs/plans/*` to `docs/design/specs/` or `docs/design/plans/`
- Move: `docs/api/*` to `docs/developer/reference/`
- Move: `docs/import-formats/*` to `docs/developer/reference/formats/`
- Move: `docs/index.html`, `docs/.nojekyll`, `docs/_sidebar.md`, `docs/README.md`, `docs/guide/`, `docs/features/` to `docs/user/`

**Interfaces:**
- Produces: a commit whose diff is only renames. Task 2 reads it with `git diff -M --name-status --diff-filter=R BASE RENAME`.

- [ ] **Step 1: Write the move script to the scratchpad**

Write `$SCRATCH/move_docs.sh` (`$SCRATCH` is the session scratchpad directory):

```bash
#!/bin/bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# Design records: superpowers is a straight folder rename.
mkdir -p docs/design
git mv docs/superpowers/specs docs/design/specs
git mv docs/superpowers/plans docs/design/plans
git mv docs/superpowers/findings docs/design/findings

# docs/plans: split by suffix.
for f in docs/plans/*.md; do
  base="$(basename "$f")"
  case "$base" in
    *-design.md) git mv "$f" "docs/design/specs/$base" ;;
    *-plan.md|*-implementation.md|*-impl.md) git mv "$f" "docs/design/plans/$base" ;;
    2026-03-03-check-for-updates-menu.md) git mv "$f" "docs/design/plans/$base" ;;
    *) echo "UNCLASSIFIED: $f" >&2; exit 1 ;;
  esac
done

# Developer reference.
mkdir -p docs/developer/reference/formats
for f in README.md entities.md enums.md providers.md; do
  git mv "docs/api/$f" "docs/developer/reference/$f"
done
for f in cylinder-passport-tag.md macdive-zsamples.md; do
  git mv "docs/import-formats/$f" "docs/developer/reference/formats/$f"
done

# User docs shell (content untouched).
mkdir -p docs/user
for f in index.html .nojekyll _sidebar.md README.md; do
  git mv "docs/$f" "docs/user/$f"
done
git mv docs/guide docs/user/guide
git mv docs/features docs/user/features

# Every source folder must now be empty of tracked files. git mv leaves
# the emptied directories (and any untracked .DS_Store) behind; remove them.
for d in docs/superpowers docs/plans docs/api docs/import-formats; do
  if [ -n "$(git ls-files "$d")" ]; then echo "NOT EMPTY: $d" >&2; exit 1; fi
  if [ -d "$d" ]; then
    find "$d" -name .DS_Store -delete
    find "$d" -depth -type d -empty -delete
  fi
  if [ -e "$d" ]; then echo "UNTRACKED FILES LEFT IN: $d" >&2; ls -R "$d" >&2; exit 1; fi
done
echo "moves done"
```

`providers.md` moves too; Task 6 deletes it, so its history stays readable at the new path.

- [ ] **Step 2: Run it**

```bash
bash "$SCRATCH/move_docs.sh"
```

Expected: `moves done`, no `UNCLASSIFIED`, `NOT EMPTY` or `UNTRACKED FILES LEFT IN` line. If the last one appears, the folder holds untracked work: look at it, move anything worth keeping, and rerun.

- [ ] **Step 3: Verify the commit will be renames only**

```bash
git diff --cached -M --name-status | cut -f1 | sort | uniq -c
git ls-files docs/design/specs | wc -l
git ls-files docs/design/plans | wc -l
```

Expected: every status is `R100`; `docs/design/specs` holds 406 files (353 from superpowers, which includes this branch's spec, plus 53) and `docs/design/plans` holds 492 (445 including this plan, plus 47). If any status is not `R100`, stop: a content change slipped in.

- [ ] **Step 4: Commit**

```bash
git commit -m "docs: move docs into an audience-based layout

Renames only, no content changes, so git log --follow keeps each file's
history:

- docs/superpowers/ becomes docs/design/
- docs/plans/ is split into docs/design/specs/ (*-design.md) and
  docs/design/plans/ (implementation plans)
- docs/api/ and docs/import-formats/ move under docs/developer/reference/
- the docsify site, guide/ and features/ move under docs/user/"
git show --stat -M --format='%h %s' HEAD | tail -3
```

Record this commit's sha as `RENAME`.

---

### Task 2: Scripted reference rewrite (commit 2)

**Files:**
- Create (scratchpad, not committed): `$SCRATCH/rewrite_doc_refs.py`
- Modify: every tracked text file that cites a moved path (about 61 outside `docs/`, plus links inside `docs/`)

**Interfaces:**
- Consumes: `BASE` (pre-move sha) and `RENAME` (Task 1 sha).
- Produces: a tree where `docs/developer/**` and `docs/contributing/**` use file-relative links and no code file cites a moved path. Task 8's guard must pass on it once Tasks 3 to 7 are done.

- [ ] **Step 1: Write the rewrite script**

Write `$SCRATCH/rewrite_doc_refs.py`:

```python
#!/usr/bin/env python3
"""One-off: rewrite references to docs paths moved by the rename commit.

Usage: rewrite_doc_refs.py BASE RENAME
Run from the repository root with the rename commit checked out.
"""

import os
import posixpath
import re
import subprocess
import sys

GITHUB_BLOB = "https://github.com/submersion-app/submersion/blob/main/"
GITHUB_TREE = "https://github.com/submersion-app/submersion/tree/main/"

# Files whose old content folds into another file in Task 3 to 5.
EXTRA = {
    "docs/ARCHITECTURE.md": "docs/developer/architecture.md",
    "docs/FEATURE_ROADMAP.md": "docs/contributing/roadmap.md",
    "docs/MIGRATION_STRATEGY.md": "docs/developer/database.md",
}
# Folders that moved wholesale; used for wrapped or partial paths.
DIR_PREFIXES = [
    ("docs/superpowers/", "docs/design/"),
    ("docs/api/", "docs/developer/reference/"),
    ("docs/import-formats/", "docs/developer/reference/formats/"),
    ("docs/guide/", "docs/user/guide/"),
    ("docs/features/", "docs/user/features/"),
]
NEVER_EDIT = {
    "CHANGELOG.md",
    "docs/design/specs/2026-10-06-docs-restructure-design.md",
    "docs/design/plans/2026-10-06-docs-restructure.md",
}
# The lookbehind skips "docs/" inside a longer path or URL
# (https://example.com/docs/api/...), which is not ours to rewrite.
TOKEN = re.compile(r"(?<![A-Za-z0-9_./-])docs/[A-Za-z0-9_./-]*[A-Za-z0-9_/-]")
LINK = re.compile(r"\]\(([^)\s]+)\)")
FENCE = re.compile(r"^\s*(```|~~~)")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")


def git(*args):
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=True
    ).stdout


def load(base, rename):
    pairs = {}
    out = git("diff", "-M", "--name-status", "--diff-filter=R", base, rename)
    for line in out.splitlines():
        _status, old, new = line.split("\t")
        pairs[old] = new
    old_files = set(git("ls-tree", "-r", "--name-only", base).splitlines())
    old_dirs = set()
    for path in old_files:
        parent = posixpath.dirname(path)
        while parent:
            old_dirs.add(parent)
            parent = posixpath.dirname(parent)
    return pairs, old_files, old_dirs


def map_path(path, pairs):
    if path in pairs:
        return pairs[path]
    if path in EXTRA:
        return EXTRA[path]
    for old, new in DIR_PREFIXES:
        if path.startswith(old):
            return new + path[len(old):]
    return None


def is_design_xref(path):
    return path.startswith("docs/superpowers/") or path.startswith("docs/plans/")


def rewrite_tokens(path, text, pairs, leftovers):
    in_design = path.startswith("docs/design/")

    def sub(match):
        token = match.group(0)
        if in_design and not is_design_xref(token):
            return token
        new = map_path(token, pairs)
        if new is None:
            if token.startswith("docs/plans/") and not in_design:
                leftovers.append(f"{path}: unmapped {token}")
            return token
        return new

    return TOKEN.sub(sub, text)


def split_url(url):
    m = re.match(r"([^?#]*)(?:\?id=([^#&]*))?(#.*)?$", url)
    path, qid, frag = m.group(1), m.group(2), m.group(3)
    if qid and not frag:
        frag = "#" + qid
    return path, frag or ""


def resolve_old(candidates, old_files, old_dirs):
    for cand in candidates:
        if cand in old_files:
            return cand
        if cand in old_dirs and posixpath.join(cand, "README.md") in old_files:
            return posixpath.join(cand, "README.md")
    return None


def relink_dev(new_path, text, pairs, reverse, old_files, old_dirs, report):
    """File-relative links for docs/developer/** and docs/contributing/**."""
    old_path = reverse.get(new_path, new_path)
    out, in_fence = [], False
    for line in text.split("\n"):
        if FENCE.match(line):
            in_fence = not in_fence
        if in_fence:
            out.append(line)
            continue

        def sub(match):
            url = match.group(1)
            if SCHEME.match(url) or url.startswith("#") or url.startswith("/"):
                return match.group(0)
            target, frag = split_url(url)
            if not target:
                return match.group(0)
            candidates = [
                posixpath.normpath(posixpath.join(posixpath.dirname(old_path), target)),
                posixpath.normpath(posixpath.join("docs", target)),
            ]
            old_target = resolve_old(candidates, old_files, old_dirs)
            if old_target is None:
                report.append(f"{new_path}: cannot resolve {url}")
                return match.group(0)
            new_target = map_path(old_target, pairs) or old_target
            if not os.path.exists(new_target):
                report.append(f"{new_path}: target gone {url} -> {new_target}")
                return match.group(0)
            rel = posixpath.relpath(new_target, posixpath.dirname(new_path))
            return f"]({rel}{frag})"

        out.append(LINK.sub(sub, line))
    return "\n".join(out)


def relink_user(new_path, text, pairs, old_files, old_dirs):
    """Docsify links that leave docs/user/ become GitHub URLs."""
    out, in_fence = [], False
    for line in text.split("\n"):
        if FENCE.match(line):
            in_fence = not in_fence
        if in_fence:
            out.append(line)
            continue

        def sub(match):
            url = match.group(1)
            if SCHEME.match(url) or url.startswith("#") or url.startswith("/"):
                return match.group(0)
            target, frag = split_url(url)
            if not target:
                return match.group(0)
            cand = posixpath.normpath(posixpath.join("docs", target))
            if cand in old_dirs and not target.endswith(".md"):
                new_dir = map_path(cand + "/", pairs)
                new_dir = (new_dir or cand + "/").rstrip("/")
                if new_dir.startswith("docs/user"):
                    return match.group(0)
                return f"]({GITHUB_TREE}{new_dir}{frag})"
            if cand not in old_files:
                return match.group(0)
            new_target = map_path(cand, pairs) or cand
            if new_target.startswith("docs/user/"):
                return match.group(0)
            return f"]({GITHUB_BLOB}{new_target}{frag})"

        out.append(LINK.sub(sub, line))
    return "\n".join(out)


def main(argv):
    base, rename = argv[1], argv[2]
    pairs, old_files, old_dirs = load(base, rename)
    reverse = {new: old for old, new in pairs.items()}
    submodules = {
        line.split("\t")[1]
        for line in git("ls-files", "-s").splitlines()
        if line.startswith("160000")
    }
    leftovers, report, changed = [], [], 0
    for path in git("ls-files").splitlines():
        if path in NEVER_EDIT or path in submodules or not os.path.isfile(path):
            continue
        try:
            with open(path, encoding="utf-8", newline="") as fh:
                original = fh.read()
        except UnicodeDecodeError:
            continue
        text = rewrite_tokens(path, original, pairs, leftovers)
        if path.endswith(".md") and (
            path.startswith("docs/developer/") or path.startswith("docs/contributing/")
        ):
            text = relink_dev(path, text, pairs, reverse, old_files, old_dirs, report)
        if path.endswith(".md") and path.startswith("docs/user/"):
            text = relink_user(path, text, pairs, old_files, old_dirs)
        if text != original:
            with open(path, "w", encoding="utf-8", newline="") as fh:
                fh.write(text)
            changed += 1
    print(f"rewrote {changed} files")
    for line in leftovers + report:
        print("  CHECK", line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

`newline=""` preserves CRLF files byte for byte (some `.dart` files are CRLF).

- [ ] **Step 2: Run it**

```bash
python3.14 "$SCRATCH/rewrite_doc_refs.py" "$BASE" "$RENAME"
```

Expected: `rewrote N files` with N around 490 (about 416 design records whose cross-references change, plus about 75 elsewhere: 37 in `lib/`, 18 in `test/`, 3 in `scripts/`, 2 in `.github/`, `README.md`, and docs pages), and no `CHECK` lines (a dry run on 2026-10-06 produced none). Read every `CHECK` line; fix each by hand in this task unless it names `providers.md` (Task 6 removes that link).

- [ ] **Step 3: Confirm no CRLF file was normalized**

```bash
git diff --numstat | awk '$1 != $2 {print}' | head
```

Expected: only Markdown files whose link count changed lines unevenly. A `.dart` file listed with a large added/removed mismatch means line endings changed; restore it with `git checkout -- <file>` and edit it by hand.

- [ ] **Step 4: Inspect the code-side diff**

```bash
git diff --stat -- lib test scripts .github README.md CONTRIBUTING.md CLAUDE.md
git diff -- lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/shared/widgets/forms/form_style.dart .github/workflows/release.yml
```

Expected: only comment or string lines change; the two wrapped comments now read `docs/design/specs/2026-07-10-` and `docs/design/specs/assets/`; `release.yml` line 11 cites `docs/design/specs/2026-02-12-github-releases-design.md`.

- [ ] **Step 5: Spot-check the relink pass**

```bash
grep -n "README.md#running" docs/developer/building.md
grep -n "multi-device-sync" docs/developer/database.md
grep -n "](" docs/developer/README.md | head -12
grep -n "](" docs/developer/reference/README.md | head -8
grep -n "github.com/submersion-app/submersion/blob" docs/user/_sidebar.md docs/user/README.md docs/user/features/README.md
```

Expected: `building.md` still links `../../README.md#running-...` (unchanged); `database.md` links `../user/guide/multi-device-sync.md#what-syncs-between-devices`; `developer/README.md` links `architecture.md`, `../contributing/README.md`, and so on; `reference/README.md` links `entities.md`, `../database.md`, `../../contributing/code-style.md`; user files link contributing pages and the passport tag spec by GitHub URL.

- [ ] **Step 6: Leftover scan**

```bash
git grep -nE "docs/(superpowers|plans/|api/|import-formats|guide/|features/|ARCHITECTURE|FEATURE_ROADMAP|MIGRATION_STRATEGY)" -- . ':!docs/design' ':!CHANGELOG.md'
git grep -nE "\?id=" -- docs/developer docs/contributing
```

Expected: the first command lists nothing outside the `docs/` files that Tasks 3 to 6 delete (`docs/ARCHITECTURE.md`, `docs/FEATURE_ROADMAP.md`, `docs/MIGRATION_STRATEGY.md`, `docs/REMAINING_TASKS.md`, `docs/CODE_OPTIMIZATION_PLAN.md`, `docs/UI_WIREFRAMES.md`). The second lists nothing.

- [ ] **Step 7: Format and commit**

```bash
dart format --set-exit-if-changed $(git diff --name-only -- '*.dart')
git add $(git diff --name-only)
git commit -m "docs: point every reference at the new docs paths

Scripted rewrite derived from the rename commit. Code comments, test
messages, workflow comments and scripts now cite docs/design/ and
docs/developer/reference/. Links in docs/developer/ and docs/contributing/
are converted from docsify root-relative to file-relative so they resolve
on GitHub, and user-doc links that leave docs/user/ become GitHub URLs."
```

`git add $(git diff --name-only)` stages only tracked files this task modified.

---

### Task 3: Merge ARCHITECTURE.md into developer/architecture.md

**Files:**
- Modify: `docs/developer/architecture.md` (new sections before `## Testing Strategy`)
- Delete: `docs/ARCHITECTURE.md`

- [ ] **Step 1: Verify the deco facts before carrying them**

```bash
sed -n 617,681p docs/ARCHITECTURE.md
grep -n "ZH-L16C" lib/core/deco/constants/buhlmann_coefficients.dart | head -2
grep -nE "^(abstract )?class (BuhlmannAlgorithm|VpmBAlgorithm|DecoModel|O2ToxicityCalculator|AscentRateCalculator|GradientFactorPresets)" -r lib/core/deco
grep -nE "default(Warning|Critical)Threshold|defaultSmoothingWindowSeconds" lib/core/deco/ascent_rate_calculator.dart
```

Expected: every class named in Step 3 is found, and the thresholds read `9.0`, `12.0` and `15`. The old section's pseudo-code (`calculateLoading`, `noaaExposureLimits` and so on) does not match the code and is not carried.

- [ ] **Step 2: Verify sync conflict handling**

```bash
sed -n 180,215p lib/core/services/sync/sync_service.dart
sed -n 1,30p lib/core/services/sync/conflict_reference.dart
```

The old four-step list (compare `localUpdatedAt`, `conflict_data` JSON, `conflict` status, resolution UI) is not carried: Step 3's text replaces it with what `SyncConflict`, `getConflicts()` and `ConflictResolution` actually do.

- [ ] **Step 3: Add the sections**

Insert before `## Testing Strategy` in `docs/developer/architecture.md`:

```markdown
## Decompression and Gas Calculations

The decompression and gas code lives in `lib/core/deco/`.

- **Decompression models.** `BuhlmannAlgorithm` (`buhlmann_algorithm.dart`)
  implements Buhlmann ZH-L16C with gradient factors, using the 16
  compartment coefficients in `constants/buhlmann_coefficients.dart`
  (`GradientFactorPresets` holds the presets). `VpmBAlgorithm`
  (`vpm_b_algorithm.dart`) implements VPM-B. Both sit behind the
  `DecoModel` interface in `deco_model.dart`, which also defines
  `DecoSchedule` and `DecoSegment`.
- **Oxygen exposure.** `O2ToxicityCalculator` (`o2_toxicity_calculator.dart`)
  tracks CNS% from the NOAA exposure limits and pulmonary exposure as OTU.
  How a ppO2 between or beyond the table entries is charged is a diver
  setting, `CnsCalculationMethod` (`entities/cns_calculation_method.dart`).
- **Ascent rate.** `AscentRateCalculator` (`ascent_rate_calculator.dart`)
  flags ascents faster than 9 m/min as a warning and faster than 12 m/min
  as critical by default, over a 15-second smoothing window.
- **Related calculators.** Altitude (`altitude_calculator.dart`), gas
  density (`gas_density.dart`), maximum operating depth
  (`max_operating_depth.dart`), semi-closed rebreather loop gas
  (`scr_calculator.dart`), and ascent gas planning (`ascent/`,
  `gas_switch/`).

## Sync Conflict Resolution

A record changed on two devices since they last synced is stored as a
conflict instead of being overwritten: its sync record keeps both versions
in `conflictData`, and the sync reports `hasConflicts`. `SyncService.getConflicts()`
(`lib/core/services/sync/sync_service.dart`) turns those records into
`SyncConflict` objects carrying the local and remote data and their
modification times. Junction rows hold nothing but ids, so
`ConflictReferenceResolver` (`conflict_reference.dart`) resolves each foreign
key to a name or date the Resolve Conflicts dialog can show. The diver then
chooses a `ConflictResolution`: keep local, keep remote, or keep both.

## Platform Support

| Platform | Minimum |
|----------|---------|
| iOS | 15.0 |
| Android | 8.0 (API 26) |
| macOS | 12.0 |
| Windows | 10 |
| Linux | 64-bit desktop with GTK 3 |

The minimums come from `IPHONEOS_DEPLOYMENT_TARGET` in
`ios/Runner.xcodeproj/project.pbxproj`, `minSdk` in
`android/app/build.gradle.kts` and `MACOSX_DEPLOYMENT_TARGET` in
`macos/Runner.xcodeproj/project.pbxproj`.
```

Before committing, re-run the Step 1 and Step 2 commands and confirm every class, file and number above still matches the code; correct the text where it does not. Before writing the Linux row, confirm it against `linux/CMakeLists.txt` and the Linux section of `README.md`; use the README's wording if it differs.

- [ ] **Step 4: Delete the old file and confirm nothing links to it**

```bash
git rm -q docs/ARCHITECTURE.md
git grep -n "ARCHITECTURE.md" -- . ':!docs/design' ':!CHANGELOG.md'
```

Expected: no output (Task 2 repointed `README.md`).

- [ ] **Step 5: Commit**

```bash
git add docs/developer/architecture.md
git commit -m "docs(developer): fold the still-accurate parts of ARCHITECTURE.md into architecture.md

Carries the deco, sync-conflict and platform sections after checking each
against the code; drops the schema-v4 tables, the 1.5.0 banner, the
feature checklist and the roadmap section."
```

---

### Task 4: Roadmap consolidation

**Files:**
- Modify: `docs/contributing/roadmap.md` (body replaced)
- Modify: `docs/contributing/README.md:200`
- Delete: `docs/FEATURE_ROADMAP.md`, `docs/REMAINING_TASKS.md`

- [ ] **Step 1: Save the three sections being kept**

```bash
awk '/^## Contributing to the Roadmap/{p=1} /^## Platform Support/{p=0} p' docs/contributing/roadmap.md > "$SCRATCH/roadmap_contrib.md"
awk '/^## Philosophy/{p=1} p' docs/contributing/roadmap.md > "$SCRATCH/roadmap_tail.md"
wc -l "$SCRATCH"/roadmap_contrib.md "$SCRATCH"/roadmap_tail.md
```

Expected: `roadmap_contrib.md` starts with `## Contributing to the Roadmap`; `roadmap_tail.md` holds `## Philosophy` and `## Version History`.

- [ ] **Step 2: Build the new roadmap.md**

```bash
{
  printf '# Feature Roadmap\n\n'
  printf '> **Last Updated:** 2026-10-06\n'
  printf '> **Current Version:** 1.8.2\n\n'
  printf 'What is built, in progress and planned, by feature category.\n\n---\n\n'
  awk '/^## Roadmap Phases/{p=1} p' docs/FEATURE_ROADMAP.md
  printf '\n---\n\n'
  cat "$SCRATCH/roadmap_contrib.md"
  cat "$SCRATCH/roadmap_tail.md"
} > "$SCRATCH/roadmap_new.md"
mv "$SCRATCH/roadmap_new.md" docs/contributing/roadmap.md
```

The old FEATURE_ROADMAP header block (title, "Comprehensive Development Plan", the 2026-02-24 status lines and the long progress line) is dropped; the body from `## Roadmap Phases` on is kept verbatim.

- [ ] **Step 3: Update the contributing guide line**

In `docs/contributing/README.md`, change:

```markdown
3. Update FEATURE_ROADMAP.md if applicable
```

to:

```markdown
3. Update the [roadmap](roadmap.md) if applicable
```

- [ ] **Step 4: Delete the old files and check references**

```bash
git rm -q docs/FEATURE_ROADMAP.md docs/REMAINING_TASKS.md
git grep -nE "FEATURE_ROADMAP|REMAINING_TASKS" -- . ':!docs/design' ':!CHANGELOG.md'
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add docs/contributing/roadmap.md docs/contributing/README.md
git commit -m "docs(contributing): make roadmap.md the one roadmap

The detailed feature matrix from FEATURE_ROADMAP.md replaces the summary
body, keeping the existing contributing, philosophy and version-history
sections. The path stays the same so its inbound links keep working.
REMAINING_TASKS.md was a hand-synced copy and is removed."
```

---

### Task 5: Fold MIGRATION_STRATEGY.md into developer/database.md

**Files:**
- Modify: `docs/developer/database.md` (new sections after `## Schema Version`, before `## Core Tables`)
- Delete: `docs/MIGRATION_STRATEGY.md`

- [ ] **Step 1: Confirm the facts the new text cites**

```bash
ls lib/core/database/database_version_exception.dart
grep -n "pre-migration backup" lib/core/services/database_service.dart
ls test/core/database | grep -c migration
```

Expected: the exception file exists; `database_service.dart` mentions the pre-migration backup (around line 250); about 190 migration test files.

- [ ] **Step 2: Insert the sections**

Insert immediately before `## Core Tables` in `docs/developer/database.md`:

```markdown
### Migration Principles

- **Never lose data.** A rung transforms or backfills; it never drops a
  column or table that still holds user data without first copying it.
- **Forward only.** There are no down migrations. A database written by a
  newer schema than the running app knows is refused with
  `DatabaseVersionException` (`lib/core/database/database_version_exception.dart`)
  rather than opened.
- **Back up first.** `DatabaseService` takes a pre-migration backup before
  running the ladder (see its open sequence in
  `lib/core/services/database_service.dart`), so a failed upgrade can be
  recovered.

### Testing Migrations

Every rung that transforms data has a test under `test/core/database/`
named `*_migration_test.dart`. The test builds a database at the version
before the rung, inserts rows in the old shape, opens it with the current
schema, and asserts the rows in the new shape.

### New Migration Checklist

1. Follow the numbered steps in [Schema Version](#schema-version).
2. Write the migration test first and watch it fail.
3. If the rung rewrites user data, assert the row count and a sample of
   values before and after.
4. If a restored or synced database must satisfy the change too, add the
   backstop to `before_open.dart`.
5. Run `flutter test test/core/database` before pushing.
```

- [ ] **Step 3: Delete the old file and check references**

```bash
git rm -q docs/MIGRATION_STRATEGY.md
git grep -n "MIGRATION_STRATEGY" -- . ':!docs/design' ':!CHANGELOG.md'
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add docs/developer/database.md
git commit -m "docs(developer): fold migration principles into database.md

MIGRATION_STRATEGY.md described a per-version file scheme and three
classes that do not exist. Its principles, the migration-test convention
and a checklist written for the rung ladder now live beside the ladder's
own documentation."
```

---

### Task 6: Reference corrections and stale deletions

**Files:**
- Modify: `docs/developer/reference/enums.md` (DiveType, ServiceType, BuddyRole sections)
- Modify: `docs/developer/reference/README.md` (drop the Providers link)
- Modify: `docs/developer/state-management.md` (add Provider Dependencies)
- Delete: `docs/developer/reference/providers.md`, `docs/CODE_OPTIMIZATION_PLAN.md`, `docs/UI_WIREFRAMES.md`, `docs/lightroom-approval/`

- [ ] **Step 1: Replace the three stale enum sections**

In `docs/developer/reference/enums.md`, replace the whole `### DiveType` section (heading through the end of its table) with:

```markdown
### Dive Types

Dive types are rows, not an enum: the `dive_types` table
(`lib/core/database/tables/tag_tables.dart`) holds the built-in types
plus each diver's custom ones, mapped to `DiveTypeEntity`
(`lib/features/dive_types/`).
```

Replace the `### ServiceType` section with:

```markdown
### ServiceCategory

The kind of work a maintenance record represents. Renamed from
`ServiceType` in schema v160; "service type" now names the user-extensible
`ServiceKind` catalog. Defined in `lib/core/constants/enums.dart`.

| Value | Display Name |
|-------|--------------|
| `annual` | Annual Service |
| `repair` | Repair |
| `inspection` | Inspection |
| `overhaul` | Overhaul |
| `replacement` | Part Replacement |
| `cleaning` | Cleaning |
| `calibration` | Calibration |
| `warranty` | Warranty Service |
| `recall` | Recall/Safety |
| `other` | Other |
```

Replace the `### BuddyRole` section with:

```markdown
### Dive Roles

Per-dive buddy roles are rows, not an enum: the `dive_roles` table
(`lib/core/database/tables/buddy_tables.dart`, schema v103) holds the
built-in roles, whose ids are the historical names (`buddy`, `diveGuide`,
`instructor`, `student`, `diveMaster`, `solo`), plus custom roles with
UUID ids. `dive_buddies.role` stores the role id.
```

Then confirm the values against the code:

```bash
sed -n 172,192p lib/core/constants/enums.dart
```

- [ ] **Step 2: Carry the one unique providers.md section, then delete it**

`state-management.md` already covers provider types, reading vs watching, async operations and test overrides. Only "Provider Dependencies" is missing. Append to `docs/developer/state-management.md`, before `## Best Practices`:

````markdown
## Provider Dependencies

A provider that derives from others watches them, so it recomputes when
either changes:

```dart
final filteredDivesProvider = Provider<AsyncValue<List<Dive>>>((ref) {
  final divesAsync = ref.watch(diveListNotifierProvider);
  final filter = ref.watch(diveFilterProvider);
  return divesAsync.whenData((dives) => filter.apply(dives));
});
```
````

Then:

```bash
git rm -q docs/developer/reference/providers.md
```

In `docs/developer/reference/README.md`, delete the line linking `providers.md` (the "Riverpod provider reference" bullet) and, if the "Further Reading" list lacks it, add `- [State Management](../state-management.md)`.

- [ ] **Step 3: Delete the remaining stale documents**

```bash
git rm -q docs/CODE_OPTIMIZATION_PLAN.md docs/UI_WIREFRAMES.md
git rm -rq docs/lightroom-approval
git grep -nE "providers\.md|CODE_OPTIMIZATION_PLAN|UI_WIREFRAMES|lightroom-approval" -- . ':!docs/design' ':!CHANGELOG.md'
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add docs/developer/reference/enums.md docs/developer/reference/README.md docs/developer/state-management.md
git commit -m "docs: correct the enum reference and retire stale documents

DiveType and BuddyRole are tables now and ServiceType is ServiceCategory.
providers.md listed many providers that no longer exist; its one unique
section moves to state-management.md. CODE_OPTIMIZATION_PLAN.md,
UI_WIREFRAMES.md and the one-off Lightroom approval packet are removed;
git history keeps them."
```

---

### Task 7: Docs map, sidebar and orphan links

**Files:**
- Create: `docs/README.md`
- Modify: `docs/user/_sidebar.md`
- Modify: `docs/developer/README.md` (Quick Links)
- Modify: `docs/developer/release-process.md` (Pointers)

- [ ] **Step 1: Write the map**

Create `docs/README.md`:

```markdown
# Submersion Documentation

| Folder | For | What is in it |
|--------|-----|---------------|
| [user/](user/) | Divers using the app | The user guide and feature pages |
| [developer/](developer/README.md) | People working on the code | Architecture, database, state management, testing, building and releasing |
| [developer/reference/](developer/reference/README.md) | People working on the code | Entity and enum reference, and file-format specs |
| [contributing/](contributing/README.md) | New contributors | How to contribute, code style, pull requests, the roadmap |
| [design/](design/) | Maintainers | Dated design records: `specs/` (designs), `plans/` (implementation plans), `findings/` (investigations) |
| [releases/](releases/) | Everyone | Release notes for each version |

New design specs go in `design/specs/`, implementation plans in
`design/plans/`, and investigation write-ups in `design/findings/`, each
named `YYYY-MM-DD-<topic>.md`. Design records are historical: they
describe the code as it was when written, so do not update them when the
code changes.
```

- [ ] **Step 2: Trim the docsify sidebar**

In `docs/user/_sidebar.md`, delete the whole `* **Developer Guide**`, `* **Contributing**` and `* **API Reference**` blocks (each heading line and its indented links). Keep `Getting Started`, `User Guide`, `Features` and `Links`. The `Cylinder Passport Tags` entry now points at its GitHub URL (from Task 2) and stays.

- [ ] **Step 3: Add the orphaned developer pages to Quick Links**

In `docs/developer/README.md`, after the `- [Building](building.md) - Build and run instructions` line, add:

```markdown
- [Release Process](release-process.md) - Beta and production releases
- [Release Secrets](release-secrets-setup.md) - Store and signing credentials
- [Play Production Access](play-production-access.md) - Google Play access record and Data safety declaration
- [Reference](reference/README.md) - Entities, enums and file formats
```

Check first that none of the four is already listed (`grep -n "release-process\|release-secrets\|play-production\|reference/" docs/developer/README.md`); add only the missing ones.

- [ ] **Step 4: Link the Play record from the release process**

In `docs/developer/release-process.md`, in `## Pointers`, after the secrets bullet, add:

```markdown
- Google Play production access and the Data safety declaration to
  reaffirm on each update: `docs/developer/play-production-access.md`
```

- [ ] **Step 5: Commit**

```bash
git add docs/README.md docs/user/_sidebar.md docs/developer/README.md docs/developer/release-process.md
git commit -m "docs: add a map of the docs tree and link orphaned pages

docs/README.md says which folder is for whom and where new design
records go. The user sidebar drops its developer, contributing and API
sections, and the release pages that nothing linked are now listed."
```

---

### Task 8: Docs link guard

**Files:**
- Create: `scripts/check_docs_links.py`
- Create: `scripts/check_docs_links_test.py`
- Modify: `.github/workflows/ci.yaml` (`script-tests` job: one new step, plus the coverage `guards` list and one `coverage run` line)

**Interfaces:**
- Produces: `check_links(root) -> list[str]`, `check_code_refs(root) -> list[str]`, `check_retired(root) -> list[str]`, `main(argv) -> int`. Each check returns human-readable failure strings; empty means pass.

- [ ] **Step 1: Write the failing tests**

Create `scripts/check_docs_links_test.py`:

```python
#!/usr/bin/env python3
"""Unit tests for check_docs_links.py."""

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_docs_links", os.path.join(_HERE, "check_docs_links.py")
)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)


def write(root, rel, content=""):
    path = os.path.join(root, *rel.split("/"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)


class LinkTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.addCleanup(self._tmp.cleanup)

    def test_resolving_link_passes(self):
        write(self.root, "docs/developer/testing.md")
        write(self.root, "docs/developer/README.md", "[T](testing.md)\n")
        self.assertEqual(guard.check_links(self.root), [])

    def test_broken_link_fails_with_location(self):
        write(self.root, "docs/developer/README.md", "x\n[T](missing.md)\n")
        failures = guard.check_links(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn(os.path.join("docs", "developer", "README.md") + ":2", failures[0])
        self.assertIn("missing.md", failures[0])

    def test_fragment_is_stripped(self):
        write(self.root, "docs/contributing/code-style.md")
        write(self.root, "docs/contributing/README.md", "[S](code-style.md#imports)\n")
        self.assertEqual(guard.check_links(self.root), [])

    def test_urls_and_anchors_are_skipped(self):
        write(
            self.root,
            "docs/README.md",
            "[a](https://example.com/x.md) [b](#top) [c](mailto:a@b.c) [d](/abs.md)\n",
        )
        self.assertEqual(guard.check_links(self.root), [])

    def test_fenced_code_is_ignored(self):
        write(self.root, "docs/developer/README.md", "```\n[T](missing.md)\n```\n")
        self.assertEqual(guard.check_links(self.root), [])

    def test_excluded_trees_are_not_checked(self):
        write(self.root, "docs/design/specs/a.md", "[x](../../lib/gone.dart)\n")
        write(self.root, "docs/user/guide/a.md", "[x](guide/gone.md)\n")
        self.assertEqual(guard.check_links(self.root), [])

    def test_link_to_directory_with_readme_passes(self):
        write(self.root, "docs/contributing/README.md")
        write(self.root, "docs/README.md", "[C](contributing/)\n")
        self.assertEqual(guard.check_links(self.root), [])


class CodeRefTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.addCleanup(self._tmp.cleanup)

    def test_resolving_reference_passes(self):
        write(self.root, "docs/design/specs/2026-01-01-x-design.md")
        write(self.root, "lib/a.dart", "/// See docs/design/specs/2026-01-01-x-design.md.\n")
        self.assertEqual(guard.check_code_refs(self.root), [])

    def test_broken_reference_fails(self):
        write(self.root, "lib/a.dart", "// docs/developer/gone.md\n")
        failures = guard.check_code_refs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn(os.path.join("lib", "a.dart") + ":1", failures[0])

    def test_lookalikes_are_ignored(self):
        write(
            self.root,
            ".github/workflows/ci.yaml",
            "# a docs/CI-only change; docs/img/x.png; docs/scanned_logs/1.jpg\n",
        )
        self.assertEqual(guard.check_code_refs(self.root), [])

    def test_top_level_files_are_scanned(self):
        write(self.root, "CLAUDE.md", "See docs/contributing/gone.md\n")
        self.assertEqual(len(guard.check_code_refs(self.root)), 1)

    def test_guard_test_file_is_not_scanned(self):
        write(self.root, "scripts/check_docs_links_test.py", "'docs/developer/gone.md'\n")
        self.assertEqual(guard.check_code_refs(self.root), [])


class RetiredTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.addCleanup(self._tmp.cleanup)

    def test_retired_folder_absent_passes(self):
        write(self.root, "docs/design/specs/a.md")
        self.assertEqual(guard.check_retired(self.root), [])

    def test_empty_retired_folder_passes(self):
        os.makedirs(os.path.join(self.root, "docs", "superpowers", "specs"))
        write(self.root, "docs/plans/.DS_Store")
        self.assertEqual(guard.check_retired(self.root), [])

    def test_retired_folder_present_fails(self):
        write(self.root, "docs/superpowers/specs/2026-10-07-x-design.md")
        write(self.root, "docs/plans/2026-10-07-y-plan.md")
        failures = guard.check_retired(self.root)
        self.assertEqual(len(failures), 2)
        self.assertIn("docs/design/", failures[0])
        self.assertIn("docs/design/", failures[1])


class MainTests(unittest.TestCase):
    def test_exit_codes(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, "docs/README.md", "ok\n")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(guard.main(["prog", root]), 0)
            write(root, "docs/README.md", "[x](gone.md)\n")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(guard.main(["prog", root]), 1)
            self.assertIn("gone.md", out.getvalue())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
python3 scripts/check_docs_links_test.py
```

Expected: an error loading `check_docs_links.py` (file not found).

- [ ] **Step 3: Write the guard**

Create `scripts/check_docs_links.py`:

```python
#!/usr/bin/env python3
"""Keep links into and within docs/ resolvable (issue #$ISSUE).

Three checks, each printed as file:line and the unresolved target:

1. Relative Markdown links resolve in docs/README.md, docs/developer/ and
   docs/contributing/. docs/design/ is excluded because design records
   describe the code as it was when written; docs/user/ is excluded until
   the user docs move to their own link rules.
2. A docs path cited from code (lib/, test/, scripts/, .github/,
   README.md, CONTRIBUTING.md, CLAUDE.md) exists. Only paths under a known
   docs folder and ending in a file extension count, which skips lookalikes
   such as "docs/CI-only".
3. The retired folders docs/superpowers/ and docs/plans/ do not exist. A
   branch created before the docs restructure fails here and is told where
   its file belongs.

Pure stdlib. Usage: check_docs_links.py [repo-root]
"""

import os
import re
import sys
from urllib.parse import unquote

LINK_ROOTS = (
    os.path.join("docs", "README.md"),
    os.path.join("docs", "developer"),
    os.path.join("docs", "contributing"),
)
CODE_REF_SOURCES = (
    "lib",
    "test",
    "scripts",
    ".github",
    "README.md",
    "CONTRIBUTING.md",
    "CLAUDE.md",
)
NOT_SCANNED = {os.path.join("scripts", "check_docs_links_test.py")}
SKIP_DIRS = {"__pycache__", "node_modules", ".dart_tool", "build"}
RETIRED = {
    os.path.join("docs", "superpowers"): (
        "move specs to docs/design/specs/, plans to docs/design/plans/ and "
        "findings to docs/design/findings/"
    ),
    os.path.join("docs", "plans"): (
        "move a *-design.md file to docs/design/specs/ and an implementation "
        "plan to docs/design/plans/"
    ),
}

LINK_RE = re.compile(r"\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
FENCE_RE = re.compile(r"^\s*(```|~~~)")
SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
CODE_REF_RE = re.compile(
    r"docs/(?:user|developer|contributing|design|releases|assets)/"
    r"[A-Za-z0-9_./-]+\.(?:md|html|png|jpg|json)\b"
)


def _markdown_files(root):
    for entry in LINK_ROOTS:
        full = os.path.join(root, entry)
        if os.path.isfile(full):
            yield entry
        elif os.path.isdir(full):
            for dirpath, dirnames, filenames in os.walk(full):
                dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
                for name in sorted(filenames):
                    if name.endswith(".md"):
                        yield os.path.relpath(os.path.join(dirpath, name), root)


def _unfenced_lines(text):
    in_fence = False
    for number, line in enumerate(text.splitlines(), 1):
        if FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if not in_fence:
            yield number, line


def check_links(root):
    failures = []
    for rel in _markdown_files(root):
        with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        base = os.path.dirname(os.path.join(root, rel))
        for number, line in _unfenced_lines(text):
            for match in LINK_RE.finditer(line):
                url = match.group(1)
                if SCHEME_RE.match(url) or url.startswith(("#", "/")):
                    continue
                target = unquote(url.split("#", 1)[0].split("?", 1)[0])
                if not target:
                    continue
                if not os.path.exists(os.path.normpath(os.path.join(base, target))):
                    failures.append(f"{rel}:{number}: broken link -> {url}")
    return failures


def _code_files(root):
    for entry in CODE_REF_SOURCES:
        full = os.path.join(root, entry)
        if os.path.isfile(full):
            yield entry
        elif os.path.isdir(full):
            for dirpath, dirnames, filenames in os.walk(full):
                dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
                for name in sorted(filenames):
                    rel = os.path.relpath(os.path.join(dirpath, name), root)
                    if rel not in NOT_SCANNED:
                        yield rel


def check_code_refs(root):
    failures = []
    for rel in _code_files(root):
        try:
            with open(os.path.join(root, rel), encoding="utf-8") as fh:
                lines = fh.read().splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for number, line in enumerate(lines, 1):
            for match in CODE_REF_RE.finditer(line):
                ref = match.group(0)
                if not os.path.exists(os.path.join(root, *ref.split("/"))):
                    failures.append(f"{rel}:{number}: missing docs path -> {ref}")
    return failures


def _has_files(folder):
    """True when the folder holds a file git could track.

    git mv leaves emptied directories behind and Finder drops .DS_Store
    files; neither reaches a commit, so neither counts as the folder
    coming back.
    """
    for _dirpath, _dirnames, filenames in os.walk(folder):
        if any(name != ".DS_Store" for name in filenames):
            return True
    return False


def check_retired(root):
    failures = []
    for folder, advice in sorted(RETIRED.items()):
        if _has_files(os.path.join(root, folder)):
            failures.append(f"{folder}/ is retired: {advice}")
    return failures


def main(argv):
    root = argv[1] if len(argv) > 1 else os.getcwd()
    checks = (
        ("Relative links in docs", check_links),
        ("Docs paths cited from code", check_code_refs),
        ("Retired docs folders", check_retired),
    )
    all_ok = True
    for title, check in checks:
        failures = check(root)
        print(f"{title}: {'ok' if not failures else f'{len(failures)} problem(s)'}")
        for failure in failures:
            print(f"  FAIL  {failure}")
        all_ok = all_ok and not failures
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

Write the real issue number from Task 0 Step 3 in place of `$ISSUE` in the docstring.

- [ ] **Step 4: Run the tests to see them pass**

```bash
python3 scripts/check_docs_links_test.py
```

Expected: `Ran 16 tests ... OK`.

- [ ] **Step 5: Run the guard on the repository**

```bash
python3 scripts/check_docs_links.py
```

Expected: three `ok` lines and exit 0. Any `FAIL` is a real broken link or reference left by Tasks 2 to 7: fix it in the file named, not in the guard.

- [ ] **Step 6: Mutation check (the guard must be able to fail)**

```bash
cp docs/developer/README.md "$SCRATCH/devreadme.bak"
printf '\n[gone](gone.md)\n' >> docs/developer/README.md
python3 scripts/check_docs_links.py; echo "exit=$?"
cp "$SCRATCH/devreadme.bak" docs/developer/README.md
mkdir -p docs/superpowers/specs && touch docs/superpowers/specs/x.md
python3 scripts/check_docs_links.py; echo "exit=$?"
rm -r docs/superpowers
git status --short docs/developer/README.md docs/superpowers
```

Expected: both runs print a `FAIL` line and `exit=1`; the final `git status` prints nothing.

- [ ] **Step 7: Wire it into CI**

In `.github/workflows/ci.yaml`, in the `script-tests` job, add after the `Check dive-download process isolation (manifest)` step:

```yaml
      - name: Check docs links and references
        # Fails on a broken relative link in docs/README.md, docs/developer/
        # or docs/contributing/, on a docs path cited from code that does
        # not exist, or if the retired docs/superpowers/ or docs/plans/
        # folder reappears. This job has no `needs: changes`, so it runs on
        # docs-only pull requests too.
        run: python3 scripts/check_docs_links.py
```

In the `Run Python guard tests with coverage` step, append `,scripts/check_docs_links.py` to the end of the `guards='...'` string (inside the closing quote), and add before the `python3 -m coverage report` line:

```yaml
          python3 -m coverage run --append --include="$guards" \
            scripts/check_docs_links_test.py
```

- [ ] **Step 8: Verify the CI gate still accounts for every job**

```bash
python3 scripts/check_ci_success_gate.py
```

Expected: passes (no job was added, only steps).

- [ ] **Step 9: Commit**

```bash
git add scripts/check_docs_links.py scripts/check_docs_links_test.py .github/workflows/ci.yaml
git commit -m "ci: guard docs links, docs paths cited from code, and retired folders

scripts/check_docs_links.py runs in Script Tests, which also runs on
docs-only pull requests. It fails on a broken relative link in the
developer and contributing docs, on a docs path cited from code that no
longer exists, and on any file under the retired docs/superpowers/ or
docs/plans/ folders, naming docs/design/ as the new home."
```

---

### Task 9: Location rule in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (section `## Claude Specific Instructions`)

- [ ] **Step 1: Add the rule**

After the line `- Anything displaying units should respect the active diver's unit settings`, add:

```markdown
- Design records live under `docs/design/`: specs in `docs/design/specs/`,
  implementation plans in `docs/design/plans/`, investigation write-ups in
  `docs/design/findings/`. This overrides the superpowers skills' default
  location. `scripts/check_docs_links.py` fails CI if a record lands
  anywhere else.
```

- [ ] **Step 2: Check the rule does not trip the guard or the leftover scan**

```bash
python3 scripts/check_docs_links.py
git grep -n "docs/superpowers" -- CLAUDE.md
```

Expected: guard passes; the grep prints nothing.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): record docs/design/ as the home for design records"
```

---

### Task 10: Verification and PR

**Files:** none beyond fix-ups found by verification.

- [ ] **Step 1: Full verification**

```bash
python3 scripts/check_docs_links.py
python3 scripts/check_docs_links_test.py
git grep -nE "docs/(superpowers|plans/|api/|import-formats)" -- . ':!docs/design' ':!CHANGELOG.md' ':!scripts/check_docs_links.py' ':!scripts/check_docs_links_test.py'
dart format --set-exit-if-changed .
flutter analyze
```

Expected: guard exit 0; tests OK; the grep prints nothing; format reports `0 changed`; analyze reports `No issues found!`; and none of this branch's added lines contain an em-dash:

```bash
git diff "$BASE" -U0 | python3 -c "import sys; print(sum(chr(0x2014) in l for l in sys.stdin if l.startswith('+')))"
```

Expected: `0`.

- [ ] **Step 2: Review the commit series**

```bash
git log --format='%h %s' "$BASE"..HEAD
git show --stat -M "$RENAME" | tail -2
```

Expected: 9 to 10 commits in task order; the rename commit shows only renames.

- [ ] **Step 3: Push**

```bash
git push -u origin ericgriffin/docs-restructure
```

The pre-push hook runs format, analyze and affected tests. The `lib/` changes are comments only; if the affected-test run hangs (see the hook-hang note in the developer testing guide), stop it by PID and push with `SKIP_TESTS=1`, since CI runs the full suite.

- [ ] **Step 4: Open the PR**

Use the repository template. Title: `docs: reorganize docs/ by audience and consolidate design records`. Body sections:

- **Summary:** the layout table from `docs/README.md`; the triage outcomes; the guard; the `CLAUDE.md` rule.
- **Issue:** `Closes #$ISSUE`.
- **Review guide:** commit 1 is renames only (`git show --stat -M <sha>`); commits 2 onward carry the content.
- **Maintainer follow-up:** update the untracked `.claude/skills/build-feature/SKILL.md` in the main checkout (lines naming `docs/superpowers/specs/` and `docs/superpowers/plans/`) to `docs/design/`.
- **Screenshots:** delete the section (no UI paths touched).

```bash
gh pr create --repo submersion-app/submersion --base main --head ericgriffin/docs-restructure \
  --title "docs: reorganize docs/ by audience and consolidate design records" \
  --body-file "$SCRATCH/pr_body.md"
```

Then bind the PR in the desktop app (`get_status`, then `bind_pr` if needed) and read its CI.
