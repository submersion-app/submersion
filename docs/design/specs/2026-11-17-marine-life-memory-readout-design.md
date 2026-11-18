# Marine life identification: memory readout for the iPhone test

A small change. Refs #4668.

## Why

[The phone memory findings](../findings/2026-11-17-marine-life-phone-memory.md)
measured the feature on a Mac and left one question for a real 6 GB iPhone:
how close the app comes to its memory limit while it analyses a photo and
scans a 4K video, and whether iOS keeps the Neural Engine's memory out of the
counted figure as macOS does. This readout lets that test be read from the
app's own log, in the build a diver would run.

## Goals

- While the app's debug mode is on, one log line after each identification
  stage: models loaded, a photo analysed, each video chunk's pass 1, each
  chunk's pass 2, models unloaded.
- Each line gives: memory left before the limit, the footprint and its peak,
  memory left at that peak, and the Neural Engine's memory, counted and not
  counted against the limit.
- Readable in Settings > About > View log, copied or shared from there, and
  kept up to the moment if iOS stops the app.

## Non-goals and anti-goals

- No on-screen readout, and no Increased Memory Limit entitlement (decided).
- Nothing changes with debug mode off: no extra channel calls, no new work.
- Not limited to debug builds: the phone test needs a profile or release
  build, since a debug build carries over 1 GB of debug-only memory. Debug
  mode is the five-tap switch, which works in any build.
- No sampling loop and no private API.

## Approaches

1. **A separate `memory` channel method (picked).** After each stage the Dart
   side asks for one reading, only when debug mode is on, and logs it.
   Existing replies stay as they are and debug mode off costs nothing. The
   reading comes a few milliseconds after the stage's work; the kernel's
   footprint peak still covers the work itself.
2. **Readings on each reply.** Every load, photo, pass 1 and pass 2 reply
   carries the figures, taken the moment the work ends. Pass 2's reply is a
   bare list and would need reshaping, and every reply carries the figures
   whether or not anyone reads them.
3. **The Swift side writes its own log file.** Dropped: the in-app log viewer
   would not see it.

Eric picked the first.

## Design

- **Native (`SubmersionVisionPlugin.swift`).** A `memory` method returns one
  `task_info(TASK_VM_INFO)` reading: `phys_footprint`,
  `ledger_phys_footprint_peak`, `ledger_tag_neural_footprint` (counted),
  `ledger_tag_neural_nofootprint_total` and
  `ledger_tag_neural_nofootprint_peak` (not counted), and on iOS
  `os_proc_available_memory()`. It runs on the plugin's serial queue, so it
  reads after the stage's work. A field the running OS does not report (an
  older `task_vm_info` revision, or the limit on macOS, which has none) is
  left out, never sent as zero.
- **Dart.** `VisionEngine.memory()` returns a `VisionMemory` value with
  nullable fields; `ChannelVisionEngine` calls the channel and the test fake
  returns a fixed reading. One small helper takes a stage name, checks
  whether debug mode's verbose file logging is on
  (`LoggerService.minimumFileLevel`), asks the engine for a reading, and logs
  one info line. A failure to read is logged at debug level and never
  reaches identification.
- **Stages.** `MediaIdentificationService` after loading, after a photo's
  analysis and after unloading; `VideoIdentificationScan` after each chunk's
  pass 1 and after its whole pass 2 (all batches), naming the chunk's time
  range.
- **The line.** In MiB, for example:
  `Memory after pass 2 (0:20 to 0:30): 2,412 MB left, footprint 612 MB (peak 845 MB), 2,179 MB left at the peak, Neural Engine 717 MB not counted, 0 MB counted`.
  "Left at the peak" is memory left plus footprint minus peak, shown only
  where the limit is known. The peak counts from app launch, so a launch
  peak above the scan's would hide the scan's; the current footprint on each
  line still shows the trend.

## Left to the builder

File and class names, the log line's exact wording, number formatting, and
how the Swift side is tested.
