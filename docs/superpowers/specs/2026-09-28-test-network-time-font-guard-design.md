# Tests that cannot reach the network, hang for minutes, or fetch fonts

## Problem

Since #2504, CI runs test files in bundles: generated entrypoints that import
many test files and run them in one isolate. Two kinds of test that pass on
their own fail there, and nothing catches either before it reaches main.

1. **A test that reaches the network passes alone and fails bundled.**
   `flutter_test` swaps in a fake `HttpOverrides` (every request answers 400)
   only when the widget binding is first set up. A plain `test()` file run on
   its own has no binding, so its requests reach the real network. In a bundle
   an earlier widget test has already set up the binding, so the same request
   quietly gets a 400. #2484's invoice test hit this after merge: it fetched PDF
   fonts over the network.
2. **A test that waits on unfinished work hangs for minutes.** Widget tests
   run under the binding's `defaultTestTimeout`, 10 minutes. In #2536 three
   theme tests awaited `GoogleFonts.pendingFonts()`, which waits for every font
   load in the isolate; an earlier file's widget tests had started loads whose
   fake clocks then stopped, so each theme test hung until its timeout and
   `Test (shard 3)` ran past CI's 40-minute limit. #2537 bounded that one
   wait, but any other test that waits on leaked work would hang the same way.

The font loads are themselves the cause of the second case: runtime font
fetching is on by default, so a widget test that renders the app theme starts
a download it never finishes.

## Goal

The same test behaves the same way alone, bundled, locally and in CI:

- a request to anything but the machine itself fails the test, naming the URL;
- a test that hangs fails in about two minutes, not ten, and its name says
  which file it is in;
- no test starts a font download.

## Decisions

| Topic | Decision |
|---|---|
| Network | Blocked for every entrypoint from its start, loopback allowed, failing with the URL |
| Sockets | Raw `Socket.connect` to a non-loopback host is blocked the same way |
| Time limit | One measured per-test limit for plain and widget tests |
| Fonts | Runtime fetching off in the shared test defaults, after a probe |
| Delivery | One issue, one PR; the network-reaching test fixes go first, in their own PR if there are more than about ten |

## Design

### Network

`testExecutable` in `test/flutter_test_config.dart` runs once per entrypoint,
whether that is one test file or a bundle. It will:

1. call `TestWidgetsFlutterBinding.ensureInitialized()`, so Flutter's own
   `HttpOverrides` swap happens now, before any test, rather than at whichever
   widget test comes first;
2. install `BlockedNetworkHttpOverrides` and `BlockedNetworkIOOverrides`, from a
   new `test/helpers/blocked_network.dart`.

The HTTP override's `HttpClient` connects normally to loopback hosts
(`localhost`, `127.0.0.1`, `::1`), so the tests that start a local
`HttpServer` keep working. Any other host fails with a `StateError`:

> A test reached the network: GET https://example.com/fonts.ttf. Tests must
> not depend on the network; inject a fake client, serve it from a loopback
> HttpServer, or use loadPdfRoboto for PDF fonts.

The IO override does the same for `Socket.connect`, which does not go through
`HttpOverrides`.

`applyGlobalTestDefaults()` installs both overrides, so a bundle puts them back
between files. `GlobalStateSnapshot` already records `HttpOverrides.current`;
it also records `IOOverrides.current`. Its exception for values "installed by
the binding" (`HttpOverrides.current`, `debugPrint`) stops mattering once the
binding exists before any file runs, so a file that swaps an override and does
not restore it fails like any other leak. The tests that override HTTP on
purpose (`fake_nominatim`, `location_service_test`) use
`HttpOverrides.runZoned`, which wins inside its zone and leaves the global
override alone; `trusted_http_overrides_test` builds clients directly and never
touches it.

### Time limit

A test's time limit comes from one of two places: `package:test`'s timeout for
plain tests and `setUpAll`/`tearDownAll` (set by `dart_test.yaml` or
`--timeout`), and the widget binding's `defaultTestTimeout` for `testWidgets`
(10 minutes). `test/helpers/test_timeouts.dart` holds one constant;
`dart_test.yaml` sets the same `timeout:`, and `testExecutable` sets
`binding.defaultTestTimeout` from the constant after setting up the binding.

The limit is chosen by measurement. One run of the suite with
`--reporter json` records every test's start and finish; the limit is the
slowest test's duration with a wide margin, expected to be about two minutes.
A test close to it declares its own `timeout:` with a comment saying why.
CI's job timeout stays as the last resort. Files with a file-level `@Timeout`
already run alone, outside bundles, so their limits still apply.

### Fonts

`applyGlobalTestDefaults()` sets `GoogleFonts.config.allowRuntimeFetching` to
`false`, and `GlobalStateSnapshot` records it. The three theme tests that turn
it off themselves (`app_theme_registry_test`, `status_colors_test`,
`theme_preset_accents_test`) drop their own toggling and restore code and keep
`settleGoogleFonts`.

This depends on what a widget test that renders the app theme does when the
font cannot be fetched. The theme tests show the load failing within
milliseconds; whether a widget test reports that failure as an error is not
yet known. The first implementation task measures it. If such tests fall back
quietly, the design stands. If they report errors, the work stops there and
the options (for example test-only font assets) come back for a decision.

### Documentation

`docs/developer/testing.md` gets a "Network, time limits and fonts" section:
what is blocked and why, how to serve a fake over loopback, the limit and how
a slow test declares its own, and that fonts are never fetched.

## Testing

`test/helpers/blocked_network_test.dart` and neighbours check that:

- a request to a public host fails with its method and URL;
- a loopback `HttpServer` still answers;
- a raw `Socket.connect` to a public host fails;
- `HttpOverrides.runZoned` still wins inside its zone;
- a plain `test()` in a file with no widget test sees the same block, which is
  the "same everywhere" promise;
- the binding's `defaultTestTimeout` and `dart_test.yaml`'s `timeout` both equal
  the constant;
- the shared defaults leave font fetching off.

## Delivery

One issue and one PR, in this order:

1. **Measure:** run the suite with the guard enabled in a scratch commit and
   with `--reporter json`, to list the tests that reach the network, every
   test's duration, and how theme-rendering widget tests behave with fetching
   off.
2. **Fix** each network-reaching test (fake client, loopback server, or
   `loadPdfRoboto`). More than about ten fixes go in their own PR first.
3. **Guard:** the overrides, the binding set-up, the snapshot and defaults
   changes, and their tests.
4. **Time limit:** the constant, `dart_test.yaml`, the binding timeout, and any
   slow test's own `timeout:`.
5. **Fonts:** the default, the snapshot, and the three theme tests.
6. **Docs.**

Done when the whole suite passes through `scripts/run_all_tests.sh` locally
with the guard on, and all six CI shards pass.

## Out of scope

- Tests under `integration_test/`, which run on devices and may use the
  network by design.
- Pruning low-value tests (Track 3, deferred).
