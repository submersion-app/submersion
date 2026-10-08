# Display Zoom — Design

Date: 2026-07-25
Branch: `worktree-display-zoom`

## Problem

On desktop there is no way to trade visual size for information density. Users
with large monitors cannot fit more dives in the list or more columns in table
mode, and users who find the default cramped cannot make everything larger. The
OS text-size setting does not solve this: it scales text only, leaving padding,
icons, row heights, and chart geometry unchanged.

## Goal

A single app-wide zoom control that behaves like browser zoom (Cmd +/-): every
logical pixel scales, so text, icons, spacing, custom-painted charts, and the 3D
view all change size together and more or less content fits on screen.

## Non-goals

- Accessibility text scaling. The OS `textScaler` continues to work and composes
  multiplicatively with zoom. This feature does not replace or override it.
- Per-widget or per-page zoom. Zoom is global.
- Pinch-to-zoom gestures. The profile chart already owns pinch and trackpad
  zoom; adding an app-level pinch would conflict with it.
- Syncing the zoom level between devices (see Persistence).

## Decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Mechanism | True zoom (root `Transform` + adjusted `MediaQuery`) | Scales everything uniformly with zero per-widget work, including `CustomPaint` charts. Density-only (`VisualDensity`) would miss custom charts and hand-rolled spacing, and yields no extra columns. |
| Breakpoints | Float | Zoom changes the logical viewport, so `ResponsiveBreakpoints` fires against the zoomed width. Zooming out can unlock master-detail and the extended rail — the structural payoff of "fit more on screen". |
| Platforms | All, unrestricted range | Deliberate. A phone in landscape at 80% can reach the 1100pt master-detail breakpoint and show a split view. Accepted as a feature, not a bug. |
| Persistence | Device-local `SharedPreferences`, standalone provider | The correct zoom for a 27" iMac is wrong for an iPhone. |
| Controls | Slider + keyboard shortcuts + macOS View menu | Discoverable on mobile, fast on desktop. |
| Range | 70%–140%, 5% steps | 15 discrete stops. Wide enough to matter, narrow enough that no stop produces an unusable layout. |

## Architecture

### 1. `lib/core/theme/display_zoom.dart` (new)

Constants and the scope widget. No dependencies on settings or Riverpod, so it
is trivially unit-testable.

```dart
class DisplayZoom {
  DisplayZoom._();

  static const double min = 0.70;
  static const double max = 1.40;
  static const double step = 0.05;
  static const double defaultValue = 1.0;
  static const int divisions = 14;

  static const int _minPercent = 70;
  static const int _maxPercent = 140;
  static const int _stepPercent = 5;

  /// Clamps a stored or computed value into range and snaps it to the nearest
  /// supported level.
  ///
  /// Clamping guards against a corrupt preference producing a zero or NaN
  /// scale, which would divide by zero and blank the app.
  ///
  /// Snapping matters just as much: repeated `+/- 0.05` arithmetic drifts.
  /// Stepping down past [min] clamps to the floor, which discards the
  /// accumulated error, so stepping back up lands on 1.0000000000000002 --
  /// rendered as "100%" but not `== 1.0`, leaving the Reset button visible and
  /// making DisplayZoomScope build a transform layer at nominal 100%. Snapping
  /// runs in integer-percent space so it cannot itself accumulate error, and
  /// it guarantees the stored value always equals the displayed percentage
  /// divided by 100.
  static double normalize(double value) {
    if (!value.isFinite) return defaultValue;
    final percent = (value * 100).round().clamp(_minPercent, _maxPercent);
    final snapped = (percent / _stepPercent).round() * _stepPercent;
    return snapped / 100;
  }
}

class DisplayZoomScope extends StatelessWidget {
  const DisplayZoomScope({super.key, required this.zoom, required this.child});

  final double zoom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Normalized at the boundary: this widget is public, and a raw 0 / NaN /
    // negative zoom would divide the logical size into infinity or NaN.
    final scale = DisplayZoom.normalize(zoom);
    if (scale == DisplayZoom.defaultValue) return child;

    final mq = MediaQuery.of(context);
    final logical = mq.size / scale;

    return MediaQuery(
      data: mq.copyWith(
        size: logical,
        padding: mq.padding / zoom,
        viewPadding: mq.viewPadding / zoom,
        viewInsets: mq.viewInsets / zoom,
        devicePixelRatio: mq.devicePixelRatio * zoom,
      ),
      child: Transform.scale(
        scale: zoom,
        alignment: Alignment.topLeft,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: logical.width,
          maxWidth: logical.width,
          minHeight: logical.height,
          maxHeight: logical.height,
          child: child,
        ),
      ),
    );
  }
}
```

Notes on the field adjustments:

- `size` divided: the child lays out in a larger (zoom < 1) or smaller
  (zoom > 1) logical space, then the transform scales it to fill the physical
  area. This is what makes breakpoints float.
- `padding` / `viewPadding` divided: safe-area insets are expressed in the
  outer coordinate space. Without dividing, content creeps under the notch at
  zoom < 1.
- `viewInsets` divided: same reasoning for the on-screen keyboard.
- `devicePixelRatio` multiplied: `ImageConfiguration` consults it to select
  asset resolution. Without this, 130% renders 1x assets upscaled.
- The `zoom == defaultValue` early return means users who never touch the
  setting get a byte-identical widget tree to today — no extra layer, no
  `MediaQuery` rebuild.
- `OverflowBox`, not `SizedBox`. `MaterialApp.builder` passes its child TIGHT
  constraints equal to the physical window, and a `SizedBox` is forced back to
  those constraints. The child would then be laid out at the physical size and
  scaled, painting only `zoom`x the window (a black band on the right and
  bottom at zoom < 1) or overflowing and clipping at zoom > 1. `OverflowBox`
  is what lets the child take the enlarged logical size. This was found by
  manual smoke test, not by unit tests: assertions on `MediaQuery` values all
  passed while the layout was wrong, so the regression test asserts the
  child's rendered `Size` via `tester.getSize`.

### 2. `lib/features/settings/presentation/providers/display_zoom_provider.dart` (new)

Zoom is device-local and never per-diver, so it does **not** live on
`AppSettings`. `SettingsNotifier._initializeAndLoad()` awaits a database
round-trip to resolve the diver ID before it reads `SharedPreferences`, so an
`AppSettings` field would render the first frames at 100% and then pop to the
stored value — the same startup problem that forced the `cached_theme_mode`
mirror.

A standalone notifier seeded synchronously from the already-injected
`SharedPreferences` (`main.dart:62` awaits it before `runApp`) cannot flash:
its initial state is the stored value on frame one.

```dart
class DisplayZoomNotifier extends StateNotifier<double> {
  DisplayZoomNotifier(this._prefs)
      : super(DisplayZoom.normalize(
          _prefs.getDouble(SettingsKeys.displayZoom) ?? DisplayZoom.defaultValue,
        ));

  final SharedPreferences _prefs;

  /// Live update with no write. Used while a slider drag is in flight.
  void previewZoom(double value) {
    state = DisplayZoom.normalize(value);
  }

  Future<void> setZoom(double value) async {
    final normalized = DisplayZoom.normalize(value);
    state = normalized;
    // Compared against storage, not state, so a commit that follows
    // previewZoom to the same value still persists.
    if (_prefs.getDouble(SettingsKeys.displayZoom) == normalized) return;
    await _prefs.setDouble(SettingsKeys.displayZoom, normalized);
  }

  Future<void> stepBy(int direction) =>
      setZoom(state + direction * DisplayZoom.step);

  Future<void> reset() => setZoom(DisplayZoom.defaultValue);
}

final displayZoomNotifierProvider =
    StateNotifierProvider<DisplayZoomNotifier, double>((ref) {
  return DisplayZoomNotifier(ref.watch(sharedPreferencesProvider));
});
```

`SettingsKeys` gains one entry alongside the existing device-local keys:

```dart
static const String displayZoom = 'display_zoom';
```

Naming follows the project convention in CLAUDE.md: `<noun>NotifierProvider`
for mutable state. Watching it yields the current `double`.

### 3. `lib/app.dart`

The builder at line 361 gains the shortcut layer and the zoom scope. Ordering
is load-bearing:

- `RestoreBarrier` stays outermost so the restore blocker remains a true
  full-screen, unscaled overlay.
- `CallbackShortcuts` sits outside `DisplayZoomScope` so the shortcut layer is
  never itself transformed.
- `Focus(autofocus: true)` is required: `CallbackShortcuts` only fires for
  keystrokes inside its focused subtree, and on desktop cold-start nothing has
  focus yet.
- The `Consumer` lives inside `builder` rather than watching in
  `_SubmersionAppState.build`, so dragging the slider rebuilds only the
  subtree instead of the entire `MaterialApp.router`.

```dart
builder: (context, child) {
  Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
  return RestoreBarrier(
    child: Consumer(
      builder: (context, ref, _) {
        final zoom = ref.watch(displayZoomNotifierProvider);
        final notifier = ref.read(displayZoomNotifierProvider.notifier);
        return CallbackShortcuts(
          bindings: _zoomBindings(notifier),
          child: Focus(
            autofocus: true,
            child: DisplayZoomScope(zoom: zoom, child: child!),
          ),
        );
      },
    ),
  );
},
```

Bindings, with the platform modifier resolved once:

- Zoom in: `equal` and `numpadAdd`
- Zoom out: `minus` and `numpadSubtract`
- Reset: `digit0`

Modifier is `meta` on macOS/iOS, `control` elsewhere.

### 4. `lib/features/settings/presentation/pages/appearance_page.dart`

A `ListTile` plus `Slider` in the General section, inserted between the theme
mode selector (line 63) and the Language tile (line 65). The tile shows the
current percentage and, when not at 100%, a Reset action.

No preview widget: because zoom applies at the app root, the Appearance page
itself scales as the slider moves. The settings screen is the live preview.

The slider drives `previewZoom` from `onChanged` and `setZoom` from
`onChangeEnd`. `divisions` already discretizes the drag, so `onChanged` fires
per notch rather than per pixel, but the split keeps storage writes out of the
drag entirely: one write per gesture instead of one per notch, and no reliance
on the completion order of overlapping async writes to decide what ends up
stored. The keyboard shortcuts and the macOS menu call `setZoom` directly,
since those are discrete commits with no drag to defer.

### 5. macOS View menu

`macos/Runner/Base.lproj/MainMenu.xib`, View submenu `HyV-fh-RgO` (line 297),
gains three visible items above the existing separator, plus one hidden
duplicate:

| Title | Key equivalent | Selector |
| --- | --- | --- |
| Zoom In | Cmd + | `zoomIn:` |
| Zoom In (hidden duplicate) | Cmd = | `zoomIn:` |
| Zoom Out | Cmd - | `zoomOut:` |
| Actual Size | Cmd 0 | `actualSize:` |

The hidden duplicate is required. Users press Cmd+= (unshifted) but every app
displays Cmd++; AppKit does not treat them as equivalent. Safari and Chrome
both ship the same hidden-duplicate workaround. Omitting it is the most likely
way this ships feeling broken.

The View submenu currently contains only "Enter Full Screen". The existing
"Zoom" item at line 317 is AppKit's `performZoom:` (maximize window) and lives
in the *Window* menu, not View; it is left alone and the new titles are
distinct from it.

`AppDelegate.swift` gains three `@IBAction` methods that invoke a new
`app.submersion/display` `MethodChannel`, mirroring the existing
`checkForUpdatesMenuItem` outlet pattern (line 19) and the
`app.submersion/updates` channel. Dart registers the handler alongside
`registerUpdateMenuChannel(ref)` in `_SubmersionAppState.initState`.

Once the menu items carry key equivalents, AppKit consumes those chords before
the Flutter engine sees them, so the Dart `CallbackShortcuts` never fires on
macOS. This is correct and needs no guard: macOS routes through the native
menu, Windows and Linux route through Dart, and neither double-fires. The
consequence is that a miswired xib action fails silently on macOS only, so
macOS needs a manual smoke check.

Windows and Linux have no menu bar; they rely on the Dart shortcuts.

## Localization

New ARB keys in `app_en.arb`:

- `settings_appearance_displaySize`
- `settings_appearance_displaySize_value` — takes an `int` placeholder
  `percent`, so the percentage is formatted per locale rather than
  concatenated in Dart
- `settings_appearance_displaySize_reset`
- `settings_appearance_displaySize_smaller`
- `settings_appearance_displaySize_larger`

Per project convention these must be translated into all 10 non-en locales,
followed by an l10n regen. The xib menu titles stay English-only, consistent
with the existing `Base.lproj`-only menu.

## Testing

No golden tests. Zoom goldens would invalidate at three scale factors on every
unrelated UI change.

| File | Assertions |
| --- | --- |
| `test/core/theme/display_zoom_scope_test.dart` | At 1.0 the child is returned with no `Transform` in the tree. At 0.8 the inner `MediaQuery.sizeOf` equals outer size / 0.8. `padding`, `viewPadding`, `viewInsets` divide. `devicePixelRatio` multiplies. |
| `test/core/theme/display_zoom_normalize_test.dart` | Stored `0.0`, `NaN`, `-1`, and `9.9` all clamp into range, covering the divide-by-zero blank-screen guard. A float-drifted `1.0000000000000002` snaps back to exactly `1.0`, and every result lands on an exact whole percent on the 5% ladder. |
| `test/core/theme/display_zoom_hit_test.dart` | A button tapped at 0.8 and at 1.3 still fires its callback. |
| `test/shared/widgets/display_zoom_breakpoints_test.dart` | A 1000pt-wide harness is not master-detail at 100% and is at 85%. Encodes the floating-breakpoint decision so it cannot be silently reverted. |
| `test/features/settings/display_zoom_provider_test.dart` | Initial state reads synchronously from prefs. `setZoom` normalizes and persists. `stepBy` walks the ladder and saturates at the bounds. `reset` returns to 1.0. A clamp-floor round trip returns to exactly `defaultValue`, asserted with exact equality rather than a tolerant matcher. |
| `test/core/theme/display_zoom_shortcuts_test.dart` | Ctrl+`-`, Ctrl+`=`, Ctrl+`0` step and reset on the Linux/Windows path; numpad `+`/`-` are bound; the wrong modifier does not fire. |
| `test/features/settings/display_zoom_menu_channel_test.dart` | `zoomIn`/`zoomOut`/`actualSize` dispatch through the `app.submersion/display` channel, and an unknown method returns an error envelope instead of looking like success. |
| `test/features/settings/presentation/display_zoom_settings_tile_test.dart` | The tile shows the current percentage, hides Reset at 100%, resets on tap, and configures the slider for the supported range. |

The hit test is the highest-value case here: a root `Transform` is exactly the
kind of change where everything renders correctly and nothing responds, and a
purely visual review would not catch it.

## Risks

1. **Hairline softness.** At non-integer scales a 1px divider lands on a
   fractional device pixel and rasterizes slightly soft. Browsers have the same
   artifact. Accepted as inherent to true zoom.
2. **Phone landscape can reach split view.** Explicitly chosen. Recorded here
   so review does not relitigate it.
3. **Zooming into a corner.** At 140% on a narrow window the layout drops to
   mobile chrome, which could make the slider awkward to reach. Cmd/Ctrl+0 and
   the inline Reset button are the escape hatches, and both remain reachable.
4. **Text fields swallowing shortcuts** on Windows and Linux. Covered by the
   shortcuts test.
5. **macOS-only silent failure** if the xib actions are miswired. Requires a
   manual macOS smoke check.
6. **Consumer test breakage.** Adding an app-level provider dependency can
   break widget tests that pump `SubmersionApp` without the matching override,
   and `flutter analyze` will not catch it. The full suite must pass before
   this is considered done. The standalone-provider design limits the blast
   radius, since `AppSettings` is untouched.

## Out of scope for this spec

- Remembering a different zoom per window on desktop multi-window setups.
- Exposing zoom in the setup wizard.
