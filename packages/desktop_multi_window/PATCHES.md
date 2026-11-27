# Local patches to desktop_multi_window 0.3.1

Vendored from pub.dev (`desktop_multi_window` 0.3.1, MIT, see `LICENSE`) for
Submersion's desktop pop-out windows (issue #5078). The `example/` app is left
out. Everything else is the published package plus the patch below.

## macOS: the runner supplies each new window's engine project

`MultiWindowManager.CreateWindow` built every new window's engine from a plain
`FlutterDartProject()`. Submersion's main window renders through
`RendererDartProject` (macos/Runner/RendererDartProject.swift), which keeps
Intel Macs on Skia because Impeller flickers there (issue #3531). A plain
project would put every pop-out window back on Impeller.

`FlutterMultiWindowPlugin.setProjectFactory(_:)` lets the runner hand over a
factory; `CreateWindow` uses it when set and falls back to
`FlutterDartProject()` otherwise. `projectFactory` is readable so the runner's
tests can check the wiring.

When updating the package, re-apply this patch and keep the RunnerTests case
`PopOutWindowTests.testPopOutWindowsUseTheRendererProject` passing.
