# Fullscreen dive profile: full-screen on phones (#811)

Date: 2026-08-10
Issue: [#811](https://github.com/submersion-app/submersion/issues/811)
Branch: `worktree-issue-811-fullscreen-profile`

## Problem

On a phone, the "fullscreen" dive profile gives the chart less than half the
screen. Three things crowd it out:

1. `ProfileInstrumentBar` renders up to 13 metric tiles. Below 600 px it uses a
   `Wrap` instead of a horizontal `ListView`, so the tiles stack into four rows
   and consume roughly a third of the display.
2. The app's bottom navigation bar is still visible. `dive_detail_page.dart`
   pushes the page with a plain `Navigator.of(context)`, which resolves to the
   single `ShellRoute` navigator inside `MainScaffold`, so the page renders
   inside the shell rather than over it.
3. The Android status bar stays up.

The reporter's own annotation marks the tile strip for removal and the chart for
expansion to the screen edges. The tiles are also redundant: every value they
show is already in the draggable readout card that floats over the chart.

## Goals

- Phone: nothing below the chart except the source bar on multi-source dives.
- Desktop and tablet: keep playback transport, drop the metric tiles.
- Fullscreen means fullscreen: no bottom nav, no status bar.

## Non-goals

- Redesigning the chart itself, its legend row, or its zoom controls.
- Changing the draggable readout card's contents or default placement.
- Any change to the inline profile chart on the dive detail page.

## Design

### Layout

`FullscreenProfilePage` gates on

```dart
final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
```

`shortestSide` rather than `maxWidth` so a phone held in landscape -- where
vertical space is scarcest -- still counts as a phone. A narrow desktop window
also loses the transport; accepted, resizing restores it.

| | Chart | SourceBar (2+ sources) | Transport row | Metric tiles |
| --- | --- | --- | --- | --- |
| Phone | `Expanded`, full bleed | shown | removed | removed |
| Desktop / tablet | `Expanded` | shown | kept | removed |

Chart padding drops from `EdgeInsets.fromLTRB(12, 8, 12, 0)` to a uniform 4 px
inset on phone so the plot reaches the edges. Desktop keeps the current padding.

`ProfileInstrumentBar` loses its tile half and is renamed `ProfileTransportBar`
-- it now contains only the transport row, and "instrument bar" would name
something that no longer exists. Its `tune` `IconButton` is deleted along with
the sheet it opened.

### Immersive mode

`FullscreenProfilePage.initState` calls
`SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: [])`
and `dispose` restores
`SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values)`.

This mirrors `photo_viewer_page.dart:87-107` exactly, including its lack of a
platform guard: the call is a no-op on desktop, and a fullscreen chart on a
tablet benefits from it as much as on a phone.

### Escaping the shell

`dive_detail_page.dart`'s `_showFullscreenProfile` changes to
`Navigator.of(context, rootNavigator: true).push(...)`. The page then sits above
the `ShellRoute` navigator, so `MainScaffold`'s bottom navigation and rail are
not painted. Android system back pops the root route normally, before the
shell's `PopScope` is consulted.

### Splitting `instrument_tiles.dart`

The file is not exclusively the instrument bar's.
`perdix_overlay/perdix_face_resolver.dart:6,99` imports it for `resolveSample`,
which the Perdix video overlay uses to read instrument values at a timestamp.

- **New** `widgets/instrument_sample.dart`: `InstrumentSample` and
  `resolveSample`, moved verbatim (including `resolveSample`'s doc comment about
  index-aligned curves). Imports narrow to `profile_analysis_service.dart`,
  `dive.dart`, `profile_position.dart`.
- **Deleted** with the rest of `instrument_tiles.dart`: `InstrumentTileId`,
  `_priorityOrder`, `computeCandidateTiles`, `applyTilePreferences`,
  `mergeTileOrder`, `applyDecoSwap`.

`perdix_face_resolver.dart` re-points its import at the new file.

### Other deletions

| Target | Notes |
| --- | --- |
| `widgets/readout_tile.dart` | Only the tile strip used it |
| `_CustomizeSheet` in the instrument bar | Reorder/visibility sheet |
| `Settings.fullscreenTileOrder`, `Settings.fullscreenHiddenTiles` | Field, constructor arg, `copyWith` arg, load, persist |
| `SettingsKeys.fullscreenTileOrder`, `SettingsKeys.fullscreenHiddenTiles` | SharedPreferences keys `fullscreen_tile_order`, `fullscreen_hidden_tiles` |
| `SettingsNotifier.setFullscreenTilePreferences` | Sole caller was the customize sheet |
| `diveLog_instruments_customize`, `diveLog_instruments_customizeHint` | 11 `.arb` files plus their generated `app_localizations*.dart` |

Stale SharedPreferences entries from previous installs are left in place. They
are per-device, unread once the keys are gone, and a migration to delete two
orphaned string lists is not worth its own risk.

### Test plan

New and changed cases in
`test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`.
Size by wrapping the page in an explicit `MediaQuery`, the convention already in
the codebase (`test/shared/widgets/map_list_layout/map_list_scaffold_test.dart`):
`setSurfaceSize` alone does not reliably drive a breakpoint that reads
`MediaQuery`, and a test that relies on it silently renders the wrong layout.

```dart
home: MediaQuery(
  data: const MediaQueryData(size: Size(400, 800)),
  child: const FullscreenProfilePage(diveId: 'd1'),
),
```

- Phone size (400x800): `ProfileTransportControls` absent.
- Desktop size (1200x900): `ProfileTransportControls` present.
- Both sizes: no `ReadoutTile`, no `tune` icon.
- Multi-source dive at phone size: `SourceBar` present.
- Phone: tapping the chart still updates `profileReviewProvider` and the
  readout card, with no playback ever activated.

Changed elsewhere:

- `instrument_tiles_test.dart` -> `instrument_sample_test.dart`, keeping only the
  `resolveSample` cases (roughly the last third).
- `readout_tile_test.dart` and `profile_instrument_bar_test.dart`'s tile cases
  deleted; the transport cases move to `profile_transport_bar_test.dart`.
- `settings_notifier_real_test.dart:451-452` assertions removed.
- The local `Settings` builders in `mock_providers.dart:446`,
  `records_page_test.dart:437`, `settings_page_test.dart:452`,
  `settings_page_shared_data_test.dart:525` drop their `order`/`hidden` params.

## Risks

- **Phone users lose playback in fullscreen.** Deliberate, per the issue: the
  chart is the point, and playback remains on the dive detail page. Touch
  scrubbing still drives the readout because `DiveProfileChart` reads
  `profileReviewProvider`, never `playbackProvider`.
- **`ProfileTransportControls.initState` currently activates playback mode as a
  side effect** (`profile_transport_controls.dart:31-43`). On phone that widget
  never mounts, so playback mode is never entered and
  `FullscreenProfilePage.dispose`'s `_wasPlaybackActiveOnEntry` cleanup is a
  no-op. Correct, but the dispose logic must be re-read to confirm it tolerates
  a page that never had a transport.
- **Immersive mode on iOS** hides the home indicator until a swipe. The photo
  viewer already ships this behavior, so it is consistent with the app.
