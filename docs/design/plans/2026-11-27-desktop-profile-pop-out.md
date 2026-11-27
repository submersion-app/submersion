# Desktop Profile Pop-out Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On macOS, Windows and Linux, open a dive's fullscreen profile view in its own OS window that follows the main window's dive (or is pinned), shares the profile cursor live, and never writes anything.

**Architecture:** A vendored `desktop_multi_window` opens the pop-out with its own Flutter engine. The pop-out connects to the main window's Drift worker isolates through `IsolateNameServer` (read-only, serialized), runs a slim `ProviderScope` with in-memory SharedPreferences, and talks to the main window over one `WindowMethodChannel` carrying typed messages. Window, channel and content are separate layers so a later move to Flutter's own windowing replaces only the window layer.

**Tech Stack:** Flutter 3.47.0, Riverpod 3, drift 2.35.3 (`drift/isolate.dart`), `desktop_multi_window` 0.3.1 (vendored), `window_manager` 0.5.2, `screen_retriever` (already transitive through `window_manager`).

**Spec:** `docs/design/specs/2026-11-27-desktop-profile-pop-out-design.md` (issue #5078). Read it with this plan; its "Spike findings" section records what was proved.

## Global Constraints

- Desktop only: every entry point checks `!HostPlatform.isWeb && HostPlatform.isDesktop` (through `popOutAvailableProvider` in UI). Never read `dart:io` `Platform` directly (`host_platform_single_source_test`).
- `package:drift/isolate.dart` and `desktop_multi_window` are imported only from `*_io.dart` files behind a facade with a web stub (`web_compile_seams_test`).
- The pop-out writes nothing: no database statement other than reads, no SharedPreferences write that reaches disk, no notification scheduling.
- Only the main window writes SharedPreferences.
- Flutter stays at 3.47.0. No em dashes, no emojis. Every new string goes in all 12 ARB files, then `flutter gen-l10n`.
- Units follow the active diver's settings (the pop-out reads the same settings).
- Tests that register `IsolateNameServer` ports, set `SharedPreferencesStorePlatform.instance`, or mock channels restore them in `addTearDown` (`test_global_state_restored_test`).
- New code goes in new files of at most 800 lines; `fullscreen_profile_page.dart`, `settings_providers.dart` and `dive_detail_page.dart` get only the small edits named below.
- Local test runs: only the test files a task writes or changes, by path.
- Commits: `feat(pop-out): ...` / `fix(pop-out): ...`; no attribution trailers.

## Review Focus

1. **The main window swaps or closes its database while the pop-out is open** (restore, storage move, demo switch, quit): the pop-out closes first and never shows broken data. Test in Task 3 (`close runs before-close hooks first`) and Task 8 (`database close closes the pop-out`).
2. **A write sneaks in from a provider nobody listed:** it is refused, logged, and the view keeps working. Test in Task 3 (`refuses writes and lets reads through`) and Task 9 (`pop-out overrides show the stored safety review without saving`).
3. **The saved frame is on a monitor that is gone:** opens centred on the main window's screen. Test in Task 5 (`frame off every display falls back to main window's display`).
4. **The pinned dive is deleted, or the followed dive belongs to a diver the main window switched away from:** pinned deleted unpins and shows the placeholder; a diver switch reloads settings and follows the new dive. Tests in Task 5 (`diveMissing on the pinned dive unpins`) and Task 9 (`prefs message reloads diver and settings`).
5. **Focus moving between the two windows on Windows and Linux** (each engine sees its window lose focus): no App Lock, no resume sync. Test in Task 5 (`focus hand-off to the pop-out within the grace is not leaving`) and Task 8 (`lifecycle goes through the arbiter while a pop-out is open`).

---

### Task 1: Vendor the window plugin and wire the runners

**Files:**
- Create: `packages/desktop_multi_window/` (copy of 0.3.1, MIT licence kept, plus `PATCHES.md` describing the change)
- Modify: `packages/desktop_multi_window/macos/desktop_multi_window/Sources/desktop_multi_window/FlutterMultiWindowPlugin.swift`
- Modify: `pubspec.yaml` (`desktop_multi_window: path: packages/desktop_multi_window`, `screen_retriever` direct dependency at the version `pubspec.lock` already resolves)
- Modify: `macos/Runner/MainFlutterWindow.swift`, `windows/runner/flutter_window.cpp`, `linux/runner/my_application.cc`
- Test: `macos/RunnerTests/` (existing target; add `PopOutWindowTests.swift`)

**Interfaces:**
- Produces (Swift): `FlutterMultiWindowPlugin.setProjectFactory(_ factory: @escaping () -> FlutterDartProject)`; `CreateWindow` uses it instead of `FlutterDartProject()` when set.
- Produces (runners): new windows register only `window_manager`, `screen_retriever` and the multi-window plugin itself (allowlist), never `RegisterGeneratedPlugins`.
- Produces (macOS): when the main window closes, every other app window closes first.

- [ ] **Step 1:** Copy the package from the pub cache into `packages/desktop_multi_window`, add the `setProjectFactory` hook, record it in `PATCHES.md`.
- [ ] **Step 2: Write the failing Swift test** `testPopOutWindowsUseTheRendererProject`: after `MainFlutterWindow.configureMultiWindow()` (new static func the runner calls from `awakeFromNib`), `FlutterMultiWindowPlugin.projectFactory?()` returns a `RendererDartProject`.
- [ ] **Step 3:** Implement `configureMultiWindow()` in `MainFlutterWindow.swift`: set the project factory to `RendererDartProject()`, set the window-created callback to register `WindowManagerPlugin` and `ScreenRetrieverPlugin` with `controller.registrar(forPlugin:)`, and observe `NSWindow.willCloseNotification` for the main window to `close()` every other `NSApp.windows` entry.
- [ ] **Step 4:** Windows: `DesktopMultiWindowSetWindowCreatedCallback` registering `WindowManagerPluginRegisterWithRegistrar` and `ScreenRetrieverPluginRegisterWithRegistrar` only. Linux: `desktop_multi_window_plugin_set_window_created_callback` registering the same two.
- [ ] **Step 5: Verify:** `flutter pub get`; `flutter build macos --debug` succeeds; run RunnerTests (`xcodebuild test -workspace macos/Runner.xcworkspace -scheme Runner -only-testing:RunnerTests/PopOutWindowTests`) and it passes. Windows and Linux compile in CI (`build-windows`, `build-linux`).
- [ ] **Step 6: Commit** `feat(pop-out): vendor desktop_multi_window and register pop-out windows`

### Task 2: Share the Drift workers

**Files:**
- Modify: `lib/core/database/background_database_connection_io.dart`, `lib/core/database/background_database_connection_web.dart`
- Create: `lib/core/database/shared_database_ports.dart` (facade), `shared_database_ports_io.dart`, `shared_database_ports_web.dart`
- Test: `test/core/database/background_database_connection_test.dart`, `test/core/database/shared_database_ports_test.dart`

**Interfaces:**
- Produces: `BackgroundDatabaseConnection` connects with `singleClientMode: false`, keeps its `DriftIsolate`, and `awaitWorkerShutdown` first calls `shutdownAll()` (bounded by the same timeout, errors ignored) so the worker still exits with other clients connected.
- Produces: `const kMainDatabasePortName = 'submersion.database.main'`, `const kLocalCacheDatabasePortName = 'submersion.database.local_cache'`; `void publishDatabase(String name, BackgroundDatabaseConnection background)`; `void unpublishDatabase(String name)`; `Future<DatabaseConnection?> connectToPublishedDatabase(String name, {QueryInterceptor? interceptor})` (null when nothing is published; `serialize: true`, `singleClientMode: false`). Web: publish/unpublish no-ops, connect returns null.

- [ ] **Step 1: Write failing tests** in `shared_database_ports_test.dart`: `a second client sees the first client's table updates` (open a temp-file background connection, publish it, connect a second `AppDatabase`-free `GeneratedDatabase` through `connectToPublishedDatabase`, insert through the first, expect the second's `tableUpdates(TableUpdateQuery.onTableName('t'))` to emit and a count of 1); `connect returns null when nothing is published`. Both unpublish in `addTearDown`.
- [ ] **Step 2: Add to the existing test file** `awaitWorkerShutdown exits the worker while another client is connected`: connect a second client via the published port, close the first database, `awaitWorkerShutdown(timeout: 5s, killIfStuck: false)` returns true.
- [ ] **Step 3: Run** both files; expect the new tests to FAIL.
- [ ] **Step 4: Implement** the connection change and the ports module.
- [ ] **Step 5: Run** both files, including the existing shutdown tests; all PASS.
- [ ] **Step 6: Commit** `feat(pop-out): let a second engine share the database workers`

### Task 3: Read-only shared databases in the service layer

**Files:**
- Create: `lib/core/database/read_only_query_interceptor.dart`
- Modify: `lib/core/services/database_service.dart`, `lib/core/services/local_cache_database_service.dart`
- Test: `test/core/database/read_only_query_interceptor_test.dart`, `test/core/services/database_service_before_close_test.dart`

**Interfaces:**
- Consumes: Task 2's ports API.
- Produces: `class ReadOnlyViolation extends StateError`; `class ReadOnlyQueryInterceptor extends QueryInterceptor` refusing `runInsert`, `runUpdate`, `runDelete`, `runBatched`, `beginTransaction`, and `runCustom` unless the statement starts (trimmed, case-insensitive) with `SELECT`, `WITH`, or a `PRAGMA` without `=`; each refusal logs through `LoggerService` (`'pop-out refused a write: <first 80 chars>'`) then throws.
- Produces: `DatabaseService.attachSharedDatabase(AppDatabase db)` and `LocalCacheDatabaseService.attachSharedDatabase(LocalCacheDatabase db)` (install without a background owner, bump generation); `VoidCallback DatabaseService.addBeforeCloseHook(Future<void> Function() hook)`; `close()` awaits every hook (errors logged, not rethrown) before closing. Both services `publishDatabase` after a successful open and `unpublishDatabase` at the start of close.

- [ ] **Step 1: Write failing tests:** `refuses writes and lets reads through` (in-memory db with the interceptor: `customSelect` works, `customStatement('INSERT ...')`, `into(...).insert`, `transaction` throw `ReadOnlyViolation`; `PRAGMA user_version` read works, `PRAGMA user_version = 3` throws); `close runs before-close hooks first` (hook records order against the database still open; a throwing hook does not stop the close; removed hooks do not run).
- [ ] **Step 2: Run** both; FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both; PASS.
- [ ] **Step 5: Commit** `feat(pop-out): read-only shared database connections`

### Task 4: Read-only settings and diver id

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (constructor, `_loadSettings`, `_saveSettings`, `_saveListArrangement` only)
- Modify: `lib/features/divers/presentation/providers/diver_providers.dart` (`CurrentDiverIdNotifier` only)
- Test: `test/features/settings/presentation/providers/settings_notifier_read_only_test.dart`, `test/features/divers/presentation/providers/current_diver_id_read_only_test.dart`

**Interfaces:**
- Produces: `SettingsNotifier.readOnly(DiverSettingsRepository repository, Ref ref)`: same listeners as today; its load reads `getSettingsForDiver(diverId) ?? const AppSettings()` and overlays the device prefs exactly as today, but never calls `getOrCreateSettingsForDiver`, `adoptDeviceLocalValues`, `hasSeascapeAppearance`, `_writeCachedTheme`, `prefs.remove` or `_scheduleNotificationsIfNeeded`; both save paths return at once. Setters still update `state` (local to the pop-out).
- Produces: `CurrentDiverIdNotifier.readOnly(SharedPreferences prefs, DiverRepository repository)`: state from `prefs.getString(currentDiverIdKey)`, no validation, no sync, no writes.

- [ ] **Step 1: Write failing tests** with a counting fake repository (reuse `test/helpers/deferred_settings_notifier.dart` patterns): `read-only load writes nothing` (after `initialLoad`, zero create/adopt/update calls, zero pref writes); `read-only load reflects the stored row` (row with metric depth gives `depthUnit == DepthUnit.meters`); `read-only setters change state but never save`; `storage change reloads` (emit on `watchSettingsChanges`, new row value lands). Diver id: `read-only notifier serves the stored id and writes nothing`.
- [ ] **Step 2: Run**; FAIL.
- [ ] **Step 3: Implement** with one `final bool _readOnly` per notifier; guards at the named call sites only.
- [ ] **Step 4: Run** the new files plus `test/architecture/settings_setters_wait_for_load_test.dart`; PASS.
- [ ] **Step 5: Commit** `feat(pop-out): read-only settings and active diver for the pop-out`

### Task 5: Pop-out domain logic

**Files:**
- Create in `lib/features/pop_out/domain/`: `pop_out_messages.dart`, `pop_out_frame.dart`, `dive_follow_state.dart`, `cursor_sync.dart`, `window_focus_arbiter.dart`
- Test: one file per source under `test/features/pop_out/domain/`

**Interfaces:**
- `sealed class PopOutMessage { MethodCall toCall(); static PopOutMessage? fromCall(MethodCall call); }` with `ShowDiveMessage(String? diveId)` `showDive`, `CursorMessage(String diveId, int? seconds)` `cursor`, `PrefsMessage(Map<String, Object> values)` `prefs`, `LockMessage(bool locked)` `lock`, `FocusRequestMessage()` `focusWindow`, `CloseMessage()` `close`, `FocusReportMessage(bool focused)` `focusChanged`, `FrameMessage(PopOutFrame frame)` `frame`, `ClosedMessage()` `closed`. Unknown method or malformed args gives null.
- `class PopOutLaunch { String? diveId; Map<String, Object> prefs; bool locked; PopOutFrame? savedFrame; PopOutFrame mainFrame; String encode(); static PopOutLaunch? decode(String arguments); }` (JSON; `kind: 'profile'` so later pop-outs add kinds).
- `class PopOutFrame { double x, y, width, height; Map<String, Object> toMap(); static PopOutFrame? fromMap(Object?); }`
- `PopOutFrame resolvePopOutFrame({PopOutFrame? saved, required List<PopOutFrame> displays, required PopOutFrame mainWindow, double defaultWidth = 900, double defaultHeight = 600, double minWidth = 480, double minHeight = 320})`: use `saved` (clamped to the minimum) when the centre of its top 40 px strip lies in a display; otherwise default size centred on the display holding the main window's centre (first display if none).
- `class DiveFollowState { String? followedDiveId; String? pinnedDiveId; String? get shownDiveId; bool get isPinned; DiveFollowState followed(String? id); DiveFollowState pin(); DiveFollowState unpin(); DiveFollowState diveMissing(String id); }`
- `class CursorEchoGate { void noteReceived(String diveId, int? seconds); bool shouldSend(String diveId, int? seconds); }` and `class CursorCoalescer { CursorCoalescer(void Function(String diveId, int? seconds) send, {Duration interval = const Duration(milliseconds: 16)}); void push(String diveId, int? seconds); void dispose(); }` (latest value wins per interval).
- `class WindowFocusArbiter { WindowFocusArbiter({required void Function() onLeft, required void Function() onReturned, Duration grace = const Duration(milliseconds: 300)}); set popOutOpen(bool open); void mainLeft(); void mainReturned(); void popOutFocus(bool focused); void dispose(); }`: with no pop-out open, `mainLeft`/`mainReturned` call through at once (today's behaviour); with one open, leaving is reported only if after `grace` neither window holds focus, and a return is reported only after a reported leave.

- [ ] **Step 1: Write failing tests**, including: `every message round-trips through toCall/fromCall`; `malformed args decode to null`; `launch round-trips and rejects other kinds`; `saved frame on a display is kept`; `frame off every display falls back to main window's display`; `frame below the minimum is clamped`; `following moves with the main window`; `pinned ignores followed changes and unpin jumps to the latest followed`; `diveMissing on the pinned dive unpins`; `diveMissing on the followed dive clears it`; `echo gate drops the value just received`; `coalescer sends only the latest value per interval` (fakeAsync); `focus hand-off to the pop-out within the grace is not leaving`; `pop-out losing focus to another app is leaving`; `returning after a real leave is reported once`; `no pop-out open reports at once`.
- [ ] **Step 2: Run**; FAIL. **Step 3: Implement. Step 4: Run**; PASS.
- [ ] **Step 5: Commit** `feat(pop-out): messages, follow and pin, cursor sync and focus rules`

### Task 6: Window and channel layer

**Files:**
- Create in `lib/features/pop_out/data/`: `pop_out_channel.dart` (interface), `pop_out_windows.dart` (facade), `pop_out_windows_io.dart`, `pop_out_windows_web.dart`
- Create: `test/helpers/fake_pop_out_windows.dart`
- Test: `test/features/pop_out/data/pop_out_windows_test.dart`

**Interfaces:**
- `abstract interface class PopOutChannel { Future<void> send(PopOutMessage message); void setHandler(void Function(PopOutMessage message)? handler); }`
- `abstract interface class PopOutWindows { PopOutChannel get channel; Future<void> openProfile(PopOutLaunch launch); Future<bool> isOpen(); Future<PopOutLaunch?> currentLaunch(); }` (`currentLaunch` reads this engine's `WindowController.fromCurrentEngine().arguments`; null on the main engine, web and mobile).
- `PopOutWindows createPopOutWindows()` from the facade; the io implementation wraps `WindowController.create(WindowConfiguration(arguments: launch.encode(), hiddenAtLaunch: true))`, `WindowController.getAll()` and `WindowMethodChannel('submersion/pop_out')`; a send with no peer is logged and dropped.
- `FakePopOutWindows` / `FakePopOutChannel` record sent messages and let a test deliver inbound ones.

- [ ] **Step 1: Write failing test** `web stub reports nothing open and no launch` and `fake channel delivers to the handler` (keeps the fake honest).
- [ ] **Step 2: Run**; FAIL. **Step 3: Implement. Step 4: Run**; PASS, and `test/architecture/web_compile_seams_test.dart` PASS.
- [ ] **Step 5: Commit** `feat(pop-out): window and channel layer`

### Task 7: Strings

**Files:** all 12 `lib/l10n/arb/app_*.arb` and the generated `app_localizations*.dart`.

- [ ] **Step 1:** Add to `app_en.arb` with descriptions: `popOut_openProfileWindow` "Open in a new window"; `popOut_pin` "Pin to this dive"; `popOut_unpin` "Follow the main window"; `popOut_selectDivePlaceholder` "Select a dive in the main window"; `popOut_lockedPlaceholder` "Unlock Submersion in the main window"; `popOut_windowTitle` "Profile: {dive}"; `popOut_connectFailed` "This window could not reach the logbook. Close it and try again." Translate into the other 11 files.
- [ ] **Step 2:** `flutter gen-l10n`; `flutter analyze` shows no l10n errors.
- [ ] **Step 3: Commit** `feat(pop-out): strings for the profile pop-out`

### Task 8: Main window side

**Files:**
- Create in `lib/features/pop_out/presentation/`: `providers/pop_out_providers.dart`, `providers/pop_out_host.dart`, `widgets/pop_out_profile_button.dart`, `widgets/shown_dive_reporter.dart`, `widgets/pop_out_cursor_bridge.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (wrap the built page in `ShownDiveReporter`), `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart` (button before fullscreen), `lib/features/dive_log/presentation/widgets/dive_profile_chart_host.dart` (bridge beside the chart), `lib/app.dart` (lifecycle through the arbiter; keep the host alive)
- Test: `test/features/pop_out/presentation/pop_out_host_test.dart`, `pop_out_profile_button_test.dart`, `shown_dive_reporter_test.dart`, `pop_out_cursor_bridge_test.dart`, `test/app_lifecycle_pop_out_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 5, 6, 7.
- `final popOutAvailableProvider = Provider<bool>` (desktop, not web); `final popOutWindowsProvider = Provider<PopOutWindows>((_) => createPopOutWindows())`; `final mainWindowDiveIdProvider = StateProvider<String?>((_) => null)`; `final popOutInboundCursorProvider = StateProvider<CursorMessage?>((_) => null)`.
- `final popOutHostProvider = NotifierProvider<PopOutHost, bool>` (state: open). `Future<void> openOrFocus()`; `Future<void> close()`; `void sendCursor(String diveId, int? seconds)` (gate + coalescer); `WindowFocusArbiter get focusArbiter`. While open it listens to `mainWindowDiveIdProvider` (ShowDive), `currentDiverIdProvider`, `displayZoomNotifierProvider` and `settingsProvider` (Prefs snapshot of every SharedPreferences key), `appLockNotifierProvider` (Lock); handles inbound Cursor (to `popOutInboundCursorProvider`), FocusReport (arbiter), Frame (saved under prefs key `pop_out_profile_frame` as JSON), Closed (state false). Registers a `DatabaseService.addBeforeCloseHook` that calls `close()` while open; `ref.onDispose` closes too (covers `restartApp`).
- `ShownDiveReporter({required String diveId, required Widget child})`: writes `mainWindowDiveIdProvider` after the frame when mounted or when `diveId` changes; ignores `''`.
- `PopOutProfileButton()`: `SizedBox.shrink()` unless `popOutAvailableProvider`; `IconButton(Icons.open_in_new, tooltip: l10n.popOut_openProfileWindow)` calling `openOrFocus()`.
- `PopOutCursorBridge({required String diveId, required List<DiveProfilePoint> chartProfile})`: renders nothing; outbound on `profileTrackingIndexProvider(diveId)` changes sends `chartProfile[index].timestamp` (or null); inbound applies `popOutInboundCursorProvider` for this dive with `setProfileCursorSeconds`.
- `app.dart`: the `LifecycleMeaning` switch body moves into `_onAppBackgrounded()` / `_onAppResumed()`; the switch calls `focusArbiter.mainLeft()` / `mainReturned()`, whose callbacks are those two methods.

- [ ] **Step 1: Write failing tests** (fakes from Task 6, `testApp`): `button hidden when pop-outs are unavailable`; `button opens with the shown dive, prefs and lock in the launch`; `second press focuses instead of opening`; `shown dive changes send showDive`; `diver switch sends a prefs snapshot`; `lock change sends lock`; `frame message is saved to prefs`; `closed message marks the host closed and stops sending`; `database close closes the pop-out`; `dispose closes the pop-out`; `reporter writes the dive id and ignores a new-dive page`; `bridge sends seconds for the tracked index and applies inbound seconds for its dive only`; `lifecycle goes through the arbiter while a pop-out is open` (inactive then pop-out focus within the grace does not call `noteBackgrounded`).
- [ ] **Step 2: Run**; FAIL. **Step 3: Implement. Step 4: Run**; PASS.
- [ ] **Step 5: Commit** `feat(pop-out): open the profile pop-out from the dive detail page`

### Task 9: Pop-out side

**Files:**
- Create in `lib/features/pop_out/presentation/`: `pop_out_app.dart`, `pop_out_profile_view.dart`, `providers/pop_out_client.dart`, `pop_out_overrides.dart`
- Create: `lib/core/bootstrap/pop_out_bootstrap.dart` (facade), `pop_out_bootstrap_io.dart`, `pop_out_bootstrap_web.dart`
- Modify: `lib/main.dart` (inside the guarded zone: `final launch = await readPopOutLaunch(); if (launch != null) return runPopOutApp(launch); return bootstrapApp();`), `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart` (optional `Widget? leading`: replaces both close buttons and disables the Escape pop when set), `lib/app.dart` (make the locale resolution shared: `Locale? resolveLocaleSetting(String localeSetting)`)
- Test: `test/features/pop_out/presentation/pop_out_client_test.dart`, `pop_out_profile_view_test.dart`, `pop_out_overrides_test.dart`, `test/features/dive_log/presentation/pages/fullscreen_profile_page_leading_test.dart`

**Interfaces:**
- `Future<PopOutLaunch?> readPopOutLaunch()` and `Future<void> runPopOutApp(PopOutLaunch launch)` from the bootstrap facade (web: null / unsupported). The io version: `SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.withData(<prefixed launch.prefs>)`; connect both published databases with `ReadOnlyQueryInterceptor` and `attachSharedDatabase` them (no published main database: show an error and close the window); `windowManager.ensureInitialized()`, set `minimumSize` 480x320, apply `resolvePopOutFrame` with `ScreenRetriever.instance.getAllDisplays()`, show; `runApp(ProviderScope(overrides: popOutProviderOverrides(...), child: PopOutApp(launch)))`. No file logging, no sync, no setup screens.
- `List<dynamic> popOutProviderOverrides({required SharedPreferences prefs, required LogFileService logFileService, required PopOutChannel channel})`: `rootProviderOverrides(prefs, logFileService)` plus `settingsProvider` (read-only), `currentDiverIdProvider` (read-only), `safetyReviewProvider` (stored review only: `retainDiveData`, `invalidateSelfWhen(watchDiveDetailChanges())`, `getReview(diveId)`), `popOutChannelProvider`.
- `final popOutClientProvider = NotifierProvider<PopOutClient, PopOutClientState>`; `PopOutClientState { DiveFollowState follow; bool locked; }`; `void pin()`, `void unpin()`, `void diveMissing(String id)`. Inbound: ShowDive, Cursor (sets `profileReviewProvider(diveId)` when it is the shown dive, after `noteReceived`), Prefs (writes the in-memory prefs, then invalidates `currentDiverIdProvider`, `displayZoomNotifierProvider`, `settingsProvider`), Lock, FocusRequest (`windowManager.show()` + `focus()`), Close (`windowManager.close()`). Outbound: `profileReviewProvider(shown)` through gate + coalescer; `WindowListener` focus/blur (FocusReport), moved/resized debounced 500 ms (Frame), close (Closed).
- `PopOutApp`: `MaterialApp` with the same theme preset, theme mode, locale resolution, delegates and `DisplayZoomScope` as `app.dart`; home `PopOutProfileView`.
- `PopOutProfileView`: locked gives `l10n.popOut_lockedPlaceholder`; no shown dive gives `l10n.popOut_selectDivePlaceholder`; a loaded dive that is null calls `diveMissing`; otherwise `FullscreenProfilePage(key: ValueKey(id), diveId: id, leading: pin button)`; pin button `Icons.push_pin_outlined` / `Icons.push_pin` with `l10n.popOut_pin` / `l10n.popOut_unpin`; sets the OS title to `l10n.popOut_windowTitle(label)` where label is `#<number> <site name>` (or the number alone).

- [ ] **Step 1: Write failing tests:** `leading replaces the close button and Escape does nothing`; `pop-out overrides show the stored safety review without saving` (counting repository: zero `saveReview`); `prefs message reloads diver and settings`; `cursor for the shown dive sets the review position and is not echoed back`; `review position changes are sent, coalesced`; `lock shows the locked placeholder and hides the chart`; `no dive shows the select placeholder`; `deleted pinned dive unpins and shows the placeholder`; `pin holds the dive while showDive moves on`.
- [ ] **Step 2: Run**; FAIL. **Step 3: Implement. Step 4: Run**; PASS.
- [ ] **Step 5: Commit** `feat(pop-out): the pop-out window's app, follow and pin, and cursor sync`

### Task 10: Verify in the real app and capture after shots

- [ ] **Step 1:** `dart format .`, `flutter analyze` clean.
- [ ] **Step 2:** Build, copy and re-sign the isolated `app.submersion.popoutdev` (as for the before shots), launch on the demo logbook.
- [ ] **Step 3:** Check by hand on macOS: open, follow, pin, unpin, scrub in each window, playback, theme and unit change in the main window, app lock, close pop-out, close main window with pop-out open, quit from the pop-out, reopen at the remembered frame. Grep the pop-out's console for `pop-out refused a write`: none expected; fix any that appear.
- [ ] **Step 4:** After screenshots: dive detail with the new button (wide and narrow), the two windows side by side, the pinned state, the select-a-dive placeholder, light and dark of the pop-out.
- [ ] **Step 5:** Kill the isolated app by PID.
