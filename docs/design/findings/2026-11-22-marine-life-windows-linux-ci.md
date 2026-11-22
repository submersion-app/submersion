# Marine life identification: Windows and Linux in CI

Findings of task D3 of marine life identification piece 3
([design](../specs/2026-11-19-marine-life-identification-3-other-platforms-design.md),
[plan](../plans/2026-11-20-marine-life-identification-3-other-platforms.md)),
issue #4801. Design section 7 asks for the download, a photo, a rotated
photo, video, and on Windows the engine choice, to be checked by hand on a
Windows PC and a Linux PC.

The maintainer has neither machine, and chose on 2026-11-22 to run the
checks on GitHub's hosted runners instead: a per-PR Windows job for the
vision package's tests, and a full run of the app's engine on Windows and
Linux. Both landed in PR #4879. What a runner cannot show (a GPU, a vendor
engine, Windows 10) is listed at the end, still unchecked.

## How it was run

- **The check:** `integration_test/species_id_onnx/`, run by
  `.github/workflows/species-id-onnx-check.yml`. It runs on demand, and on
  a pull request that changes the workflow, `integration_test/species_id_onnx/`
  or `tool/species_id_onnx_it/`; a change to the engine itself does not
  start it, so one needs a run on demand. It builds the app for the
  runner's platform and drives the real `OnnxVisionEngine` and
  `SpeciesPackController`: the live pack is downloaded from its published
  manifest with the app's own client and downloader, unpacked, and loaded,
  as the settings page's Download does. Only two things differ: the pack
  goes under a test folder, and the analysis queue the Download pauses has
  nothing in it. Nine checks, and the job fails if any is skipped
  (`scripts/check_no_skipped_tests.py`).
- **Inputs:** two public domain NOAA photos (an anemonefish, 1024 x 768,
  and a goatfish school, 1024 x 666), each also stored turned with EXIF
  orientation 6; and two 3 second clips made from the anemonefish photo by
  ffmpeg, one landscape (1280 x 960) and one portrait (720 x 1280).
- **The run:** workflow run 45001349401 on PR #4879's head (5e09d53),
  2026-11-22. Both jobs passed, 9 of 9 checks each.

| | Linux | Windows |
|---|---|---|
| Runner image | `ubuntu-26.04` (kernel 7.0.0, Azure) | `windows-2025-vs2026` (Windows Server 2025, build 26100) |
| Processors | 4 | 4 |
| GPU | None | None; only the Microsoft Basic Render Driver |
| Engine devices offered | processor | hardware, DirectML, processor |
| ONNX Runtime threads | 2 | 2 |
| Memory reading | `VmRSS` and `VmHWM` | working set and its peak |

## Results

| | Linux | Windows |
|---|---|---|
| Pack 2026.11.20.0513 downloaded and installed (603 MB, 758 MB on disk) | 177 s, first attempt | 104 s, first attempt |
| First load, inside the Download | 2.4 s | 3.8 s |
| Load again, after the Download freed the models (same worker) | 1.3 s, on the processor | 3.1 s, on the processor |
| The same models again | 0 ms (nothing to do) | 0 ms (nothing to do) |
| Memory before loading | 759 MB | 548 MB |
| Memory with the models loaded | 3,807 MB (peak 3,860) | 2,175 MB (peak 2,758) |
| Anemonefish photo | 7.6 s, 5 detections; again 7.3 s | 8.1 s, 5 detections; again 7.9 s |
| Goatfish photo | 10.5 s, 8 detections | 10.9 s, 8 detections |
| Landscape clip, first 2 s chunk (8 frames) | Refused as unsupported, as designed | 18.3 s (2.3 s a frame), fish on all 8 |
| Portrait clip, first 2 s chunk (8 frames) | Refused as unsupported, as designed | 17.3 s (2.2 s a frame), fish on all 8 |
| Clip moments embedded for naming | Not applicable | 3 per clip, about 4 s each clip |
| Memory after unloading | **3,775 MB** (peak 4,477) | 412 MB (peak 2,944) |
| Reload after unloading | 1.3 s | 2.9 s |

What each check showed:

- **The download.** The pack came down whole on the first attempt on both,
  and each file's size and SHA-256 checked. An earlier run on the same day
  had the Linux download dropped at 181 of 603 MB by the network; the check
  now taps Download again up to three times, as a diver taps Retry, and
  resumes from what arrived. It was not needed this time.
- **The two builds agree.** Every detection on both photos has the same
  score and the same box on Linux and Windows, to three decimals.
- **Rotated photos.** A photo stored turned with EXIF orientation 6 gives
  its boxes back in the upright photo's place: overlap 0.974 to 1.000 with
  the upright detections, edges within 0.001, on both platforms. The
  upright photo with an orientation 6 tag added (so it shows on its side)
  is analysed on its side: 768 x 1024, taller than wide, as the check
  requires. Its boxes differ from the upright ones by more than the turn
  (overlap 0.073 to 0.932 with where the upright boxes land), as expected,
  since the models see the fish on its side.
- **Windows' engine choice.** Windows ML's catalogue was read in 12 ms and
  listed no engines, so the Download offered none to fetch
  (`offersEngineToFetch` and `fetchEngine` both answered false). DirectML
  was on the list of devices to try, and the models opened on the
  processor with no crash. B1 found that handing the Basic Render Driver's
  device to DirectML ends the process, while attaching DirectML by name
  fails cleanly ("No devices detected"). The shipped engine attaches
  DirectML by name, and its device filter (`chooseHardwareDevices`) keeps
  the driver off the hardware session; this run shows the two together
  falling back to the processor safely.
- **Video on Windows.** Both clips were read at their right size and
  shape, and every frame of the first chunk was scanned. The portrait clip
  is stored a quarter turn round with a display rotation that turns it
  back, and holds the photo letterboxed across its middle. Its top box
  (0.002, 0.290, 0.992 x 0.419) sits exactly in that band, so the rotation
  was applied before the models saw the frame; the crops kept for naming
  are that box, 714 x 536 px. The landscape clip's boxes match the upright
  photo's (0.274, 0.123, 0.227 x 0.531 against 0.281, 0.131, 0.227 x
  0.529), so its frames were upright too.
- **Linux is photos only.** The video calls were refused as unsupported, as
  task B15 designed.

## Open: Linux keeps the memory after unloading

On Windows the working set fell from 2.2 GB to 412 MB when the models were
unloaded. On Linux the resident set stayed at 3.8 GB, though the models
had gone: the check confirms a call after the unload is refused as not
loaded, and the reload took the full 1.3 s. Two likely causes, neither
checked: glibc's allocator keeps freed memory in the process rather than
handing it back to the system (`malloc_trim` returns it), or ONNX Runtime's
own memory arena keeps it. Windows' figure may also flatter it, since
Windows can trim a working set without the memory being freed.

What it may cost a diver: on a Linux PC the app holds about 3 GB from the
first time the models are freed until it quits. That is right after the
Download, which loads the models once and frees them, and again after each
quiet spell, when the app frees them on its own. A later load reuses what
is held rather than adding to it: the Download's load, its unload and the
check's next load, all in one worker, peaked at 3,860 MB together, not
the 6.8 GB two separate copies would need. The run's highest point, 4.5
GB, came between that load and the unload, while the photos were analysed;
no reading was taken in between to say which step reached it. Whether to
look into it is the maintainer's call.

## Not covered by CI

These still need a real machine, and the maintainer has none to hand:

- **A Windows PC with a GPU:** a vendor engine listed, fetched in the
  Download (`WinMLEpEnsureReady`) and still chosen after a relaunch; the
  catalogue's field order and callback thread with an engine listed;
  DirectML on a real GPU, and the Basic Render Driver beside it; the
  fallback to the processor when the GPU engine is made to fail; two
  vendor engines or two GPUs; the 100-photo comparison (D3 step 2); and
  speed on a GPU. Everything in D3 step 3 depends on this.
- **Windows 10**, with DirectML and the processor only.
- **A desktop Linux PC** with a display and a GPU driver. The runner ran
  under `xvfb`.
- **Speed on a diver's PC.** The runners' 4 shared processors are slower
  than most desktops, so the times above are an upper bound: a modest
  machine should take about this long and a faster one less. They are not
  a measure of what divers will see.
