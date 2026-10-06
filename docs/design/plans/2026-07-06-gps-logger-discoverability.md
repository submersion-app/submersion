# GPS Logger Discoverability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the GPS Logger findable (top-level "GPS Log" nav section + dashboard quick action) and make an active recording visible app-wide (status strip above the bottom nav).

**Architecture:** Relocate the existing `GpsLoggerPage` from `/planning/gps-logger` to a new top-level `/gps-log` route with a redirect from the old path. Register a `gps-log` entry in the canonical `kNavDestinations` model (which feeds the mobile More sheet, the user-customizable bottom-nav slots, and pairs with three hardcoded touch points in the desktop rail). Add a display-only `GpsRecordingStrip` widget to `MainScaffold` that watches the existing `gpsRecorderStateProvider`. Add a fourth button to the dashboard Quick Actions card. Remove the Planning-hub tile, Planning sidebar item, and the dead-code ToolsPage card.

**Tech Stack:** Flutter, go_router, Riverpod 3, flutter gen-l10n (ARB with ICU plurals).

## Global Constraints

- Work happens on branch `worktree-gps-track-logging` in the worktree at `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/gps-track-logging` (these commits land on PR #497). Use worktree-absolute paths in every file operation; verify `git branch --show-current` prints `worktree-gps-track-logging` before each commit.
- Run `dart format .` (whole repo) before every commit; commits must produce zero formatting diffs.
- `flutter analyze` (whole project, never piped through head/tail for gating) must be clean before each commit.
- New localized strings go into ALL 11 locales (`en, ar, de, es, fr, he, hu, it, nl, pt, zh`) followed by `flutter gen-l10n`; commit the regenerated `lib/l10n/arb/app_localizations*.dart` files.
- Lint `always_use_package_imports` is on: all lib/test imports use `package:submersion/...` (relative imports only for test helpers already using them).
- No Co-Authored-By lines in commit messages. No emojis in code or docs.
- Run tests per file (`flutter test <file>`), never broad directories, to avoid Bash timeouts.
- Widget tests: any post-`pumpWidget` call into drift-backed repositories/services must be wrapped in `tester.runAsync(...)` (see `test/features/gps_log/gps_logger_page_test.dart` for the deadlock this prevents). The tasks below avoid the issue entirely by overriding `gpsRecorderStateProvider` with a value stream — no database needed.
- If pushing: `env -u GITHUB_TOKEN git push --no-verify` (worktree pre-push hook runs against the main tree; stale GITHUB_TOKEN shadows the keyring).

---

### Task 1: Localization keys (`nav_gpsLog`, `gpsLogger_stripStatus`)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Generated: `lib/l10n/arb/app_localizations*.dart` (via `flutter gen-l10n`)

**Interfaces:**
- Consumes: existing keys `tools_gpsLogger_title` / `tools_gpsLogger_subtitle` (already in all locales; do not touch).
- Produces: `String get nav_gpsLog` and `String gpsLogger_stripStatus(num count)` on `AppLocalizations` — used by Tasks 3, 4, 5.

- [ ] **Step 1: Insert the keys into all 11 ARB files with a script**

Write this to `/Users/ericgriffin/.claude/jobs/f43c136b/tmp/add_discoverability_l10n.py` and run `python3` on it from the worktree root. Anchors: `nav_gpsLog` inserts immediately before the `"nav_home"` line (alphabetical: equipment < gpsLog < home); `gpsLogger_stripStatus` inserts immediately before the `"gpsLogger_trackSubtitle"` line (alphabetical: stopButton < stripStatus < trackSubtitle). The en file also gets `@gpsLogger_stripStatus` metadata (plural placeholder type `num`).

```python
import io

nav = {
    "en": "GPS Log",
    "ar": "سجل GPS",
    "de": "GPS-Log",
    "es": "Registro GPS",
    "fr": "Journal GPS",
    "he": "יומן GPS",
    "hu": "GPS-napló",
    "it": "Registro GPS",
    "nl": "GPS-log",
    "pt": "Registro GPS",
    "zh": "GPS 记录",
}

strip = {
    "en": "Recording GPS track · {count, plural, one{{count} point} other{{count} points}}",
    "ar": "جارٍ تسجيل مسار GPS · {count, plural, one{نقطة واحدة} two{نقطتان} few{{count} نقاط} other{{count} نقطة}}",
    "de": "GPS-Track wird aufgezeichnet · {count, plural, one{{count} Punkt} other{{count} Punkte}}",
    "es": "Grabando track GPS · {count, plural, one{{count} punto} other{{count} puntos}}",
    "fr": "Enregistrement du tracé GPS · {count, plural, one{{count} point} other{{count} points}}",
    "he": "מקליט מסלול GPS · {count, plural, one{נקודה אחת} two{שתי נקודות} other{{count} נקודות}}",
    "hu": "GPS-útvonal rögzítése · {count, plural, one{{count} pont} other{{count} pont}}",
    "it": "Registrazione traccia GPS · {count, plural, one{{count} punto} other{{count} punti}}",
    "nl": "GPS-track wordt opgenomen · {count, plural, one{{count} punt} other{{count} punten}}",
    "pt": "Gravando trilha GPS · {count, plural, one{{count} ponto} other{{count} pontos}}",
    "zh": "正在记录 GPS 轨迹 · {count, plural, other{{count} 个点}}",
}

en_meta = '''  "@gpsLogger_stripStatus": {
    "placeholders": {
      "count": {
        "type": "num"
      }
    }
  },
'''

for locale in nav:
    path = f"lib/l10n/arb/app_{locale}.arb"
    with io.open(path, encoding="utf-8") as f:
        lines = f.readlines()

    out = []
    nav_done = strip_done = False
    for line in lines:
        if not nav_done and '"nav_home":' in line:
            out.append(f'  "nav_gpsLog": "{nav[locale]}",\n')
            nav_done = True
        if not strip_done and '"gpsLogger_trackSubtitle":' in line:
            out.append(f'  "gpsLogger_stripStatus": "{strip[locale]}",\n')
            if locale == "en":
                out.append(en_meta)
            strip_done = True
        out.append(line)

    assert nav_done and strip_done, f"{path}: anchors not found"
    with io.open(path, "w", encoding="utf-8") as f:
        f.writelines(out)
    print(f"{locale}: ok")
```

Expected output: `<locale>: ok` for all 11 locales.

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exits without error (the "delete l10n.yaml" note is normal noise).

- [ ] **Step 3: Verify the generated getters exist**

Run: `grep -n "String get nav_gpsLog" lib/l10n/arb/app_localizations.dart && grep -n "gpsLogger_stripStatus(num count)" lib/l10n/arb/app_localizations.dart`
Expected: one match each.

- [ ] **Step 4: Analyze and format**

Run: `dart format . && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "Add nav and recording-strip localization keys for GPS Log"
```

---

### Task 2: Route relocation — top-level `/gps-log` with redirect

**Files:**
- Modify: `lib/core/router/app_router.dart` (nested route at ~lines 253-257; new top-level route next to `/transfer` at ~line 735)
- Test: `test/core/router/app_router_test.dart`

**Interfaces:**
- Consumes: `GpsLoggerPage` from `package:submersion/features/gps_log/presentation/pages/gps_logger_page.dart` (import already present in app_router.dart).
- Produces: route name `gpsLog` at path `/gps-log`; redirect from `/planning/gps-logger`. Tasks 3-5 navigate with `context.go('/gps-log')`.

- [ ] **Step 1: Write the failing router tests**

Append inside the existing top-level `group` in `test/core/router/app_router_test.dart` (it already builds `router = container.read(appRouterProvider);` in `setUp` and defines `_findRouteByName`):

```dart
group('gps-log relocation', () {
  test('gpsLog route is registered at top level', () {
    final route = _findRouteByName(router.configuration.routes, 'gpsLog');
    expect(route, isNotNull);
    expect(route!.path, '/gps-log');
  });

  test('old planning gps-logger path is a redirect', () {
    GoRoute? findByPath(List<RouteBase> routes) {
      for (final route in routes) {
        if (route is GoRoute) {
          if (route.path == 'gps-logger') return route;
          final found = findByPath(route.routes);
          if (found != null) return found;
        }
        if (route is ShellRoute) {
          final found = findByPath(route.routes);
          if (found != null) return found;
        }
      }
      return null;
    }

    final route = findByPath(router.configuration.routes);
    expect(route, isNotNull);
    expect(route!.redirect, isNotNull);
    expect(route.builder, isNull);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: FAIL — `gpsLog` route found at path `gps-logger` (not `/gps-log`), and the old route has a builder, not a redirect.

- [ ] **Step 3: Replace the nested route with a redirect and add the top-level route**

In `lib/core/router/app_router.dart`, replace:

```dart
                  GoRoute(
                    path: 'gps-logger',
                    name: 'gpsLogger',
                    builder: (context, state) => const GpsLoggerPage(),
                  ),
```

with:

```dart
                  // GPS Logger moved to top-level /gps-log; keep old deep
                  // links working.
                  GoRoute(
                    path: 'gps-logger',
                    redirect: (context, state) => '/gps-log',
                  ),
```

Then add the new top-level route as a sibling of `/transfer` (immediately after the `/transfer` GoRoute's closing `),` and before the `// Settings` comment), matching the NoTransitionPage pattern of its siblings:

```dart
          // GPS surface track logger
          GoRoute(
            path: '/gps-log',
            name: 'gpsLog',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const GpsLoggerPage(),
            ),
          ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: PASS (all tests in the file, including pre-existing ones).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/core/router/app_router.dart test/core/router/app_router_test.dart
git commit -m "Relocate GPS Logger route to top-level /gps-log with redirect"
```

---

### Task 3: "GPS Log" navigation destination

**Files:**
- Modify: `lib/shared/widgets/nav/nav_destinations.dart` (add entry between `transfer` and `settings`; update count doc comments)
- Modify: `lib/shared/widgets/nav/nav_primary_provider.dart` (count doc comments only)
- Modify: `lib/shared/widgets/main_scaffold.dart` (three touch points: `_calculateSelectedIndex` wide-screen map, `_onDestinationSelected` wide-screen switch, rail `destinations` list)
- Test: `test/shared/widgets/nav/nav_destinations_test.dart`, `test/shared/widgets/main_scaffold_test.dart`

**Interfaces:**
- Consumes: `l10n.nav_gpsLog` (Task 1), `l10n.tools_gpsLogger_subtitle` (existing), route `/gps-log` (Task 2).
- Produces: `NavDestination(id: 'gps-log', ...)` in `kNavDestinations` — automatically appears in the mobile More sheet and becomes user-promotable to the bottom bar via the existing customization system; rail index 12 (settings shifts to 13).

- [ ] **Step 1: Update the failing nav model tests first**

In `test/shared/widgets/nav/nav_destinations_test.dart`:
- Change `expect(kNavDestinations.length, 14);` to `15` and update that test's name/comment from "13 routable + more sentinel" to "14 routable + more sentinel".
- In the expected-ids test ("contains the expected 13 routable ids plus more sentinel"), insert `'gps-log',` between `'transfer',` and `'settings',` in the expected list and update the name to "expected 14 routable ids".
- In the `movableNavIds` group: insert `'gps-log',` between `'transfer',` and `'settings',` in the expected list, and change `expect(movableNavIds.length, 12);` to `13`.

In `test/shared/widgets/main_scaffold_test.dart`, in the test named `'wide-screen rail still shows all 13 default destinations'`: rename to `'wide-screen rail still shows all 14 default destinations'` and update its count expectation from 13 to 14 (if it asserts label texts, add `'GPS Log'` after `'Transfer'`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/shared/widgets/nav/nav_destinations_test.dart` then `flutter test test/shared/widgets/main_scaffold_test.dart`
Expected: FAIL on the updated count/id expectations.

- [ ] **Step 3: Add the destination to `kNavDestinations`**

In `lib/shared/widgets/nav/nav_destinations.dart`, insert between the `transfer` and `settings` entries:

```dart
  NavDestination(
    id: 'gps-log',
    route: '/gps-log',
    icon: Icons.gps_fixed,
    selectedIcon: Icons.gps_fixed,
    label: (l10n) => l10n.nav_gpsLog,
    subtitle: (l10n) => l10n.tools_gpsLogger_subtitle,
  ),
```

Update the doc comments in the same file: list header "Length is **14** — 13 routable destinations plus the `more` sentinel" becomes "Length is **15** — 14 routable destinations plus the `more` sentinel"; the `movableNavIds` comment "(12 entries)" reference in `nav_primary_provider.dart` line 11 becomes "(13 entries)"; the `navDestinationsProvider` comment "(14 entries including `more`)" in `nav_primary_provider.dart` line 6 becomes "(15 entries including `more`)"; the `NavDestination.subtitle` doc "used for Courses and Planning" becomes "used for Courses, Planning, and GPS Log".

- [ ] **Step 4: Wire the desktop rail (three touch points in `main_scaffold.dart`)**

In `_calculateSelectedIndex`, after `if (location.startsWith('/transfer')) return 11;` insert:

```dart
      if (location.startsWith('/gps-log')) return 12;
```

and change `if (location.startsWith('/settings')) return 12;` to `return 13;`.

In `_onDestinationSelected`'s wide-screen switch, after `case 11:` (`/transfer`) insert:

```dart
        case 12:
          context.go('/gps-log');
          break;
```

and change the settings case from `case 12:` to `case 13:`.

In the rail `destinations:` list, after the `nav_transfer` NavigationRailDestination insert:

```dart
                              NavigationRailDestination(
                                icon: const Icon(Icons.gps_fixed),
                                selectedIcon: const Icon(Icons.gps_fixed),
                                label: Text(context.l10n.nav_gpsLog),
                              ),
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/shared/widgets/nav/nav_destinations_test.dart` then `flutter test test/shared/widgets/main_scaffold_test.dart` then `flutter test test/shared/widgets/nav/nav_primary_provider_test.dart`
Expected: PASS (all three files; the primary-provider tests exercise normalization and must not regress).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/shared/widgets/ test/shared/widgets/
git commit -m "Add GPS Log destination to navigation model and desktop rail"
```

---

### Task 4: Recording status strip

**Files:**
- Create: `lib/features/gps_log/presentation/widgets/gps_recording_strip.dart`
- Modify: `lib/shared/widgets/main_scaffold.dart` (both layouts)
- Test: `test/features/gps_log/gps_recording_strip_test.dart` (create), `test/shared/widgets/main_scaffold_test.dart` (extend)

**Interfaces:**
- Consumes: `gpsRecorderStateProvider` (StreamProvider) and `gpsTrackRecorderProvider` from `package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart`; `GpsRecorderState` / `GpsRecorderStatus` from `package:submersion/features/gps_log/data/services/gps_track_recorder.dart`; `l10n.gpsLogger_stripStatus(num)` (Task 1); route `/gps-log` (Task 2).
- Produces: `class GpsRecordingStrip extends ConsumerWidget` — renders `SizedBox.shrink()` unless recording.

- [ ] **Step 1: Write the failing strip widget tests**

Create `test/features/gps_log/gps_recording_strip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_recording_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _recordingState = GpsRecorderState(
  status: GpsRecorderStatus.recording,
  trackId: 't1',
  pointCount: 2,
);

Widget app({List<Override> overrides = const []}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: GpsRecordingStrip()),
      ),
      GoRoute(
        path: '/gps-log',
        builder: (context, state) => const Scaffold(body: Text('GPS-LOG-PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('renders nothing while idle', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('shows pluralized status while recording', (tester) async {
    await tester.pumpWidget(
      app(
        overrides: [
          gpsRecorderStateProvider.overrideWith(
            (ref) => Stream.value(_recordingState),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recording GPS track · 2 points'), findsOneWidget);
  });

  testWidgets('tap navigates to the GPS Log page', (tester) async {
    await tester.pumpWidget(
      app(
        overrides: [
          gpsRecorderStateProvider.overrideWith(
            (ref) => Stream.value(_recordingState),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.text('GPS-LOG-PAGE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/gps_log/gps_recording_strip_test.dart`
Expected: FAIL — `gps_recording_strip.dart` does not exist (compile error).

- [ ] **Step 3: Implement the strip**

Create `lib/features/gps_log/presentation/widgets/gps_recording_strip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App-wide slim banner shown while a GPS track recording is active.
///
/// MainScaffold renders it above the bottom nav (phones) or at the bottom of
/// the content area (rail layouts). It renders nothing while idle, so it is
/// naturally absent on platforms that cannot record.
class GpsRecordingStrip extends ConsumerWidget {
  const GpsRecordingStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorder = ref.watch(gpsTrackRecorderProvider);
    final state = ref.watch(gpsRecorderStateProvider).value ?? recorder.state;
    if (state.status != GpsRecorderStatus.recording) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      child: InkWell(
        onTap: () => context.go('/gps-log'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.fiber_manual_record,
                size: 12,
                color: colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.gpsLogger_stripStatus(state.pointCount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run strip tests to verify they pass**

Run: `flutter test test/features/gps_log/gps_recording_strip_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Place the strip in both MainScaffold layouts**

In `lib/shared/widgets/main_scaffold.dart` add the import:

```dart
import 'package:submersion/features/gps_log/presentation/widgets/gps_recording_strip.dart';
```

Wide layout — the content column becomes:

```dart
                Expanded(
                  child: Column(
                    children: [
                      const UpdateBanner(),
                      Expanded(child: widget.child),
                      const GpsRecordingStrip(),
                    ],
                  ),
                ),
```

Mobile layout — the body column becomes:

```dart
      body: GlobalDropTarget(
        child: Column(
          children: [
            const UpdateBanner(),
            Expanded(child: widget.child),
            const GpsRecordingStrip(),
          ],
        ),
      ),
```

- [ ] **Step 6: Extend the MainScaffold test harness and add strip tests**

In `test/shared/widgets/main_scaffold_test.dart`, add imports:

```dart
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
```

Change the harness signature to accept extra overrides:

```dart
Future<Widget> _buildTestApp({
  String initialLocation = '/dashboard',
  List<Override> extraOverrides = const [],
}) async {
```

and spread them into the ProviderScope: `overrides: [ ...existing four overrides..., ...extraOverrides ],`.

Add to the `MainScaffold` group:

```dart
    testWidgets('recording strip appears while a GPS session is active', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        await _buildTestApp(
          extraOverrides: [
            gpsRecorderStateProvider.overrideWith(
              (ref) => Stream.value(
                const GpsRecorderState(
                  status: GpsRecorderStatus.recording,
                  trackId: 't1',
                  pointCount: 3,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recording GPS track · 3 points'), findsOneWidget);
    });

    testWidgets('recording strip is absent while idle', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await _buildTestApp());
      await tester.pumpAndSettle();
      expect(find.textContaining('Recording GPS track'), findsNothing);
    });
```

- [ ] **Step 7: Run scaffold tests to verify they pass**

Run: `flutter test test/shared/widgets/main_scaffold_test.dart`
Expected: PASS (all tests, old and new).

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/gps_log/presentation/widgets/ lib/shared/widgets/main_scaffold.dart test/features/gps_log/gps_recording_strip_test.dart test/shared/widgets/main_scaffold_test.dart
git commit -m "Show app-wide recording strip while a GPS session is active"
```

---

### Task 5: Dashboard Quick Action

**Files:**
- Modify: `lib/features/dashboard/presentation/widgets/quick_actions_card.dart`
- Test: `test/features/dashboard/presentation/quick_actions_card_test.dart` (create)

**Interfaces:**
- Consumes: `l10n.tools_gpsLogger_title` ("GPS Logger", existing), route `/gps-log` (Task 2).
- Produces: fourth button in the Quick Actions card. The card remains a plain `StatelessWidget` with no providers.

- [ ] **Step 1: Write the failing test**

Create `test/features/dashboard/presentation/quick_actions_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget app() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: SizedBox(height: 400, child: QuickActionsCard()),
        ),
      ),
      GoRoute(
        path: '/gps-log',
        builder: (context, state) => const Scaffold(body: Text('GPS-LOG-PAGE')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  testWidgets('GPS Logger quick action navigates to /gps-log', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('GPS Logger'));
    await tester.pumpAndSettle();
    expect(find.text('GPS-LOG-PAGE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dashboard/presentation/quick_actions_card_test.dart`
Expected: FAIL — "GPS Logger" text not found.

- [ ] **Step 3: Add the button**

In `lib/features/dashboard/presentation/widgets/quick_actions_card.dart`, inside the inner `Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, ...)`, after the statistics `SizedBox` add:

```dart
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/gps-log'),
                      icon: const Icon(Icons.gps_fixed),
                      label: Text(context.l10n.tools_gpsLogger_title),
                    ),
                  ),
```

Note: the card sits inside an `IntrinsicHeight` row on the dashboard next to `PersonalRecordsCard`; the row stretches to the tallest child, so a fourth button grows the row rather than overflowing. If the test in Step 4 reports a RenderFlex overflow anyway, that is a real regression to fix, not to suppress.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dashboard/presentation/quick_actions_card_test.dart`
Expected: PASS with no overflow errors.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/dashboard/presentation/widgets/quick_actions_card.dart test/features/dashboard/presentation/quick_actions_card_test.dart
git commit -m "Add GPS Logger quick action to dashboard"
```

---

### Task 6: Remove the Planning and ToolsPage entry points

**Files:**
- Modify: `lib/features/planning/presentation/pages/planning_page.dart` (remove the GPS `_PlanningTool` entry)
- Modify: `lib/features/planning/presentation/widgets/planning_shell.dart` (remove the GPS `_SidebarItem` entry)
- Revert: `lib/features/tools/presentation/pages/tools_page.dart` to its state on `main` (drops the dead-code GPS card)
- Test: `test/features/planning/planning_page_test.dart` (drop the GPS Logger assertion)

**Interfaces:**
- Consumes: nothing new.
- Produces: `/gps-log` (Task 2) plus the More sheet (Task 3) and quick action (Task 5) become the only entry points. The l10n keys `tools_gpsLogger_title` / `tools_gpsLogger_subtitle` remain in use (nav subtitle + quick action); `tools_gpsLogger_description` becomes unused, which is harmless.

- [ ] **Step 1: Update the planning test first**

In `test/features/planning/planning_page_test.dart`, delete these two lines from the hub test:

```dart
    // GPS Logger is reachable from the hub, not only by deep link.
    await tester.scrollUntilVisible(find.text('GPS Logger'), 200);
    expect(find.text('GPS Logger'), findsOneWidget);
```

- [ ] **Step 2: Remove the Planning hub tile**

In `lib/features/planning/presentation/pages/planning_page.dart`, delete this entry from `_planningToolsOf`:

```dart
    _PlanningTool(
      icon: Icons.gps_fixed,
      color: Colors.indigo,
      title: context.l10n.tools_gpsLogger_title,
      subtitle: context.l10n.tools_gpsLogger_subtitle,
      route: '/planning/gps-logger',
    ),
```

- [ ] **Step 3: Remove the Planning sidebar item**

In `lib/features/planning/presentation/widgets/planning_shell.dart`, delete this entry from the sidebar `tools` list:

```dart
      _SidebarItem(
        icon: Icons.gps_fixed,
        iconColor: Colors.indigo,
        title: context.l10n.tools_gpsLogger_title,
        subtitle: context.l10n.tools_gpsLogger_subtitle,
        isSelected: location.contains('/gps-log'),
        route: '/planning/gps-logger',
      ),
```

(The `isSelected`/`route` values may read `/gps-logger` or `/gps-log` depending on the tree state — delete whichever GPS `_SidebarItem` entry is present.)

- [ ] **Step 4: Revert the dead ToolsPage card**

Run: `git checkout main -- lib/features/tools/presentation/pages/tools_page.dart`
Expected: `git diff main -- lib/features/tools/presentation/pages/tools_page.dart` prints nothing.

- [ ] **Step 5: Verify no stale references remain**

Run: `grep -rn "planning/gps-logger\|tools/gps-logger" lib test`
Expected: no matches (the redirect route uses the relative path `gps-logger`, which this grep does not match). Any match is a leftover to fix.

- [ ] **Step 6: Run the affected tests**

Run: `flutter test test/features/planning/planning_page_test.dart` then `flutter test test/features/gps_log/gps_logger_page_test.dart`
Expected: PASS (both files).

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/planning/ lib/features/tools/ test/features/planning/
git commit -m "Remove Planning and ToolsPage GPS Logger entry points"
```

---

### Task 7: Full verification pass

**Files:** none created or modified (fixes only if a step fails).

**Interfaces:** none — this task gates the branch.

- [ ] **Step 1: Formatting is a no-op**

Run: `dart format --set-exit-if-changed . > /dev/null; echo "exit=$?"`
Expected: `exit=0`

- [ ] **Step 2: Whole-project analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Run every affected test file individually**

```bash
flutter test test/core/router/app_router_test.dart
flutter test test/shared/widgets/nav/nav_destinations_test.dart
flutter test test/shared/widgets/nav/nav_primary_provider_test.dart
flutter test test/shared/widgets/main_scaffold_test.dart
flutter test test/features/gps_log/gps_recording_strip_test.dart
flutter test test/features/gps_log/gps_logger_page_test.dart
flutter test test/features/dashboard/presentation/quick_actions_card_test.dart
flutter test test/features/planning/planning_page_test.dart
```

Expected: `All tests passed!` for each.

- [ ] **Step 4: Build**

Run: `flutter build macos --debug`
Expected: `✓ Built build/macos/Build/Products/Debug/Submersion.app`

- [ ] **Step 5: Push to PR #497**

```bash
git branch --show-current   # must print worktree-gps-track-logging
env -u GITHUB_TOKEN git push --no-verify
```

Expected: push succeeds; PR #497 picks up the new commits.
