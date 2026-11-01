# Public Download Count Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collect GitHub download counts daily and show them on `submersion.app`: a quiet line under the download button that links to a new `/downloads/` page.

**Architecture:** A daily workflow on `main` of `submersion-app/submersion` writes one per-file snapshot and a `downloads/summary.json` to an orphan `metrics` branch. The website reads that one file in the browser from `raw.githubusercontent.com` and hides the number whenever the data is unavailable. `summary.json` is the only link between the two repos.

**Tech Stack:** Python 3 standard library, GitHub Actions, plain ES modules, inline SVG, `node --test`.

**Spec:** `docs/design/specs/2026-11-01-public-download-count-design.md`. The approved mockups are in `docs/design/specs/2026-11-01-public-download-count-mockups/`.

## Global Constraints

- Count only non-draft releases in `submersion-app/submersion`, by case-insensitive suffix: macOS `.dmg`; Windows `.exe`; Android `.apk`; Linux `.tar.gz`, `.deb`, `.rpm`.
- Prereleases count toward the total but are not listed under recent releases.
- `summary.json` keys are exactly `schema`, `generated_at`, `total`, `platforms`, `recent_releases`, `history`. `schema` is `1`. Platform keys are `macos`, `android`, `windows`, `linux`.
- Data URL: `https://raw.githubusercontent.com/submersion-app/submersion/metrics/downloads/summary.json`
- Data is unavailable if the fetch fails or times out, the JSON is malformed, `schema` is not 1, the numbers are invalid, or `generated_at` is more than 7 days old.
- Never say "users", "installs" (except in the stores note below) or "people" about the number. Never show the raw API total, an estimate or a placeholder number.
- Exact public copy:
  - Home line: `<number> downloads from GitHub`
  - Page label: `downloads from GitHub, including app updates`
  - Page note: `App Store and Google Play installs are not counted.`
  - Trend placeholder: `The trend will appear here once a few weeks of daily snapshots have built up. GitHub keeps no history, so it starts from the first snapshot.`
- Numbers use `en-US` separators. All data reaches the page through `textContent` or SVG attributes, never as HTML.
- No website dependencies beyond Google Fonts. No analytics. No new top navigation item.
- Python: standard library only. No em-dashes, and no spaced hyphens as punctuation, in any code, comment, commit, issue or PR text.
- Repository and GitHub text must not mention Claude, Claude Code or Anthropic in any form.
- Stage explicit paths. In the app repo, never stage `packages/libdivecomputer_plugin/third_party/libdivecomputer`.

## Review Focus

1. GitHub answers 200 with no releases, or with no counted files. The job must fail and publish nothing, not publish a total of 0.
2. A new installer type appears, such as `.pkg`, `.msi` or `.AppImage`. It must raise a workflow warning, not vanish silently from the count.
3. A partial or hand-edited `summary.json` where the platforms do not add up to the total. The site must treat it as unavailable.
4. A visitor's clock is wrong. A `generated_at` ahead of their clock must still display, because a wrong clock does not make the numbers wrong.
5. A trend whose totals never change, or that has gaps. The chart must draw without `NaN` and space points by real date.

---

## Part A: Collector (`submersion-app/submersion`)

Work in this worktree, on branch `ericgriffin/submersion-github-downloads-a9780e`. Run Python with `python3.14`, because the system `python3` is 3.9.

### Task 1: Classify files and build the summary

**Files:**
- Create: `scripts/snapshot_downloads.py`
- Test: `scripts/snapshot_downloads_test.py`

**Interfaces:**
- Produces, in `scripts/snapshot_downloads.py`:
  - `PLATFORMS = ("macos", "android", "windows", "linux")`
  - `classify_asset(name: str) -> str | None`
  - `build_snapshot(releases: list[dict], captured_at: datetime) -> dict`, returning `{"schema": 1, "date": "YYYY-MM-DD", "captured_at": "YYYY-MM-DDTHH:MM:SSZ", "releases": [{"tag", "published_at", "prerelease", "assets": [{"name", "downloads"}]}]}`, all UTC, with drafts removed and every other file kept.
  - `totals_for(snapshot: dict) -> dict`, returning `{"total": int, "platforms": {...}}`
  - `recent_releases(snapshot: dict, limit: int = 4) -> list[dict]`, each `{"tag", "published_at", "downloads"}`
  - `build_summary(snapshots: list[dict]) -> dict`, taking snapshots oldest first
  - `unclassified_assets(snapshot: dict) -> list[str]`

- [ ] **Step 1: Commit the approved design and this plan**

```bash
git add docs/design/specs/2026-11-01-public-download-count-design.md docs/design/specs/2026-11-01-public-download-count-mockups docs/superpowers/plans/2026-11-01-public-download-count.md
git commit -m "docs: add public download count design and plan"
```

- [ ] **Step 2: Write the failing tests**

Load the module the way `scripts/check_ci_success_gate_test.py` does (`importlib.util`, `unittest`). Fixture `RELEASES`, as GitHub API dicts with `tag_name`, `draft`, `prerelease`, `published_at` and `assets` of `{"name", "download_count"}`:

| Release | Flags | Files and counts |
| --- | --- | --- |
| `v1.8.3.9095`, published 2026-10-26 | | `Submersion-v1.8.3.9095-macOS.dmg` 100, `-Windows-Setup.exe` 50, `-Android.apk` 40, `-Linux.tar.gz` 20, `.deb` 3, `.rpm` 2, `appcast.xml` 999, `-Android.aab` 7, `-iOS.ipa` 7, `checksums-sha256.txt` 5, `release-notes.html` 4 |
| `v1.6.1-beta.116`, published 2026-07-10 | prerelease | `-macOS.dmg` 10 |
| `v9.9.9.1`, published `None` | draft | `-macOS.dmg` 500 |
| `demo-data`, published 2026-10-27 | | `submersion-demo-s327.zip` 11, `demo-manifest.json` 90 |

```python
class ClassifyTest(unittest.TestCase):
    def test_platform_suffixes(self):
        self.assertEqual(mod.classify_asset("Submersion-v1-macOS.DMG"), "macos")
        self.assertEqual(mod.classify_asset("x-Windows-Setup.exe"), "windows")
        self.assertEqual(mod.classify_asset("x-Android.apk"), "android")
        for name in ("x-Linux.tar.gz", "x.deb", "x.rpm"):
            self.assertEqual(mod.classify_asset(name), "linux")

    def test_excluded_files(self):
        for name in ("appcast.xml", "x.aab", "x.ipa", "checksums-sha256.txt",
                     "release-notes.html", "demo.zip", "manifest.json", "notes.gz"):
            self.assertIsNone(mod.classify_asset(name))


class SnapshotTest(unittest.TestCase):
    def setUp(self):
        self.snapshot = mod.build_snapshot(RELEASES, NOW)  # NOW = 2026-11-01 04:17:00 UTC

    def test_drafts_are_removed(self):
        self.assertNotIn("v9.9.9.1", [r["tag"] for r in self.snapshot["releases"]])

    def test_every_other_file_is_kept(self):
        latest = self.snapshot["releases"][0]
        self.assertIn({"name": "appcast.xml", "downloads": 999}, latest["assets"])

    def test_dates_are_utc(self):
        self.assertEqual(self.snapshot["date"], "2026-11-01")
        self.assertEqual(self.snapshot["captured_at"], "2026-11-01T04:17:00Z")

    def test_totals_count_installers_and_prereleases_only(self):
        self.assertEqual(mod.totals_for(self.snapshot), {
            "total": 225,
            "platforms": {"macos": 110, "android": 40, "windows": 50, "linux": 25},
        })


class SummaryTest(unittest.TestCase):
    def test_recent_releases_skip_prereleases_and_uncounted(self):
        recent = mod.recent_releases(mod.build_snapshot(RELEASES, NOW))
        self.assertEqual([r["tag"] for r in recent], ["v1.8.3.9095"])
        self.assertEqual(recent[0]["downloads"], 215)

    def test_recent_releases_keep_newest_four(self):
        ...  # six stable releases in shuffled order; assert the four newest, newest first

    def test_summary_shape_and_history_order(self):
        first = mod.build_snapshot(RELEASES, datetime(2026, 11, 1, 4, 17, tzinfo=timezone.utc))
        second = mod.build_snapshot(BIGGER_RELEASES, datetime(2026, 11, 2, 4, 17, tzinfo=timezone.utc))
        summary = mod.build_summary([first, second])
        self.assertEqual(sorted(summary), ["generated_at", "history", "platforms",
                                           "recent_releases", "schema", "total"])
        self.assertEqual(summary["schema"], 1)
        self.assertEqual(summary["generated_at"], "2026-11-02T04:17:00Z")
        self.assertEqual([h["date"] for h in summary["history"]], ["2026-11-01", "2026-11-02"])
        self.assertEqual(summary["total"], summary["history"][-1]["total"])

    def test_new_installer_type_is_reported(self):  # Review Focus 2
        releases = [dict(RELEASES[0], assets=[{"name": "x-macOS.pkg", "download_count": 1}])]
        self.assertEqual(mod.unclassified_assets(mod.build_snapshot(releases, NOW)), ["x-macOS.pkg"])

    def test_known_excluded_files_are_not_reported(self):
        self.assertEqual(mod.unclassified_assets(mod.build_snapshot(RELEASES, NOW)), [])
```

`BIGGER_RELEASES` is `RELEASES` with the `.dmg` count raised, which the assertions above do not depend on.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python3.14 scripts/snapshot_downloads_test.py`
Expected: FAIL with `No such file` or a load error.

- [ ] **Step 4: Implement the functions**

Start the file with a docstring saying why only these suffixes count, and `from __future__ import annotations`. `.tar.gz` is matched whole, so `notes.gz` stays excluded. `unclassified_assets` ignores files classified to a platform and files ending in `.xml`, `.aab`, `.ipa`, `.txt`, `.html`, `.json` or `.zip`, and returns the rest sorted and de-duplicated. `recent_releases` sorts by `published_at` descending and counts only classified files, which is why the fixture gives 215.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3.14 scripts/snapshot_downloads_test.py`
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add scripts/snapshot_downloads.py scripts/snapshot_downloads_test.py
git commit -m "feat(metrics): classify release files and build the download summary"
```

### Task 2: Fetch releases and write the `metrics` files

**Files:**
- Modify: `scripts/snapshot_downloads.py`
- Test: `scripts/snapshot_downloads_test.py`

**Interfaces:**
- Consumes: everything from Task 1.
- Produces:
  - `fetch_all_releases(get_page: Callable[[int], list[dict]]) -> list[dict]`, asking for pages from 1 and stopping at a page shorter than 100
  - `github_get_page(repo: str, token: str, page: int) -> list[dict]`, using `urllib.request` with `per_page=100` and a 30 second timeout
  - `load_snapshots(root: Path) -> list[dict]`, reading `downloads/YYYY/MM/*.json`, oldest first
  - `write_outputs(root: Path, snapshot: dict) -> list[str]`, returning workflow warnings
  - `main(argv: list[str] | None = None, get_page: Callable | None = None, now: datetime | None = None) -> int`
  - CLI: `python3 scripts/snapshot_downloads.py --repo owner/name --out DIR`, reading the token from `GH_TOKEN`

- [ ] **Step 1: Write the failing tests**

Add these, using `tempfile.TemporaryDirectory`, a fake `get_page`, and `contextlib.redirect_stdout` where output is asserted:

```python
class FetchTest(unittest.TestCase):
    def test_reads_every_page(self):
        pages = {1: [{"id": i} for i in range(100)], 2: [{"id": 100}]}
        asked = []
        def get_page(n):
            asked.append(n)
            return pages[n]
        self.assertEqual(len(mod.fetch_all_releases(get_page)), 101)
        self.assertEqual(asked, [1, 2])

    def test_exactly_full_last_page_stops_on_the_empty_one(self):
        pages = {1: [{"id": i} for i in range(100)], 2: []}
        self.assertEqual(len(mod.fetch_all_releases(pages.__getitem__)), 100)

    def test_error_propagates(self):
        def get_page(_):
            raise urllib.error.URLError("down")
        with self.assertRaises(urllib.error.URLError):
            mod.fetch_all_releases(get_page)


class GitHubPageTest(unittest.TestCase):
    def test_request_is_authenticated_and_paged(self):
        response = io.BytesIO(b"[]")
        with mock.patch("urllib.request.urlopen", return_value=response) as urlopen:
            self.assertEqual(mod.github_get_page("o/r", "tok", 3), [])
        request = urlopen.call_args.args[0]
        self.assertIn("/repos/o/r/releases?per_page=100&page=3", request.full_url)
        self.assertEqual(request.get_header("Authorization"), "Bearer tok")


class OutputTest(unittest.TestCase):
    # setUp: self.root is a temporary Path
    def test_writes_snapshot_summary_and_readme(self):
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, NOW))
        self.assertTrue((self.root / "downloads/2026/11/2026-11-01.json").is_file())
        self.assertEqual(json.loads((self.root / "downloads/summary.json").read_text())["total"], 225)
        self.assertTrue((self.root / "README.md").is_file())

    def test_same_day_rerun_overwrites(self):
        mod.write_outputs(self.root, mod.build_snapshot(RELEASES, NOW))
        mod.write_outputs(self.root, mod.build_snapshot(BIGGER_RELEASES, NOW))
        summary = json.loads((self.root / "downloads/summary.json").read_text())
        self.assertEqual(len(summary["history"]), 1)
        self.assertEqual(summary["history"][0]["total"], summary["total"])

    def test_history_is_rebuilt_from_files(self):
        # Write two days, edit day one's file by hand, write day two again.
        # Assert the summary's first history entry shows the hand edit.
        ...

    def test_gap_in_days_leaves_no_entry(self):
        ...  # 2026-11-01 and 2026-11-04 give exactly those two history dates

    def test_falling_total_warns_and_still_publishes(self):
        mod.write_outputs(self.root, mod.build_snapshot(BIGGER_RELEASES, NOW))
        later = datetime(2026, 11, 2, 4, 17, tzinfo=timezone.utc)
        warnings = mod.write_outputs(self.root, mod.build_snapshot(RELEASES, later))
        self.assertTrue(any("fell" in w for w in warnings))
        self.assertEqual(json.loads((self.root / "downloads/summary.json").read_text())["total"], 225)


class MainTest(unittest.TestCase):
    def run_main(self, get_page):
        with mock.patch.dict(os.environ, {"GH_TOKEN": "tok"}):
            return mod.main(["--repo", "o/r", "--out", str(self.root)], get_page=get_page, now=NOW)

    def test_success_writes_files(self):
        self.assertEqual(self.run_main(lambda page: RELEASES if page == 1 else []), 0)
        self.assertTrue((self.root / "downloads/summary.json").is_file())

    def test_failed_fetch_writes_nothing(self):
        def get_page(_):
            raise urllib.error.URLError("down")
        self.assertEqual(self.run_main(get_page), 1)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_no_releases_writes_nothing(self):  # Review Focus 1
        self.assertEqual(self.run_main(lambda _: []), 1)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_no_counted_files_writes_nothing(self):  # Review Focus 1
        self.assertEqual(self.run_main(lambda _: [RELEASES[3]]), 1)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_new_installer_type_prints_a_workflow_warning(self):  # Review Focus 2
        ...  # one release with a .dmg and a .pkg; stdout contains "::warning::" and the .pkg name
```

`mock.patch` on `urlopen` returns a context manager in real use, so build the fake with `MagicMock` if `io.BytesIO` does not fit how the implementation reads it. The assertions above do not change.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3.14 scripts/snapshot_downloads_test.py`
Expected: FAIL, the new functions are missing.

- [ ] **Step 3: Implement the functions**

`write_outputs` reads the newest stored snapshot from before `snapshot["date"]` for the falling-total check, writes the day file, writes `README.md` only if missing (a short note that this branch holds machine-written download counts, with no shared history with `main`), then writes `summary.json` from `load_snapshots`. Write JSON with `indent=2` and a trailing newline, so the daily diffs stay readable.

`main` fetches first and writes last. On `urllib.error.URLError`, `TimeoutError`, `ValueError`, a missing `GH_TOKEN`, no releases, or a zero total, it prints a `::error::` line and returns 1. Warnings print as `::warning::` lines.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3.14 scripts/snapshot_downloads_test.py`
Expected: `OK`

- [ ] **Step 5: Check against the live API**

```bash
rm -rf "$TMPDIR/metrics-check" && mkdir -p "$TMPDIR/metrics-check"
GH_TOKEN=$(gh auth token) python3.14 scripts/snapshot_downloads.py --repo submersion-app/submersion --out "$TMPDIR/metrics-check"
python3.14 -c "import json,os;s=json.load(open(os.environ['TMPDIR']+'/metrics-check/downloads/summary.json'));print(s['total'],s['platforms'],[r['tag'] for r in s['recent_releases']])"
```

Expected: exit 0, no `::warning::` lines, a total of at least 11,452, platform counts at or above macOS 7,271, Android 2,028, Windows 1,537 and Linux 616, and four stable tags with no `demo-data`.

- [ ] **Step 6: Commit**

```bash
git add scripts/snapshot_downloads.py scripts/snapshot_downloads_test.py
git commit -m "feat(metrics): fetch releases and write the metrics branch files"
```

### Task 3: Schedule the job and ship the collector

**Files:**
- Create: `.github/workflows/download-metrics.yml`
- Modify: `.github/workflows/ci.yaml` (the "Run Python guard tests with coverage" step)

**Interfaces:**
- Consumes: the CLI from Task 2.
- Produces: on `metrics`, `downloads/summary.json` at the Data URL in Global Constraints. Part B reads this.

- [ ] **Step 1: Wire the tests into CI**

In `ci.yaml`, append `,scripts/snapshot_downloads.py` to the `guards=` value, and after the `fetch_published_manifest_test.py` entry add:

```yaml
          python3 -m coverage run --append --include="$guards" \
            scripts/snapshot_downloads_test.py
```

- [ ] **Step 2: Create the workflow**

```yaml
name: Download metrics

# Saves GitHub's download counters once a day to the metrics branch, because
# GitHub keeps only running totals with no history. submersion.app reads
# downloads/summary.json from that branch; scripts/snapshot_downloads.py has
# the counting rules.
#
# metrics is an orphan branch, so it is built in its own directory rather than
# a worktree of this checkout, and an empty repo there starts it the first time.
#
# If this job fails, GitHub emails whoever last changed the cron line, and the
# site hides the number once the data is more than 7 days old.
on:
  schedule:
    - cron: "23 4 * * *"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: download-metrics
  cancel-in-progress: false

jobs:
  snapshot:
    name: Save download counts
    if: github.repository == 'submersion-app/submersion'
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v7
        with:
          sparse-checkout: scripts
          persist-credentials: false

      - name: Load the metrics branch
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          git init --initial-branch=metrics metrics-data
          cd metrics-data
          git remote add origin "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
          if git ls-remote --exit-code --heads origin metrics; then
            git fetch origin metrics
            git checkout -B metrics FETCH_HEAD
          fi

      - name: Save today's counts
        env:
          GH_TOKEN: ${{ github.token }}
        run: python3 scripts/snapshot_downloads.py --repo "$GITHUB_REPOSITORY" --out metrics-data

      - name: Push to the metrics branch
        working-directory: metrics-data
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add README.md downloads
          git commit -m "Download snapshot $(date -u +%F)"
          git push origin metrics
```

- [ ] **Step 3: Check the workflow's branch steps locally**

Against a throwaway bare repo in `$TMPDIR`, run the "Load" and "Push" shell lines twice, with the remote URL swapped for the bare repo and a hand-made `README.md` and `downloads/` file each time.
Expected: the first pass creates `metrics` as a root commit, and the second adds a child commit with the first pass's files still present. `git log --oneline metrics` in the bare repo shows two commits.

- [ ] **Step 4: Run the wider checks**

Run: `python3.14 scripts/snapshot_downloads_test.py && python3.14 scripts/check_ci_success_gate.py && python3.14 -c "import yaml;yaml.safe_load(open('.github/workflows/download-metrics.yml'))"`
Expected: all exit 0. If `yaml` is not installed for that interpreter, skip that part and rely on `actionlint` if present.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/download-metrics.yml .github/workflows/ci.yaml
git commit -m "feat(metrics): save download counts daily to the metrics branch"
```

- [ ] **Step 6: Open the issue and PR**

Search open PR bodies for the issue first. Open an issue titled "Show public GitHub download counts on the website", set its type with `gh api -X PATCH repos/submersion-app/submersion/issues/<n> -f type=Feature`, and record the number. Initialise the worktree as `CLAUDE.md` describes so the pre-push hook can run, push, and open a PR to `main` whose description says `Closes #<n>`. The PR touches `scripts/`, so CI runs the full pipeline. That is expected.

- [ ] **Step 7: After the merge, make the first run**

```bash
gh workflow run download-metrics.yml --repo submersion-app/submersion
```

Expected: the run succeeds and `git ls-remote --heads origin metrics` shows the branch. Fetch the Data URL with `curl -sI` and confirm 200 with `access-control-allow-origin: *`. Check the total against Task 2, Step 5.

---

## Part B: Website (`submersion-app/submersion-website`)

Work in a fresh clone in the scratchpad, on a new branch `ericgriffin/download-count` from `origin/main`. Do not use `~/repos/submersion-app/submersion-website`, which is on another branch with untracked work.

Run tests with `node --test tests/*.test.mjs`. Preview with `python3 -m http.server 5173`, through the preview tools.

### Task 4: Validate and format the summary

**Files:**
- Create: `downloads/data.js`
- Test: `tests/downloads-data.test.mjs`

**Interfaces:**
- Consumes: the `summary.json` contract.
- Produces, in `downloads/data.js`:
  - `SUMMARY_URL`, `MAX_AGE_DAYS = 7`, `FETCH_TIMEOUT_MS = 5000`, `TREND_MIN_SNAPSHOTS = 14`
  - `PLATFORMS = [["macos", "macOS"], ["android", "Android"], ["windows", "Windows"], ["linux", "Linux"]]`
  - `parseSummary(raw, now = new Date())`, returning the summary object or `null`
  - `formatCount(n)`, `shortTag(tag)`
  - `async loadSummary({ fetchFn, now } = {})`, returning the summary or `null`, and never throwing

- [ ] **Step 1: Write the failing tests**

```js
const NOW = new Date("2026-11-03T00:00:00Z");
const good = (over = {}) => ({
  schema: 1,
  generated_at: "2026-11-01T04:23:00Z",
  total: 225,
  platforms: { macos: 110, android: 40, windows: 50, linux: 25 },
  recent_releases: [{ tag: "v1.8.3.9095", published_at: "2026-10-26T00:00:00Z", downloads: 215 }],
  history: [{ date: "2026-11-01", total: 225, platforms: { macos: 110, android: 40, windows: 50, linux: 25 } }],
  ...over,
});

test("accepts a good summary", () => assert.deepEqual(parseSummary(good(), NOW), good()));

for (const [name, raw] of [
  ["not an object", null],
  ["wrong schema", good({ schema: 2 })],
  ["text total", good({ total: "225" })],
  ["zero total", good({ total: 0, platforms: { macos: 0, android: 0, windows: 0, linux: 0 } })],
  ["fractional total", good({ total: 225.5 })],
  ["missing platform", good({ platforms: { macos: 225 } })],
  ["platforms do not add up", good({ total: 226 })], // Review Focus 3
  ["bad generated_at", good({ generated_at: "soon" })],
  ["no recent releases", good({ recent_releases: [] })],
  ["bad release", good({ recent_releases: [{ tag: 3 }] })],
  ["bad history entry", good({ history: [{ date: "x" }] })],
]) {
  test(`rejects ${name}`, () => assert.equal(parseSummary(raw, NOW), null));
}

test("stale data is rejected after 7 days", () => {
  const generated = "2026-11-01T00:00:00Z";
  assert.ok(parseSummary(good({ generated_at: generated }), new Date("2026-11-08T00:00:00Z")));
  assert.equal(parseSummary(good({ generated_at: generated }), new Date("2026-11-08T00:00:01Z")), null);
});

test("data ahead of the visitor's clock still shows", () => { // Review Focus 4
  assert.ok(parseSummary(good(), new Date("2020-01-01T00:00:00Z")));
});

test("formatCount uses en-US separators", () => assert.equal(formatCount(11452), "11,452"));

test("shortTag drops the build number", () => {
  assert.equal(shortTag("v1.8.3.9095"), "v1.8.3");
  assert.equal(shortTag("v1.8.3"), "v1.8.3");
  assert.equal(shortTag("demo"), "demo");
});

test("loadSummary returns good data", async () => {
  const fetchFn = async () => ({ ok: true, json: async () => good() });
  assert.deepEqual(await loadSummary({ fetchFn, now: NOW }), good());
});

test("loadSummary returns null on an HTTP error, a throw or bad JSON", async () => {
  assert.equal(await loadSummary({ fetchFn: async () => ({ ok: false, status: 404 }), now: NOW }), null);
  assert.equal(await loadSummary({ fetchFn: async () => { throw new Error("down"); }, now: NOW }), null);
  const badJson = async () => ({ ok: true, json: async () => { throw new SyntaxError("x"); } });
  assert.equal(await loadSummary({ fetchFn: badJson, now: NOW }), null);
});

test("loadSummary gives up after the timeout", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const fetchFn = (_url, { signal }) => new Promise((_, reject) => {
    signal.addEventListener("abort", () => reject(new Error("aborted")));
  });
  const result = loadSummary({ fetchFn, now: NOW });
  t.mock.timers.tick(FETCH_TIMEOUT_MS);
  assert.equal(await result, null);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test tests/downloads-data.test.mjs`
Expected: FAIL, cannot find `downloads/data.js`.

- [ ] **Step 3: Implement `downloads/data.js`**

Counts must be positive-or-zero integers, and the total must be above 0 and equal the sum of the four platforms. History entries need a `YYYY-MM-DD` date and an integer total. `loadSummary` fetches with `{ cache: "no-cache", signal }`, using an `AbortController`, and its default `fetchFn` calls the global `fetch`. Start the file with a comment in the style of `computers/render.js`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `node --test tests/downloads-data.test.mjs`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add downloads/data.js tests/downloads-data.test.mjs
git commit -m "feat(downloads): validate and format the download summary"
```

### Task 5: Calculate the trend line

**Files:**
- Create: `downloads/trend.js`
- Test: `tests/downloads-trend.test.mjs`

**Interfaces:**
- Consumes: `formatCount` from Task 4.
- Produces:
  - `trendPoints(history, { width, height, pad })`, returning an array of `{ x, y }`
  - `trendText(history)`, returning a sentence for screen readers

- [ ] **Step 1: Write the failing tests**

```js
const entry = (date, total) => ({ date, total, platforms: {} });
const size = { width: 100, height: 50, pad: 0 };

test("spaces points by real date, so gaps stay visible", () => { // Review Focus 5
  const points = trendPoints([entry("2026-11-01", 10), entry("2026-11-02", 20), entry("2026-11-11", 30)], size);
  assert.deepEqual(points.map((p) => p.x), [0, 10, 100]);
});

test("higher totals sit higher on the chart", () => {
  const [low, high] = trendPoints([entry("2026-11-01", 10), entry("2026-11-02", 20)], size);
  assert.equal(low.y, 50);
  assert.equal(high.y, 0);
});

test("a flat trend draws a level line, not NaN", () => { // Review Focus 5
  const points = trendPoints([entry("2026-11-01", 10), entry("2026-11-02", 10)], size);
  assert.deepEqual(points.map((p) => p.y), [25, 25]);
});

test("a single point does not divide by zero", () => {
  assert.deepEqual(trendPoints([entry("2026-11-01", 10)], size), [{ x: 0, y: 25 }]);
});

test("padding insets the chart", () => {
  const points = trendPoints([entry("2026-11-01", 10), entry("2026-11-02", 20)], { width: 100, height: 50, pad: 5 });
  assert.deepEqual(points, [{ x: 5, y: 45 }, { x: 95, y: 5 }]);
});

test("trendText states both ends without claiming a direction", () => {
  assert.equal(
    trendText([entry("2026-11-01", 11452), entry("2026-11-15", 12000)]),
    "From 11,452 downloads on 2026-11-01 to 12,000 on 2026-11-15.",
  );
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test tests/downloads-trend.test.mjs`
Expected: FAIL, cannot find `downloads/trend.js`.

- [ ] **Step 3: Implement `downloads/trend.js`**

Parse dates with `Date.UTC`, so daylight saving cannot shift a point. Return plain numbers.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `node --test tests/downloads-trend.test.mjs`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add downloads/trend.js tests/downloads-trend.test.mjs
git commit -m "feat(downloads): calculate the trend line"
```

### Task 6: Add the home page line

**Files:**
- Create: `downloads/home-line.js`
- Modify: `index.html`, `styles.css`
- Test: `tests/downloads-page.test.mjs`

**Interfaces:**
- Consumes: `loadSummary`, `formatCount` from Task 4.
- Produces: the element `#download-count`, with `#download-count-number` inside.

- [ ] **Step 1: Write the failing tests**

```js
const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");

test("the home line starts hidden and links to the page", () => {
  const line = /<p[^>]*id="download-count"[\s\S]*?<\/p>/.exec(read("index.html"));
  assert.ok(line, "no download-count line");
  assert.match(line[0], /\shidden[\s>]/);
  assert.match(line[0], /href="downloads\/"/);
  assert.match(line[0], /<\/strong>\s*downloads from GitHub/);
});

test("the home line sits between the download button and the store badges", () => {
  const html = read("index.html");
  const order = ["download-primary-meta", 'id="download-count"', 'id="download-stores"'].map((s) => html.indexOf(s));
  assert.ok(order[0] > 0 && order[0] < order[1] && order[1] < order[2], String(order));
});

test("the home line loads on its own, away from the release lookup", () => {
  assert.match(read("index.html"), /<script type="module" src="downloads\/home-line\.js"><\/script>/);
  assert.doesNotMatch(read("script.js"), /download-count/);
});

test("the home page adds nothing to the top menu", () => {
  const links = /<div class="nav__links">([\s\S]*?)<\/div>/.exec(read("index.html"));
  assert.doesNotMatch(links[1], /downloads\//);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test tests/downloads-page.test.mjs`
Expected: FAIL, no download-count line.

- [ ] **Step 3: Add the line, the styles and the script**

In `index.html`, directly after the closing `</a>` of `#download-primary`:

```html
<p class="download__count" id="download-count" hidden>
  <a href="downloads/"><strong id="download-count-number"></strong> downloads from GitHub</a>
</p>
```

Before `</body>`, add `<script type="module" src="downloads/home-line.js"></script>`.

In `styles.css`, beside the other `.download__` rules, style `.download__count` at 14px in `--ink-muted`, with `.download__count strong` at weight 600 in `--cyan`, and margin as the approved mockup shows. A hidden block has no height, so `ocean.js` skips it and it keeps the default light ink, which reads correctly in this deep section.

`downloads/home-line.js` calls `loadSummary()`. On a summary it sets `#download-count-number` with `textContent` and removes `hidden`. On `null` it does nothing.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `node --test tests/*.test.mjs`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add downloads/home-line.js index.html styles.css tests/downloads-page.test.mjs
git commit -m "feat(downloads): show the download count under the download button"
```

### Task 7: Build the `/downloads/` page

**Files:**
- Create: `downloads/index.html`, `downloads/page.css`, `downloads/page.js`
- Modify: `tests/downloads-page.test.mjs`, `tests/support-matrix-page.test.mjs`, `README.md`

**Interfaces:**
- Consumes: everything in `downloads/data.js` and `downloads/trend.js`.
- Produces: DOM ids `numbers`, `total`, `platforms`, `releases`, `trend`, `updated`, `unavailable`.

- [ ] **Step 1: Write the failing tests**

Add `"downloads/index.html"` to the page list in `tests/support-matrix-page.test.mjs`, so the page keeps the homepage's menu. Add to `tests/downloads-page.test.mjs`:

```js
const page = () => read("downloads/index.html");

test("the page carries the required copy", () => {
  assert.match(page(), /downloads from GitHub, including app updates/);
  assert.match(page(), /App Store and Google Play installs are not counted\./);
});

test("the trend placeholder is the approved wording", () => {
  assert.match(read("downloads/page.js"), /The trend will appear here once a few weeks of daily snapshots have built up\. GitHub keeps no history, so it starts from the first snapshot\./);
});

test("numbers and the unavailable message both start hidden", () => {
  assert.match(page(), /id="numbers"[^>]*\shidden/);
  assert.match(page(), /id="unavailable"[^>]*\shidden/);
});

test("the page explains itself without JavaScript", () => {
  assert.match(page(), /<noscript>[\s\S]*github\.com\/submersion-app\/submersion\/releases[\s\S]*<\/noscript>/);
});

test("the page has its canonical address", () => {
  assert.match(page(), /<link rel="canonical" href="https:\/\/submersion\.app\/downloads\/" \/>/);
});

test("page.js never writes data as HTML", () => {
  assert.doesNotMatch(read("downloads/page.js"), /innerHTML|insertAdjacentHTML/);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test tests/downloads-page.test.mjs tests/support-matrix-page.test.mjs`
Expected: FAIL, `downloads/index.html` is missing.

- [ ] **Step 3: Create `downloads/index.html`**

Copy the head, skip link, ocean, header, footer and scripts from `computers/index.html`, changing:
- title `Downloads · Submersion Dive Log`
- description `How many times Submersion has been downloaded from GitHub, by platform and release.`
- canonical and Open Graph values for this page
- stylesheet `/downloads/page.css`, and module script `/downloads/page.js`

Body: `<h1>Downloads</h1>` in `.zone__inner`, then, in a `<div class="wrap downloads__panel">` outside `.zone__inner`, the way `computers/index.html` places `.matrix__panel`:
- `#numbers` (hidden): `#total`, the page label, `ul#platforms`, `ul#releases`, `#trend`, the page note, `#updated`
- `#unavailable` (hidden): `Download numbers aren't available right now.`, with a link to `https://github.com/submersion-app/submersion/releases`
- `<noscript>` with the same message and link

- [ ] **Step 4: Create `downloads/page.css`**

Follow the opening of `computers/page.css`: set fixed light tokens on the panel, because it sits on `--panel` at any depth. Lay it out as in `breakdown.html` option B: large cyan total, two boxes that stack on phones, trend box below. Add `.sr-only` if the markup needs it, since that class lives in `computers/page.css`.

- [ ] **Step 5: Create `downloads/page.js`**

Call `loadSummary()`. On `null`, remove `hidden` from `#unavailable`. Otherwise fill the page with `textContent` and remove `hidden` from `#numbers`:
- `#total` from `formatCount(summary.total)`
- one `li` for each of `PLATFORMS`, in that order, with the label and count
- one `li` for each recent release, with `shortTag(tag)` and the count
- `#updated` as `Last updated ${summary.generated_at.slice(0, 10)}.`, matching the `computers/` page
- `#trend`: if `history.length < TREND_MIN_SNAPSHOTS`, a paragraph with the exact placeholder. Otherwise an SVG built with `createElementNS`, a `viewBox` of `0 0 640 200`, a `polyline` from `trendPoints` with `stroke: var(--cyan)`, and `role="img"` with `aria-label` from `trendText`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `node --test tests/*.test.mjs`
Expected: all pass.

- [ ] **Step 7: Add the page to `README.md`**

Under Structure, add a `downloads/` entry: the page and home line read `downloads/summary.json` from the app repo's `metrics` branch, and `scripts/snapshot_downloads.py` there holds the counting rules.

- [ ] **Step 8: Check it in a real browser**

With the static server running and the real `summary.json` loading, check `/` and `/downloads/` at desktop and phone widths. Then use `javascript_tool` to replace `fetch` before load, or a local copy of the file, to see the unavailable state, and a 20-entry history to see the chart.
Expected: the number matches the live file, the home line reads clearly in the deep section, there is no horizontal scroll at 375 px, no console errors, and the page matches the approved mockup. The chart check data stays out of the commit.

- [ ] **Step 9: Commit**

```bash
git add downloads/index.html downloads/page.css downloads/page.js tests/downloads-page.test.mjs tests/support-matrix-page.test.mjs README.md
git commit -m "feat(downloads): add the downloads page"
```

### Task 8: Ship the website and file the follow-up

**Files:** none new.

- [ ] **Step 1: Capture screenshots**

Before and after of the home download section, and after of `/downloads/`, at desktop and phone widths. Attach them through the project's secret gist, following the "Pull Request Screenshots" section of the global instructions.

- [ ] **Step 2: Open the website PR**

Push `ericgriffin/download-count` and open a PR to `main` in `submersion-app/submersion-website`, with the screenshots embedded and `Refs submersion-app/submersion#<n>`. Merging deploys to `submersion.app`, so leave the merge to the maintainer.

- [ ] **Step 3: Confirm the live site after the merge**

Expected: `https://submersion.app/downloads/` and the home line both show the same number as `summary.json`.

- [ ] **Step 4: File the follow-up**

Open an issue in `submersion-app/submersion` for adding App Store and Google Play numbers, noting that they need App Store Connect and Play Console access. Set its type as in Task 3, Step 6.
