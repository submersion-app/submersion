# Windows ML from an unpackaged app

Findings of task B1 of marine life identification piece 3
([design](../specs/2026-11-19-marine-life-identification-3-other-platforms-design.md),
[plan](../plans/2026-11-20-marine-life-identification-3-other-platforms.md)),
issue #4801. The question (design section 2a, risk "Windows ML in an
unpackaged app"): does Windows ML work from Submersion as it is installed
today, an unpackaged Win32 app with no package identity, before task B14
builds on it?

## How it was tested

A throwaway Flutter app in a private scratch repository, run on GitHub's
hosted Windows runners on 2026-11-20. Nothing from it ships.

- **Windows ML:** the `Microsoft.Windows.AI.MachineLearning` 2.5.96 NuGet
  package (SHA-256 `35d6e84f…53a3`), its three x64 DLLs copied beside the
  executable. No Windows App SDK, no bootstrapper, no change to the app
  manifest.
- **The code:** ONNX Runtime was driven through a copy of the app's own
  wrapper (`packages/submersion_vision/lib/src/ort/ort_runtime.dart`), and
  Windows ML's catalogue through its flat C header (`WinMLEpCatalog.h`) by
  Dart FFI.
- **Two hosts:** a Flutter 3.47.0 release build running the checks on a
  worker isolate, as the engine's worker does, and a plain Dart executable
  running them on its main thread.
- **Two machines:** Windows Server 2022 (build 20348) and Windows Server
  2025 (build 26100). Each has 2 AMD EPYC cores and no GPU: the display
  adapter is "Microsoft Hyper-V Video", and the only graphics device listed
  is the Microsoft Basic Render Driver, Windows' software renderer, with
  0 MB of video memory.
- **Session cases:** each GPU session case ran in a child process of its
  own, saving its stage before and after opening, so a native crash in one
  could not hide another.

## Answers

The two machines and the two hosts agreed on every point.

| Question (plan, B1 step 2) | Answer |
| --- | --- |
| Does it work with no Windows App SDK bootstrap? | Yes. The DLLs load beside the executable and the catalogue opens with no bootstrapper and no package identity. The package's README says the same for Windows 10 19H1 and later. |
| Files the installer carries | `onnxruntime.dll` 23,579,512 bytes, `DirectML.dll` 18,700,648, `Microsoft.Windows.AI.MachineLearning.dll` 979,792: 43.3 MB in all, and no other files. |
| Does the catalogue work on Windows 10? | Not tested: no Windows 10 runner exists. Server 2022 (build 20348, older than 24H2) behaved exactly as Server 2025 in everything tested. Windows 10 stays a hand check (D3). |
| ONNX Runtime version shipped | 1.28.3 (reported by `GetVersionString`; the package description says the same). |
| Does the catalogue need COM on the calling thread? | No: `WinMLEpCatalogCreate` returned `S_OK` on a worker isolate's thread that never initialised COM. |
| Hardware engines listed | None, as expected on machines without a GPU or NPU. |
| Devices ONNX Runtime lists | `CPUExecutionProvider` (processor) and `DmlExecutionProvider` (GPU type, on the Basic Render Driver). |
| A model on the processor | Correct output (`[2, 3, 4]` from the add-one test model). |

## A crash B14 must design around

Every path that hands the Basic Render Driver's device to DirectML ends the
process during session creation with exit code `0xC0000409` (a native
fast-fail). No error comes back to the caller, so a worker isolate cannot
catch it: in the app it would end the app.

| Session case | Result |
| --- | --- |
| Processor only (what the engine does today) | Runs, correct output |
| Selection policy "prefer GPU" (`SessionOptionsSetEpSelectionPolicy`) | Process crash while opening |
| The same, with CPU fallback disabled | Process crash while opening |
| DirectML's listed device attached explicitly (`SessionOptionsAppendExecutionProvider_V2`) | Process crash while opening |
| DirectML by name (`SessionOptionsAppendExecutionProvider("DML")`) | Clean error: "No devices detected that match the filter criteria" |
| The same, with CPU fallback disabled | The same clean error |

ONNX Runtime's log stops at the same line in all three crashes, just as the
session starts creating the DirectML engine for that device. The by-name call
screens out the software adapter itself; the device-based calls do not, and
DirectML fails on it in a way that is never turned into an error.

PCs whose only graphics device is the Basic Render Driver are real: virtual
machines, servers, and PCs with a missing or broken display driver. So:

- **B14 lists the devices itself** (`GetEpDevices`) and drops any hardware
  device that is the Basic Render Driver (vendor id `0x1414`, device id
  `0x8c`) before attaching an engine explicitly. It never uses the "prefer
  GPU" policy, which picks devices on its own.
- **`OrtDevice.preferGpu`** in the wrapper is unused today (every session
  opens on the processor) and must stay unused; B14 replaces it rather than
  calling it.
- **Nothing shipped is affected.** The merged engine opens every session on
  the processor (`OnnxWorker.spawn` defaults to `[OrtDevice.cpu]`), and
  Windows builds carry plain ONNX Runtime, not Windows ML, until B14.

## Not answered here

These need a Windows PC with a GPU, in D3:

- **Vendor engines.** Fetching a vendor's engine (`WinMLEpEnsureReady`), its
  library path, registering it, and running a model on it. No engine was
  listed on these machines, so none could be fetched.
- **The Basic Render Driver beside a real GPU.** Whether ONNX Runtime also
  lists it on a PC with a real GPU, and that the filtered list attaches the
  real one.
- **Windows 10**, and speed on a GPU.

## What it changes in the plan

- B1 step 3's stop (Windows ML cannot be made to work unpackaged) is not
  triggered. B14 goes ahead with Windows ML's three DLLs beside the
  executable, with no bootstrapper and no installer change beyond the
  files.
- B14 gains the device filter above, with a test for it, and the
  distribution terms the maintainer accepted on 2026-11-20 (Microsoft's
  terms on the installer's licence page, and a privacy note that Windows ML
  may send usage data to Microsoft).
