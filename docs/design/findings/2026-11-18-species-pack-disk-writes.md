# Species pack install: disk writes

Issue #4708. Installing the marine life species pack on an iPhone 17 Pro Max
filed an iOS disk writes report: 1,074 MB written in 15 minutes, over the
limit of 1 GB a day ([phone memory findings](2026-11-17-marine-life-phone-memory.md)).
1,074 MB is 1 GiB (1,073.7 MB): iOS files the report when the limit is
crossed, so the install's full total was higher than the report shows.

## How it was measured

On a Mac, with `proc_pid_rusage` (`ri_logical_writes` and
`ri_diskio_byteswritten`) read before and after each step, against the live
pack 2026.11.18.0356 served locally (all six files match the manifest's
SHA-256). The download and install ran the app's own `SpeciesPackDownloader`
and `SpeciesPackStore` in a test process; the Core ML steps ran in a small
Swift tool that does what `VisionPipeline.compiledModel` and `load` do.

Xcode's Organizer and MetricKit report disk writes as logical writes, so the
logical column is the one that counts toward the iOS limit.

The pack downloads 633.6 MB. Unpacked, its models are 777.2 MB: the
classifier's weights are 608 MB (the zip saves 25%), the Megalodon
detector's 114 MB and the first detector's 55 MB (7 to 8%).

## Before

| Step | Logical writes | Disk writes |
|---|---|---|
| Download the six files | 634 MB | 633 MB |
| `install()`: unzip the three models | 779 MB | 777 MB |
| `MLModel.compileModel` and the move beside the package | about 1.5 MB | about 1 MB |
| First model load, `.all` compute units (the installer's warm-up) | 3,227 MB | 777 MB |

The app's own code wrote 1,413 MB: each model once as a zip and again
unpacked.

## After

Each model zip is unpacked as it downloads (`ZipStreamUnpacker`), so the zip
is never written. The hash is still checked over the zip's bytes as they
arrive, and the unpacked folder is renamed into place only when it matches.

| Step | Logical writes | Disk writes |
|---|---|---|
| Download the six files, unpacking the models | 797 MB | 790 to 796 MB |
| `install()` | 0 MB | 0 MB |
| Compile and first load | unchanged | unchanged |

The models unpacked this way are byte for byte those `unzip` gives, and Core
ML compiles and loads them.

The cost: a download cut off partway through a model zip starts that zip
again, as there is no zip on disk to resume. Files already finished are
kept, and the naming files still resume with a Range request.

## What Core ML writes

- **Compiling is nearly free.** `MLModel.compileModel` gives the compiled
  model's `weight.bin` as an APFS clone of the package's, so it writes about
  0.3 MB per model.
- **The first load writes a full copy of the weights.** Core ML builds a
  device-specific cache (`com.apple.e5rt.e5bundlecache` in the app's
  `Library/Caches`, 740 MB here). Each compute-unit setting gets its own
  entry: loading with `.cpuOnly`, `.cpuAndGPU` and `.cpuAndNeuralEngine` each
  wrote another 608 MB for the classifier. On the Mac the `.all` load counts
  3.2 GB of logical writes, mostly temporary files that never reach the disk.
- **A cached load still counts.** A later `.all` load wrote nothing to disk
  but counted the weights' size (777 MB) in logical writes.

The app cannot avoid these. Whether the phone counts them the same way is
unmeasured: on an iPhone the Neural Engine compile runs in
`ANECompilerService`, a separate process whose writes are its own. If the
phone does count about 777 MB for each model load, a day with two separate
identification sessions would cross the limit without any install.
