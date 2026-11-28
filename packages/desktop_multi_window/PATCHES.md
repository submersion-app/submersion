# Local patches to desktop_multi_window 0.3.1

Vendored from pub.dev (`desktop_multi_window` 0.3.1, MIT, see `LICENSE`) for
Submersion's desktop pop-out windows (issue #5078). The `example/` app is left
out. Everything else is the published package plus the patches below.

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

## macOS: a closed window's engine shuts down

A closed window was never freed: the plugins registered on its engine
(`window_manager` among them) hold the window, the window holds its view
controller, and that holds the engine. Every closed pop-out left an engine
running, with its Dart isolate, its database connection and its window-channel
registration, which also blocked a reopened window from pairing on the
channel. On `willClose` the observer now shuts the engine down and clears the
window's content view controller, on the next main-queue turn so the close
itself completes first.

## pubspec: no workspace resolution

The published pubspec says `resolution: workspace`, a leftover from the
upstream repository's pub workspace. Submersion has no workspace and uses the
package as a path dependency, so the line is removed: the package resolves as
an ordinary package, standalone included.

When updating the package, re-apply these patches and keep the RunnerTests case
`PopOutWindowTests.testPopOutWindowsUseTheRendererProject` passing.
