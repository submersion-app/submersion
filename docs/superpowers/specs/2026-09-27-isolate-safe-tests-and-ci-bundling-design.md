# Isolate-safe tests and bundled CI test runs (issue #2500)

## Problem

CI time is dominated by the test shards, and their cost grows with the number
of test files, not the number of tests. `flutter test` compiles and loads every
`*_test.dart` as its own entrypoint in its own isolate, and `--coverage`
collects a hit map per file. At 3,762 files that is about 4.8 seconds per file:
16 shards of about 20 minutes each, 327 of the 404 job-minutes in a run.

Every run asks for 16 shard jobs plus the platform builds, so about three runs
fit under the 60 concurrent job limit. The median successful run takes 79
minutes of wall-clock for roughly 23 minutes of work.

Running many test files in one isolate removes most of the per-file cost.
Measured on 122 files (1,311 tests) at CI concurrency (`-j 2`):

| Mode | Separate files | One bundle | Speedup |
|---|---|---|---|
| No coverage | 76.3 s | 36.1 s | 2.1x |
| With `--coverage` | 299.0 s | 76.3 s | 3.9x |

Coverage output was equivalent (382,608 instrumented lines in both; 28,546
lines hit separately, 28,563 bundled).

A whole-suite run in 113 bundles passed 34,790 tests and failed 86, in 21
files that all pass alone, plus one bundle that failed to load. Each failure is
a test that leaves global state behind. A fresh isolate per file hides that
today.

## Decisions

| Topic | Decision |
|---|---|
| Scope | One PR, `Closes #2500`: the test repairs, the guard, the bundle generator, the CI switch and the shard cut. |
| Leaking tests | Fix the root causes. No list of files excused from bundling because they leak. |
| Production code | One change: a `debugReset` seam on `AppShortcuts`, matching `ScreenAwake.debugReset`. |
| Bundle membership | By directory, so adding a test file changes only its own directory's bundle. |
| Where bundling applies | CI only. Local runs and the pre-push hook are unchanged, because a bundle is no faster at local concurrency (36 s against 28 to 32 s). |
| Shard count | The fewest shards that keep the slowest shard under the slowest platform build, set from measured timings in this PR. |
| Platform builds | Untouched. |
| Out of scope | Removing low-value tests and changing coverage targets. Separate issues. |

## Part 1: test repairs

Seven repairs. Six mechanisms explain all 22 failures; repair 2 is a
second-order leak that repair 1 would otherwise expose.

### 1. `PathProviderPlatform.instance` replaced and never restored

Sixteen files install a fake that overrides one method and leave it in place.
Later files then get `UnimplementedError` from the base class, or a path
inside a temp directory the leaking test already deleted. Because
`performSync` catches every exception, one leak shows up as six different
sync assertions.

Fix, using the idiom already in
`storage_settings_custom_folder_subtitle_test.dart`:

```dart
late PathProviderPlatform originalPathProvider;

setUp(() async {
  originalPathProvider = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
});

tearDown(() async {
  // The fake points into a temp dir deleted below, so it must not outlive it.
  PathProviderPlatform.instance = originalPathProvider;
  await tempDir.delete(recursive: true);
});
```

Where the fake is installed inside a test body, `addTearDown` restores it.

Files: `database_service_vacuum_test`, `database_service_isolate_test`,
`database_service_location_adoption_test`,
`database_service_headless_upgrade_guard_test`,
`local_cache_database_service_test`, `save_and_share_file_test`,
`share_file_fallback_test`, `blender_invoice_test`,
`media_cache_eviction_provider_test`, `media_cache_root_test`,
`plan_canvas_share_anchor_test`, `saved_plans_sheet_test`,
`storage_settings_pick_failure_test`, `storage_settings_reset_test`,
`debug_log_providers_test`, `storage_usage_wiring_test`.

The same idiom repairs the other unrestored `*Platform.instance` assignments
the guard in Part 2 reports: file picker, Google sign-in, permission handler
and video player, one file each.

### 2. Method channel handlers left installed

The export tests mock `plugins.flutter.io/path_provider` and
`dev.fluttercommunity.plus/share` in `setUpAll` and only delete their work
directory in `tearDownAll`. The handler outlives the file and answers later
path lookups with `null`.

Fix: set both handlers to `null` in `tearDownAll`. Files:
`export_service_test`, `export_service_dive_types_test`,
`export_service_pdf_units_test`, `export_pdf_logbook_test`,
`export_uddf_profiles_test`, `pdf_course_export_service_test`,
`pdf_trip_export_test`.

### 3. `SharePlus.instance` keeps the first platform it sees

share_plus declares
`static final SharePlus instance = SharePlus._(SharePlatform.instance)`. The
platform is captured on first read and cannot be replaced, so in a shared
isolate the first file to share wins and every later fake is ignored. A
restore cannot fix this.

Fix: a forwarding platform pinned once per isolate, before any test runs.

```dart
// test/helpers/late_bound_share_platform.dart
class LateBoundSharePlatform extends SharePlatform {
  final SharePlatform _channel = MethodChannelShare();

  @override
  Future<ShareResult> share(ShareParams params) {
    final current = SharePlatform.instance;
    return (identical(current, this) ? _channel : current).share(params);
  }
}
```

`test/flutter_test_config.dart` installs it and reads `SharePlus.instance`
once so the forwarder is what gets captured. Tests keep assigning their own
fake to `SharePlatform.instance`; the forwarder looks it up on every call. The
eight files that assign a fake also restore the previous value, under the same
rule as the path provider. The nine files that mock the share channel keep
working, because the forwarder falls back to the channel implementation.

This must land with repair 1. Once the path provider is restored, export tests
run far enough to reach the share sheet, which would pin the real platform and
break `save_and_share_file_test` and `share_file_fallback_test`.

### 4. A `TileLayer` built at declaration time

`offline_map_providers_test.dart:181` builds a `TileLayer` in the body of
`main()`. Its constructor creates an HTTP client. Alone, that happens before
the test binding exists. In a bundle an earlier file has already installed the
binding's mock HTTP layer, which refuses to run outside a test, and the whole
bundle fails to load.

Fix: `late final tileLayer = TileLayer(...)`.

### 5. PDF fonts cached after a blocked download

`pdf_export_generated_at_test` and `pdf_export_template_routing_test` do not
initialise a binding, so alone they download Roboto from the public internet.
In a bundle the binding answers every request with 400, the printing package
falls back to Helvetica without throwing, and `PdfFonts` caches it.

Fix: a helper that seeds the printing cache from the Flutter SDK's own copy of
Roboto, so the tests need no network in either mode.

```dart
// test/helpers/pdf_roboto.dart
Future<void> loadPdfRoboto() async {
  for (final style in ['Regular', 'Bold', 'Italic', 'BoldItalic']) {
    final bytes = await File(p.join(_materialFontsDir(), 'Roboto-$style.ttf'))
        .readAsBytes();
    await PdfBaseCache.defaultCache.add('Roboto-$style', bytes);
  }
  PdfFonts.instance.reset();
  await PdfFonts.instance.initialize();
}
```

The two files call it in `setUpAll` and reset `PdfFonts` in `tearDownAll`, so
Roboto does not leak into files that expect Helvetica. `_materialFontsDir`
resolves from `FLUTTER_ROOT`, falling back to the path of the running
`flutter_tester` binary. The plan verifies this on CI's Linux runner before
the two files depend on it.

### 6. `AppShortcuts` registration latch

`AppShortcuts.ensureRegistered()` sets a private flag. After
`ShortcutCatalog.instance.clear()` the flag still says registered, so nothing
can register again and the catalog stays empty.

Fix: `@visibleForTesting static void debugReset()` on `AppShortcuts`, called
from the `setUp` of `shortcut_display_test` and `keyboard_shortcuts_test`
alongside the catalog clear. Production behaviour is unchanged.

### 7. Harness defaults restored to the wrong value

`test/flutter_test_config.dart` sets three defaults once per file. Six files
change one and "restore" something else:

| Files | Leaves behind | Harness default |
|---|---|---|
| Four under `test/features/data_quality/` | `QualityScanScheduler.enabled = true` | `false` |
| `export_service_pdf_units_test`, `course_detail_export_units_test` | `debugCanShareFiles = null` | `true` |

`null` means "ask the host", which is `false` on Linux. CI runs on Linux, so
this one would appear in CI and not on a Mac.

Fix: the defaults move into one function that both the harness and the tests
call.

```dart
// test/helpers/global_test_defaults.dart
void applyGlobalTestDefaults() {
  QualityScanScheduler.enabled = false;
  SensorSummaryScheduler.enabled = false;
  debugCanShareFiles = true;
}
```

Every test file that assigns one of the three calls
`applyGlobalTestDefaults()` in its `tearDown`.

### Related, tracked elsewhere

`buddy_merge_test` asserts `updatedAt` is strictly greater within one
millisecond and fails intermittently in a warm isolate. It has its own fix in
progress. If that has not merged when this PR's CI runs, the file carries the
run-alone marker from Part 3 until it does.

## Part 2: guard

`test/architecture/test_global_state_restored_test.dart`, in the style of the
existing guards (pattern scan, allowlist with a reason per entry, and a test
that every allowlisted file still exists). It scans every `.dart` file under
`test/`, skipping `test/.bundles/`.

| Rule | A file that... | Must also... |
|---|---|---|
| Platform singletons | assigns `<Name>Platform.instance = ...` | read the previous value into a variable (`= <Name>Platform.instance;`) |
| Harness defaults | assigns `QualityScanScheduler.enabled`, `SensorSummaryScheduler.enabled` or `debugCanShareFiles` | call `applyGlobalTestDefaults()` |
| HTTP overrides | assigns `HttpOverrides.global = ...` | read the previous value into a variable |

Allowlisted: `test/flutter_test_config.dart` and
`test/helpers/global_test_defaults.dart`, which define the defaults.

The failure message names each offending `file:line` and states the idiom to
use. The guard is written first and is expected to fail on the files listed in
Part 1; the repairs turn it green.

The guard is a pattern match. It proves a restore exists, not that it runs on
every path. The whole-suite bundled run is what proves the suite is safe.

## Part 3: bundle generator

`scripts/bundle_tests.py`, with `scripts/bundle_tests_test.py`, following the
existing script conventions (standard library only, `unittest`, run by the
Script Tests job with coverage). Compatible with Python 3.9.

```
python3 scripts/bundle_tests.py --shard 2 --total-shards 6 --out test/.bundles
```

It writes the bundles for that shard and prints the paths to hand to
`flutter test`, one per line.

**Discovery.** Every `*_test.dart` under `test/`, sorted, excluding the output
directory.

**Files that run alone.** A file is passed to `flutter test` as itself, not
bundled, when it has:

- a library-level `@Tags`, `@TestOn`, `@Timeout`, `@Skip`, `@Retry` or
  `@OnPlatform` annotation, which the runner reads only from an entrypoint
  (7 files today);
- a call to `matchesGoldenFile`, which resolves against the entrypoint's
  directory (1 file, already in the 7);
- a `main` that is `async` or takes parameters (none today);
- the marker comment `// test-bundle: run-alone <reason>`.

The marker is the operational escape hatch: one line in the affected file
unblocks main while a newly found conflict is fixed properly. It is not a
substitute for the repairs in Part 1.

**Grouping.** By directory. A directory with more than `--max-files` test
files (default 120) is split by its subdirectories, recursively. A leaf
directory still over the limit is split alphabetically into equal chunks.
Adding a test file therefore changes one bundle, in the directory the author
is already working in.

**Bundle contents.**

```dart
import 'package:flutter_test/flutter_test.dart';

import '../helpers/global_test_defaults.dart';
import '../features/buddies/data/buddy_photo_persistence_test.dart' as t0;

void main() {
  group('features/buddies/data/buddy_photo_persistence_test.dart', () {
    setUpAll(applyGlobalTestDefaults);
    t0.main();
  });
}
```

The group name is the file's path, so every failure still names its file.
`setUpAll(applyGlobalTestDefaults)` reproduces the per-file reset the harness
gives today.

Bundles live in `test/.bundles/` so `test/flutter_test_config.dart` still
applies. The directory is added to `.gitignore`, its files do not end in
`_test.dart`, and the analyzer skips dot directories.

**Shard assignment.** Each unit (a bundle or a run-alone file) is weighted by
its declared test count. Units are sorted by weight, heaviest first, and each
goes to the lightest shard so far, with ties broken by name. The assignment is
deterministic for a given tree. Moving a bundle between shards cannot create a
conflict, because bundles do not share an isolate.

**Paths.** Built with `os.path.join`; Dart import strings use forward slashes
on every platform.

## Part 4: CI

In `.github/workflows/ci.yaml`, the `Run tests` step of the `test` job
replaces its `find | awk` file list with the generator's output:

```bash
mapfile -t paths < <(python3 scripts/bundle_tests.py \
  --shard "${{ matrix.shard }}" --total-shards "${TOTAL_SHARDS}" \
  --out test/.bundles)
```

The empty-shard guard stays. The `flutter test --coverage --exclude-tags
performance` invocation, the coverage upload and the per-shard Codecov flag
are unchanged. The comment block above the matrix is rewritten to describe the
new cost model.

The Script Tests job adds `scripts/bundle_tests.py` to its coverage set and
runs `scripts/bundle_tests_test.py`.

**Shard count.** Set in two pushes within this PR:

1. Bundling with 16 shards, to measure real bundled shard times on CI
   hardware.
2. The shard matrix, `TOTAL_SHARDS` and `codecov.yml` `after_n_builds`
   (shard count plus one) changed together to the fewest shards that keep the
   slowest shard under the slowest platform build, with headroom for growth.

The projection from the local probe is about 5 shards. The measured number
decides.

The Timezone Tests job keeps its hand-maintained file list and is not bundled.

## Part 5: documentation

- `docs/developer/testing.md`: a section on shared isolates in CI: the rule
  (a test restores any global it replaces), the two helpers, the run-alone
  marker, and how to reproduce a CI bundle locally.
- The development guide at the repository root, Gotchas section: one entry
  stating the rule and naming the guard.

## Verification

| Check | How |
|---|---|
| Guard catches the leaks | Written first; fails listing the Part 1 files; green after the repairs |
| Generator | Unit tests: grouping, splitting, run-alone detection, marker, shard assignment is disjoint and complete, deterministic output, path separators |
| Suite passes bundled | Generate with `--total-shards 1`, run every bundle locally, zero failures |
| Suite still passes unbundled | Every touched test file run on its own |
| Coverage unchanged | Codecov project coverage on the PR against main |
| CI cost | Test job-minutes per run, before and after |

## Risks

| Risk | Mitigation |
|---|---|
| One compile error fails a whole bundle | The Analyze job reports compile errors against the file; the bundle's load error names it too |
| A leak of a kind the guard does not know | Failures name the file; the run-alone marker unblocks main; the guard gains a rule |
| Warm isolates expose timing assumptions | Treated as real test bugs and fixed, as with `buddy_merge_test` |
| Memory growth in a long-lived isolate | Bundles capped at 120 files; watched in the first CI runs |
| Wrong `after_n_builds` blocks every merge | Changed in the same commit as the shard matrix, and checked in review |
| Local and CI run tests differently | The documented generator command reproduces any CI bundle locally |
