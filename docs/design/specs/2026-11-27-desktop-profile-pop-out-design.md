# Desktop profile pop-out window

Status: design approved in conversation, 2026-11-27. Target release v1.8.7.

## Why

On a desktop with two monitors, the diver wants a dive's profile on the
second monitor while browsing dives in the main window. Today the app is a
single OS window: the profile lives inside the dive detail pane, and the
fullscreen profile view replaces the main window's content, so it cannot sit
beside the dive list.

The diver's own words: "mostly a chart on my second monitor while I browse
dives. I'd definitely want the scrubbed position to update in realtime in
both windows."

## Goals

- On macOS, Windows and Linux, a dive's profile can be popped out into its
  own OS window, which the diver can drag to another monitor and resize.
- The pop-out follows the dive the main window shows, so browsing dives
  changes it, unless the diver pins it to one dive.
- The profile cursor is shared live between the two windows: scrubbing
  either moves the cursor in the other whenever both show the same dive.
- Edits made in the main window (units, a changed dive, a deleted dive) reach
  the pop-out without reopening it.
- The window plumbing (opening, message channel, shared database access) is
  reusable, so other screens can be popped out later without redoing it.

## Non-goals

- Popping out anything other than the dive profile in this release (the dive
  detail page, statistics charts and the planner were considered and left for
  later).
- Editing in the pop-out. It is a viewer: no annotation edits, no gas-switch
  edits, nothing that writes.
- Several profile pop-outs at once, or one pop-out per dive for comparison.
- Reopening the pop-out automatically after the app restarts.
- Phones, tablets and the web app. The button does not appear there.
- Moving to Flutter's built-in multi-window API. It is still experimental and
  only available on Flutter's main channel (checked at 3.50.1); the repo pins
  3.47.0.

## Anti-goals

These would make the feature a failure even if it technically worked:

- The pop-out opening the database file itself: running migrations, starting
  a second sync engine, holding a second SQLCipher handle, or writing.
- A cursor that lags visibly, jitters, or ping-pongs between windows.
- The pop-out showing a dive while the main window is locked by app lock.
- The pop-out showing data in different units or a different theme from the
  main window.
- A pop-out that outlives the database it reads (after a restore, a storage
  location change or a soft restart) and shows stale or broken data.
- A pop-out that reopens off-screen because the monitor it was on is gone.

## Approaches considered

1. **Plugin window sharing the main window's database worker (chosen).**
   `desktop_multi_window` 0.3.1 (August 2026; macOS, Windows, Linux) opens a
   window with its own Flutter engine. The pop-out runs a slim app root that
   connects to the Drift worker isolate the main window already runs, so the
   fullscreen profile page's existing providers work unchanged and Drift's
   table-update notifications reach the pop-out for free. Selection, cursor
   and playback travel over a small message channel. Trade-off: the worker
   becomes shared, so its lifetime and shutdown need care, and each pop-out
   costs one Flutter engine's memory.
2. **Plugin window that renders snapshots the main window sends.** No database
   in the pop-out; the main window serializes the dive, its analysis and the
   settings on every change. Rejected: the fullscreen page reads around a
   dozen providers, each would need a serializable snapshot and an override,
   payloads are large, and it drifts every time the page changes.
3. **Wait for Flutter's built-in windowing.** One engine, shared state, no
   plumbing, but not usable on stable Flutter, so it cannot ship in v1.8.7.
   The chosen design keeps the window layer separate so a later switch
   replaces only that layer.

A separate app process per window was dropped early: it needs its own
database connection and a cross-process channel, strictly worse than (1).

## Design (as decided)

### Where the control lives

- A pop-out button sits beside the existing fullscreen button in the dive
  detail page's profile section header (`dive_detail_profile_section.dart`),
  on macOS, Windows and Linux only.
- If the pop-out is already open, the button brings it to the front (and
  un-minimizes it) instead of opening another.

### What the window shows

- The existing fullscreen profile view (`FullscreenProfilePage`): chart,
  legend, range mode and range stats and the tooltip panel. It is opened with
  no `EditSession` and no `onOpenInNotes`, which the page already treats as
  read-only.
- No playback transport bar (play, step, scrub strip, speed): the pop-out is
  a chart to look at beside the main window, so it leaves the bar out
  (`showTransport: false`). Decided after the first build, at the diver's
  request.
- The OS window title names the dive, for example "Profile: #142 Salt Pier",
  and updates when the dive changes.
- The page's own controls that only make sense inside the main window (a back
  or close-fullscreen control that pops a route) are hidden in the pop-out;
  closing is the OS window's close button.

### Follow and pin

- **Following (the default):** the pop-out shows the dive whose detail the
  main window is showing. On desktop that is the dive selected in the dive
  list's master-detail pane, and also a dive detail opened from elsewhere
  (a trip, a site, search). When the main window moves to a screen with no
  dive (Sites, Settings), the pop-out keeps the last dive rather than
  blanking.
- **Pinned:** a pin button in the pop-out's header holds it on its current
  dive. Browsing in the main window no longer changes it. Unpinning jumps to
  the main window's current dive and resumes following.
- Pin state lives in the pop-out only and is not remembered across openings
  (each opening starts following).
- **No dive:** if no dive has been shown yet, or the shown dive is deleted,
  the pop-out shows a short message ("Select a dive in the main window")
  instead of an empty chart. A pinned dive that is deleted unpins and shows
  the same message.

### Shared cursor

- The shared position is the dive time in seconds, not a sample index, since
  each window builds its own chart series. The main window's detail chart
  cursor is `profileTrackingIndexProvider(diveId)` (an index into the chart
  profile, converted with the existing `setProfileCursorSeconds` helpers);
  its own fullscreen view's, like the pop-out's, is the fullscreen page's
  `profileReviewProvider(diveId)`, already in seconds. Both main-window
  cursors are shared (the fullscreen one was added after review).
- Scrubbing either window moves the other window's cursor when both show the
  same dive. Clearing the cursor (pointer leaves the chart) clears it in both.
- Updates are coalesced to at most one message per frame per direction.
- There is no echo loop: each window drops the landings of the position it
  just received, and any repeat of what it last sent. One received position
  can land twice in the main window (exactly in its fullscreen view, snapped
  to a sample in the detail chart beneath); the diver's own move forgets any
  landing still expected.
- When the two windows show different dives (pinned, or following lags a
  moment during a switch), positions are not exchanged.

### Data access

- The pop-out never opens the database file. The main window publishes the
  connect port of its Drift worker isolate (`IsolateNameServer`, which is
  process-wide), and the pop-out connects to that worker with Drift's isolate
  client in serializing mode, since the two engines are separate isolate
  groups. It builds its `AppDatabase` on that connection and overrides the
  database provider with it.
- The main window's worker currently connects with `singleClientMode: true`,
  which ties the worker's life to its one client. That changes so the worker
  serves several clients and stays alive until the main window's existing
  shutdown path ends it; a pop-out disconnecting must never close it.
- If the fullscreen page reads the local cache database (the second worker,
  `LocalCacheDatabaseService`), that worker is shared the same way.
- Before the main window closes or swaps its database (restore, storage
  location change, `restartApp`, wipe, app shutdown), it closes the pop-out
  first. The diver reopens it afterwards.

### Settings, theme and lock

- Values stored in the database (diver settings such as units) reach the
  pop-out through the shared connection and its update notifications, read
  by the read-only settings source described under "Strictly read-only".
- Values the main window keeps outside the database that change what the
  page shows (active diver, theme mode, locale, display zoom, and any other
  such app-level value the page reads) are pushed by the main window over the
  channel when the pop-out opens and whenever they change.
- Only the main window writes SharedPreferences. On Windows and Linux the
  store is a single file, and two engines writing it would clobber each
  other.
- While app lock has the main window locked, the pop-out hides the dive
  behind a locked placeholder and shows it again on unlock.
- **Focus moving between the app's own windows is staying in the app**
  (decided by the diver). Today the main window treats
  `AppLifecycleState.inactive` as leaving: App Lock counts it as
  backgrounded, and the following resume starts a sync, the stale-drafts
  check and the health import (`app.dart`, `didChangeAppLifecycleState`).
  With a pop-out open, the pop-out reports its focus over the channel, and
  the main window ignores an inactive that hands focus to its own pop-out,
  and the resume that follows it. Only leaving both windows (another app in
  front, the screen locking, minimising both) counts as leaving, so App
  Lock's "immediately" and its timeout keep their meaning and a click back
  into the main window does not start a sync.

### Strictly read-only

- The pop-out writes nothing, not even derived data as a side effect of
  viewing (builder's check, settled by the no-writes anti-goal):
  - `safetyReviewProvider` saves a recomputed review when the stored one is
    stale (`repo.saveReview`, which also stamps sync records). In the pop-out
    it is overridden to show the stored review, or one computed without
    saving. The main window remains the only place reviews are saved.
  - The real `SettingsNotifier` writes SharedPreferences on load and can save
    the diver settings row and schedule notifications. The pop-out replaces
    it with a read-only source built from the diver settings row (through the
    shared connection, so unit changes still arrive live) plus the app-level
    values the main window pushes.
  - No sync clock (HLC) is configured in the pop-out's engine; with no writes
    it never needs one.
- **Unsaved edits are not shown** (decided by the diver). While the main
  window holds unsaved annotation or gas-switch edits in its `EditSession`,
  the pop-out shows the dive as saved and catches up when the edit is saved.

### Window lifecycle

- The pop-out remembers its size and position (saved by the main window), so
  it reopens where it was. If that frame is no longer on any connected
  screen, it opens centred on the main window's screen at a default size.
- Closing the pop-out leaves the main window alone. Closing or quitting the
  main window closes the pop-out (through the existing exit guard on
  quit).
- Quitting from the pop-out (Cmd-Q on macOS, the app menu) quits the app
  through the main window's normal quit path.

### Architecture

Three layers, so later pop-outs and a later move to Flutter's own windowing
each touch only one:

1. **Window layer:** opening, focusing, closing and framing windows, and the
   entry-point switch in `main()` that runs the pop-out root when the engine
   was started as a pop-out (`WindowController.fromCurrentEngine()` and its
   arguments). Wraps `desktop_multi_window`; nothing else imports it.
2. **Channel layer:** typed messages between windows over a
   `WindowMethodChannel` (show dive, cursor, app-level settings, lock,
   close), with a fake for tests.
3. **Content:** the pop-out root (slim `ProviderScope`, shared database
   connection, theme) and the profile content with follow and pin.

The pop-out root skips everything the main window's startup does that a
viewer does not need: setup and onboarding screens, sync, backups, update
checks, log file attachment, share intake and the app exit guard.

### Native runners

Each platform's runner registers plugins for new windows as
`desktop_multi_window` requires (`flutter_window.cpp` on Windows,
`MainFlutterWindow.swift` on macOS, `my_application.cc` on Linux). The macOS
custom channels registered in `MainFlutterWindow.swift` (bookmarks, iCloud,
metadata, multipeer and the rest) stay on the main engine only; the pop-out
never calls them.

## Constraints

- Desktop only: every new call is behind the existing desktop-platform checks,
  and web and mobile builds must not import the plugin (conditional import or
  a stub).
- Flutter stays at 3.47.0 (`.github/flutter-version.txt`).
- New user-visible strings go in every ARB file.
- Units follow the active diver's settings, as everywhere else.
- Tests that touch process-wide state (channel mocks, `IsolateNameServer`
  registrations) restore it, per `docs/developer/testing.md`.
- Files stay within the repo's size guard (800 lines); new code goes in new
  small files rather than growing `fullscreen_profile_page.dart` (already
  about 1,040 lines).
- The cross-engine Drift connection is the riskiest piece. Build it first as
  a spike on macOS. If a second engine cannot use the main window's worker,
  stop and bring it back to the diver before building the rest.

## Spike findings (2026-11-27)

A standalone macOS app (Flutter 3.47, `desktop_multi_window` 0.3.1, drift
2.35.3, `window_manager` 0.5.2), outside this repo, proved the risky piece:

- A second window's engine found the first engine's Drift worker port
  through `IsolateNameServer` and connected with `serialize: true` and
  `singleClientMode: false`. It read the same database.
- Every table update the main engine announced reached the pop-out within
  about 2 ms.
- `WindowMethodChannel` (bidirectional, the default) carried calls both
  ways.
- `window_manager` 0.5.2 binds to its own engine's window
  (`registrar.view?.window`, set lazily), so the pop-out retitled only
  itself. The patched fork the plugin's README mentions is not needed.
- The pop-out closing its connection and its window left the worker
  serving the main engine.

Two build calls followed from reading the plugin:

- **Vendor `desktop_multi_window`** under `packages/`, as the repo already
  does for `auto_updater_windows`. On macOS it creates each window's engine
  with a plain `FlutterDartProject()`, which would put the pop-out on
  Impeller on Intel Macs and bring back the flicker of #3531. The vendored
  copy adds a hook so the runner supplies the project
  (`RendererDartProject`).
- **Register an allowlist of plugins in the pop-out's engine**, not
  `RegisterGeneratedPlugins`. Some plugins take process-wide hooks when they
  register (a notification-center delegate, URL handlers, the updater), and
  a second registration would take them from the main window.

## Left to the builder

- Message names and payload shapes on the channel.
- How the main window reports "the dive I am showing" (a provider the dive
  detail page writes when it becomes visible is the expected route).
- The default pop-out size and the minimum size.
- Exact wording of the placeholder and pin tooltip strings.
- The pin and pop-out icons, from the app's existing icon set.
- How frame persistence is keyed and stored (main window's SharedPreferences).
- Whether `window_manager` is needed in the pop-out for framing, or the
  multi-window plugin's own controller is enough.
- Test strategy below the end-to-end level: the follow and pin state machine,
  echo suppression and frame restore are plain Dart and should be unit tested
  with a fake channel; the pop-out root's placeholder states get widget
  tests. The real two-engine behaviour is checked by hand on macOS and shown
  in the PR's screenshots.
