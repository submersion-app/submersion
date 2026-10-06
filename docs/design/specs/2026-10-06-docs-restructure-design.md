# Docs Restructure (Spec 1 of 2)

**Status:** Approved design, 2026-10-06
**Scope:** Repository `docs/` tree only. Spec 2 (user documentation sourced
from `docs/user/` and published to submersion.app) is a separate design and
builds on the layout this spec lands. The GitHub wiki is out of scope for both
and stays free for other uses.

## Goal

Make `docs/` organized by audience, so a reader can tell from the top-level
folder who a document is for, and remove stale or duplicated documents
instead of carrying them forward. Design records (specs, implementation plans,
findings) get one home with a neutral name, and the move is enforced in CI so
it cannot silently regress.

## Current state (origin/main at 964eeca)

- `docs/superpowers/` holds 797 files: `specs/` 352, `plans/` 444,
  `findings/` 1.
- `docs/plans/` holds 100 older design records that mix specs and
  implementation plans in one folder.
- Eight loose files sit at the `docs/` root, several stale (ARCHITECTURE.md
  still says schema version 4; the code is at 264).
- `docs/api/` and `docs/import-formats/` are developer reference material at
  the top level.
- `docs/index.html`, `.nojekyll`, `_sidebar.md`, `README.md`, `guide/` and
  `features/` form a docsify site that is not published anywhere.
- 61 files outside `docs/` cite a path this spec moves: 37 in `lib/`
  (comments), 18 in `test/`, 3 in `scripts/`, 2 in `.github/`, and
  `README.md`.
- Links in `developer/`, `contributing/` and `api/` are written docsify-style
  (relative to the `docs/` root, for example `developer/testing.md` inside
  `developer/README.md`), so they are broken when read on GitHub.

## Target layout

```
docs/
  README.md            short map: which folder is for whom
  user/                docsify site, guide/, features/ (content owned by Spec 2)
  developer/           architecture, building, database, navigation,
                       state-management, testing, local-test-performance,
                       release-process, release-secrets-setup,
                       play-production-access
    reference/         README, entities, enums
      formats/         cylinder-passport-tag, macdive-zsamples
  contributing/        README, code-style, pull-requests, roadmap
  design/              specs/, plans/, findings/
  releases/            unchanged (scripts/release reads it)
  assets/              unchanged (README.md and .gitignore depend on it)
```

`releases/` and `assets/` keep their paths because tooling depends on them:
`scripts/release/sanitize_apple_store_notes.py` scans `docs/releases/*.md`,
and `.gitignore` allowlists `docs/assets/screenshots/readme/`.

## Moves

### Design records to `docs/design/`

- `docs/superpowers/{specs,plans,findings}/` is renamed to
  `docs/design/{specs,plans,findings}/`, including
  `docs/superpowers/specs/assets/`.
- `docs/plans/` is split by filename suffix. No basename collides with an
  existing file in the destination.

| Source | Count | Destination |
| --- | --- | --- |
| `docs/plans/*-design.md` | 53 | `docs/design/specs/` |
| `docs/plans/*-plan.md`, `*-implementation.md`, `*-impl.md` | 46 | `docs/design/plans/` |
| `docs/plans/2026-03-03-check-for-updates-menu.md` | 1 | `docs/design/plans/` (titled "Implementation Plan"; named exception) |

### Developer reference

| Source | Destination |
| --- | --- |
| `docs/api/README.md` | `docs/developer/reference/README.md` |
| `docs/api/entities.md` | `docs/developer/reference/entities.md` |
| `docs/api/enums.md` | `docs/developer/reference/enums.md` |
| `docs/import-formats/cylinder-passport-tag.md` | `docs/developer/reference/formats/cylinder-passport-tag.md` |
| `docs/import-formats/macdive-zsamples.md` | `docs/developer/reference/formats/macdive-zsamples.md` |

### User docs shell to `docs/user/`

`docs/index.html`, `.nojekyll`, `_sidebar.md`, `README.md`, `guide/` and
`features/` move into `docs/user/` with their content unchanged. Docsify
resolves links relative to its own root, so the site keeps working from its
new root. The one edit is removing the sidebar's "Developer Guide",
"Contributing" and "API Reference" sections, because those pages are not user
documentation. Spec 2 rewrites this tree in place, so these files move once.

`docs/README.md` is then free to become the new map of the tree.

## Triage of stale and duplicated documents

| File | Verdict | Detail |
| --- | --- | --- |
| `docs/ARCHITECTURE.md` | Merge into `developer/architecture.md`, then delete | Carry over the deco module overview (Buhlmann ZH-L16C with gradient factors, CNS/OTU, ascent-rate thresholds), sync conflict resolution, and the platform-support table. Drop the schema-v4 tables, the "1.5.0" version banner, the feature checklist and the roadmap section. |
| `docs/FEATURE_ROADMAP.md` | Content replaces the body of `contributing/roadmap.md`, then delete | Keep the existing "Contributing to the Roadmap", "Philosophy" and "Version History" sections of roadmap.md. Refresh the header (it says 1.2.25 / 2026-02-24). Keeping the roadmap.md path preserves its 7 inbound links. |
| `docs/MIGRATION_STRATEGY.md` | Merge into `developer/database.md`, then delete | Carry over the principles (never lose data, forward-only, no downgrade), pointers to the real pre-migration backup in `lib/core/services/database_service.dart` and to `lib/core/database/database_version_exception.dart`, the migration-test convention under `test/core/database/`, and a new-migration checklist rewritten for the rung ladder. Drop the classes that do not exist (`MigrationSafetyService`, `BackupManager`, `DatabaseVersionInfo`), the per-version file scheme, and "Data Migration from Other Apps". |
| `docs/REMAINING_TASKS.md` | Delete | Hand-synced copy of the roadmap. |
| `docs/CODE_OPTIMIZATION_PLAN.md` | Delete | Every figure is out of date; the files it proposed splitting have since grown. Recommendations that still matter belong in tech-debt issues. |
| `docs/UI_WIREFRAMES.md` | Delete | One commit since the history baseline; predates the Insights rename. |
| `docs/api/providers.md` | Delete | 21 of its 67 provider names no longer exist. Any pattern notes missing from `developer/state-management.md` move there first. |
| `docs/api/enums.md` | Move (above) and correct | `DiveType`, `ServiceType` and `BuddyRole` are no longer `enum` declarations; correct or remove those entries. |
| `docs/lightroom-approval/` | Delete | One-off Adobe review submission (2026-07-17); git history keeps it. |
| `docs/developer/play-production-access.md` | Keep | Orphaned today; link it from `developer/README.md` and `developer/release-process.md`. |

## Reference rewrite

- A one-off script builds an old-path to new-path map from the move tables
  above and rewrites every occurrence in `lib/`, `test/`, `scripts/`,
  `.github/`, `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, and all of `docs/`.
  It is not committed.
- `CHANGELOG.md` is left as is: its entries are historical.
- `README.md` links to `docs/ARCHITECTURE.md` and `docs/FEATURE_ROADMAP.md`
  are repointed to `docs/developer/architecture.md` and
  `docs/contributing/roadmap.md`.
- `docs/contributing/README.md` ("Update FEATURE_ROADMAP.md") is reworded to
  name `roadmap.md`.
- Every link in `docs/developer/` (including `reference/`) and
  `docs/contributing/` is converted from docsify root-relative to
  file-relative, so it resolves on GitHub.
- The reference in `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
  that wraps a spec path across two comment lines is fixed by hand, since a
  pattern match cannot see it.

## Location rule

The tracked `CLAUDE.md` gains a rule under "Claude Specific Instructions":
specs go in `docs/design/specs/`, implementation plans in
`docs/design/plans/`, findings in `docs/design/findings/`. The superpowers
brainstorming and writing-plans skills treat a user preference for these
locations as overriding their `docs/superpowers/` default.

Out of the PR's reach, listed for the maintainer: the untracked
`.claude/skills/build-feature/SKILL.md` in the main checkout names
`docs/superpowers/specs/` and `docs/superpowers/plans/` (around lines 89 and
112) and needs the same change by hand.

## Guard

New `scripts/check_docs_links.py` with `scripts/check_docs_links_test.py`. It
runs as a step in the `Script Tests` job of `.github/workflows/ci.yaml`, which
has no `needs: changes` and therefore runs on docs-only pull requests, and it
is added to that job's coverage `guards` list.

Checks:

1. **Relative Markdown links resolve** in `docs/README.md`,
   `docs/developer/**` and `docs/contributing/**`. URLs, `mailto:`, absolute
   paths and anchor-only links are skipped; fenced code blocks are ignored;
   a `#fragment` is stripped before resolving. `docs/design/**` is excluded
   because design records describe code as it was when written.
   `docs/user/**` is excluded until Spec 2 adds it under its own link rules.
2. **Code-to-docs references resolve.** Any path matching
   `docs/(user|developer|contributing|design|releases|assets)/` followed by a
   path ending in `.md`, `.html`, `.png`, `.jpg` or `.json`, found in `lib/`,
   `test/`, `scripts/`, `.github/`, `README.md`, `CONTRIBUTING.md` or
   `CLAUDE.md`, must exist. Requiring a known top-level folder and a file
   extension excludes lookalikes such as `docs/CI-only` and test fixture paths
   such as `docs/scanned_logs/1.jpg`.
3. **Retired folders stay gone.** `docs/superpowers/` and `docs/plans/` must
   not exist. The failure message names `docs/design/specs/` or
   `docs/design/plans/` as the new home, so a branch created before this
   change knows how to rebase.

Each failure prints `file:line` and the unresolved target. The script exits
non-zero on any failure.

Tests build temporary fixture trees with Python's `tempfile` module,
covering: a resolving link, a broken link, a link with a
fragment, a URL and an anchor-only link (skipped), a link inside a fenced
code block (ignored), a broken link inside an excluded tree (ignored), a
resolving and a broken code reference, a lookalike such as `docs/CI-only`
(ignored), and each retired folder present (fails) and absent (passes).

## Delivery

One issue, one PR (`Closes #<issue>`), in reviewable commits:

1. Renames only: every move above as `git mv`, no content changes, so
   `git log --follow` keeps history.
2. Reference rewrite (scripted) plus the link-style conversion.
3. Content merges and deletions from the triage table, plus the new
   `docs/README.md` map and the sidebar edit.
4. Guard script, its tests, the `ci.yaml` step and coverage entry, and the
   `CLAUDE.md` location rule.

The PR description deletes the Screenshots section: no `presentation/`,
theme or platform UI paths are touched.

## Verification

- `python3 scripts/check_docs_links.py` passes on the result.
- No occurrence of `docs/superpowers`, `docs/plans/`, `docs/api/` or
  `docs/import-formats` remains outside `docs/design/`, `CHANGELOG.md`, and
  the guard script and its test (which name the retired folders on purpose).
- `python3 scripts/check_docs_links_test.py` passes.
- `dart format --set-exit-if-changed .` and `flutter analyze` are clean
  (`lib/` changes are comments only).
- The `Script Tests` and `CI Success` checks are green on the PR.

## Risks

- **In-flight branches.** Any open branch that adds a spec under
  `docs/superpowers/` conflicts or reintroduces the folder after merge. Guard
  check 3 fails such a branch with the new path; the fix is a `git mv` of the
  new file.
- **Sessions on an older `CLAUDE.md`.** Sessions started before the merge keep
  writing to `docs/superpowers/` until they merge main; the same guard
  catches it.
- **Large rename PR.** About 900 renames. Keeping commit 1 rename-only lets a
  reviewer confirm it with `git show --stat -M` and focus on commits 2 to 4.

## Out of scope

- Rewriting user-guide content, reconciling `docs/user/` with the wiki, and
  publishing to submersion.app (Spec 2).
- The `submersion-website` repository, including its own `docs/` folder.
- Fixing historical links in design records that point at code that has
  since moved.
