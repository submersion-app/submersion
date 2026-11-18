# Marine Life Memory Readout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** While debug mode is on, log the app's memory after each marine life identification stage, for the 6 GB iPhone test.

**Architecture:** A new `memory` method on the `submersion_vision` channel returns one `task_info(TASK_VM_INFO)` reading (plus `os_proc_available_memory()` on iOS). `VisionEngine.memory()` decodes it into a `VisionMemory`. A small `MemoryReadout` asks for a reading after a stage only when info lines reach the log file, and logs one line. `MediaIdentificationService` and `VideoIdentificationScan` call it at their stages.

**Tech Stack:** Swift (Darwin `task_info`, `os/proc.h`), Dart, Flutter method channel, `LoggerService`.

**Spec:** `docs/design/specs/2026-11-17-marine-life-memory-readout-design.md`

## Global Constraints

- Nothing runs with debug mode off: no channel call, no reading. The gate is `LoggerService.minimumFileLevel.index <= LogLevel.info.index`.
- Not limited to debug builds; no `kDebugMode`, no dart-define.
- Public API only (`task_info`, `os_proc_available_memory`); no sampling loop; no entitlement.
- A field the OS does not report is left out of the reply and is null in Dart, never 0.
- Deployment targets: iOS 15.0, macOS 12.0 (`submersion_vision.podspec`).
- A reading failure never reaches identification: it is logged at debug level and dropped.
- No em dashes or spaced hyphens in prose, code comments or the log line. No tool attribution anywhere.
- Run only the test files listed in each task, by path.

## Review Focus

1. Debug mode off: no `memory` call reaches the engine (Task 3, `record does nothing when info lines are not kept`).
2. A failing reading (a `VisionEngineException`, or the plugin missing) must not stop or change a photo's or a video's identification (Task 4, `a failing memory reading leaves the photo identified`).
3. macOS has no per-app limit: the line must not say "0 MB left" (Task 3, `a reading with no limit leaves out what is left`).
4. An older iOS reports fewer `task_vm_info` fields: missing keys are null, not 0 (Task 1, `memory leaves out what the platform does not report`).
5. A chunk that closes no tracks runs no pass 2: no pass 2 line for it (Task 4, `a chunk with nothing to embed logs no pass 2 reading`).

---

### Task 1: `VisionEngine.memory()` and its channel decoding

**Files:**
- Create: `lib/features/species_id/domain/entities/vision_memory.dart`
- Modify: `lib/features/species_id/domain/services/vision_engine.dart`, `lib/features/species_id/data/engines/channel_vision_engine.dart`, `packages/submersion_vision/lib/submersion_vision.dart`, `test/features/species_id/data/fake_vision_engine.dart`
- Test: `test/features/species_id/data/channel_vision_engine_test.dart`

**Interfaces:**
- Produces: `class VisionMemory extends Equatable` with `final int footprintBytes; final int? footprintPeakBytes; final int? availableBytes; final int? neuralCountedBytes; final int? neuralNotCountedBytes; final int? neuralNotCountedPeakBytes;`, a const constructor (only `footprintBytes` required) and `copyWith`.
- Produces: `Future<VisionMemory> memory();` on `VisionEngine`, documented "The app's memory now, for the debug log. Fields the platform does not report are null."
- Produces: `static Future<Map<Object?, Object?>?> memory()` on `SubmersionVision`, invoking `'memory'`.
- Produces: channel reply keys `footprint`, `footprintPeak`, `available`, `neuralCounted`, `neuralNotCounted`, `neuralNotCountedPeak` (bytes, ints).
- Produces: `FakeEngine.memoryReading` (a `VisionMemory`, default `VisionMemory(footprintBytes: 300 * 1048576)`), `FakeEngine.memoryFailure` (`Object?`, thrown by `memory()` when set), and `memory()` adds `'memory'` to `events`.

- [ ] **Step 1: Write the failing tests** in `channel_vision_engine_test.dart`, in the file's existing style (mock handler, cleared in its `tearDown`):
  - `memory decodes every field the plugin reports`: handler answers `'memory'` with all six keys (`footprint: 600 * 1048576`, `footprintPeak: 845 * 1048576`, `available: 2412 * 1048576`, `neuralCounted: 0`, `neuralNotCounted: 717 * 1048576`, `neuralNotCountedPeak: 717 * 1048576`); expect a `VisionMemory` equal to those values.
  - `memory leaves out what the platform does not report`: handler answers `{'footprint': 1048576}`; expect `footprintBytes == 1048576` and the other five null.
  - `memory with no reply is an engine failure`: handler answers null; expect `throwsA(isA<VisionEngineException>())`.
- [ ] **Step 2: Run** `flutter test test/features/species_id/data/channel_vision_engine_test.dart`. Expected: compile failure (`memory` undefined).
- [ ] **Step 3: Implement** the entity, the interface method, `SubmersionVision.memory()`, `ChannelVisionEngine.memory()` through `_guard` (an int field is null unless the value is a `num`; a missing `footprint` or a null reply throws `VisionEngineException('inference_failed', 'no reply')`), and the fake's `memory()`.
- [ ] **Step 4: Run** the same command. Expected: all pass.
- [ ] **Step 5: Commit** `feat(species-id): a memory reading through the vision engine`.

### Task 2: The native `memory` method

**Files:**
- Create: `packages/submersion_vision/darwin/Classes/MemoryReading.swift`
- Modify: `packages/submersion_vision/darwin/Classes/SubmersionVisionPlugin.swift`

**Interfaces:**
- Consumes: the reply keys from Task 1.
- Produces: `enum MemoryReading { static func current() -> [String: Any] }`, Foundation and Darwin only (no Flutter import), so a scratch command-line tool can compile it alone.

- [ ] **Step 1: Implement** `current()`: one `task_info(mach_task_self_, TASK_VM_INFO, ...)` with the full `task_vm_info_data_t` count. Swift cannot import the `TASK_VM_INFO_REVn_COUNT` macros, so work out each revision's count from where its last field ends (`MemoryLayout.offset(of:)`), which a later revision cannot move. At rev 1 send `footprint` (`phys_footprint`). At rev 3 add `footprintPeak` (`ledger_phys_footprint_peak`), `neuralCounted` (`ledger_tag_neural_footprint` plus its compressed pages) and `neuralNotCounted` (`ledger_tag_neural_nofootprint` plus its compressed pages): this is all iOS 15 to 17 and macOS 12 to 14 report. At rev 7 `neuralNotCounted` becomes `ledger_tag_neural_nofootprint_total` and `neuralNotCountedPeak` (`ledger_tag_neural_nofootprint_peak`) is added. Send `available` from `os_proc_available_memory()` only on an iPhone or iPad, not on the Simulator, Mac Catalyst or an iPhone build running on a Mac, which have no limit and report 0. A failed `task_info` returns an empty map. (Updated after review to match what was built.)
- [ ] **Step 2: Add** `case "memory": run(result) { MemoryReading.current() }` to the plugin's `handle`, so it reads on the serial queue after the stage's work.
- [ ] **Step 3: Verify on macOS** by compiling `MemoryReading.swift` with a three-line scratch `main.swift` (in the session scratchpad, not the repo) that prints `MemoryReading.current()`. Expected: `footprint`, `footprintPeak`, `neuralCounted`, `neuralNotCounted` and `neuralNotCountedPeak` present, `available` absent.
- [ ] **Step 4: Verify the iOS build** with `flutter build ios --simulator --debug` (run in the background). Expected: `✓ Built`.
- [ ] **Step 5: Commit** `feat(species-id): the vision plugin reports the app's memory`.

### Task 3: `MemoryReadout` and the log line

**Files:**
- Create: `lib/features/species_id/data/services/memory_readout.dart`
- Test: `test/features/species_id/data/memory_readout_test.dart`

**Interfaces:**
- Consumes: `VisionEngine.memory()`, `VisionMemory`, `FakeEngine.memoryReading` / `memoryFailure` (Task 1).
- Produces: `String describeMemory(String stage, VisionMemory reading)` (top level, pure) and `class MemoryReadout { MemoryReadout({required VisionEngine engine, bool Function()? enabled}); Future<void> record(String stage); }`. `enabled` defaults to the Global Constraints gate. `record` never throws; it logs `describeMemory(...)` at info through `LoggerService.forClass(MemoryReadout)`, and a failure at debug.

- [ ] **Step 1: Write the failing tests:**
  - `describes a full reading`: a reading of footprint 612, peak 845, available 2412, neural counted 0, not counted 717, not counted peak 717 (MiB) gives exactly `Memory after pass 2 (0:20 to 0:30): 2412 MB left, footprint 612 MB (peak 845 MB), 2179 MB left at the peak, Neural Engine 717 MB not counted (peak 717 MB), 0 MB counted` for stage `pass 2 (0:20 to 0:30)`.
  - `a reading with no limit leaves out what is left`: available null gives `Memory after load: footprint 612 MB (peak 845 MB), Neural Engine 717 MB not counted (peak 717 MB), 0 MB counted`.
  - `a reading with only the footprint`: gives `Memory after load: footprint 612 MB`.
  - `record does nothing when info lines are not kept`: `enabled: () => false`; expect no `'memory'` in `FakeEngine.events`.
  - `record logs one info line`: `enabled: () => true`; listen to `LoggerService.logStream` (cancel the subscription in `addTearDown`); expect one info entry whose message starts with `Memory after photo:`.
  - `record swallows a failed reading`: `memoryFailure = VisionEngineException('unsupported')`; expect `record('photo')` to complete normally and no info entry.
- [ ] **Step 2: Run** `flutter test test/features/species_id/data/memory_readout_test.dart`. Expected: compile failure.
- [ ] **Step 3: Implement.** MB is bytes divided by 1048576, rounded, no thousands separator. "Left at the peak" is `available + footprint - peak`, shown only when available and peak are both known. Each optional part is left out when its values are null, as the expected lines show.
- [ ] **Step 4: Run** the same command. Expected: all pass.
- [ ] **Step 5: Commit** `feat(species-id): log a memory reading after a stage`.

### Task 4: Readings at each stage

**Files:**
- Modify: `lib/features/species_id/data/services/media_identification_service.dart`, `lib/features/species_id/data/services/media_identification_video.dart`, `lib/features/species_id/data/services/video_identification_scan.dart`, `lib/features/species_id/presentation/providers/species_id_providers.dart`
- Test: `test/features/species_id/data/media_identification_service_test.dart`, `test/features/species_id/data/video_identification_scan_test.dart`

**Interfaces:**
- Consumes: `MemoryReadout` (Task 3).
- Produces: an optional `MemoryReadout? memoryReadout` constructor parameter on `MediaIdentificationService` and on `VideoIdentificationScan`; null records nothing, so every existing test is unchanged. The provider passes `MemoryReadout(engine: engine)`; the service hands its own to each scan.
- Stage names: `load` (after `_engine.load` in `_ensureLoaded`), `photo` (after a successful `analyze` in `_analyseImage`), `unload` (after `_engine.unload` in `_unloadModels`), `pass 1 (m:ss to m:ss)` (in `runChunk` after `detectVideo` returns, with the chunk's start and scanned end), `pass 2 (m:ss to m:ss)` (in `runChunk` after `_nameTracks` returns, only when the chunk closed at least one track).

- [ ] **Step 1: Write the failing tests:**
  - service, `a photo logs readings after load and after the photo`: a service built with `memoryReadout: MemoryReadout(engine: engine, enabled: () => true)`; after identifying one photo, `engine.events` reads `load, memory, analyze:<path>, memory`.
  - service, `a failing memory reading leaves the photo identified`: same, with `engine.memoryFailure` set; the photo's identifications are stored as without a readout.
  - scan, `each chunk logs a reading after pass 1 and after pass 2`: a 20 second video whose two chunks each close a track (fewer than 12 moments each); the `detectVideo`, `embedMoments` and `memory` entries of `engine.events` read `detectVideo:0, memory, embedMoments, memory, detectVideo:10000, memory, embedMoments, memory`.
  - scan, `a chunk with nothing to embed logs no pass 2 reading`: a 10 second video with no boxes; those entries read `detectVideo:0, memory`.
- [ ] **Step 2: Run** `flutter test test/features/species_id/data/media_identification_service_test.dart` and, separately, `flutter test test/features/species_id/data/video_identification_scan_test.dart`. Expected: compile failure.
- [ ] **Step 3: Implement** the parameter, the five calls (`await _memoryReadout?.record(...)`), the hand-over to the scan and the provider wiring.
- [ ] **Step 4: Run** both commands again, plus `test/features/species_id/data/media_identification_service_video_test.dart`. Expected: all pass, existing tests unchanged.
- [ ] **Step 5: Commit** `feat(species-id): memory readings at each identification stage`.

### Task 5: Developer doc and a Simulator check

**Files:**
- Modify: `docs/developer/species-identification.md` (a short "Memory readout" section after "Video")

- [ ] **Step 1: Write the section:** what the lines are for (the iPhone test), how to turn them on (debug mode: five taps, then Settings > About > View log), that a profile or release build gives the phone's real figures, and what each figure means, including that the peak counts from launch.
- [ ] **Step 2: Check in the iPhone 17e Simulator** (the session's existing install, no sync): install the Task 2 build, turn on debug mode, open the seeded photo and video, and read the log. Expected: `Memory after load`, `photo`, `pass 1 (...)` and `pass 2 (...)` lines.
- [ ] **Step 3: Run** `python3.14 scripts/check_docs_links.py` and `dart format` on the changed Dart files. Expected: links ok, nothing reformatted.
- [ ] **Step 4: Commit** the doc, the design doc and this plan: `docs(species-id): how to read the memory readout`.
