# Marine life identification: phone memory

How much memory marine life identification needs, measured on a Mac as a
stand-in for an iPhone and then on an iPhone. It answers the "Phone memory" open risk in
[the program overview](../specs/2026-11-17-marine-life-identification-program-design.md):
whether the 608 MB classifier is too much even for the 6 GB floor. Refs #4668.

Measured on 2026-11-17 on an Apple M5 Pro (64 GB, macOS 27.2), with pack
`2026.11.17.1617`: the Community Fish Detector (`cfd-rfdetr-nano-640-20260706`,
54 MB of weights) and BioCLIP 2 (`bioclip-2-vitl14-2957b32`, 608 MB), both
16-bit Core ML. On 2026-11-18 the same pack was run in the app on an iPhone
17 Pro Max (see "On an iPhone"), which settles how iOS counts the Neural
Engine's memory. A 6 GB iPhone is still unmeasured; what is left is at the
end.

Sizes are MiB of **physical footprint**, the figure iOS compares with an
app's memory limit, unless a line says otherwise.

## The answers

1. **The classifier's weights do not count against the limit when Core ML
   runs it on the GPU,** which is where it runs on this Mac. Core ML reads the
   weights straight from the model files: once both models are loaded the
   process is 1.2 GB resident but its footprint is 17 to 35 MiB. Mapped file
   pages are clean, so the system can drop and re-read them instead of
   counting them.
2. **On the Mac's GPU path the feature's peaks come from the media, not
   the models:** 253 MiB analysing a 50 MP photo, 277 MiB in a video's
   pass 1 and 243 MiB in its pass 2. They are decoding the photo, the 4K
   decoder's buffers and full-size 4K frames. On an iPhone the models, at
   about 0.7 GiB, cost more than this decoding (answer 6).
3. **On the Neural Engine, 634 to 718 MiB goes to an account that is not
   counted.** Forcing the Neural Engine, the kernel puts the models' memory
   in the process's `ledger_tag_neural_nofootprint` ledger (what
   `ri_neural_footprint` reports), while the counted
   `ledger_tag_neural_footprint` stays at zero, read in the process with
   `task_info(TASK_VM_INFO)`. The physical footprint stays under 200 MiB.
   That is macOS. On an iPhone it is counted (answer 6).
4. **No first-load spike while the models load,** in the harness.
   Compiling them for the GPU took 2.7 s with a 37 MiB peak; for the Neural
   Engine it took 8.3 s, done by the system's compiler service, with a
   35 MiB peak in the harness process. The app was not measured while it
   loaded them (see "The app's own figure").
5. **Against an iPhone's limit.** Apple does not publish the per-app limit;
   developers commonly report about half the memory, roughly 3 GB on a 6 GB
   phone. The feature's own share is about 0.3 GB on the GPU path, and
   about 1 GB if the Neural Engine account counts, which on an iPhone it
   does. The Mac runs could not show the whole app's total; the iPhone run
   did (answer 6).
6. **On an iPhone the Neural Engine's memory counts, and the app still fits
   on a 12 GB phone.** On an iPhone 17 Pro Max (iOS 27.2.1, profile build)
   Core ML ran both models on the Neural Engine, and iOS put their memory
   in the counted ledger: 634 MiB once loaded, 712 to 718 MiB in use, none
   once unloaded. The app's limit there was 3,376 MiB. Identification's
   highest point was 2,432 MiB, with a 50 MP photo open, leaving 944 MiB.
   The app's own media handling, not the models, set its overall peak.

## How it was measured

- **Harness.** A command-line tool compiled from the app's own
  `packages/submersion_vision/darwin/Classes/VisionPipeline.swift` and
  `VideoScanner.swift`, unchanged but for their Flutter import and a stand-in
  for `FlutterStandardTypedData` (as `tool/species_pack/vision_cli/` does).
  No Flutter, database or network. It goes through the app's stages: idle,
  load both models with `computeUnits = .all`, analyse a photo, then for each
  10 second chunk of a video run pass 1 (`detect`, a frame every 250 ms) and
  pass 2 (`embed`, in batches of 12 moments, as the app does), then unload.
  Pass 2 embedded up to three boxes from every other sampled frame, 58
  moments in all. For two more runs the copy's `computeUnits` was switched
  to `.cpuAndNeuralEngine` and `.cpuOnly`.
- **Sampling.** `proc_pid_rusage(RUSAGE_INFO_V6)` every 20 ms, with each
  stage's name written to a file the sampler reads. It reports the physical
  footprint, its lifetime and interval peaks, the neural footprint and the
  resident size. The `footprint` tool gave the breakdown by category. In
  one more Neural Engine run the harness also read
  `task_info(TASK_VM_INFO)` at each stage, which splits the neural
  footprint into its counted and not-counted ledgers.
- **Where Core ML runs the models.** `MLComputePlan` with `.all` on this Mac
  puts all 602 detector operations and all 563 classifier operations on the
  GPU (99.8% and 100% of the estimated cost).
- **Media.** A 50 MP JPEG (8192 by 6144) of a reef with a school of small
  fish, which the detector boxes 8 of, and a 27 second action camera clip of
  a reef wall with a school: HEVC, 3840 by 2160, 60 frames a second.
- **Cold and warm.** The first run of each path started from the model
  packages, so it includes compiling them; the others reused the compiled
  models.

## Results

Physical footprint by stage, MiB:

| Stage | GPU (`.all`, cold) | GPU (`.all`, warm) | Neural Engine (cold) | Neural Engine (warm) | CPU only |
| --- | --- | --- | --- | --- | --- |
| Idle, nothing loaded | 2 | 2 | 2 | 2 | 2 |
| Loading | 37 | 17 | 35 | 15 | 21 |
| Loaded, idle | 34 | 17 | 35 | 15 | 20 |
| Photo, peak | 253 | 253 | 181 | 161 | 167 |
| Video pass 1, peak | 277 | 274 | 177 | 165 | 192 |
| Video pass 2, peak | 243 | 241 | 149 | 132 | 124 |
| After unloading | 81 | 78 | 52 | 36 | 44 |

Neural footprint on the Neural Engine path: 634 MiB once loaded, 718 MiB
while analysing, none half a second after unloading, all of it in the
not-counted ledger. On the other paths it stays at zero.

Resident size, for contrast: 1.2 GB while loading on the GPU and CPU paths
and up to 1.0 GB in use, while the footprint stayed under 0.3 GB. The
difference is the mapped model files, which the system may drop when they
are not in use: loaded and idle, the GPU path was 0.66 GB resident and the
CPU path 30 MB.

Time, warm: a photo with 8 crops took 434 ms on the GPU, 329 ms on the Neural
Engine and 674 ms on the CPU. Pass 1 took 1.1 s per 10 seconds of 4K video on
the GPU, 1.9 s on the Neural Engine and 2.3 s on the CPU; pass 2 took about
40, 60 and 90 ms a moment.

## The app's own figure

The app itself was measured only briefly. A local macOS profile build is
killed at launch until App.framework is re-signed, so the one in-app run was
a debug build, for about a minute, before any model was loaded. It idled at
1.6 GiB, 1.3 GiB of it the debug Dart VM (JIT code and heap), which a
shipped build does not carry, and peaked at 3.2 GiB while starting. Those
figures say nothing about a shipped app's idle memory, so the model figures
above are reported on their own.

## The iOS Simulator

On an iPhone 17e Simulator (debug build, fresh install), downloading and
installing the pack, analysing the photo and scanning the video all work: 8
fish boxed in the photo, 21 tracks named in the video in about 90 seconds,
one suggestion shown. The Simulator runs Core ML on the Mac's CPU and, unlike
macOS, keeps about 1.3 GB of the weights in counted memory: 0.5 GiB idle,
2.2 GiB at the peak of the install's load check, 1.9 to 2.1 GiB with the
models loaded. Those figures stand for neither a Mac nor a phone, and have no
per-app limit to compare with.

## On an iPhone

Measured on 2026-11-18 on an iPhone 17 Pro Max (iPhone18,2, 12 GB, iOS
27.2.1), with the same pack, photo and clip. The figures are the app's own
memory readout ([the developer guide](../../developer/species-identification.md#memory-readout)),
one line after each stage, from a profile build with marine life
identification on. The test build had its own bundle id and no iCloud,
HealthKit or push, so it started empty and never saw the diver's log. A
build made with Xcode 27 is stopped at launch on iOS 27 unless the app
adopts the UIScene lifecycle (#4696), so the test build adopted it in a
scratch copy; that changes only the order the window and the engine start
in.

| Stage | Footprint | Peak so far | Left | Neural Engine, counted |
| --- | --- | --- | --- | --- |
| Models loaded, photo open | 2,237 | 2,348 | 1,139 | 634 |
| Photo analysed | 2,388 | 2,432 | 988 | 718 |
| Models unloaded, photo open | 1,700 | 2,432 | 1,676 | 0 |
| Models loaded, video open | 1,417 | 2,708 | 1,959 | 634 |
| Video, pass 1 of each chunk | 1,480 to 1,517 | 2,708 | 1,859 to 1,896 | 712 to 718 |
| Video, pass 2 of each chunk | 1,485 to 1,515 | 2,708 | 1,861 to 1,891 | 718 |
| Models unloaded, video open | 785 | 2,708 | 2,591 | 0 |

MiB throughout. What the run showed:

- **The limit was 3,376 MiB.** Footprint plus what is left came to that on
  every line, so the limit held still for the whole run.
- **iOS counts the Neural Engine's memory.** The not-counted ledger stayed
  at zero; the models' memory went into the counted ledger and so into the
  footprint. The models cost about 0.7 GiB of the limit while in use.
  Unloading frees it at once; on the Mac it was gone by the sample half a
  second after unloading.
- **The idle classifier is dropped and brought back.** At the start of
  later scans the counted figure fell to 131 MiB, most likely the
  detector alone, and rose to 718 MiB again when pass 2 used the
  classifier.
- **The app's own media cost more than the models.** With the 50 MP photo
  open in the viewer and no model loaded, the app was at 1,700 MiB; with
  the video open, 785 MiB. Its overall peak, 2,708 MiB with 668 MiB left,
  came while no model was loaded, in the minutes when about 20 photos and
  videos were being added to the dive.
- **Nothing was stopped.** No memory report was filed for the app during
  the run. Installing the pack did file a disk writes report: 1,074 MB
  written in 15 minutes, over iOS's 1 GB a day threshold. That is a report,
  not a stop, but a shipped build would show it to the developer.
- **Speed.** The photo took about 0.4 s. The 27 second clip was scanned in
  about 7 s: pass 1 took about 1.6 s per 10 seconds of video, and pass 2 up
  to 1.9 s a chunk.

## Still open

- **A 6 GB iPhone.** Its limit is unmeasured. If it is about 3 GB, as
  developers commonly report, identification's highest point here (2.4 GiB
  with a 50 MP photo open) would leave about 0.5 GB, and the app's media
  peak much less. Its Neural Engine (the A15 or A16) may also place the
  models differently.
- **The app's own memory with large media.** The viewer holds the app at
  1.6 GiB with one 50 MP photo, and the minutes of adding many media at
  once reached 2.6 GiB. That is outside identification but sets the real
  ceiling. Traced in [the media memory findings](2026-11-18-media-memory.md)
  (#4699).
- **The Increased Memory Limit entitlement**
  (`com.apple.developer.kernel.increased-memory-limit`) was not tried; the
  app does not have it.

Until a 6 GB phone is measured, the 6 GB floor (`minimumMemoryBytes` in
`SubmersionVisionPlugin.swift`) stays as it is.
