# Material You dynamic colour and M3 Expressive: where Submersion stands

Date: 2026-10-25. Toolchain at the time: Flutter 3.47.0 stable (framework
revision 4cf2416426, 2026-08-11), `material_color_utilities` 0.13.0 locked
transitively, every Material import in `lib/` from `package:flutter/material.dart`
and none from `package:material_ui`.

## Summary

Submersion is a Material 3 app (`useMaterial3: true`) with five fixed presets
in `lib/core/theme/full_themes/`. One preset is seeded (Submersion, through
`ColorScheme.fromSeed`); the other four are hand-built and fill in missing
roles with `withTintedContainers` and, on PR #3642, `withDerivedNeutrals`.
It has neither of the two newer pieces:

1. **Dynamic colour** (Material You wallpaper colours on Android 12+, the
   accent colour on macOS, Windows and Linux) could be added as a sixth
   "System" preset, as one medium-sized PR. One catch: the current
   `dynamic_color` release (2.x) depends on the new standalone `material_ui`
   package, so today Submersion either pins `dynamic_color` 1.9.0 or migrates
   to `material_ui` first.
2. **M3 Expressive** has barely started in Flutter. The only shipped pieces
   are the `StyleVariant` enum, an opt-in Expressive `IconButton` and the
   shape library. All of them are in `material_ui`, not in the frozen
   `flutter/material` library Submersion imports. Third-party packages
   cover more ground, but they are built on `material_ui` and have single
   maintainers. Not worth adopting yet.

Recommendation: build dynamic colour now if Android users want it, starting
with a test-only step. Leave Expressive until `material_ui` ships it for
the components Submersion leans on, and until the in-SDK Material library
is formally deprecated, since that forces the `material_ui` migration both
features need.

## 1. Dynamic colour

### What `dynamic_color` offers today

| Version | Date | Material import | Notes |
| --- | --- | --- | --- |
| 2.1.0 | 2026-08-20 | `material_ui` ^1.0.0 | Adds XDG Desktop Portal accent colour on Linux |
| 2.0.0 | 2026-08-20 | `material_ui` ^1.0.0 | "Migrated to `material_ui` 1.0.0"; `material_color_utilities` ^0.13.0 |
| 1.9.0 | 2026-08-07 | `flutter/material` | Populates the missing ColorScheme surface roles (dynamic_color #574, #582, #649); AGP 9; Android `minSdk` 24; test utilities split into `dynamic_color_testing` |
| 1.8.1 | 2025-08-01 | `flutter/material` | Last release before the surface-role fix |

Sources: [pub.dev page][dc-pub], [CHANGELOG][dc-changelog],
[1.9.0 dependencies][dc-190].

**Platforms:** Android, macOS, Windows and Linux. No iOS and no web; on those,
and on Android below 12, the builder hands back `null`.

**How the ColorScheme comes back** ([`dynamic_color_builder.dart`][dc-builder]):
`DynamicColorBuilder` is a stateful widget whose `builder` receives
`ColorScheme? lightDynamic` and `ColorScheme? darkDynamic`. It resolves them
asynchronously:

- Android 12+: `DynamicColorPlugin.getCorePalette()` returns the system's
  palette, and an extension turns it into a scheme with
  `corePalette.toColorScheme()` (dark: `brightness: Brightness.dark`).
- Desktop, when no core palette comes back: `DynamicColorPlugin.getAccentColor()`,
  then `ColorScheme.fromSeed(seedColor: accentColor, brightness: ...)` with
  no variant argument, so it uses the default `DynamicSchemeVariant.tonalSpot`
  ([fromSeed docs][fromseed]).
- Both null when neither path works.

It also exports `ColorScheme.harmonized()` and `Color.harmonizeWith(primary)`,
which shift colours toward the dynamic primary.

**The `material_ui` catch.** Flutter froze contributions to the in-SDK
Material and Cupertino libraries in 3.44 and published them as standalone
`material_ui` and `cupertino_ui` packages. The in-SDK libraries are "scheduled
for formal deprecation in an upcoming stable release"; there is no removal
date ([breaking-change guide][mui-guide], [Flutter blog, 2026-09-09][mui-blog]).
`dynamic_color` 2.x builds its `ColorScheme` from `material_ui`, and the
guide is explicit that "values from `package:flutter/material.dart` cannot be
assigned to parameters expecting types from `package:material_ui`".
`MaterialUiCompatibilityBridge` passes theme data across the boundary but
"cannot resolve type mismatches" in public API signatures. So for Submersion
today:

- **Pin `dynamic_color: 1.9.0`.** It imports `flutter/material`, accepts the
  locked `material_color_utilities` 0.13.0 (`>=0.2.0 <=0.13.0`), and its
  Android `minSdk` 24 is below Submersion's 26. Upgrading to 2.x becomes
  part of the `material_ui` migration.
- **Or migrate to `material_ui` first** (`dart fix --apply
  --code=migrate_design_widgets`), then take 2.x. That migration touches
  roughly 1,500 files in `lib/` and every dependency that exposes Material
  types. The deprecation will force it eventually, but it is its own project.

### How a "System" preset fits the registry

The registry builds all five presets once, at initialisation, as static
`ThemeData` finals, and `resolveTheme` just picks light or dark
(`lib/core/theme/app_theme_registry.dart`). A System preset can't work like
that, because its colours exist only at runtime. What it needs:

- **A theme builder, not a theme.** Turn `submersion_theme.dart` into a
  `buildSubmersionTheme(ColorScheme)` function and keep `submersionLight` /
  `submersionDark` as calls to it. The System preset then reuses the
  Submersion preset's component themes (cards, inputs, FAB) with a
  different scheme. Don't get there with
  `submersionLight.copyWith(colorScheme: ...)`: the `ThemeData` factory
  derives colours such as `scaffoldBackgroundColor` and `canvasColor` from
  the scheme, and `copyWith` replaces the field without re-deriving them.
- **Memoise per scheme.** The registry comment warns that `resolveTheme` runs
  on every app rebuild. The System theme should be built once for each
  distinct dynamic scheme and cached.
- **Read the palette before the first frame.** `DynamicColorBuilder` builds
  with `null` first and swaps once the platform call returns, so the app
  would paint Submersion blue for a frame and then change colour. Calling
  `DynamicColorPlugin.getCorePalette()` / `getAccentColor()` in `main()`
  before `runApp`, and passing the result in through a provider, avoids the
  flash. The startup splash (`resolveStartupThemePreset`,
  `lib/core/presentation/startup_theme.dart`) can use the same value.
- **Fall back where there is no palette.** `themePresetId` is a per-diver
  setting and syncs between devices, so a diver who picks System on Android
  will open the app on iOS with `'system'` selected. Register the preset on
  every platform and have it resolve to the Submersion seed when the
  platform gives nothing. The Theme gallery
  (`lib/features/settings/presentation/pages/theme_gallery_page.dart`) can
  hide the card where it would only ever show the fallback.
- **Gallery preview and name.** `ThemePreviewCard` takes a preset, so the
  preview needs the resolved runtime theme. The name needs a new `theme_system`
  ARB key in every locale and a case in `_resolveThemeName`.

### Interaction with the existing colour machinery

- **`withTintedContainers` and `withDerivedNeutrals`:** don't apply them to
  the System scheme. They exist because the plain `ColorScheme` constructor
  fills omitted roles with the accent or the surface. A dynamic scheme
  already has every role: the desktop path goes through `fromSeed`, and 1.9.0
  populates the surface roles on the Android path. Running the helpers would
  replace tonal containers with alpha tints and lose the Material You look.
  They stay helpers for the hand-built presets.
- **`FeatureAccentColors`:** keep the fixed palette. Its curated hues are
  checked against each preset's card; the buddies accent, for example, must
  reach 4.5:1 (`test/core/theme/theme_preset_accents_test.dart`).
  `tonalSpot` neutrals are low-chroma near-whites and near-blacks, so the
  margins should hold, but the System preset can't be enumerated the way
  the tests do today (see below). `harmonizeWith` would make accents pick
  up the wallpaper hue. That is optional polish for later: it would move
  every curated value the tests pin.
- **`StatusColors`:** keep it fixed, and don't harmonise it. Its class
  comment already explains why the alert, warn and OK colours are fixed
  hues instead of scheme roles (a scheme-derived "due soon" turned
  lavender). That logic applies even more strongly to a scheme that follows
  the wallpaper.
- **Contrast tests in `test/core/theme/`:** `theme_container_contrast_test`,
  `status_colors_test`, `theme_preset_accents_test` and (on #3642)
  `theme_neutral_roles_test` all loop over `AppThemeRegistry.presets` and
  read the static themes. A System preset would only add its fallback,
  which is the Submersion theme again, so they would pass without testing
  anything new. Instead, they need a **hue sweep**: build the System theme
  from a set of seeds (say 12 hues 30 degrees apart, in both brightnesses)
  and run the same assertions. That is deterministic if the System preset
  seeds `fromSeed` itself (next point). If it uses the Android core palette
  directly, `dynamic_color_testing`'s `DynamicColorTestingUtils.setMockDynamicColors()`
  can feed sample palettes.

### Open decision: use the platform's scheme or re-seed it

On Android the plugin returns the scheme the system computed, so it matches
system apps exactly. That scheme isn't necessarily the `tonalSpot` variant
`fromSeed` uses by default. The alternative is to take only its `primary`
(or the desktop accent) as a seed and call
`ColorScheme.fromSeed` in Submersion, the same path as the default preset:

| | Platform scheme as-is | Re-seed with `fromSeed` |
| --- | --- | --- |
| Matches system apps | Exactly | Close; tones can shift slightly |
| Contrast tests | Mocked palettes only | Deterministic hue sweep |
| Code path | New (CorePalette conversion) | Same as the Submersion preset |

Re-seeding is easier to guarantee for readability, which is what #3641 and
#3642 were about. Using the platform scheme as-is is more faithful to what
"Material You" means. This is a product call for the maintainer.

## 2. M3 Expressive

### What Flutter has said

The umbrella issue is [flutter/flutter#168813][umbrella] ("Bring Material 3
Expressive to Flutter", opened 2025-05-14, open). Its pinned updates show the
sequence:

- **2025-05-14:** "Currently, we are not actively developing Material 3
  Expressive", and no contributions accepted.
- **2025-06-10:** the same, plus an investigation into moving Material and
  Cupertino out of the framework.
- **2025-07-29:** the libraries are being decoupled, and "All new work for
  Material 3 Expressive will happen in the new packages".
- **2026-09-09:** the decoupling blog post says "work is already underway on
  official implementations of Liquid Glass and Material 3 Expressive"
  ([blog][mui-blog]).
- **2026-10-14:** in [flutter/flutter#194350][roadmap], the team says there
  is no public roadmap, that releases follow merged PRs instead of SDK
  releases, and points to a tracking project ([flutter project 250][proj250])
  and a [component migration checklist][checklist].

A design doc on versioning, [flutter/flutter#187278][versioning], sets the
goal: Material 3, Material 3 Expressive and later versions coexist, and an
app opts in.

### What `material_ui` supports now

From the [`material_ui` changelog][mui-changelog] (latest 1.8.0) and merged
`flutter/packages` PRs:

- **1.2.0:** `StyleVariant` enum with `material3` and `material3Expressive`
  ([#12717][pr12717], merged 2026-09-02). Its API doc says Expressive support
  "is under development" ([StyleVariant][stylevariant]).
- **1.5.0:** Expressive `IconButton`, opted into with
  `IconButtonThemeData(variant: StyleVariant.material3Expressive)`
  ([#12832][pr12832], merged 2026-09-26). Open bug: nested `IconButtonTheme`s
  drop the opt-in ([flutter/flutter#194414][bug194414]). Also in 1.5.0:
  standard, medium and high contrast colour scheme baselines.
- **1.8.0:** the shape library: `RoundedPolygon`, `CornerRounding`,
  `MaterialShapes` and a morphing `MaterialShapeBorder`
  ([#12771][pr12771], merged 2026-10-14).
- **In progress:** Expressive `ElevatedButton` ([#13084][pr13084], open);
  a typography refactor "in preparation for M3E" (flutter/packages#13371, open). Motion
  springs were a WIP PR that was closed (flutter/packages#13137); motion physics, split
  buttons and emphasised typography are open issues ([#184932][i184932],
  [#184948][i184948], [#184933][i184933]).

The checklist sets the rules: opt in component by component, keep Material 3
as the default, and "Do not add a global `ThemeData` expressive variant yet."
None of this is in `package:flutter/material.dart`, which is frozen, so
Submersion would need the `material_ui` migration before it could use any
of it.

### Third-party packages

| Package | Latest | Publisher | Built on | Coverage |
| --- | --- | --- | --- | --- |
| [`material_3_expressive`][p-m3e] | 1.2.0 | unverified uploader | `material_ui` ^1.8.0, Flutter 3.47 | 44 widgets (button groups, split button, FAB menu, toolbar, loading indicator, nav bar and rail, and more); also pulls in `dynamic_color` and `material_new_shapes` |
| [`m3e_core`][p-m3ecore] | 1.1.4 | muditpurohit.tech (verified) | `material_ui` ^1.3.0 since 1.1.0, Flutter 3.47 | Modular: buttons, floating toolbar, loading and progress indicators, shapes, slider, sheets, typography; `^0.1.6` for apps still on `flutter/material` |
| `m3e_collection` | 0.3.7 | | | Re-exports a family of `m3e_*` component packages |

Each has one maintainer and a few thousand downloads, and they replace
widgets instead of theming Flutter's own. Using one would make Submersion's
look depend on a small package while the official implementations land
piece by piece underneath it.

## Recommendation

| | Value | Effort | Verdict |
| --- | --- | --- | --- |
| System (dynamic colour) preset | Medium: Android 12+ users expect it; desktop accent is a smaller win | One medium PR on `dynamic_color` 1.9.0 (builder refactor, pre-`runApp` palette read, preset and gallery card, l10n key, hue-sweep tests) | Worth doing when it gets prioritised |
| `material_ui` migration | None visible by itself; it unblocks `dynamic_color` 2.x and Expressive | Large, mechanical (`dart fix`), with risk around dependencies | Wait for the formal deprecation announcement, then plan it as its own issue |
| M3 Expressive | Low today: one component and a shape library are official | Needs the migration first; third-party packages are a fork of the look | Don't adopt; revisit when Expressive buttons, FAB and navigation ship in `material_ui` |

**Smallest first step (test-only, no new dependency):** refactor
`submersion_theme.dart` into `buildSubmersionTheme(ColorScheme)` (no visual
change), then add a hue-sweep test. It should build that theme from
`ColorScheme.fromSeed` for 12 seed hues in both brightnesses and run the
existing assertions against each one: container contrast, neutral roles
(after #3642), the buddies accent on cards, and the `StatusColors` accents
on surface and `surfaceContainerLow`. If it passes, a System preset can reuse
`FeatureAccentColors` and `StatusColors` unchanged. If it fails, the failing
hues show which fixed colours would need per-scheme handling, before any
dependency or UI work starts.

## Sources

- [dynamic_color on pub.dev][dc-pub]
- [dynamic_color CHANGELOG][dc-changelog]
- [dynamic_color 1.9.0 dependencies][dc-190]
- [dynamic_color_builder.dart source][dc-builder]
- [ColorScheme.fromSeed API docs][fromseed]
- [Breaking change: standalone material_ui and cupertino_ui][mui-guide]
- [Flutter blog: Material and Cupertino decoupling are here (2026-09-09)][mui-blog]
- [material_ui changelog][mui-changelog]
- [material_ui StyleVariant API docs][stylevariant]
- [flutter/flutter#168813: Bring Material 3 Expressive to Flutter][umbrella]
- [flutter/flutter#194350: roadmap question and team replies][roadmap]
- [Flutter GitHub project 250: M3E tracking][proj250]
- [Material 3 Expressive component migration checklist][checklist]
- [flutter/flutter#187278: Material Design version management design doc][versioning]
- [flutter/packages#12717: StyleVariant enum][pr12717]
- [flutter/packages#12832: M3E IconButton][pr12832]
- [flutter/packages#12771: Material shapes][pr12771]
- [flutter/packages#13084: M3E ElevatedButton (open)][pr13084]
- [flutter/flutter#194414: nested IconButtonThemes drop the opt-in][bug194414]
- [flutter/flutter#184932: motion-physics system][i184932]
- [flutter/flutter#184948: split buttons][i184948]
- [flutter/flutter#184933: emphasised typography][i184933]
- [material_3_expressive on pub.dev][p-m3e]
- [m3e_core on pub.dev][p-m3ecore]

[dc-pub]: https://pub.dev/packages/dynamic_color
[dc-changelog]: https://github.com/material-foundation/flutter-packages/blob/main/packages/dynamic_color/CHANGELOG.md
[dc-190]: https://pub.dev/packages/dynamic_color/versions/1.9.0
[dc-builder]: https://github.com/material-foundation/flutter-packages/blob/main/packages/dynamic_color/lib/src/dynamic_color_builder.dart
[fromseed]: https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html
[mui-guide]: https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui
[mui-blog]: https://flutter.dev/blog/decoupling-material-cupertino
[mui-changelog]: https://pub.dev/packages/material_ui/changelog
[stylevariant]: https://pub.dev/documentation/material_ui/latest/material_ui/StyleVariant.html
[umbrella]: https://github.com/flutter/flutter/issues/168813
[roadmap]: https://github.com/flutter/flutter/issues/194350
[proj250]: https://github.com/orgs/flutter/projects/250
[checklist]: https://github.com/flutter/flutter/blob/master/docs/ecosystem/material_ui/Material-3-Expressive-component-migration-checklist.md
[versioning]: https://github.com/flutter/flutter/issues/187278
[pr12717]: https://github.com/flutter/packages/pull/12717
[pr12832]: https://github.com/flutter/packages/pull/12832
[pr12771]: https://github.com/flutter/packages/pull/12771
[pr13084]: https://github.com/flutter/packages/pull/13084
[bug194414]: https://github.com/flutter/flutter/issues/194414
[i184932]: https://github.com/flutter/flutter/issues/184932
[i184948]: https://github.com/flutter/flutter/issues/184948
[i184933]: https://github.com/flutter/flutter/issues/184933
[p-m3e]: https://pub.dev/packages/material_3_expressive
[p-m3ecore]: https://pub.dev/packages/m3e_core
