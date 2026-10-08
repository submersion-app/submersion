# App Theme Presets — Design

## Overview

Add visual theme options to Submersion. Users can choose from pre-built color palette themes (seed color swap) and full visual themes (color + typography + shapes). Theme choice is independent of light/dark mode and persisted per-diver.

## Themes

### Palette Themes (seed color only)

| Name | ID | Seed Color | Description |
|------|----|------------|-------------|
| Submersion | `submersion` | `#0077B6` | Current default, ocean blue |
| Coral Reef | `coral_reef` | `#E07A5F` | Warm terracotta/coral |
| Tropical Lagoon | `tropical_lagoon` | `#00B4A0` | Bright teal/turquoise |
| Kelp Forest | `kelp_forest` | `#2D6A4F` | Earthy green |
| Night Dive | `night_dive` | `#7B2D8B` | Deep purple |

Palette themes use `ColorScheme.fromSeed()` to generate the full Material 3 light/dark palettes. Shared component overrides (card radius, input decoration, FAB shape) are applied on top.

### Full Visual Themes (color + typography + shapes)

| Name | ID | Description |
|------|----|-------------|
| Console | `console` | Monospace font, sharp 4px corners, bordered cards, instrument-like |
| Tropical | `tropical` | Nunito font, 20px rounded cards, bubbly shadows, coral accent |
| Minimalist | `minimalist` | Thin font weights, hairline borders, near-monochrome |
| Deep | `deep` | Translucent cards, gradient FAB, immersive dark atmosphere |

Full visual themes provide hand-crafted `ThemeData` pairs (light + dark).

## Architecture

### Approach: Theme Registry with Seed-Only + Full ThemeData

Palette themes provide only a seed color; Material 3 generates light/dark palettes automatically. Full themes provide complete `ThemeData` objects. A central registry maps preset IDs to definitions, and a `resolveTheme()` function returns the correct `ThemeData` for any preset + brightness combination.

### Data Model

```dart
enum ThemeType { palette, full }

class AppThemePreset {
  final String id;
  final String nameKey;        // l10n key
  final ThemeType type;
  final Color? seedColor;      // palette themes only
  final ThemeData? lightTheme; // full themes only
  final ThemeData? darkTheme;  // full themes only
}
```text
### Theme Resolution

```dart
ThemeData resolveTheme(AppThemePreset preset, Brightness brightness) {
  if (preset.type == ThemeType.full) {
    return brightness == Brightness.light ? preset.lightTheme! : preset.darkTheme!;
  }
  return buildPaletteTheme(preset.seedColor!, brightness);
}
```text
`buildPaletteTheme()` wraps the current `AppTheme.light`/`AppTheme.dark` logic but accepts a dynamic seed color instead of hardcoded `AppColors.primary`.

## Persistence & State Management

### Database

Add one column to `DiverSettings`:

```dart
TextColumn get themePreset => text().withDefault(const Constant('submersion'))();
```text
Theme preset and theme mode remain independent columns/settings.

### Migration

Bump schema version. Add column with default `'submersion'` — no data backfill needed.

### Repository

Parse preset ID with fallback:

```dart
AppThemePreset _parseThemePreset(String id) {
  return appThemePresets.firstWhere(
    (p) => p.id == id,
    orElse: () => appThemePresets.first, // fallback to Submersion
  );
}
```text
### AppSettings

Add `themePreset` field alongside existing `themeMode`:

```dart
class AppSettings {
  final ThemeMode themeMode;        // existing — unchanged
  final AppThemePreset themePreset; // new — defaults to 'submersion'
}
```dart
### Providers

```dart
final themePresetProvider = Provider<AppThemePreset>((ref) {
  return ref.watch(settingsProvider.select((s) => s.themePreset));
});
```text
### MaterialApp Wiring

```dart
final preset = ref.watch(themePresetProvider);
final themeMode = ref.watch(themeModeProvider);

MaterialApp.router(
  theme: resolveTheme(preset, Brightness.light),
  darkTheme: resolveTheme(preset, Brightness.dark),
  themeMode: themeMode,
)
```text
Light/dark mode preference stays independent of theme choice.

### Sync

Add `themePreset` to `sync_data_serializer.dart` — same pattern as `themeMode`, just another string field.

## Theme Gallery UI

New page at route `/settings/themes`.

### Layout

- 2-column grid of preview cards
- Two sections: "Color Palettes" and "Visual Themes"
- Each card shows a mini mockup with theme colors/shapes, theme name below
- Active theme has checkmark/highlighted border
- Tapping a card applies immediately (calls `setThemePreset`)
- Gallery re-renders in the new theme for instant feedback

### Navigation

- Route: `/settings/themes`
- Entry: "Theme" row in Settings page (Appearance section) showing current theme name
- Light/dark/system toggle stays in main Settings page (independent of theme)

### Localization

New keys: `settings_themes_title`, `settings_themes_color_palettes`, `settings_themes_visual_themes`, plus one key per theme name.

## File Organization

```text

lib/core/theme/
  app_theme.dart               MODIFY — extract buildPaletteTheme()
  app_colors.dart              UNCHANGED
  app_theme_preset.dart        NEW — AppThemePreset, ThemeType
  app_theme_registry.dart      NEW — preset list, resolveTheme()
  full_themes/
    console_theme.dart         NEW
    tropical_theme.dart        NEW
    minimalist_theme.dart      NEW
    deep_theme.dart            NEW

lib/features/settings/
  presentation/
    pages/
      theme_gallery_page.dart       NEW
    widgets/
      theme_preview_card.dart       NEW
    providers/
      settings_providers.dart       MODIFY — add themePreset
  data/
    repositories/
      diver_settings_repository.dart  MODIFY — parse/serialize

lib/core/database/
  database.dart                MODIFY — add column + migration

lib/core/router/
  app_router.dart              MODIFY — add route

lib/app.dart                   MODIFY — wire themePresetProvider

l10n/
  app_en.arb                   MODIFY — theme name + gallery keys

```

Semantic colors in `app_colors.dart` (depth, temperature, gas mix, chart colors) stay fixed across all themes.

## Testing

### Unit Tests

- AppThemePreset validation (palette has seedColor, full has ThemeData)
- resolveTheme() returns correct ThemeData for each preset + brightness
- buildPaletteTheme() generates valid ThemeData
- _parseThemePreset() fallback for unknown IDs
- SettingsNotifier.setThemePreset() updates state and persists

### Integration Tests

- Database migration — existing rows get 'submersion' default
- Round-trip persistence — set/reload/verify
- Sync serialization round-trip

### Widget Tests

- ThemeGalleryPage renders all presets in correct sections
- Tapping a card calls setThemePreset
- Active theme shows checkmark
- MaterialApp applies resolved theme when preset changes

## Edge Cases

- Unknown preset ID (future theme removed, or sync from newer version) — falls back to Submersion via `orElse`
- App downgrade — same fallback behavior
- Semantic colors (depth, temperature, gas mix) remain fixed across all themes
