# Local Test Run Performance

How to make `flutter test` fast on a development machine, especially when
several worktrees are running tests at once.

This page is about the speed of *running* the test suite. For the tests that
measure application performance, see the Performance Tests section of
[Testing](testing.md).

## Summary

Local test runs are limited by disk throughput, not by CPU. `flutter test`
writes and copies a large kernel file for every test file, so a run moves tens
of gigabytes through `$TMPDIR`. Pointing `$TMPDIR` at a RAM disk measured
between 1.3x and 2x faster, and stops concurrent worktrees from fighting over
the SSD. The benefit scales with how busy the machine is: nearer 1.3x when
little else is running, nearer 2x when several worktrees are testing at once.

The tuning is machine-local by design. Only these instructions live in the
repository; the scripts, shell config, and launch agents all sit outside it, in
`~/.local/bin`, `~/.zshenv`, and `~/Library/LaunchAgents`. Nothing here changes
CI behaviour, and the numbers below are tuned to one specific machine, so treat
them as a starting point rather than settings to copy verbatim.

## Why runs are slow

### Every test file writes a copy of the app kernel

`flutter_tools` compiles each test file into a Dart kernel (`.dill`) and then
copies it, in `packages/flutter_tools/lib/src/test/test_compiler.dart`:

```dart
if (shouldCopyDillFile) {
  final File kernelReadyToRun = await outputFile.copy('$path.dill');
  if (firstCompile || !testCache.existsSync() ||
      (testCache.lengthSync() < outputFile.lengthSync())) {
    await outputFile.copy(testFilePath);   // second copy
  }
```

Measured sizes for this project on a warm run:

| Artifact | Size |
|---|---|
| `output.dill`, early in a run | 66 MB |
| `listener.dart.dill`, mid run | 133 MB |
| `listener.dart.dill`, late in a run | 207 MB |
| `.dart_tool/flutter_build/.../app.dill` | 217 MB |

So each test file costs roughly 200 MB written, 200 MB copied, and 200 MB read
back by `flutter_tester`, or about half a gigabyte of I/O per file. During runs
the disk was observed sustaining 1.6 to 2.9 GB/s at 21,000 to 27,500 IOPS with
10 to 17 percent of CPU time spent in the kernel doing those copies.

Note that the kernel grows as a run proceeds, because the resident compiler
accumulates every package it has seen. The 500th test file in a run is far more
expensive than the 10th. This is why per-file load cost looks flat and has no
single slow-file outlier to fix: the cost tracks accumulated kernel size, not
the complexity of the individual file.

### Compilation is serialized within each invocation

Each `flutter test` invocation creates one `TestCompiler` and queues every
compile through it. The queue comment in `test_compiler.dart` is explicit:

> Only trigger processing if queue was empty ... This effectively enforces "one
> compilation request at a time".

Test suites therefore cannot start faster than a single compiler emits kernels.
Sampling a run showed the live `flutter_tester` count swinging between 0 and 13
while a lone compiler sat pinned at most of one core and the machine was over
80 percent idle.

### The default concurrency is half your cores

`package:test` defaults to `max(1, Platform.numberOfProcessors ~/ 2)`. On an
18-core machine that is 9. Raising it helps, but only slightly, because the
compiler and the disk are the real limits:

| `-j` (24 files) | Wall time |
|---|---|
| 1 | 77.3s |
| 9 (default) | 27.1s |
| 18 | 26.3s |
| 36 | 25.3s |

## Setup

### 1. RAM disk helper

Create `~/.local/bin/flutter-ramtmp`:

```bash
#!/usr/bin/env bash
# Create (idempotently) a RAM-backed volume for Flutter's test temp traffic.
#
# Why: `flutter test` copies the incremental kernel once per test file. Those
# dills run 66-207 MB each and grow as a run proceeds, so a single invocation
# moves tens of GB through $TMPDIR. On a laptop running several worktrees at
# once that saturates the NVMe long before it saturates the CPU.
#
# Usage:
#   flutter-ramtmp [size_gb]             create if missing (default 24), print
#                                        the temp dir:
#                                          export TMPDIR="$(flutter-ramtmp)/"
#   flutter-ramtmp --clean [hours]       delete flutter_tools.* dirs left by
#                                        killed or hung runs: nothing inside
#                                        written for <hours> (default 3) and no
#                                        live process naming the dir
#   flutter-ramtmp --clean-dry-run [h]   list what --clean would delete
#   flutter-ramtmp --recreate [size_gb]  detach and rebuild at a new size;
#                                        refuses while any flutter test
#                                        process is alive (contents are lost)
#
# A ram:// device cannot be resized in place (`hdiutil resize` returns EINVAL
# and there is no partition to grow), which is why --recreate exists.

set -euo pipefail

DEFAULT_GB="${FLUTTER_RAMTMP_GB:-24}"
VOL_NAME="fltmp"
MOUNT="/Volumes/${VOL_NAME}"
TMPSUB="${MOUNT}/tmp"

is_mounted() {
  mount | grep -q " on ${MOUNT} "
}

create() {
  local size_gb="$1"
  if is_mounted; then
    mkdir -p "${TMPSUB}"
    echo "${TMPSUB}"
    return 0
  fi

  # 512-byte sectors
  local sectors=$(( size_gb * 1024 * 1024 * 2 ))
  local dev
  dev="$(hdiutil attach -nomount "ram://${sectors}" 2>/dev/null | awk '{print $1}')"
  if [ -z "${dev}" ]; then
    echo "flutter-ramtmp: hdiutil failed to allocate ram://${sectors}" >&2
    return 1
  fi

  # erasevolume formats and mounts in one step, no sudo required.
  if ! diskutil erasevolume HFS+ "${VOL_NAME}" "${dev}" >/dev/null 2>&1; then
    echo "flutter-ramtmp: failed to format ${dev}" >&2
    hdiutil detach "${dev}" >/dev/null 2>&1 || true
    return 1
  fi

  mkdir -p "${TMPSUB}"
  echo "${TMPSUB}"
}

# PIDs and commands of every process that is part of a `flutter test` run.
flutter_test_procs() {
  ps -axo pid=,command= |
    grep -E 'flutter_tools\.snapshot test|/flutter_tester ' |
    grep -v grep || true
}

clean() {
  local hours="$1" dry_run="$2"
  is_mounted || return 0
  local minutes=$(( hours * 60 ))
  local live
  live="$(ps -axo command= || true)"

  local d freed=0 kb
  for d in "${TMPSUB}"/flutter_tools.*; do
    [ -d "${d}" ] || continue
    # A running suite writes a new dill per test file, so anything written
    # within the window means the run is still alive.
    if [ -n "$(find "${d}" -mmin "-${minutes}" -print -quit 2>/dev/null)" ]; then
      continue
    fi
    # A live flutter_tester names its listener dill on its command line.
    if printf '%s\n' "${live}" | grep -qF "${d}/"; then
      continue
    fi
    kb="$(du -sk "${d}" | awk '{print $1}')"
    freed=$(( freed + kb ))
    if [ "${dry_run}" = 1 ]; then
      echo "would delete ${d} ($(( kb / 1024 )) MB)"
    else
      rm -rf "${d}"
      echo "deleted ${d} ($(( kb / 1024 )) MB)"
    fi
  done
  if [ "${dry_run}" = 1 ]; then
    echo "flutter-ramtmp: $(( freed / 1024 )) MB in stale dirs (dry run)"
  else
    echo "$(date '+%F %T') flutter-ramtmp: freed $(( freed / 1024 )) MB"
  fi
}

recreate() {
  local size_gb="$1"
  local procs
  procs="$(flutter_test_procs)"
  if [ -n "${procs}" ]; then
    echo "flutter-ramtmp: refusing to recreate, flutter test processes are running:" >&2
    printf '%s\n' "${procs}" | cut -c1-160 >&2
    return 2
  fi
  if is_mounted; then
    # No -force: a volume something still has open stays mounted.
    if ! hdiutil detach "${MOUNT}" >/dev/null 2>&1; then
      echo "flutter-ramtmp: ${MOUNT} is busy; not detaching" >&2
      return 1
    fi
  fi
  create "${size_gb}"
}

case "${1:-}" in
  --clean) clean "${2:-3}" 0 ;;
  --clean-dry-run) clean "${2:-3}" 1 ;;
  --recreate) recreate "${2:-${DEFAULT_GB}}" ;;
  -h|--help) sed -n '2,24p' "$0" ;;
  *) create "${1:-${DEFAULT_GB}}" ;;
esac
```

Then `chmod +x ~/.local/bin/flutter-ramtmp`.

Size it for your machine. 24 GB out of 64 GB is comfortable: it leaves room
for several worktrees testing at once while capping what leftover temp files
can hold at well under half of RAM. Allocation is lazy, so an idle RAM disk
costs almost nothing; only the pages actually written consume memory.

#### Changing the size

A `ram://` device cannot grow or shrink while mounted. `hdiutil resize`
rejects it with `Invalid argument (22)`, and `diskutil erasevolume` puts the
filesystem straight on the device with no partition to resize. The only way
to change the size is to detach the volume and build a new one, which
discards its contents. `--recreate` does that safely: it refuses while any
`flutter test` or `flutter_tester` process is alive, and it detaches without
`-force`, so a volume that something still has open stays mounted.

```bash
~/.local/bin/flutter-ramtmp --recreate 24
```

To make a new size stick across logins, also change the size argument in the
login agent (step 3). The agent's argument wins over the script's default.

### 2. Point `TMPDIR` at it

Append to `~/.zshenv`, not `~/.zshrc`. `.zshrc` is only sourced for
interactive shells, and a great deal of tooling shells out with `zsh -c`, which
would silently miss the setting. The guard matters too: if the volume is not
mounted, the shell falls back to the system default rather than breaking.

```bash
if [ -d /Volumes/fltmp/tmp ]; then
  export TMPDIR=/Volumes/fltmp/tmp/
fi
```

#### One consequence worth knowing

On macOS a RAM disk can only mount under `/Volumes/`, and that is exactly the
pattern `VolumeStatus.volumeRootOf` uses to recognise a removable drive. Any
test that writes a fixture to `Directory.systemTemp` and then expects it to
look like it is on the boot volume will therefore see the opposite once
`TMPDIR` points at the RAM disk.

That bit `local_file_resolver_test.dart`, which asserted a temp path needs no
mount probe: the resolver classified the fixture as sitting on an unmounted
volume and returned `UnavailableData`. Because the pre-push hook runs the tests
affected by your change, the failure blocked pushes for a reason unrelated to
the code being pushed. CI never saw it, since CI uses the default temp
directory.

That test now anchors its fixtures to the boot volume itself, so the RAM disk
is safe to use. If you hit the same shape in a new test, either anchor the
fixture the same way or pass an explicit `platformOverride` to `VolumeStatus`
rather than relying on the real heuristics. As a one-off escape hatch,
`TMPDIR=/private/tmp` in front of a single command restores the default without
unsetting anything.

### 3. Recreate it at login

A RAM disk does not survive a reboot. Create
`~/Library/LaunchAgents/app.local.flutter-ramtmp.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>app.local.flutter-ramtmp</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/YOUR_USERNAME/.local/bin/flutter-ramtmp</string>
    <string>24</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/flutter-ramtmp.out</string>
  <key>StandardErrorPath</key>
  <string>/tmp/flutter-ramtmp.err</string>
</dict>
</plist>
```

Load it with
`launchctl load ~/Library/LaunchAgents/app.local.flutter-ramtmp.plist`.
`ProgramArguments` needs an absolute path, so substitute your own username.

The size argument here is what persists: the agent runs at every login and
passes it to the helper, overriding the helper's own default.

### 4. Clean up leftovers automatically

A killed or hung `flutter test` never deletes its `flutter_tools.*` directory,
and each one holds hundreds of megabytes to over a gigabyte of kernels. Left
alone they fill the volume. When that happens the compiler fails with
`No space left on device` and `flutter test` hangs forever instead of exiting,
which leaves yet another directory behind (see [Maintenance](#maintenance)).

Create `~/Library/LaunchAgents/app.local.flutter-ramtmp-clean.plist` to run
`--clean` every 30 minutes. It deletes only directories with nothing written
inside them for 3 hours and not named by any live process, so running suites
are never touched:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>app.local.flutter-ramtmp-clean</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/YOUR_USERNAME/.local/bin/flutter-ramtmp</string>
    <string>--clean</string>
    <string>3</string>
  </array>
  <key>StartInterval</key>
  <integer>1800</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/flutter-ramtmp-clean.out</string>
  <key>StandardErrorPath</key>
  <string>/tmp/flutter-ramtmp-clean.err</string>
</dict>
</plist>
```

Load it with
`launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/app.local.flutter-ramtmp-clean.plist`.
`flutter-ramtmp --clean-dry-run` lists what it would delete.

### 5. A wrapper that applies the tuning

Create `~/.local/bin/ft` so you do not have to remember the flags:

```bash
#!/usr/bin/env bash
# `flutter test` with this machine's tuning applied.
# Usage: ft [paths/flags...]      Env: FT_JOBS (default 18)
# Measured 1.3x to 2x on a 48-file run, widening with concurrent load.
set -uo pipefail

if [ -x "${HOME}/.local/bin/flutter-ramtmp" ]; then
  if RAMTMP="$("${HOME}/.local/bin/flutter-ramtmp" 2>/dev/null)" && [ -d "${RAMTMP}" ]; then
    export TMPDIR="${RAMTMP}/"
  fi
fi

exec flutter test -j "${FT_JOBS:-18}" "$@"
```

Set `FT_JOBS` to roughly your core count. The default of 18 is tuned for an
18-core machine and should be lowered on smaller hardware.

## Results

Identical 48 test files, `-j 18`, runs interleaved to control for background
load drifting during the measurement:

| `TMPDIR` | Wall time |
|---|---|
| Default, on the internal SSD | 38.1s, 43.2s, 53.0s, 58.8s |
| RAM disk | 29.7s, 28.8s |

That is a range of 1.3x (38.1s against 29.7s) to 2.0x (58.8s against 28.8s),
not a flat 2x. The spread is the interesting part rather than noise to average
away: RAM disk runs stayed flat near 29s while SSD runs degraded from 38s to
59s as other worktrees started their own test runs. Moving temp traffic off the
SSD is what decouples concurrent worktrees from each other, so the busier the
machine, the more it is worth.

Two caveats on these numbers. They come from one machine, and no run was taken
on a genuinely idle system, since another worktree was testing throughout the
measurement window. The 1.3x figure is therefore a floor observed under light
load rather than a clean unloaded baseline, and a quiet machine may see less.

## Do not run multiple invocations in one worktree

It is tempting to shard the suite into several concurrent `flutter test`
invocations inside a single worktree. This was tried and measured, and it does
not work here. Two invocations in the same worktree share:

- `build/native_assets/<platform>/`, which every invocation rebuilds. One run
  rewrites the dylibs while another is reading them, producing
  `can't open file: .../libpdfium.dylib` and killing the run outright.
- The flutter startup lock, which serializes the phase anyway.

`build-dir` is user-level flutter config, not a per-invocation flag, so the
directory cannot be separated per shard.

Even after working around the startup race, sharding was not faster (49s versus
42s on 300 files) and it produced a spurious test failure that passed when run
alone. That is the same contention flakiness that makes overlapping local runs
unreliable in general.

Parallelism **across** worktrees is fine. Each worktree has its own `build/`
directory, so there is no shared mutable state between them.

## Maintenance

Killed or crashed runs leak their temp directories. These accumulate quickly
given the file sizes involved: 23 GB across 18 abandoned directories was
observed on one machine. A RAM disk makes this urgent rather than untidy:
once the volume is full, the compiler's write fails with
`No space left on device` and `flutter test` waits forever for a result that
never comes. It shows no failure and no summary line, and every run sits at 0%
CPU. The error is only visible with `flutter test -v`. Check the volume first
when runs stall:

```bash
df -h /Volumes/fltmp
ls -d /Volumes/fltmp/tmp/flutter_tools.* | wc -l
```

The cleanup agent from step 4 handles this on its own. To reclaim space
immediately:

```bash
~/.local/bin/flutter-ramtmp --clean-dry-run   # list what would go
~/.local/bin/flutter-ramtmp --clean           # delete it
~/.local/bin/flutter-ramtmp --clean 1         # shorter idle window, in hours
```

Staleness is judged by write time, not by `lsof`. A running suite opens each
kernel only briefly, so `lsof` frequently shows nothing open on the volume even
while several suites are running on it.

Orphaned `flutter_tester` processes also survive killed runs and pin their temp
directories. Identify them by a parent PID of 1, zero CPU, and a long elapsed
time:

```bash
ps -Ao pid,ppid,etime,pcpu,comm | grep flutter_tester | awk '$2 == 1'
```

Kill those by explicit PID. Never use a blanket `pkill -f flutter_tester`,
because that will also kill test runs belonging to other worktrees and other
sessions, which then look like mysterious failures with no summary line.

## Things that are not the problem

Worth recording so nobody re-investigates them:

- **Rosetta.** The engine artifacts live under a directory named `darwin-x64`,
  which looks alarming on Apple Silicon. It is a legacy directory name. Check
  with `file`, and the binary reports `Mach-O 64-bit executable arm64`.
- **Efficiency-core scheduling.** Check `sysctl hw.perflevel0.name` before
  assuming test processes are being parked on efficiency cores. On an M5 Pro
  the two levels report as "Super" and "Performance", with no efficiency
  cores involved.
