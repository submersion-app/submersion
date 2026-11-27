# Repository structure cleanup

Status: awaiting approval. Target release: v1.8.7.

## Intent

The maintainer and the agent sessions working in this repository keep losing
time hunting for scripts. `scripts/` holds 104 entries at its top level with no
grouping beyond a few subfolders, there are two developer-tool folders (`tool/`
and `tools/`), and the root carries folders nothing uses. The goal is a layout
where the answer to "where does the thing that does X live?" is the first folder
name you would guess, and where that stays true after the cleanup lands.

Agents search by guessing names and reading indexes, not by remembering, so the
design favours purpose-named folders plus one index file over clever naming.

## Goals

- Every script in `scripts/` sits in a folder named for its purpose.
- One index, `scripts/README.md`, lists every script and Dart tool with a
  one-line description, grouped the same way as the folders.
- One developer-tool folder for Dart code (`tool/`), following the Dart package
  layout convention.
- Unused root folders are gone.
- A CI guard keeps the structure from drifting back.

## Non-goals

- Renaming script files. Names like `gen_*` and `generate_*` stay as they are;
  only their folders change. Renaming would multiply the reference churn for
  little gain.
- Changing what any script does.
- Restructuring `lib/`, `test/`, `docs/` or the platform folders.
- Rewriting dated design records (`docs/design/specs`, `plans`, `findings`).
  They are history and keep the paths that were true when they were written.

## Anti-goals

- A cleanup that turns CI red, now or days later. Workflows call scripts by path,
  and some workflows run only on a schedule, a release or a tag, so a missed path
  surfaces late. Every workflow path must be updated and verified, not only the
  ones `ci.yaml` exercises on a PR.
- Losing file history. Moves use `git mv` so `git log --follow` keeps working.
- Breaking external links: store listings and the website point at root files
  such as `PRIVACY.md`.

## Approaches considered

1. **Index only.** Keep `scripts/` flat, add `scripts/README.md`, delete dead
   scripts. Cheapest, nothing in CI moves, but the folder still opens to about
   100 entries and the index only helps someone who reads it first.
2. **Purpose folders, an index and a guard (chosen).** Group scripts into
   purpose folders, keep Dart tools in `tool/`, add the index and a CI check that
   every script is indexed and none sits loose. Most churn of the three that keep
   the Dart convention, but the folder names answer the question on their own,
   and the guard stops drift.
3. **One home for everything.** Merge `tool/` and `tools/` into
   `scripts/<purpose>/` regardless of language. One place to look, but it breaks
   Dart's `tool/` convention and every `dart run tool/...` instruction, for little
   gain over approach 2.

The maintainer picked approach 2.

## The rule

- `scripts/` holds everything that is not Dart: Python, shell and Ruby, grouped
  by purpose. Tests sit next to the script they test (`foo.py`, `foo_test.py`).
- `tool/` holds Dart developer tools, as the Dart package layout expects.
- `scripts/README.md` indexes both folders.
- Only `README.md`, `setup.sh` and `requirements.txt` sit at the top of
  `scripts/`. `setup.sh` stays because CONTRIBUTING and CLAUDE.md send every new
  contributor to it.

## Target layout of `scripts/`

| Folder | Holds | Moves in |
| --- | --- | --- |
| `checks/` | Guards that fail CI when a rule is broken | every top-level `check_*.py` and its test |
| `testing/` | Running and reporting tests | `bundle_tests.py`, `run_all_tests.sh`, `run_perf_tests.sh`, `test_concurrency.sh`, `report_inherited_failures.py`, `filter_trivial_coverage.py`, `pre_push_hook_test.sh`, `run_color_encode_it.sh`, with their tests |
| `ci/` | Preparing a CI runner or fixing a build output | `apt_mirror.py`, `fix_macho_symbol_order.py`, with their tests |
| `web/` | Already exists; gains the web build entry point | `build_web.sh` |
| `release/` | Already exists; gains the remaining release steps | `generate_appcast.sh`, `generate_appcast_beta.sh`, `generate_release_notes_html.sh`, `linux_package_deps.py`, `gen_udev_rules.py`, with their tests; `data/linux_soname_map.json` |
| `bots/` | Scripts scheduled workflows run to raise issues or update outside pages | `beta_failure_alert.py`, `dependabot_failure_alert.py`, `demo_package_age_alert.py`, `snapshot_downloads.py`, `wiki_howto_index.py`, `export_support_matrix_catalog.py`, with their tests; `data/support_matrix_platform_rules.json` |
| `codegen/` | Generators that write files under `lib/` | `gen_embedded_ca_bundle.py`, `gen_query_error_codes.py`, `gen_query_label_lookup.py`, `generate_eff_wordlist.py`, `generate_crypto_test_vectors.py` |
| `artwork/` | Builders for in-app artwork, with their sources | from `tool/`: `build_equipment_icon_font.py`, `equipment_glyphs.py`, `build_figure_artwork.py` and `tool/figure/` |
| `datasets/` | Harvesters for bundled datasets, one subfolder per dataset, each holding its script, test, inputs and fixtures | `chambers/` (`chamber_*.py`, `chamber_leads.json`, `.chamber_geocode_cache.json`, `data/chamber_coordinates.json`, `data/chambers_overlay.json`, `data/overlay_parts/`, `fixtures/chambers/`), `dive_sites/` (`dive_site_harvester.py`), `sea_areas/` (`sea_area_harvester.py`), `site_catalogue/` (`site_catalogue_intake.py`), and the existing `geography/` and `tide/` folders |
| unchanged | Already grouped | `brand/`, `deco_golden/`, `demo_data/`, `readme/` |

After the moves `scripts/data/` and `scripts/fixtures/` are empty and removed:
each data file now sits beside the one script that reads it.

`tool/generate_scrubber_sample_dives.py` moves to `scripts/testing/`: it is the
only regenerator for `test/dives/scrubber-1500-dives.uddf`, so it stays.

The folder is `ci/`, not `build/`, because the root `.gitignore` ignores every
directory named `build` at any depth, and `check_docs_links.py` and
`check_dependabot_gemfiles.py` skip such directories. A file added to
`scripts/build/` later would be silently left out of git.

## `tool/`

- `tools/db_bench.dart`, `tools/synth_fixture.dart` and `tools/vmcap.dart` move
  to `tool/perf/`. `tools/` is removed.
- The Python files listed above leave `tool/` for `scripts/artwork/`.
- Everything else in `tool/` stays where it is.

## Root

- Delete `codemaps/` and `.reports/`. They are a generated snapshot from
  2026-01-21 (303 Dart files then, about 6,500 now) that nothing reads.
- Move `codecov.yml` to `.github/codecov.yml`, a location Codecov reads.
- Fold `flutter_launcher_icons.yaml` into a `flutter_launcher_icons:` section of
  `pubspec.yaml`, which the package reads by default.
- Keep `web_hosting/`. `scripts/web/build_web.sh` copies it into every web
  bundle and its `HOSTING.md` is the self-hosting guide.
- Keep every Markdown file at the root. `PRIVACY.md` and `TERMS.md` may be the
  URLs on store listings, and GitHub, contributors and tools expect `README`,
  `CHANGELOG`, `CONTRIBUTING`, `CODE_OF_CONDUCT`, `SECURITY`, `LICENSE` and
  `CLAUDE.md` there.
- Keep the Flutter and Dart config files (`pubspec.*`, `analysis_options.yaml`,
  `dart_test.yaml`, `l10n.yaml`, `.metadata`): the tooling requires them at the
  root.

## Deletions

Approved by the maintainer.

- `codemaps/`, `.reports/` (decided above).
- `scripts/rename_statistics_to_insights.py`, its test, and the `ci.yaml` step
  that runs the test and the `code --check` and `keys --check` guards. The
  guard existed to stop branches opened before the October 2026 rename from
  bringing back old routes or l10n keys; those branches have had nearly two
  months to land, and the maintainer chose to retire it.

## The guard

A new `scripts/checks/check_scripts_index.py`, with a test, run in `ci.yaml`
beside the other checks. It fails when:

- a script file (`.py`, `.sh`, `.rb`, `.dart` entry points, excluding tests and
  `conftest.py`) under `scripts/` or `tool/` is not named in `scripts/README.md`;
- `scripts/README.md` names a path that does not exist;
- a file other than `README.md`, `setup.sh` and `requirements.txt` sits at the
  top of `scripts/`;
- a retired folder reappears: `tools/`, `codemaps/`, `.reports/`,
  `scripts/data/`, `scripts/fixtures/`;
- a `scripts/` or `tool/` path named in `.github/` or `hooks/pre-push` does not
  exist. This is how the workflows that only run on a schedule, a release, a
  tag or `workflow_run` are verified: statically, on every PR, without
  dispatching runs that file issues, update the wiki or publish builds.

Its error message names the file and the fix (add it to the index, or move it
into a purpose folder).

## Updating references

Every move updates, in the same commit, everything that names the old path:

- `.github/workflows/*`, `.github/actions/*`, `.github/codeql/codeql-config.yml`,
  `.github/dependabot.yml`, `.github/PULL_REQUEST_TEMPLATE.md`, including the
  explicit list of Python tests in `ci.yaml`.
- `hooks/pre-push`.
- Scripts that call or import each other (for example `build_web.sh` and
  `check_web_bundle.py`, `release/build_linux_packages.sh` and
  `linux_package_deps.py`, `release/stage_linux_package.py` and
  `gen_udev_rules.py`, `check_bundled_native_assets.py` and
  `check_native_libs_present.py`, `chamber_harvester.py` and its siblings).
- Scripts that find the repository root or their data by a relative path
  (`Path(__file__).parent.parent`, `dirname "$0"/..` and the like). Moving a
  script one folder deeper breaks these silently; each one gets checked.
- Dart files that name a script: tests that read a script (for example
  `test/architecture/coverage_filter_mask_parity_test.dart`), and generated
  files in `lib/` whose header says which script regenerates them.
- Living docs: `docs/developer/`, `docs/contributing/`, `docs/user/`, folder
  READMEs, `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`.

`CLAUDE.md` gains one line under Code Organization pointing at
`scripts/README.md` and stating the rule, so every session starts knowing where
scripts live.

## Delivery

- One issue, one PR, assigned to release v1.8.7.
- One commit per folder group (move plus every reference to it), to keep the
  review readable. The PR is squash-merged like every other, so the groups do
  not need to be green one by one; the squashed commit still records renames
  because each file's content barely changes.
- Merge timing: `beta.yml` runs from main's current workflow files but checks
  out the commit whose CI just finished. A main commit whose CI is still running
  when this PR merges would get a beta that calls the new paths on the old
  layout, fail, and raise a failure alert. Merge only when
  `gh run list --branch main --status in_progress` is empty, and do not merge
  anything else to main until this PR's own CI and beta have finished.
- Outside this repository: `submersion-app/submersion-website`'s
  `tools/support-matrix/SWEEP.md` runs
  `python3 scripts/export_support_matrix_catalog.py`, which moves to
  `scripts/bots/`. A one-line PR to the website repository updates that path;
  it is opened alongside this PR and merged right after this one lands, so the
  routine never sees a path that does not exist yet. The maintainer approved
  opening it.
- Before the PR: every workflow file parses, `git grep` finds no old path outside
  `docs/design/` and `CHANGELOG.md`, every moved Python and shell test passes from
  its new path, and `check_docs_links.py` and the new guard pass.

## Left to the builder

- The exact folder for any script whose purpose is borderline, as long as the
  index and the guard agree.
- The wording of each index line.
- How the guard parses `scripts/README.md` (links or code spans).
