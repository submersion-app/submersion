# Marine life identification release gate: turn it on

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn marine life identification on wherever it can run (iPhone, iPad, Mac), behind an 8 GB floor on iPhone and iPad, with truthful pack credits and the program overview's risks updated.

**Architecture:** The floor moves out of the Flutter-bound plugin file into a Flutter-free `MemoryFloor` enum in `MemoryReading.swift`, so a command-line check can compile it and the macOS CI job that already builds the vision sources can run it. Credits stay data in `tool/species_pack/build_pack.py`, tested by `manifest_test.py`. The flag becomes a getter whose default is on only where an engine runs, with a test override, so the default never depends on which test read it first.

**Tech Stack:** Swift (swiftc check program, GitHub Actions on macOS), Python 3 (unittest), Dart and Flutter tests, Markdown.

**Spec:** `docs/design/specs/2026-11-18-marine-life-release-gate-design.md`

## Global Constraints

- The floor is 6.5 GiB (`6_979_321_856` bytes), applied on iPhone and iPad only; a device at or above it is eligible. Macs keep no floor.
- The fish detector's credit licence reads exactly: `No licence stated; its authors leave the terms to the user`, and its text links `https://github.com/filippovarini/community-fish-detector/issues/8`.
- The GBIF credit's text names what the pack uses: species names and counts of where each species has been recorded.
- `marineLifeIdEnabled` is on by default where `!kIsWeb` and `defaultTargetPlatform` is iOS or macOS (the same test as `ChannelVisionEngine._apple`), off elsewhere; `--dart-define=MARINE_LIFE_ID=false` turns it off everywhere.
- No new file under `packages/submersion_vision/darwin/Classes/`: a new pod source file breaks existing checkouts until `pod install` runs.
- No em-dashes anywhere; no mention of AI tools in commits or the PR. The PR says `Refs #4668`.
- Run only the test files changed, by path.

## Review Focus

1. An 8 GB device that reports well under 8 GiB (system reserve) must still be eligible: pinned by the 7.0 GiB case in Task 1.
2. A 6 GB device reporting its full 6 GiB must not be eligible: pinned by the 6 GiB case in Task 1.
3. The boundary itself is eligible (`>=`), so a rounding change cannot flip it silently: pinned in Task 1.
4. The check must fail CI when it fails locally: Task 1 runs it from the workflow and checks its exit status.
5. A web build in Safari on a Mac reports `defaultTargetPlatform` macOS; the flag must stay off there: pinned in Task 3.
6. A test that overrides the platform to iOS must not leave the flag on for the next test file in the same isolate (CI bundles files): pinned in Task 3 by the getter reading the platform on every call.
7. The pack already built (`2026.11.18.0356`) carries the old credits; publishing must use a rebuilt or regenerated manifest: under "Before merging", not a task here.

---

### Task 1: The memory floor at 6.5 GiB, checked in CI

**Files:**
- Modify: `packages/submersion_vision/darwin/Classes/MemoryReading.swift` (add `MemoryFloor`)
- Modify: `packages/submersion_vision/darwin/Classes/SubmersionVisionPlugin.swift:27-29, 122-126` (drop the constant, call `MemoryFloor`)
- Create: `tool/species_pack/vision_cli/floor_check.swift`, `tool/species_pack/vision_cli/check_floor.sh`
- Modify: `.github/workflows/vision-merge-check.yml` (one more step)

**Interfaces:**
- Produces: `enum MemoryFloor { static let minimumMemoryBytes: UInt64; static func isEligible(physicalMemory: UInt64) -> Bool }` in `MemoryReading.swift`. The constant keeps its old name so the docs that cite `minimumMemoryBytes` still find it.

- [ ] **Step 1: Write the failing check** `floor_check.swift` (`@main` struct, `precondition` asserts, prints `memory floor: ok`):

```swift
let gib: Double = 1024 * 1024 * 1024
func bytes(_ g: Double) -> UInt64 { UInt64(g * gib) }
precondition(MemoryFloor.minimumMemoryBytes == 6_979_321_856)
precondition(!MemoryFloor.isEligible(physicalMemory: bytes(5.5)))   // a 6 GB phone as it reports
precondition(!MemoryFloor.isEligible(physicalMemory: bytes(6.0)))   // the most a 6 GB device can report
precondition(MemoryFloor.isEligible(physicalMemory: bytes(6.5)))    // the boundary is eligible
precondition(MemoryFloor.isEligible(physicalMemory: bytes(7.0)))    // an 8 GB device with 1 GiB reserved
precondition(MemoryFloor.isEligible(physicalMemory: bytes(11.5)))   // a 12 GB phone
```

`check_floor.sh [OUT_DIR]` follows `check_merge.sh`: `set -eu`, `swiftc -O -parse-as-library` of `floor_check.swift` and `MemoryReading.swift`, then run the binary.

- [ ] **Step 2: Run it and see it fail**

Run: `sh tool/species_pack/vision_cli/check_floor.sh "$TMPDIR/floor_check"`
Expected: compile error, `cannot find 'MemoryFloor' in scope`.

- [ ] **Step 3: Add `MemoryFloor` to `MemoryReading.swift`** with `minimumMemoryBytes = 6_979_321_856` (6.5 GiB) and `isEligible` as `physicalMemory >= minimumMemoryBytes`. Its doc comment says why 6.5 GiB (8 GB devices report a little less than 8 GiB, 6 GB devices never more than 6 GiB) and that it is the launch floor from the release gate design.

- [ ] **Step 4: Point the plugin at it.** In `SubmersionVisionPlugin.swift` remove `minimumMemoryBytes` and its comment; `availability()` on iOS returns `MemoryFloor.isEligible(physicalMemory: ProcessInfo.processInfo.physicalMemory) ? "available" : "deviceNotEligible"`.

- [ ] **Step 5: Run the check and see it pass**

Run: `sh tool/species_pack/vision_cli/check_floor.sh "$TMPDIR/floor_check"`
Expected: `memory floor: ok`, exit 0. Then flip one `precondition` locally to confirm a failure exits non-zero, and restore it.

- [ ] **Step 6: Confirm nothing else uses the old constant.** The plugin file imports Flutter, so no command-line tool can compile it; the PR's Build iOS and Build macOS jobs do. Locally: `git grep -n "minimumMemoryBytes" -- packages`. Expected: only `MemoryReading.swift` (the declaration and `isEligible`).

- [ ] **Step 7: Run the merge check too**, since the workflow now runs both: `sh tool/species_pack/vision_cli/check_merge.sh "$TMPDIR/merge_check"`. Expected: passes as before.

- [ ] **Step 8: Add a workflow step** to `vision-merge-check.yml` after the merge check: `name: Check the memory floor`, `run: tool/species_pack/vision_cli/check_floor.sh "$RUNNER_TEMP/floor_check"`. Update the header comment to mention it. The job name stays `Vision Merge Check`.

- [ ] **Step 9: Commit**

```bash
git add packages/submersion_vision/darwin/Classes/MemoryReading.swift packages/submersion_vision/darwin/Classes/SubmersionVisionPlugin.swift tool/species_pack/vision_cli/floor_check.swift tool/species_pack/vision_cli/check_floor.sh .github/workflows/vision-merge-check.yml
git commit -m "feat(species-id): need 8 GB of memory for marine life identification at launch"
```

### Task 2: Credits that say what is true

**Files:**
- Modify: `tool/species_pack/build_pack.py:36-47` (`GBIF_CREDIT`, `DETECTOR_CREDITS["cfd"][0]`)
- Test: `tool/species_pack/manifest_test.py` (`CreditsTests`)

- [ ] **Step 1: Write the failing tests** in `CreditsTests`:

```python
def test_the_fish_detector_credit_says_no_licence_is_stated(self):
    credits = {c["name"]: c for c in build_pack.credits_for("cfd")}
    cfd = credits["Community Fish Detector"]
    self.assertEqual(cfd["licence"], "No licence stated; its authors leave the terms to the user")
    self.assertIn("https://github.com/filippovarini/community-fish-detector/issues/8", cfd["text"])
    self.assertNotIn("awaiting", cfd["licence"])

def test_the_gbif_credit_names_what_the_pack_uses(self):
    gbif = {c["name"]: c for c in build_pack.credits_for("both")}["GBIF occurrence and taxonomy data"]
    self.assertIn("Species names", gbif["text"])
    self.assertIn("counts of where each species has been recorded", gbif["text"])
```

- [ ] **Step 2: Run them and see them fail**

Run: `python3.14 tool/species_pack/manifest_test.py`
Expected: the two new tests FAIL (old licence string, old GBIF text).

- [ ] **Step 3: Change the two credits** in `build_pack.py` to the strings the tests pin; the fish detector's text keeps its first sentence and adds the issue URL.

- [ ] **Step 4: Run the tests and see them pass**

Run: `python3.14 tool/species_pack/manifest_test.py`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tool/species_pack/build_pack.py tool/species_pack/manifest_test.py
git commit -m "fix(species-id): say the fish detector carries no stated licence in pack credits"
```

### Task 3: The flag is on wherever an engine runs

**Files:**
- Modify: `lib/core/constants/feature_flags.dart:40-50`
- Test: `test/core/constants/marine_life_flag_test.dart` (create)
- Modify: the test files that set the flag (`git grep -l marineLifeIdEnabled -- test`, 7 today), so their teardown calls the reset

**Interfaces:**
- Produces: `bool get marineLifeIdEnabled`, `set marineLifeIdEnabled(bool value)` (a test override), `@visibleForTesting void resetMarineLifeIdEnabled()`. Every existing read of `marineLifeIdEnabled` in `lib/` is unchanged.

- [ ] **Step 1: Write the failing tests** in `marine_life_flag_test.dart`, each with `addTearDown(resetMarineLifeIdEnabled)` and, where it sets one, `addTearDown(() => debugDefaultTargetPlatformOverride = null)`:
  - `on for iOS and macOS by default`: with the override set to `TargetPlatform.iOS`, then `TargetPlatform.macOS`, `marineLifeIdEnabled` is true.
  - `off for Android, Windows and Linux by default`: false for each.
  - `follows the platform on every read`: iOS gives true, then switching the override to Android gives false with no reset in between.
  - `a test override wins until reset`: set false on iOS, read false; reset, read true.
- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/core/constants/marine_life_flag_test.dart`
Expected: compile error, `resetMarineLifeIdEnabled` not defined.

- [ ] **Step 3: Implement** in `feature_flags.dart`: a private `const _marineLifeIdDefine = bool.fromEnvironment('MARINE_LIFE_ID', defaultValue: true)`, a private nullable override, the getter returning the override or `_marineLifeIdDefine && !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)`, the setter, and the reset. Rewrite the doc comment: on where an engine runs since the release gate design (link it), the define turns it off, tests use the setter and `resetMarineLifeIdEnabled` in `addTearDown`.
- [ ] **Step 4: Run it and see it pass**

Run: `flutter test test/core/constants/marine_life_flag_test.dart`
Expected: all PASS.

- [ ] **Step 5: Move the existing tests to the reset.** In each file from the grep, replace teardowns that assign `marineLifeIdEnabled = false` with `resetMarineLifeIdEnabled`. Check `test/architecture/test_global_state_restored_test.dart` accepts the reset as the restore for this global; if it does not, add the helper to the list the guard knows, as `docs/developer/testing.md` describes.
- [ ] **Step 6: Find tests that now see the feature.** `git grep -l -E "TargetPlatform\.(iOS|macOS)" -- test` intersected with tests of the gated screens (media viewer, species chips, photos and videos page, storage inventory, media store providers). Run those files by path, at most 15 per command, output to the scratchpad. Expected: PASS; any failure is a test that relied on the flag being off, fixed by setting it explicitly in that test.
- [ ] **Step 7: Run the changed tests and analyze**

Run: `flutter analyze lib/core/constants test/core/constants` and the files from Steps 5 and 6.
Expected: no issues; all PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/core/constants/feature_flags.dart test/core/constants/marine_life_flag_test.dart <files from steps 5 and 6>
git commit -m "feat(species-id): turn marine life identification on for iPhone, iPad and Mac"
```

### Task 4: Docs record the release gate

**Files:**
- Modify: `docs/design/specs/2026-11-17-marine-life-identification-program-design.md` ("Open risks": the detectors' licences and phone memory bullets; the flag conditions paragraph links the release gate design)
- Modify: `docs/developer/species-identification.md:39-40` ("at least 6 GB" becomes 8 GB, with the 6.5 GiB floor)
- Add: the release gate design and this plan

- [ ] **Step 1: Edit the overview.** Licences bullet: the pair is chosen for the first pack, both risks accepted, Megalodon-only is the fallback. Phone memory bullet: the launch floor is 8 GB (6.5 GiB reported), lowered once the media fix lands and a 6 GB phone is measured. Link the release gate design from both and from the flag conditions.
- [ ] **Step 2: Edit the developer guide** line to say phones and tablets need 8 GB at launch.
- [ ] **Step 3: Check links and dashes**

Run: `python3.14 scripts/check_docs_links.py` and `grep -n -P "\x{2014}|\x{2013}" <changed docs>`
Expected: links OK; no dash matches.

- [ ] **Step 4: Commit**

```bash
git add docs/design/specs/2026-11-18-marine-life-release-gate-design.md docs/design/plans/2026-11-18-marine-life-release-gate.md docs/design/specs/2026-11-17-marine-life-identification-program-design.md docs/developer/species-identification.md
git commit -m "docs(species-id): record the marine life release gate decisions"
```

## Before merging (not tasks here)

1. Regenerate the manifest over the measured pack's files (`2026.11.18.0356`), with `mf.file_entry` on each file and `mf.build_manifest(..., credits=credits_for("both"))`, so it carries the new credits. Do not rebuild: a rebuild fetches GBIF again, and if `candidates.json`, `text_embeddings.f16` or `regions.bin` differ by a byte the pack silently gets provisional bars. Check `naming.provisional` is false and the Community Fish Detector credit reads the new licence before uploading.
2. On Eric's go: create the `species-pack` release and upload the manifest and pack files. It does not exist yet.
3. Then the PR can merge (Eric's call). The first release with it on needs the App Review notes from the design.
