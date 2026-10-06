# Color Accents — Design Spec

**Date:** 2026-07-23
**Status:** Approved (brainstorming complete)
**Branch:** worktree-color-accents

## Summary

Add an optional per-feature-area accent color system to Submersion. Each feature
area (Dives, Sites, Equipment, ...) gets a curated identity color. Three
independent toggles in Settings > Appearance apply those colors to three
surfaces: main navigation icons, section header icons, and settings/list-tile
leading icons. Everything defaults to off, preserving today's appearance.

## Goals

- More color in the app, opt-in only.
- One general framework (palette + lookup + gating) that all current and future
  colored surfaces draw from.
- Settings follow the diver across devices (synced), like theme mode/preset.

## Non-goals

- User-customizable colors (no color picker).
- Per-theme-preset palettes (the mechanism allows them later, but v1 ships one
  curated palette).
- Coloring text/labels — icons only.

## Architecture (Approach A: ThemeExtension + per-surface gate providers)

### 1. Palette & ThemeExtension

New file `lib/core/theme/feature_accent_colors.dart`:

- `class FeatureAccentColors extends ThemeExtension<FeatureAccentColors>`
  holding `Map<String, Color> colors` keyed by stable feature id strings
  (the `NavDestination.id` values, plus extra settings-row keys).
- `Color? of(String featureId)` — null-safe lookup; `null` means "use theme
  default". Unknown ids degrade gracefully, never crash.
- `copyWith` and `lerp` implemented; `lerp` interpolates each map entry with
  `Color.lerp` so accents animate during theme transitions.
- Two curated instances: `FeatureAccentColors.light` and
  `FeatureAccentColors.dark` (dark variants are lighter/desaturated versions of
  the same hues for contrast on dark surfaces).

Each of the 5 theme presets (`submersion_theme.dart`, `console_theme.dart`,
`tropical_theme.dart`, `minimalist_theme.dart`, `deep_theme.dart`) registers
the appropriate instance in `ThemeData.extensions` for both brightnesses. A
preset may override the palette later without touching consumers.

### Starting palette (base hues; exact values tuned for contrast in both modes)

| Feature id | Hue | Feature id | Hue |
| --- | --- | --- | --- |
| `dashboard` | brand blue | `courses` | indigo |
| `dives` | ocean blue | `statistics` | teal |
| `sites` | green | `planning` | deep purple |
| `trips` | violet | `transfer` | cyan |
| `equipment` | orange | `gps-log` | red |
| `buddies` | pink | `settings` | blue-grey |
| `dive-centers` | brown | `certifications` | amber |

The `more` sentinel is intentionally uncolored (it is a control, not a
destination). Additional open-keyed `settings-<id>` entries mirror the
settings root sections, adopting the exact colors hardcoded there today so
the root's appearance does not change: `settings-about` blueGrey,
`settings-appearance` pink, `settings-data` green, `settings-dataSources`
red, `settings-decompression` deepPurple, `settings-profile` blue,
`settings-safety` redAccent, `settings-manage` indigo,
`settings-notifications` orange, `settings-sharedData` cyan,
`settings-units` teal, `settings-debug` grey.

### 2. Settings, persistence & sync

Three per-diver booleans, all default `false`:

| Setting | Surface |
| --- | --- |
| `accentNavIcons` | Bottom nav bar, desktop rail, More overflow sheet |
| `accentSectionHeaders` | Feature page header icons |
| `accentListIcons` | Settings rows and detail-page list-tile leading icons |

Plumbing follows the existing themeMode/themePreset path:

1. **Drift:** three `BoolColumn`s with `clientDefault(() => false)` on
   `DiverSettings` (`lib/core/database/database.dart`), schema bump to **v135**
   (v134 is claimed by the media-upload-quality branch), `onUpgrade` step adds
   the columns.
2. **Repository:** read/write mapping in
   `lib/features/settings/data/repositories/diver_settings_repository.dart`.
3. **State:** three fields on `AppSettings` + `copyWith`; three setters on
   `SettingsNotifier` persisting via `updateSettingsForDiver`; three narrow
   derived providers (e.g. `accentNavIconsProvider`) alongside
   `themeModeProvider` so surfaces rebuild only when their own toggle changes.
4. **Sync:** export is automatic — `_exportDiverSettings` serializes whole
   rows via the generated `toJson()`, so new columns are included without
   changes. Only `_applyDiverSettingDefaults` needs the three keys with
   `false` defaults so payloads from older devices hydrate. Older devices
   ignore unknown fields.

**Settings UI:** new "Color accents" group on
`lib/features/settings/presentation/pages/appearance_page.dart` (between the
theme controls and the navigation-customization link): three `SwitchListTile`s
with one-line subtitles. New l10n strings added to English plus all 10
non-English locales, then l10n regen.

### 3. Surface application

**Shared consumer widget**
`FeatureAccentIcon(featureId:, icon:, surface: AccentSurface.nav | .header | .list, ...)`:
the `surface` parameter selects which of the three gate providers the widget
watches. It looks up the ThemeExtension via
`Theme.of(context).extension<FeatureAccentColors>()`, and falls back to the
default `IconTheme` color when the toggle is off, the id is unknown, or the
extension is unregistered. The gating rule lives in exactly one place.

**3a. Navigation** (`accentNavIcons`)

- Prerequisite behavior-preserving refactor: the desktop `NavigationRail` in
  `lib/shared/widgets/main_scaffold.dart` (currently 14 hardcoded
  `NavigationRailDestination`s plus two hardcoded index<->route switches) is
  rewritten to iterate `kNavDestinations` (skipping `more`), deriving index
  mapping from list position — matching how the mobile `NavigationBar` already
  works. Accent logic then has a single home.
- When enabled, each destination's icon gets `color: accents.of(id)`:
  - Unselected icons: full accent color.
  - Selected icon: also accent-colored, on the standard Material 3
    `secondaryContainer` indicator pill. If a hue lacks contrast against the
    pill, tune the hue rather than special-casing.
  - More overflow sheet destinations: same treatment, same toggle.
- Labels remain theme-colored everywhere; only icons get accents.

**3b. Section headers** (`accentSectionHeaders`)

Reality check (planning discovery): no feature page currently shows an icon
in its AppBar title — all are text-only. The toggle therefore *adds* the
icon: when ON, a shared `FeatureAppBarTitle(featureId:, title:)` widget
renders the feature's filled nav icon, accent-tinted, before the AppBar
title; when OFF, it renders the plain text title exactly as today. Applied
to the feature pages' AppBars (the shared `*ListContent` app bars for
dives/sites/trips/equipment/buddies/dive-centers/certifications/courses and
the inline AppBars of statistics/planning/transfer/gps-log).

**3c. Settings & list tiles** (`accentListIcons`)

- Feature list tiles: the *existing* leading icon avatars take the owning
  feature's accent when ON (equipment `CircleAvatar` icons -> `equipment`
  accent, trip avatars -> `trips`, dive-center containers -> `dive-centers`).
  Tiles with no leading feature icon today (dives, sites, buddies,
  certifications) are unchanged — the toggle never adds icons to list rows.
- Settings sub-pages (e.g. the Appearance page): monochrome leading icons
  take the owning section's accent (`settings-appearance`) when ON.
- Settings root page: already colored today via hardcoded `Colors.*` on
  `settingsSections`. Those colors migrate into the `FeatureAccentColors`
  palette under `settings-<id>` keys with identical light values (no visual
  change), and the root reads the palette directly — always colored, NOT
  gated by the toggle. The `color` field on `SettingsSection` is removed.

## Error handling

- Unknown id / unregistered extension -> `null` -> theme default. No crash
  paths anywhere in the accent system.
- Migration: columns carry defaults; upgrade and fresh install both land "off".
- Sync version skew: older payloads import as `false`; older devices ignore
  the new fields.
- A preset missing the extension degrades to uncolored icons (and a test
  prevents it).

## Testing (TDD)

- **Unit:**
  - Palette completeness guard: every routable `kNavDestinations` id has an
    entry in both light and dark instances (catches future nav additions).
  - Every theme preset registers `FeatureAccentColors` in both brightnesses.
  - `lerp` / `copyWith` / `of` behavior, including unknown-id null return.
  - `SettingsNotifier` setter persistence round-trip for the three booleans.
  - Sync serializer export/import round-trip for the three new fields,
    including missing-field default behavior.
- **Widget:**
  - `FeatureAccentIcon` matrix: toggle off -> default color; on -> accent;
    unknown id -> default.
  - Nav bar and rail render accents when enabled, defaults when disabled.
- **Rail refactor regression:** destination order, routes, and selected-index
  mapping on wide layout match current behavior exactly (riskiest change —
  rewrites working navigation code).
- Known repo test traps apply: fake-async + Drift deadlocks, settings-notifier
  mock patterns, theme-animation pump patterns.

## Quality gates

- `dart format .` clean.
- `flutter analyze` clean (info-level lints fail CI).
- New l10n strings translated in all 10 non-English locales + regen.
