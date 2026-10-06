# Dark "Deep" Splash Screen and Hero Bar — Design

Date: 2026-07-24
Status: Approved

## Goal

When the app is in dark mode, the startup splash screen and the dashboard hero
bar render a dark, deep-ocean version of the animated ocean background. Same
animations, same layout, same content — only the colors change. Light mode is
untouched.

## Current State

- `lib/core/presentation/widgets/ocean_background.dart` (`OceanBackground`)
  paints the shared gradient, caustic shimmer, and 15 rising bubbles for both
  the splash and the hero header. It already branches on brightness, but its
  dark palette is a slightly darker teal (`0xFF00838F` / `0xFF00796B`), not a
  deep-ocean look.
- The splash (`lib/core/presentation/pages/startup_page.dart`) renders inside
  a throwaway `MaterialApp` whose theme defaults to light, so
  `Theme.of(context)` always reports light there — the splash is bright teal
  even on dark devices. Its error/migration screens separately key off
  `MediaQuery.platformBrightnessOf`.
- The setup wizard (`lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart`)
  passes `brightness: Brightness.light` explicitly to match the always-bright
  splash.
- The diver's theme mode (system/light/dark) is stored in the database
  (diver settings), which is not open while the splash is showing.

## Decisions

1. **Palette: "Abyss Blue".** Dark mode gradient becomes
   `#0B2540 -> #08243A at 90% alpha -> #041220 at 85% alpha`, top-left to
   bottom-right (same stops/structure as the light gradient). Bubble color
   drops to white at 0.10 alpha; caustic opacity to 0.06 (the values the
   current dark branch already uses). All bubble specs,
   speeds, wobble, and caustic drift are unchanged.
2. **Dark trigger: prefs-cached theme mode.** The diver's theme-mode setting
   is mirrored into SharedPreferences so the splash can resolve the effective
   brightness before the database opens.
3. **Setup wizard follows the splash.** The wizard uses the same resolved
   brightness instead of pinning light.

## Architecture

### 1. `OceanBackground` palette swap

Replace the dark-branch colors in `ocean_background.dart` with the Abyss Blue
values above. No structural changes; the widget keeps its existing
`brightness` override parameter.

### 2. Startup brightness resolver

New small module `lib/core/presentation/startup_brightness.dart`:

- A SharedPreferences key `cached_theme_mode` with values
  `system` | `light` | `dark`.
- A pure function
  `Brightness resolveStartupBrightness(SharedPreferences prefs, Brightness platformBrightness)`:
  - `light` / `dark` map directly to the corresponding brightness;
  - `system`, a missing key, or an unrecognized value fall back to
    `platformBrightness`.

### 3. Write-through cache

- The settings notifier writes `cached_theme_mode` whenever the theme mode
  changes.
- Settings hydration re-writes the key on every launch once the database is
  open, so a restore, sync, or diver switch that changes the setting leaves
  the cache stale for at most one launch.

### 4. Consumers

- `StartupWrapper.build` computes `isDark` via the resolver (it already holds
  `widget.prefs`) and:
  - passes the resolved brightness to the splash `OceanBackground`;
  - uses the same value for the error/migration screen colors (replacing the
    direct `platformBrightnessOf` read).
- The setup wizard replaces `brightness: Brightness.light` with the resolver
  result (fresh installs have no cached value and follow the OS).
- The hero header needs no change: it follows the real app theme, so it picks
  up the new dark palette automatically via `OceanBackground`.

## Edge Cases

- **Fresh install:** no cached value -> follows OS brightness.
- **Restore / sync / diver switch changes theme mode:** cache is corrected
  during settings hydration on the same launch; the splash is correct from
  the next launch onward.
- **In-app override vs OS:** a user forcing dark while the OS is light (or
  vice versa) gets the correct splash because the cache stores the in-app
  setting, not the OS state.

## Out of Scope

- Native launch screens (no `flutter_native_splash` is in use; nothing native
  to keep in sync).
- Per-theme-preset ocean palettes / `ThemeExtension` integration — deliberate
  YAGNI; the inline palette branch can be extracted later if palettes
  multiply.
- Any change to the light-mode look.

## Testing

- Unit tests for `resolveStartupBrightness`: every ThemeMode value crossed
  with both platform brightnesses, absent key, invalid string.
- Widget test: `OceanBackground` renders the Abyss Blue gradient when dark
  and the existing teal gradient when light.
- Settings-notifier tests: write-through on theme-mode change and on
  hydration.
- Update existing startup and setup-wizard widget tests for the new wiring
  (the wizard gains a prefs dependency; its test harness must provide one —
  a known source of consumer-test breakage in this repo).
