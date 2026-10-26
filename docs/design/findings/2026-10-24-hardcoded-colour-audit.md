# Hardcoded grey, white and black colours: Material 3 role audit

Date: 2026-10-24

## Question

Submersion already runs Material 3 (`useMaterial3: true` in all five themes).
What is left is code that paints with fixed `Colors.grey*`, `Colors.white*`
and `Colors.black*` instead of `ColorScheme` roles. Which of those uses are
wrong, and what role should each become?

## Method

- Inventory: every `Colors.grey*|white*|black*` in `lib/` (excluding
  generated files and `PdfColors.*`, which is the PDF package's own palette
  and correct for exports). 319 uses in 106 files.
- Each use was classified against its surrounding code: what sits underneath
  it (photo, video, map tile, fixed gradient, data colour, or a themed
  surface).
  - KEEP: correct as a fixed colour.
  - MAP: should be a `ColorScheme` role.
  - AMBIGUOUS: needs a product decision.
  - BUG: visibly wrong today in dark mode or a non-default theme.
- Every BUG cluster below was spot-checked by reading the code.

## Results

| Class | Count |
| --- | --- |
| KEEP | 259 |
| MAP | 45 |
| AMBIGUOUS | 15 |
| of which BUG (visible today) | 27 |

Most of the hardcoded colours are correct. Media viewers, photo and video
scrims, map markers, the ocean gradient, certification e-cards, the Perdix
overlay and data palettes are deliberately theme-independent. The real
problems cluster into six patterns.

## Prerequisite: four themes leave most M3 roles unset

Console, Deep, Minimalist and Tropical build `ColorScheme(...)` by hand and
set only `primary`, `onPrimary`, `secondary`, `surface`, `onSurface`,
`surfaceContainerLow` and `error` (then `withTintedContainers` adds the
container roles). Flutter's fallbacks for the rest
(`color_scheme.dart` in the SDK) are:

| Role | Falls back to | Effect in those four themes |
| --- | --- | --- |
| `onSurfaceVariant` | `onSurface` | "muted" text renders at full ink |
| `outline`, `outlineVariant` | `onBackground` (= `onSurface`) | hairlines render as full-contrast lines |
| `surfaceContainerLowest`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest` | `surface` | tonal fills are invisible against the page |
| `shadow`, `scrim` | black | fine |

This already affects the 183 existing `surfaceContainer*` uses and every
`outlineVariant` divider in those themes. It also means the mapping below
would only half work there: a grey label moved to `onSurfaceVariant` stops
being muted.

**Proposal:** extend `lib/core/theme/tinted_containers.dart` (or add a sibling
helper applied the same way) to derive the missing roles from `surface` and
`onSurface`:

- `onSurfaceVariant`: `onSurface` at about 70% blended over `surface`.
- `outline`: about 45%. `outlineVariant`: about 20%.
- `surfaceContainer*`: `onSurface` tinted over `surface` at increasing
  steps.

Then add contrast assertions next to `test/core/theme/theme_container_contrast_test.dart`
(`onSurfaceVariant` on every surface container at least 4.5:1; `outline`
at least 3:1). Do this first; the other fixes build on it.

## Bugs, by pattern

### 1. White content on a themed fill that is light in dark mode

In every dark scheme, `primary`, `secondary`, `tertiary` and `error` are
light tones (seeded tone 80; Console dark primary `#4AE0C0`, error `#FFB4AB`).
White on them is about 1.5:1. Fix: use the matching on-role.

| Location | Fill | Fix |
| --- | --- | --- |
| `lib/features/dive_sites/presentation/pages/site_map_page.dart:517` | `primary` when selected | `isSelected ? onPrimary : Colors.white` (the border on the line above already does this) |
| `lib/features/dive_sites/presentation/widgets/site_map_content.dart:519` | same | same |
| `lib/features/dive_log/presentation/widgets/dive_map_content.dart:502` | same | same |
| `lib/features/maps/presentation/pages/dive_activity_map_page.dart:438` | same | same |
| `lib/features/dive_centers/presentation/pages/dive_center_map_page.dart:331` | same | same |
| `lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart:353` | same | same |
| `lib/features/dive_sites/presentation/widgets/match_sites_map.dart:106` | `secondary` when selected | `onSecondary` |
| `lib/core/presentation/widgets/dive_comparison_card.dart:707`, `:714`, `:757` | `tertiary` / `primary` / `error` passed in as `color` | pass the matching on-role alongside the fill |
| `lib/features/import_wizard/presentation/widgets/entity_review_list.dart:1178`, `:1186`, `:1200` | `primary` / `error` when selected | same; the fixed `green700` / `blue700` fills can keep white |
| `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart:125`, `:568` | `error` (critical) or `Colors.orange` (warning) | `onError` for critical; a dark foreground (or `StatusColors`) for the orange warning. Safety text, highest priority. |

### 2. White spinner inside a disabled FilledButton

Each save button sets `onPressed: null` while saving, so the fill becomes
`onSurface` at 12% and the white spinner disappears in light mode. Fix:
drop `color:`, matching the app's 78 other small spinners. An uncoloured
`CircularProgressIndicator` takes `colorScheme.primary` (not the button's
foreground), which reads on the pale disabled fill.

- `lib/features/dive_centers/presentation/pages/dive_center_edit_page.dart:747`
- `lib/features/settings/presentation/pages/cloud_sync_page.dart:389`
- `lib/features/equipment/presentation/pages/equipment_edit_page.dart:837`
- `lib/features/trips/presentation/pages/trip_edit_page.dart:871`

### 3. Grey text and icons on themed surfaces

| Location | Use | Role |
| --- | --- | --- |
| `lib/features/deco_calculator/presentation/widgets/gas_mix_selector.dart:170` | N2 percentage, `Colors.grey` on `surfaceContainerHighest` (about 2:1) | `onSurfaceVariant` |
| `lib/features/tags/presentation/widgets/tag_input_widget.dart:272` | 11px "+N" text, `Colors.grey[600]` | `onSurfaceVariant` |
| `lib/features/tags/presentation/widgets/tag_input_widget.dart:267` | "+N" pill fill, grey at 15% | `surfaceContainerHighest` |
| `lib/features/settings/presentation/pages/storage_settings_page.dart:762` | secondary text | `onSurfaceVariant` |
| `lib/features/settings/presentation/widgets/migration_confirmation_dialog.dart:46` | arrow icon | `onSurfaceVariant` |
| `lib/features/dive_log/presentation/widgets/custom_field_input_row.dart:29` | drag handle | `onSurfaceVariant` |

`dive_profile_chart.dart:2058` was first listed here. On a closer read, its
grey sits beside lime and cyan as one of the ascent-rate category colours,
so it is a data colour and stays.

### 4. Black signature ink on a dark pad

`lib/features/signatures/presentation/widgets/signature_capture_widget.dart:41`
and `lib/features/signatures/presentation/widgets/buddy_signature_request_sheet.dart:329`
draw black strokes on `surfaceContainerHighest`, which is dark in dark mode
(about 1.7:1). The saved PNG uses its own black ink, so exports are fine.
**Decision needed:** treat the pad as paper (fixed white background, black
ink, same as the export) or as a themed surface (`onSurface` ink). Paper is
the smaller change and matches what gets saved.

### 5. White glyphs on pastel accents in the Connections canvas

`lib/features/connections/presentation/canvas/connections_painter.dart:266`,
`:281`: node fills come from `FeatureAccentColors`, which are pastel in dark
mode (about 2:1). The share image always uses the dark palette, so exported
images are affected too. Fix: a luminance pick, reusing
`EquipmentSectionColors.readableOn`.

### 6. Media tiles where white has no backing

- `lib/features/media/presentation/widgets/site_attachment_large_card.dart:126`:
  56px white play icon with no scrim. A video without a poster shows the
  light `surfaceContainerHighest` placeholder, so the icon vanishes. Fix:
  put it on a black 50% circle like `media_viewer_page.dart:1126`.
- `lib/features/media/presentation/widgets/media_library_grid.dart:106`:
  bare white check on a 30% primary tint. Fix: use the primary circle with an
  `onPrimary` check, as `media_grid.dart` already does.

## Non-bug mappings (consistency only)

These look the same today in every theme but should use roles so a future
theme can change them.

- **Shadows to `colorScheme.shadow`** (keep the alpha):
  - `media_map_marker.dart:49`
  - `site_filter_sheet.dart:186`
  - `equipment_filter_sheet.dart:184`
  - `tag_input_widget.dart:174`
  - `photo_marker_overlay.dart:237`
  - `range_selection_overlay.dart:336`
  - `certification_card_photo.dart:63`
  - `certification_ecard_back.dart:37`
- **Modal barriers to `colorScheme.scrim`** (keep the alpha):
  `show_refine_panel.dart:49` and `restore_barrier.dart:98`.
- **White "punch-out" rings on themed charts to `colorScheme.surface`.**
  They glare as white halos in dark mode:
  - `tide_chart.dart:723`
  - `tide_cycle_graph.dart:228`
  - `tank_line_builders.dart:50`
  - `profile_editor_chart.dart:206`
  - `dive_profile_chart.dart:7213`
  - `range_selection_overlay.dart:333`
- **Startup error scaffold** (`startup_page.dart:1902-1904`): uses
  `0xFF121212` / white while its restore card follows `splashTheme`.
  `splashTheme.colorScheme` is already in scope.

## Needs a decision

| Location | Question |
| --- | --- |
| `dive_list_page.dart:710-711`, `compact_dive_list_tile.dart:252-253` | Text is chosen white or black87 by luminance even on plain cards. Use `onSurface` / `onSurfaceVariant` when there is no card colour, keep the pick for attribute colours. The 0.5 threshold is also too high (about 0.18 is the crossover), and `computeLuminance` ignores the alpha of the selection fill. |
| `color_correction_label.dart:67`, `:74` | One widget, two backgrounds: right over a photo, a black blob in the themed colour-adjust panel header. Add a variant that uses `secondaryContainer` in the panel? |
| `dive_3d_interactive_viewport.dart:747`, `:752` | The time plane is white at 10% / 50% but the viewport paints no backdrop, so it vanishes on light themes. `onSurface` alpha, or give the viewport its own dark backdrop? |
| `media_share_helper.dart:95` | White spinner on a black54 barrier. Readable everywhere; switch to the default only for consistency. |

## Correctly fixed (no change)

259 uses, in these groups:

- Full-screen media viewers and their scrims (photos and video are content,
  and M3 media viewers stay dark in every theme).
- Map markers, halos, cluster rings and shadows over map tiles.
- `OceanBackground`, the splash and lock screens, and the dashboard hero.
  These sit on a fixed gradient that is the same in every theme, and the
  splash is themed before it draws.
- Certification e-cards on agency brand gradients.
- The Perdix dive-computer overlay, which imitates real hardware.
- Signature PNG export backgrounds.
- Data palettes: species categories, gas colours, insights pie slices,
  weather and time-of-day buckets, tag colours.
- Luminance-based contrast helpers (`tag_chip_colors.dart`,
  `equipment_section_colors.dart`, `stat_charts.dart`).

## Side findings (not theming)

- **White on pale data colours.** These are theme-independent but deserve a
  luminance pick:
  - pie labels on the light depth palette (`insights_overview_page.dart:952`;
    `stat_charts.dart` already does this right)
  - the "+" on yellow and lime tag colours (`tag_input_widget.dart:217`)
  - the silver medal (`ranking_list.dart:127`)
  - the dark-mode grey species avatar (`seen_species_tile.dart:54`)
- **Four duplicate `_getCategoryColor` helpers** in `marine_life`
  (`species_detail_page`, `species_manage_page`, `site_marine_life_section`,
  `species_picker_dialog`) disagree with the shared `colorForSpeciesCategory`.
  For example, mammal is teal in the duplicates and brown in the shared
  helper.

## Suggested sequencing

1. **Theme roles prerequisite**, plus contrast tests. This changes how every
   existing `surfaceContainer*` and `outlineVariant` use looks in four
   themes, so it needs before-and-after screenshots of each.
2. **Safety and visible bugs** (patterns 1, 2, 3, 6): small, independent
   edits, each with a widget test where practical.
3. **Signature pad and Connections canvas**, after the decision in
   pattern 4.
4. **Consistency mappings** (shadow, scrim, chart rings, startup scaffold).
5. **Optionally, a guard test** in `test/architecture/`. It would ban
   `Colors.grey*` under `presentation/` outside an allowlist, so new grey
   text cannot creep back in. White and black have too many legitimate uses
   over media to ban.
