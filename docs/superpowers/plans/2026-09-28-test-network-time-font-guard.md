# Network, Time-Limit and Font Guard for Tests: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every test behave the same alone, bundled, locally and in CI: requests to anything but loopback fail with the URL, a hung test fails in about two minutes instead of ten, and no test fetches fonts.

**Architecture:** `test/flutter_test_config.dart` sets up the widget binding at the start of every entrypoint, and `applyGlobalTestDefaults()` installs a loopback-only `HttpOverrides` and `IOOverrides` (new `test/helpers/blocked_network.dart`) and turns off Google Fonts runtime fetching. The global-state snapshot and scanner learn the new globals. One measured time limit goes to `dart_test.yaml` for plain tests and to the binding's `defaultTestTimeout` for widget tests.

**Tech Stack:** Dart `dart:io` (`HttpOverrides`, `IOOverrides`), `flutter_test`, `package:test` config (`dart_test.yaml`), `google_fonts`, Python 3 (stdlib) for the measurement script.

**Spec:** `docs/superpowers/specs/2026-09-28-test-network-time-font-guard-design.md`

## Global Constraints

- Loopback means `localhost` and loopback addresses (`127.0.0.0/8`, `::1`), as text (IPv6 possibly in brackets) or as an `InternetAddress`.
- The refusal is a `StateError` whose message starts `A test reached the network: ` followed by the URL (HTTP) or `host:port` (sockets).
- The harness installs one shared instance of each override: the global-state snapshot compares by identity.
- Out of scope: `integration_test/`.
- Delivery: one issue, one PR; the network-reaching test fixes go first, in their own PR if more than about ten test files need them.
- No em-dashes, en-dashes as punctuation, `--` or spaced hyphens as prose punctuation, in code, comments, docs, commit messages or PR text (user rule).
- No mention of Claude, Claude Code or Anthropic in commits, PR text or comments (repo rule).
- Run `dart format .` before each commit that touches Dart.

## Deviations from the spec (rulings)

- **Order:** fonts (Task 3) land before the network guard (Task 5), not after. Widget tests that render the app theme start font downloads today; with the guard on and fetching still on, each would fail with a network refusal. Cost if wrong: none, the end state is the same.
- **Message names the URL, not the method.** The request is refused from `HttpClient.findProxy`, which receives only the URL. A connection factory would also see only the URL and would have to rebuild TLS for loopback `https`. The spec's example message is updated in Task 1. Cost if wrong: the method is missing from a message whose URL already identifies the call.

## Review Focus

1. A loopback server reached as `localhost`, `LOCALHOST`, `localhost.`, `127.0.0.1`, `127.x.y.z`, `::1` or `[::1]` must keep working; a host that merely contains `localhost` (`localhost.example.com`) must not. Pinned in Task 1.
2. A plain `test()` in a file with no widget test, run on its own, must be blocked exactly as in a bundle. Pinned in Task 5.
3. `Image.network` in a widget test must fail with its URL, not a silent 400. Pinned in Task 5.
4. A test that swaps `HttpOverrides.global` or `IOOverrides.global` and restores the captured value must leave the snapshot clean. Pinned in Task 5.
5. A file that turns font fetching back on without restoring it must be caught by the snapshot and by the scanner. Pinned in Task 3.

## File Structure

| File | Responsibility |
|---|---|
| `test/helpers/blocked_network.dart` (new) | `isLoopbackHost`, `networkRefusal`, `BlockedNetworkHttpOverrides`, `BlockedNetworkIOOverrides`, the two shared instances |
| `test/helpers/blocked_network_test.dart` (new) | The overrides in isolation, installed with `run*WithOverrides` zones |
| `test/helpers/blocked_network_harness_test.dart` (new) | What every test sees once the harness installs them: plain test, sockets, `Image.network` |
| `test/helpers/test_timeouts.dart` (new) | `testTimeLimit`, the one per-test limit |
| `test/helpers/test_timeouts_test.dart` (new) | `dart_test.yaml` and the binding both use `testTimeLimit` |
| `test/flutter_test_config.dart` | Binding first, then defaults; binding timeout |
| `test/helpers/global_test_defaults.dart` (+ its test) | Installs the overrides, turns off font fetching |
| `test/helpers/global_state_snapshot.dart` (+ its test) | Records `IOOverrides.current` and the font setting |
| `test/architecture/global_state_scanner.dart` (+ its test, + `test_global_state_restored_test.dart` docs) | Polices `IOOverrides.global` and the font setting |
| `dart_test.yaml` | `timeout:` for plain tests |
| Four font-toggling tests | Drop their own toggling |
| `docs/developer/testing.md` | "Network, time limits and fonts" section |

---

### Task 1: The blocking overrides

**Files:**
- Create: `test/helpers/blocked_network.dart`
- Create: `test/helpers/blocked_network_test.dart`
- Modify: `docs/superpowers/specs/2026-09-28-test-network-time-font-guard-design.md` (the example message)

**Interfaces:**
- Produces: `bool isLoopbackHost(Object? host)`; `StateError networkRefusal(String target)`; `class BlockedNetworkHttpOverrides extends HttpOverrides`; `class BlockedNetworkIOOverrides extends IOOverrides`; `final BlockedNetworkHttpOverrides blockedNetworkHttpOverrides`; `final BlockedNetworkIOOverrides blockedNetworkIOOverrides`.

- [ ] **Step 1: Write the failing tests**

`test/helpers/blocked_network_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'blocked_network.dart';

class _FakeClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Matcher _refusalOf(String target) => isA<StateError>().having(
  (error) => error.message,
  'message',
  startsWith('A test reached the network: $target.'),
);

void main() {
  group('isLoopbackHost', () {
    for (final host in [
      'localhost',
      'LOCALHOST',
      'localhost.',
      '127.0.0.1',
      '127.1.2.3',
      '::1',
      '[::1]',
    ]) {
      test('$host is this machine', () {
        expect(isLoopbackHost(host), isTrue);
      });
    }

    test('loopback InternetAddresses are this machine', () {
      expect(isLoopbackHost(InternetAddress.loopbackIPv4), isTrue);
      expect(isLoopbackHost(InternetAddress.loopbackIPv6), isTrue);
    });

    for (final host in [
      'example.com',
      'fonts.gstatic.com',
      'localhost.example.com',
      '8.8.8.8',
      '10.0.0.1',
      '',
    ]) {
      test("'$host' is not", () {
        expect(isLoopbackHost(host), isFalse);
      });
    }

    test('anything that is not a host is not', () {
      expect(isLoopbackHost(null), isFalse);
      expect(isLoopbackHost(42), isFalse);
    });
  });

  group('BlockedNetworkHttpOverrides', () {
    test('a request to a public host fails with its URL', () async {
      final error = await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        try {
          await client.getUrl(Uri.parse('https://example.com/fonts.ttf'));
          return null;
        } catch (caught) {
          return caught;
        } finally {
          client.close(force: true);
        }
      }, blockedNetworkHttpOverrides);

      expect(error, _refusalOf('https://example.com/fonts.ttf'));
    });

    test('a loopback HttpServer still answers', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response
          ..write('ok')
          ..close();
      });

      final body = await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        try {
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:${server.port}/'),
          );
          final response = await request.close();
          return response.transform(utf8.decoder).join();
        } finally {
          client.close(force: true);
        }
      }, blockedNetworkHttpOverrides);

      expect(body, 'ok');
    });

    test('HttpOverrides.runZoned inside it still wins', () {
      final client = HttpOverrides.runWithHttpOverrides(
        () => HttpOverrides.runZoned(
          HttpClient.new,
          createHttpClient: (_) => _FakeClient(),
        ),
        blockedNetworkHttpOverrides,
      );

      expect(client, isA<_FakeClient>());
    });
  });

  group('BlockedNetworkIOOverrides', () {
    test('Socket.connect to a public host fails with host and port', () async {
      final error = await IOOverrides.runWithIOOverrides(
        () => Socket.connect('example.com', 443).then<Object?>((socket) {
          socket.destroy();
          return null;
        }, onError: (Object caught) => caught),
        blockedNetworkIOOverrides,
      );

      expect(error, _refusalOf('example.com:443'));
    });

    test('Socket.startConnect to a public host fails too', () async {
      final error = await IOOverrides.runWithIOOverrides(
        () => Socket.startConnect('8.8.8.8', 53).then<Object?>((task) {
          task.cancel();
          return null;
        }, onError: (Object caught) => caught),
        blockedNetworkIOOverrides,
      );

      expect(error, _refusalOf('8.8.8.8:53'));
    });

    test('Socket.connect to a loopback server still connects', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) => socket.destroy());

      final socket = await IOOverrides.runWithIOOverrides(
        () => Socket.connect(InternetAddress.loopbackIPv4, server.port),
        blockedNetworkIOOverrides,
      );
      socket.destroy();

      expect(socket.remoteAddress.isLoopback, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/helpers/blocked_network_test.dart`
Expected: FAIL to compile: `blocked_network.dart` does not exist.

- [ ] **Step 3: Write the implementation**

`test/helpers/blocked_network.dart`:

```dart
import 'dart:io';

/// Whether [host] is this machine: `localhost`, or a loopback address such as
/// 127.0.0.1 or ::1, as text (an IPv6 address may be in brackets) or as an
/// [InternetAddress].
bool isLoopbackHost(Object? host) {
  if (host is InternetAddress) return host.isLoopback;
  if (host is! String) return false;
  var name = host.toLowerCase();
  if (name.endsWith('.')) name = name.substring(0, name.length - 1);
  if (name == 'localhost') return true;
  if (name.startsWith('[') && name.endsWith(']')) {
    name = name.substring(1, name.length - 1);
  }
  return InternetAddress.tryParse(name)?.isLoopback ?? false;
}

/// The failure for a test that tried to reach [target] over the network.
StateError networkRefusal(String target) => StateError(
  'A test reached the network: $target. Tests must not depend on the '
  'network: inject a fake client, serve the response from a loopback '
  'HttpServer, or call loadPdfRoboto() for PDF fonts. See "Network, time '
  'limits and fonts" in docs/developer/testing.md.',
);

String _describe(Object? host) =>
    host is InternetAddress ? host.address : '$host';

/// Real [HttpClient]s that can only reach this machine.
///
/// HttpClient asks findProxy for every request's URL before it opens a
/// connection, and turns a throw there into that request's error. Refusing
/// there leaves TLS, certificates and everything else about the client as
/// they are.
class BlockedNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        if (!isLoopbackHost(uri.host)) throw networkRefusal('$uri');
        return 'DIRECT';
      };
  }
}

/// Sockets that can only reach this machine.
///
/// Covers `Socket.connect` and `Socket.startConnect`. A secure socket connects
/// below this hook, so an HTTPS request is refused by
/// [BlockedNetworkHttpOverrides] instead.
class BlockedNetworkIOOverrides extends IOOverrides {
  @override
  Future<Socket> socketConnect(
    host,
    int port, {
    sourceAddress,
    int sourcePort = 0,
    Duration? timeout,
  }) {
    if (!isLoopbackHost(host)) {
      return Future.error(networkRefusal('${_describe(host)}:$port'));
    }
    return super.socketConnect(
      host,
      port,
      sourceAddress: sourceAddress,
      sourcePort: sourcePort,
      timeout: timeout,
    );
  }

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(
    host,
    int port, {
    sourceAddress,
    int sourcePort = 0,
  }) {
    if (!isLoopbackHost(host)) {
      return Future.error(networkRefusal('${_describe(host)}:$port'));
    }
    return super.socketStartConnect(
      host,
      port,
      sourceAddress: sourceAddress,
      sourcePort: sourcePort,
    );
  }
}

/// The instances the harness installs. The global-state snapshot compares by
/// identity, so the same objects are installed every time.
final blockedNetworkHttpOverrides = BlockedNetworkHttpOverrides();
final blockedNetworkIOOverrides = BlockedNetworkIOOverrides();
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/helpers/blocked_network_test.dart`
Expected: PASS (all).

- [ ] **Step 5: Update the spec's example message**

In `docs/superpowers/specs/2026-09-28-test-network-time-font-guard-design.md`, replace the example refusal block

```text
> A test reached the network: GET https://example.com/fonts.ttf. Tests must
> not depend on the network; inject a fake client, serve it from a loopback
> HttpServer, or use loadPdfRoboto for PDF fonts.
```

with

```text
> A test reached the network: https://example.com/fonts.ttf. Tests must not
> depend on the network: inject a fake client, serve the response from a
> loopback HttpServer, or call loadPdfRoboto() for PDF fonts.

The request is refused from `HttpClient.findProxy`, which sees the URL but not
the method.
```

and in the Testing list replace "a request to a public host fails with its method and URL;" with "a request to a public host fails with its URL;".

- [ ] **Step 6: Analyze, format, commit**

```bash
flutter analyze test/helpers/blocked_network.dart test/helpers/blocked_network_test.dart
dart format .
git add test/helpers/blocked_network.dart test/helpers/blocked_network_test.dart docs/superpowers/specs/2026-09-28-test-network-time-font-guard-design.md
git commit -m "test: loopback-only HTTP and socket overrides for the test harness"
```

Expected: `No issues found!`.

---

### Task 2: Measure (nothing committed)

**Files:**
- Temporary: `test/flutter_test_config.dart`, `test/helpers/global_test_defaults.dart` (backed up, edited, restored)
- Scratch (outside the repo): `summarise_run.py`, `measure.jsonl`

**Interfaces:**
- Consumes: `blockedNetworkHttpOverrides`, `blockedNetworkIOOverrides` from Task 1.
- Produces (in the ledger): the list of test files that reach the network, with URLs; any failure caused by fonts being off; any other failure; the slowest tests; the chosen `testTimeLimit` in whole minutes.

- [ ] **Step 1: Back up the two files**

```bash
S=<scratchpad dir>
cp test/flutter_test_config.dart "$S/flutter_test_config.dart.bak"
cp test/helpers/global_test_defaults.dart "$S/global_test_defaults.dart.bak"
```

Restore with `cp` from these backups in Step 6, never with `git checkout`.

- [ ] **Step 2: Turn everything on, temporarily**

In `test/flutter_test_config.dart`, make `testExecutable` start with `TestWidgetsFlutterBinding.ensureInitialized();` (import `package:flutter_test/flutter_test.dart`). In `test/helpers/global_test_defaults.dart`, add at the end of `applyGlobalTestDefaults()`:

```dart
  HttpOverrides.global = blockedNetworkHttpOverrides;
  IOOverrides.global = blockedNetworkIOOverrides;
  GoogleFonts.config.allowRuntimeFetching = false;
```

with imports `dart:io`, `package:google_fonts/google_fonts.dart` and `blocked_network.dart`.

- [ ] **Step 3: Write the summary script**

`$S/summarise_run.py`:

```python
#!/usr/bin/env python3
"""Summarises `flutter test --reporter json` for the guard plan's Task 2."""

import collections
import json
import sys

tests, suites, starts, durations = {}, {}, {}, {}
errors = collections.defaultdict(list)
results = {}

with open(sys.argv[1], encoding="utf-8", errors="replace") as handle:
    for raw in handle:
        raw = raw.strip()
        if not raw.startswith("{"):
            continue
        try:
            event = json.loads(raw)
        except ValueError:
            continue
        kind = event.get("type")
        if kind == "suite":
            suites[event["suite"]["id"]] = event["suite"].get("path") or ""
        elif kind == "testStart":
            test = event["test"]
            tests[test["id"]] = (test.get("name", ""), test.get("suiteID"))
            starts[test["id"]] = event["time"]
        elif kind == "error":
            errors[event["testID"]].append(event.get("error", ""))
        elif kind == "testDone":
            test_id = event["testID"]
            results[test_id] = event.get("result")
            if not event.get("hidden") and test_id in starts:
                durations[test_id] = event["time"] - starts[test_id]


def file_of(test_id):
    name, suite = tests.get(test_id, ("", None))
    first = name.split(" ", 1)[0]
    if first.endswith("_test.dart"):
        return "test/" + first
    path = suites.get(suite, "")
    return "test/" + path.split("/test/", 1)[-1] if "/test/" in path else path


def category(messages):
    text = "\n".join(messages)
    if "A test reached the network" in text:
        return "network"
    if "google_fonts" in text or "GoogleFonts" in text or "allowRuntimeFetching" in text:
        return "fonts"
    return "other"


failed = collections.defaultdict(list)
for test_id, result in results.items():
    if result in ("failure", "error"):
        messages = errors.get(test_id, [])
        first = messages[0].splitlines()[0] if messages else ""
        failed[category(messages)].append(
            (file_of(test_id), tests.get(test_id, ("", None))[0], first)
        )

for kind in ("network", "fonts", "other"):
    rows = failed.get(kind, [])
    files = sorted({row[0] for row in rows})
    print(f"== {kind}: {len(rows)} failing tests in {len(files)} files")
    for row in sorted(rows):
        print(f"  {row[0]} :: {row[1]} :: {row[2][:160]}")

slowest = sorted(durations.items(), key=lambda item: -item[1])[:30]
print("== slowest tests (seconds)")
for test_id, millis in slowest:
    print(f"  {millis / 1000:7.1f}  {file_of(test_id)} :: {tests[test_id][0]}")
for seconds in (20, 40, 60, 120):
    over = sum(1 for millis in durations.values() if millis > seconds * 1000)
    print(f"== tests over {seconds}s: {over}")
```

- [ ] **Step 4: Run the whole suite bundled, as CI does, with the JSON reporter**

```bash
flutter test --exclude-tags performance --concurrency=16 --reporter json \
  $(python3 scripts/bundle_tests.py --total-shards 1 --max-files 40) \
  > "$S/measure.jsonl" 2> "$S/measure.err"
rm -rf test/.bundles
python3 "$S/summarise_run.py" "$S/measure.jsonl"
```

Expected: the run finishes (exit status non-zero is fine); the summary prints the three failure categories, the 30 slowest tests and the over-threshold counts. Check `df -h /Volumes/fltmp` first; a full temp disk hangs `flutter test` with no output.

- [ ] **Step 5: Decide, and record each decision in the ledger**

- **Fonts gate.** If `fonts` lists any failing test, STOP: report the list to the user with the options from the spec (for example test-only font assets) and wait. Otherwise record "fonts off: no failures".
- **Other failures.** For each `other` failure, run its file alone on the unmodified tree (after Step 6). Failing there too means it is already broken on main: record it and leave it. Passing there means the early binding or the overrides caused it: it joins Task 4's list.
- **Network list.** Record each file in `network` with the URLs. If more than ten files, Task 4 becomes its own PR (see Task 4).
- **Time limit.** Start from 2 minutes. Every test slower than a third of the limit gets its own timeout in Task 6. If more than ten tests are slower than a third of the limit, raise the limit one minute at a time until at most ten are. Record the limit in whole minutes and the list of tests that get their own timeout, with their measured durations.

- [ ] **Step 6: Restore and verify nothing is left changed**

```bash
cp "$S/flutter_test_config.dart.bak" test/flutter_test_config.dart
cp "$S/global_test_defaults.dart.bak" test/helpers/global_test_defaults.dart
git status --short
```

Expected: `git status` shows nothing.

---

### Task 3: Font fetching off for every test

**Files:**
- Modify: `test/helpers/global_test_defaults.dart`, `test/helpers/global_test_defaults_test.dart`
- Modify: `test/helpers/global_state_snapshot.dart`, `test/helpers/global_state_snapshot_test.dart`
- Modify: `test/architecture/global_state_scanner.dart` (`harnessDefaults`), `test/architecture/test_global_state_restored_test.dart` (doc comment)
- Modify: `test/core/theme/app_theme_registry_test.dart`, `test/core/theme/status_colors_test.dart`, `test/core/theme/theme_preset_accents_test.dart`, `test/features/trips/presentation/widgets/trip_list_content_test.dart`

**Interfaces:**
- Produces: `applyGlobalTestDefaults()` leaves `GoogleFonts.config.allowRuntimeFetching == false`; snapshot key `'GoogleFonts.config.allowRuntimeFetching'`; `harnessDefaults` contains `'GoogleFonts.config.allowRuntimeFetching'`.

- [ ] **Step 1: Write the failing tests**

In `test/helpers/global_test_defaults_test.dart` add `import 'package:google_fonts/google_fonts.dart';`, add `expect(GoogleFonts.config.allowRuntimeFetching, isFalse);` to the end of both tests, and add `GoogleFonts.config.allowRuntimeFetching = true;` beside the other assignments in `puts every harness default back`.

In `test/helpers/global_state_snapshot_test.dart` add `import 'package:google_fonts/google_fonts.dart';` and, after `a changed harness default is reported`:

```dart
  test('turning font fetching back on is reported', () {
    final before = GlobalStateSnapshot.take();
    addTearDown(applyGlobalTestDefaults);

    GoogleFonts.config.allowRuntimeFetching = true;

    expect(GlobalStateSnapshot.take().changedSince(before), [
      'GoogleFonts.config.allowRuntimeFetching',
    ]);
  });
```

In `test/architecture/global_state_scanner.dart` add `'GoogleFonts.config.allowRuntimeFetching',` to `harnessDefaults`. The existing loop in `global_state_scanner_test.dart` (`changing $name without the helper is an offence`) then covers it.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/helpers/global_test_defaults_test.dart test/helpers/global_state_snapshot_test.dart test/architecture/`
Expected: FAIL: the defaults leave fetching on; the snapshot does not report it; the restore guard flags the four font-toggling tests (`harness default`).

- [ ] **Step 3: Implement**

`test/helpers/global_test_defaults.dart`: add `import 'package:google_fonts/google_fonts.dart';`, append `GoogleFonts.config.allowRuntimeFetching = false;` to `applyGlobalTestDefaults()`, and add to its doc comment:

```dart
/// Google Fonts runtime fetching is off. A widget test that renders the app
/// theme would otherwise start a font download that never finishes once the
/// test's fake clock stops, and a later test that waits for pending fonts
/// hangs (issue #2536). The family name is still on every TextStyle.
```

`test/helpers/global_state_snapshot.dart`: add `import 'package:google_fonts/google_fonts.dart';` and the entry `'GoogleFonts.config.allowRuntimeFetching': GoogleFonts.config.allowRuntimeFetching,` after `'SensorSummaryScheduler.enabled'`.

`test/architecture/test_global_state_restored_test.dart`: in the doc comment bullet that lists `QualityScanScheduler.enabled`, `SensorSummaryScheduler.enabled` or `debugCanShareFiles`, add `GoogleFonts.config.allowRuntimeFetching`.

The four tests, which the defaults now cover:

- `app_theme_registry_test.dart`, `status_colors_test.dart`, `theme_preset_accents_test.dart`: delete the two comment lines `// Runtime fetching is off for this file's tests only. Set in setUpAll, not` / `// here, because a CI bundle declares every file before any test runs.`, the line `late bool originalFetching;`, the two lines `originalFetching = GoogleFonts.config.allowRuntimeFetching;` / `GoogleFonts.config.allowRuntimeFetching = false;`, and the line `tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = originalFetching);`. Keep `runZonedGuarded`, the `debugPrint` silencing and `settleGoogleFonts()`. Remove the `google_fonts` import if nothing else in the file uses it.
- `trip_list_content_test.dart`: delete the line `GoogleFonts.config.allowRuntimeFetching = false;` (line 1158), and replace the comment sentence `Disabling runtime fetching keeps that from reaching the network;` with `The test harness turns off runtime fetching, so that never reaches the network;`. Remove the `google_fonts` import if nothing else uses it.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/helpers/ test/architecture/ test/core/theme/ test/features/trips/presentation/widgets/trip_list_content_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze, format, commit**

```bash
flutter analyze test/helpers test/architecture test/core/theme test/features/trips/presentation/widgets/trip_list_content_test.dart
dart format .
git add test/helpers/global_test_defaults.dart test/helpers/global_test_defaults_test.dart test/helpers/global_state_snapshot.dart test/helpers/global_state_snapshot_test.dart test/architecture/global_state_scanner.dart test/architecture/test_global_state_restored_test.dart test/core/theme/app_theme_registry_test.dart test/core/theme/status_colors_test.dart test/core/theme/theme_preset_accents_test.dart test/features/trips/presentation/widgets/trip_list_content_test.dart
git commit -m "test: turn off Google Fonts runtime fetching for every test"
```

---

### Task 4: Tests that reach the network stop doing so

**Files:** the test files Task 2 recorded under `network` and under "other failures caused by the early binding or the overrides". If there are none, record "Task 4: none found" and skip to Task 5.

**Interfaces:**
- Consumes: Task 2's list; `loadPdfRoboto()` / `unloadPdfRoboto()` from `test/helpers/pdf_roboto.dart`; `FakeNominatim` from `test/helpers/fake_nominatim.dart` as the model for a fake `HttpClient`.

If the list has more than ten files, do this task on its own branch from `origin/main` (`ericgriffin/tests-without-network`), open its PR with `Refs #<issue>` (the issue from Task 7, opened now), and rebase nothing: Task 5 waits until that PR merges, then merges `origin/main` into this branch.

- [ ] **Step 1: For each file, reproduce its failure on its own with the guard on**

Repeat Task 2 Steps 1 and 2 (backup, temporary edits), then for each file:

Run: `flutter test <file>`
Expected: FAIL with `A test reached the network: <URL>`.

- [ ] **Step 2: Fix each file with the remedy that fits its URL**

- **PDF fonts** (URL on `fonts.gstatic.com` or a `pdf` font host, from `PdfFonts`): call the existing helper around the test, as other PDF tests do:

```dart
setUpAll(loadPdfRoboto);
tearDownAll(unloadPdfRoboto);
```

- **A service the code calls through `package:http`**: inject a `MockClient` from `package:http/testing.dart` where the code accepts a client, for example:

```dart
final client = MockClient((request) async => http.Response('{}', 200));
```

- **A service reached through `dart:io` `HttpClient` with no client parameter**: run the call inside a fake server's zone, as `test/helpers/fake_nominatim.dart` does with `HttpOverrides.runZoned(..., createHttpClient: (_) => FakeHttpClient(server))`.
- **A real server the test needs**: bind it on loopback (`HttpServer.bind(InternetAddress.loopbackIPv4, 0)`) and point the code at `http://127.0.0.1:<port>`.
- **`Image.network` in a widget**: give the widget a non-network `ImageProvider` in the test (for example `MemoryImage` of a 1x1 PNG), or assert on the error builder if the failure is the behaviour under test.

- [ ] **Step 3: Verify each fixed file passes with the guard on and off**

With the temporary edits still in place: `flutter test <file>` → PASS. Restore the two files from the backups (Task 2 Step 6), then `flutter test <file>` → PASS.

- [ ] **Step 4: Commit (one commit per file or per remedy)**

```bash
dart format .
git add <fixed files>
git commit -m "test: stop <file or area> reaching the network"
```

---

### Task 5: Install the network guard for every test

**Files:**
- Modify: `test/flutter_test_config.dart`
- Modify: `test/helpers/global_test_defaults.dart`, `test/helpers/global_test_defaults_test.dart`
- Modify: `test/helpers/global_state_snapshot.dart`, `test/helpers/global_state_snapshot_test.dart`
- Modify: `test/architecture/global_state_scanner.dart`, `test/architecture/global_state_scanner_test.dart`, `test/architecture/test_global_state_restored_test.dart`
- Create: `test/helpers/blocked_network_harness_test.dart`

**Interfaces:**
- Consumes: Task 1's instances and `isLoopbackHost`.
- Produces: `HttpOverrides.current` is `blockedNetworkHttpOverrides` and `IOOverrides.current` is `blockedNetworkIOOverrides` at the start of every test file; snapshot key `'IOOverrides.current'`; scanner rule `ioRule = 'IO overrides'`.

- [ ] **Step 1: Write the failing tests**

`test/helpers/blocked_network_harness_test.dart` (plain tests only, plus one widget test at the end; the plain ones must pass when this file runs alone):

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'blocked_network.dart';

void main() {
  test('the harness installs the blocking overrides', () {
    expect(HttpOverrides.current, same(blockedNetworkHttpOverrides));
    expect(IOOverrides.current, same(blockedNetworkIOOverrides));
  });

  test('a plain test cannot reach the network', () async {
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    await expectLater(
      client.getUrl(Uri.parse('https://example.com/data.json')),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          startsWith(
            'A test reached the network: https://example.com/data.json.',
          ),
        ),
      ),
    );
  });

  test('a plain test cannot open a socket to a public host', () async {
    await expectLater(
      Socket.connect('example.com', 443),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets('a network image fails with its URL, not a silent 400', (
    tester,
  ) async {
    final errors = <Object>[];
    await tester.runAsync(() async {
      final done = Completer<void>();
      const NetworkImage('https://example.com/guard-probe.png')
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (_, _) => done.complete(),
              onError: (error, _) {
                errors.add(error);
                done.complete();
              },
            ),
          );
      await done.future;
    });

    expect(errors.single.toString(), contains('example.com/guard-probe.png'));
  });
}
```

In `test/helpers/global_test_defaults_test.dart` add `import 'dart:io';` and `import 'blocked_network.dart';`, expect `HttpOverrides.current` to be `same(blockedNetworkHttpOverrides)` and `IOOverrides.current` to be `same(blockedNetworkIOOverrides)` in both tests, and in `puts every harness default back` capture and replace them first:

```dart
    final previousHttp = HttpOverrides.current;
    final previousIo = IOOverrides.current;
    addTearDown(() {
      HttpOverrides.global = previousHttp;
      IOOverrides.global = previousIo;
    });
    HttpOverrides.global = _OtherHttp();
    IOOverrides.global = _OtherIo();
```

with `class _OtherHttp extends HttpOverrides {}` and `class _OtherIo extends IOOverrides {}` at the top level.

In `test/helpers/global_state_snapshot_test.dart` add, after `HTTP overrides and foundation hooks are reported`:

```dart
  test('IO overrides are reported', () {
    final before = GlobalStateSnapshot.take();
    final previous = IOOverrides.current;
    addTearDown(() => IOOverrides.global = previous);

    IOOverrides.global = _IoOverrides();

    expect(GlobalStateSnapshot.take().changedSince(before), [
      'IOOverrides.current',
    ]);
  });

  test('restoring the harness overrides reports nothing', () {
    final before = GlobalStateSnapshot.take();
    final previousHttp = HttpOverrides.current;
    final previousIo = IOOverrides.current;
    HttpOverrides.global = _Overrides();
    IOOverrides.global = _IoOverrides();

    HttpOverrides.global = previousHttp;
    IOOverrides.global = previousIo;

    expect(GlobalStateSnapshot.take().changedSince(before), isEmpty);
  });
```

with `class _IoOverrides extends IOOverrides {}` beside `_Overrides`.

In `test/architecture/global_state_scanner_test.dart`, after the `HTTP overrides` group:

```dart
  group('IO overrides', () {
    test('an assignment with no capture is an offence', () {
      final offences = scan('IOOverrides.global = _Overrides();\n');

      expect(offences.map((o) => o.rule), [ioRule]);
    });

    test('capturing IOOverrides.current and assigning it back is accepted', () {
      final offences = scan('''
final previous = IOOverrides.current;
IOOverrides.global = _Overrides();
addTearDown(() => IOOverrides.global = previous);
''');

      expect(offences, isEmpty);
    });
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/helpers/blocked_network_harness_test.dart test/helpers/global_test_defaults_test.dart test/helpers/global_state_snapshot_test.dart test/architecture/global_state_scanner_test.dart`
Expected: FAIL: the harness does not install the overrides; the snapshot has no `IOOverrides.current`; `ioRule` is undefined.

- [ ] **Step 3: Implement**

`test/flutter_test_config.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/global_test_defaults.dart';
import 'helpers/late_bound_share_platform.dart';

/// Global test harness config, run once per entrypoint by `flutter test`.
///
/// An entrypoint is a test file, or in CI a generated bundle of test files
/// that share one isolate (issue #2500).
///
/// The binding is set up first, whether or not the entrypoint has a widget
/// test. Setting it up replaces `HttpOverrides.global`; doing that here, once,
/// means the harness defaults decide what every test sees, rather than
/// whichever widget test happens to run first.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  applyGlobalTestDefaults();
  pinLateBoundSharePlatform();
  await testMain();
}
```

`test/helpers/global_test_defaults.dart`: add imports `dart:io` and `blocked_network.dart`, append to `applyGlobalTestDefaults()`:

```dart
  HttpOverrides.global = blockedNetworkHttpOverrides;
  IOOverrides.global = blockedNetworkIOOverrides;
```

and add to its doc comment:

```dart
/// Network access is limited to this machine (test/helpers/blocked_network.dart):
/// a request or socket to any other host fails the test with the URL or host,
/// the same way in a file run alone and in a bundle.
```

`test/helpers/global_state_snapshot.dart`: add the entry `'IOOverrides.current': IOOverrides.current,` after `'HttpOverrides.current'`.

`test/architecture/global_state_scanner.dart`: add `const ioRule = 'IO overrides';` after `httpRule`, and after the `HttpOverrides` `checkReplacements(...)` call:

```dart
  checkReplacements(
    read: 'IOOverrides.current',
    target: 'IOOverrides.global',
    rule: ioRule,
  );
```

`test/architecture/test_global_state_restored_test.dart`: in the doc comment's first bullet, change `A *Platform.instance or HttpOverrides.global` to `A *Platform.instance, HttpOverrides.global or IOOverrides.global`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/helpers/ test/architecture/`
Expected: PASS. Also run `flutter test test/helpers/blocked_network_harness_test.dart` on its own: PASS (the "alone" promise).

- [ ] **Step 5: Run the whole suite bundled, as CI does**

```bash
flutter test --exclude-tags performance --concurrency=16 \
  $(python3 scripts/bundle_tests.py --total-shards 1 --max-files 40) \
  > "$S/guard_run.log" 2>&1; echo "exit $?"
rm -rf test/.bundles
grep -aE '^[0-9]+:[0-9]+ \+[0-9]+' "$S/guard_run.log" | tail -1
```

Expected: `exit 0` and `All tests passed!`. Any failure naming `A test reached the network` is a file Task 4 missed: fix it as in Task 4 and add it to that task's commits.

- [ ] **Step 6: Analyze, format, commit**

```bash
flutter analyze
dart format .
git add test/flutter_test_config.dart test/helpers/global_test_defaults.dart test/helpers/global_test_defaults_test.dart test/helpers/global_state_snapshot.dart test/helpers/global_state_snapshot_test.dart test/helpers/blocked_network_harness_test.dart test/architecture/global_state_scanner.dart test/architecture/global_state_scanner_test.dart test/architecture/test_global_state_restored_test.dart
git commit -m "test: block the network for every test, alone or bundled"
```

---

### Task 6: One time limit for every test

**Files:**
- Create: `test/helpers/test_timeouts.dart`, `test/helpers/test_timeouts_test.dart`
- Modify: `dart_test.yaml`, `test/flutter_test_config.dart`
- Modify: each test Task 2 recorded as slower than a third of the limit

**Interfaces:**
- Consumes: Task 2's limit (whole minutes, called N below; 2 unless Task 2 raised it) and its slow-test list.
- Produces: `const Duration testTimeLimit`.

- [ ] **Step 1: Write the failing test**

`test/helpers/test_timeouts_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_timeouts.dart';

void main() {
  test('dart_test.yaml gives plain tests the same limit', () {
    final config = File('dart_test.yaml').readAsStringSync();
    final match = RegExp(
      r'^timeout:\s*(\d+)m\s*$',
      multiLine: true,
    ).firstMatch(config);

    expect(match, isNotNull, reason: 'dart_test.yaml has no "timeout: <N>m"');
    expect(int.parse(match!.group(1)!), testTimeLimit.inMinutes);
  });

  test('widget tests get the same limit from the binding', () {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();

    expect(binding.defaultTestTimeout.duration, testTimeLimit);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/helpers/test_timeouts_test.dart`
Expected: FAIL to compile: `test_timeouts.dart` does not exist.

- [ ] **Step 3: Implement**

`test/helpers/test_timeouts.dart` (with N from Task 2):

```dart
/// How long one test may run before it fails.
///
/// A test that waits for work that never finishes, such as a font load
/// another file left pending (issue #2536), used to hang for the widget
/// binding's default of 10 minutes. This limit applies to plain tests through
/// dart_test.yaml and to widget tests through the binding's
/// defaultTestTimeout, set in test/flutter_test_config.dart. It was chosen from
/// the durations of a full run (issue #<issue>): every test but a few ran in
/// under a third of it, and those few declare their own `timeout:`.
const testTimeLimit = Duration(minutes: 2);
```

`dart_test.yaml`: add at the top level, above `tags:`:

```yaml
# Per-test limit for plain tests; widget tests get the same limit from the
# binding in test/flutter_test_config.dart. Keep it equal to testTimeLimit in
# test/helpers/test_timeouts.dart (test_timeouts_test.dart checks).
timeout: 2m
```

`test/flutter_test_config.dart`: add `import 'helpers/test_timeouts.dart';` and replace `TestWidgetsFlutterBinding.ensureInitialized();` with:

```dart
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // testWidgets reads this when each test is declared, so it is set before
  // testMain declares any.
  if (binding is AutomatedTestWidgetsFlutterBinding) {
    binding.defaultTestTimeout = const Timeout(testTimeLimit);
  }
```

For each slow test from Task 2, add a `timeout:` argument of at least three times its measured duration in whole minutes, with a comment:

```dart
    // Measured at <S> s in a full run (issue #<issue>); longer than a third of
    // testTimeLimit.
    timeout: const Timeout(Duration(minutes: <M>)),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/helpers/test_timeouts_test.dart`
Expected: PASS.

- [ ] **Step 5: Prove both limits bite, then delete the probe**

Create `test/zz_timeout_probe_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_timeouts.dart';

void main() {
  test('a plain test that never finishes', () async {
    await Future<void>.delayed(testTimeLimit + const Duration(seconds: 30));
  });

  testWidgets('a widget test that never finishes', (tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(testTimeLimit + const Duration(seconds: 30)),
    );
  });
}
```

Run: `flutter test test/zz_timeout_probe_test.dart`
Expected: both tests FAIL with `Test timed out after 2 minutes` (N minutes), after about N minutes, not 10. Then `rm test/zz_timeout_probe_test.dart`.

- [ ] **Step 6: Analyze, format, commit**

```bash
flutter analyze
dart format .
git add test/helpers/test_timeouts.dart test/helpers/test_timeouts_test.dart dart_test.yaml test/flutter_test_config.dart <slow test files>
git commit -m "test: fail a hung test after two minutes, not ten"
```

---

### Task 7: Docs, full verification, issue and PR

**Files:**
- Modify: `docs/developer/testing.md`

- [ ] **Step 1: Write the docs section**

In `docs/developer/testing.md`, before `## Shared Isolates in CI`, add:

```markdown
## Network, Time Limits and Fonts

Every test runs with the same three limits, whether it runs on its own, in a
CI bundle, or through `flutter test` locally.

- **No network.** A request or socket to any host but this machine fails the
  test with `A test reached the network: <URL>`. Inject a fake client
  (`MockClient` from `package:http/testing.dart`), serve the response from a
  loopback `HttpServer` (`HttpServer.bind(InternetAddress.loopbackIPv4, 0)`),
  or call `loadPdfRoboto()` for PDF fonts. The overrides live in
  `test/helpers/blocked_network.dart`; `HttpOverrides.runZoned` still wins
  inside its zone.
- **A time limit per test.** A test fails after `testTimeLimit`
  (`test/helpers/test_timeouts.dart`), set for plain tests in `dart_test.yaml`
  and for widget tests on the binding. A test that is slow on purpose declares
  its own `timeout:` with a comment saying why.
- **No font downloads.** Google Fonts runtime fetching is off for every test.
  The family name is still on each `TextStyle`; the font bytes never load.
```

- [ ] **Step 2: Verify the whole suite locally, bundled**

Run the bundled command from Task 5 Step 5 again.
Expected: `exit 0`, `All tests passed!`.

- [ ] **Step 3: Commit, open the issue, push, open the PR**

```bash
git add docs/developer/testing.md
git commit -m "docs(testing): network, time limits and fonts in tests"
```

Open an issue ("Tests can reach the network, hang for ten minutes and fetch fonts") describing the problem from the spec, set its type to Task over REST, push the branch, and open the PR with `Closes #<issue>` using `.github/PULL_REQUEST_TEMPLATE.md`, deleting the Screenshots section. The PR body lists Task 2's findings: network files and their fixes, the limit and its measured basis, and the tests with their own timeouts.

- [ ] **Step 4: Read the first CI run**

Expected: all six test shards pass; no test fails with `A test reached the network`.
