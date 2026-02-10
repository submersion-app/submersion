# Accessibility & Keyboard Navigation - Implementation Plan

> **Design:** 2026-02-09-accessibility-keyboard-nav-design.md
> **Branch:** feature/accessibility
> **Worktree:** .worktrees/accessibility/
> **Baseline:** 605 tests passing (27 pre-existing loading errors)

---

## Task Overview

| Batch | Focus | Files | Description |
|-------|-------|-------|-------------|
| 1 | Infrastructure | 5 new files | Core accessibility framework (registry, helpers, shortcuts) |
| 2 | Global Integration | 3 files | Wire shortcuts into app, help overlay, platform helper |
| 3 | Shared Widgets | 8 files | Annotate shared scaffolds, layouts, common components |
| 4 | Dashboard & Navigation | 9 files | Dashboard page + widgets, main scaffold navigation |
| 5 | Dive Log (Core) | 22 files | Dive list, detail, edit, search + all dive widgets |
| 6 | Dive Sites & Maps | 13 files | Site pages + map pages + widgets |
| 7 | Equipment & Gear | 8 files | Equipment list, detail, edit, sets |
| 8 | People (Buddies, Divers, Centers) | 15 files | Buddy, diver, dive center pages + widgets |
| 9 | Certifications, Courses, Trips | 16 files | Cert/course/trip pages + widgets |
| 10 | Statistics | 14 files | Statistics hub + all sub-pages + widgets |
| 11 | Tools & Calculators | 10 files | Dive planner, deco calc, gas calcs, tools hub |
| 12 | Transfer, Import, Settings | 20 files | Transfer, universal import, dive import, settings pages |
| 13 | Media, Signatures, Marine Life | 14 files | Photo viewer, signatures, species pages |
| 14 | Remaining Pages & Dialogs | ~10 files | Onboarding, planning, tank presets, dive types, tides |
| 15 | Accessibility Tests | 4 new files | Semantic, keyboard, focus, help overlay tests |

---

## Batch 1: Infrastructure (5 new files)

### Task 1: Create ShortcutRegistry

**File:** `lib/core/accessibility/shortcut_registry.dart`

Create the central shortcut registration service:

```dart
class ShortcutEntry {
  final String label;
  final String category;
  final SingleActivator activator;
  final bool isGlobal;
}

class ShortcutRegistry {
  static final ShortcutRegistry instance = ShortcutRegistry._();
  ShortcutRegistry._();

  final List<ShortcutEntry> _entries = [];

  void register(ShortcutEntry entry);
  void registerAll(List<ShortcutEntry> entries);
  void unregisterCategory(String category);
  List<ShortcutEntry> get entries => List.unmodifiable(_entries);
  Map<String, List<ShortcutEntry>> get byCategory;
}
```

**Verify:** File compiles with `dart analyze lib/core/accessibility/shortcut_registry.dart`

### Task 2: Create AppShortcuts with Global Bindings

**File:** `lib/core/accessibility/app_shortcuts.dart`

Define all global shortcuts and a platform-aware helper:

```dart
SingleActivator platformShortcut(LogicalKeyboardKey key) {
  // Meta on macOS, Control on Windows/Linux
}
```

Global shortcuts table:
- Cmd+N -> new dive
- Cmd+F -> open search
- Cmd+, -> settings
- Cmd+/ -> help overlay
- Cmd+1 through Cmd+5 -> tab switching
- Cmd+W -> go back
- Escape -> close/deselect

Expose a `globalBindings(BuildContext context, WidgetRef ref)` method that returns `Map<ShortcutActivator, VoidCallback>`.

Register all entries in `ShortcutRegistry`.

**Verify:** File compiles

### Task 3: Create Semantic Helpers

**File:** `lib/core/accessibility/semantic_helpers.dart`

Extension methods for common accessibility patterns:

```dart
extension SemanticHelpers on Widget {
  Widget semanticButton({required String label}) =>
    Semantics(button: true, label: label, child: this);

  Widget semanticLabel(String label) =>
    Semantics(label: label, child: this);

  Widget excludeSemantics() =>
    ExcludeSemantics(child: this);
}

// Helper to build chart summary labels
String chartSummaryLabel({
  required String chartType,
  required String description,
});

// Helper to build list item labels
String listItemLabel({
  required String title,
  String? subtitle,
  String? status,
});
```

**Verify:** File compiles

### Task 4: Create Focus Helpers

**File:** `lib/core/accessibility/focus_helpers.dart`

Utilities for focus management:

```dart
// Wrap a page in standard focus traversal
Widget accessiblePage({required Widget child}) =>
  FocusTraversalGroup(
    policy: OrderedTraversalPolicy(),
    child: child,
  );

// Focusable card with visible focus indicator
class FocusableCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String semanticLabel;
  // Shows focus ring when keyboard-focused
}
```

**Verify:** File compiles

### Task 5: Create Shortcuts Help Dialog

**File:** `lib/core/accessibility/shortcuts_help_dialog.dart`

Modal dialog showing all registered shortcuts:

- Read from `ShortcutRegistry.instance`
- Group by category with section headers
- Show platform-appropriate modifier key labels (Cmd on macOS, Ctrl on Win/Linux)
- Dismiss with Escape or close button
- Clean Material 3 styling

**Verify:** File compiles

---

## Batch 2: Global Integration (3 files)

### Task 6: Wire Global Shortcuts into App Router

**File:** `lib/core/router/app_router.dart` (modify)

Wrap the shell route's builder child with `CallbackShortcuts`:

```dart
builder: (context, state, child) {
  return CallbackShortcuts(
    bindings: AppShortcuts.globalBindings(context, ref),
    child: Focus(
      autofocus: true,
      child: existingChild,
    ),
  );
}
```

Add import for `app_shortcuts.dart`.

**Verify:** `flutter analyze` passes. App compiles.

### Task 7: Wire Shortcuts into Main Scaffold

**File:** `lib/shared/widgets/main_scaffold.dart` (modify)

Add Cmd+/ handler to show shortcuts help dialog. Add semantic labels to navigation destinations (NavigationRail and BottomNavigationBar items).

**Verify:** `flutter analyze` passes.

### Task 8: Create Accessibility Barrel Export

**File:** `lib/core/accessibility/accessibility.dart` (new)

Barrel file exporting all accessibility modules:

```dart
export 'shortcut_registry.dart';
export 'app_shortcuts.dart';
export 'semantic_helpers.dart';
export 'focus_helpers.dart';
export 'shortcuts_help_dialog.dart';
```

**Verify:** `flutter test` baseline unchanged (605 passing).

---

## Batch 3: Shared Widgets (8 files)

### Task 9: Annotate Shared Scaffolds

**Files:**
- `lib/shared/widgets/main_scaffold.dart`
- `lib/shared/widgets/master_detail/master_detail_scaffold.dart`
- `lib/shared/widgets/map_list_layout/map_list_scaffold.dart`

For each:
- Add `FocusTraversalGroup` at root
- Add `tooltip` to all `IconButton` widgets
- Add `Semantics` to any `GestureDetector`/`InkWell` taps
- Add semantic labels to navigation items

**Verify:** `flutter analyze` passes.

### Task 10: Annotate Shared Components

**Files:**
- `lib/shared/widgets/sort_bottom_sheet.dart`
- `lib/shared/widgets/master_detail/map_view_toggle_button.dart`
- `lib/shared/widgets/map_list_layout/collapsible_list_pane.dart`
- `lib/shared/widgets/map_list_layout/map_info_card.dart`
- `lib/shared/widgets/master_detail/responsive_breakpoints.dart`

For each:
- Add `tooltip` to `IconButton` widgets
- Add `Semantics` wrappers to tappable areas
- Add `semanticLabel` to informational icons

**Verify:** `flutter analyze` passes.

---

## Batch 4: Dashboard & Navigation (9 files)

### Task 11: Annotate Dashboard Page and Widgets

**Files:**
- `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- `lib/features/dashboard/presentation/widgets/quick_stats_row.dart`
- `lib/features/dashboard/presentation/widgets/quick_actions_card.dart`
- `lib/features/dashboard/presentation/widgets/personal_records_card.dart`
- `lib/features/dashboard/presentation/widgets/alerts_card.dart`
- `lib/features/dashboard/presentation/widgets/stat_summary_card.dart`
- `lib/features/dashboard/presentation/widgets/activity_status_row.dart`
- `lib/features/dashboard/presentation/widgets/recent_dives_card.dart`
- `lib/features/dashboard/presentation/widgets/hero_header.dart`

For each:
- Add `tooltip` to all `IconButton` widgets
- Add `Semantics` to tappable cards/rows
- Add `semanticLabel` to stat values and icons
- Add `excludeSemantics` to decorative elements (hero background, dividers)
- Add dynamic labels to stat cards (e.g., "Total dives: 142")

**Verify:** `flutter analyze` passes.

---

## Batch 5: Dive Log - Core Feature (22 files)

### Task 12: Annotate Dive List Page + Widgets

**Files:**
- `lib/features/dive_log/presentation/pages/dive_list_page.dart`
- `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- `lib/features/dive_log/presentation/widgets/dive_summary_widget.dart`

Add page-specific shortcuts:
- Cmd+E -> export selected
- Cmd+A -> select all
- Delete -> delete selected

Add semantics:
- List items get descriptive labels ("Dive 42: Blue Hole, 32m, 48 min")
- Selection mode buttons get tooltips
- Filter/sort buttons get tooltips

**Verify:** `flutter analyze` passes.

### Task 13: Annotate Dive Detail Page

**Files:**
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart`
- `lib/features/dive_log/presentation/widgets/cylinder_sac_card.dart`
- `lib/features/dive_log/presentation/widgets/deco_info_panel.dart`
- `lib/features/dive_log/presentation/widgets/tissue_saturation_panel.dart`
- `lib/features/dive_log/presentation/widgets/tissue_saturation_chart.dart`

Add page-specific shortcuts:
- E -> edit dive
- Cmd+D -> duplicate dive

Add semantics:
- All action buttons get tooltips
- Chart gets dynamic summary label
- Info cards get descriptive labels
- Tissue saturation chart gets summary

**Verify:** `flutter analyze` passes.

### Task 14: Annotate Dive Profile Chart + Related Widgets

**Files:**
- `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
- `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart`
- `lib/features/dive_log/presentation/widgets/playback_controls.dart`
- `lib/features/dive_log/presentation/widgets/playback_stats_panel.dart`
- `lib/features/dive_log/presentation/widgets/range_stats_panel.dart`
- `lib/features/dive_log/presentation/widgets/range_selection_overlay.dart`
- `lib/features/dive_log/presentation/widgets/profile_selector_widget.dart`

Add semantics:
- Profile chart gets dynamic summary label (max depth, duration, temp range)
- Playback controls get tooltips (play/pause, step forward/back, speed)
- Range selection handles get semantic labels
- Legend items get descriptive labels
- Profile selector gets label for current/available profiles

**Verify:** `flutter analyze` passes.

### Task 15: Annotate Dive Edit + Search Pages

**Files:**
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- `lib/features/dive_log/presentation/pages/dive_search_page.dart`
- `lib/features/dive_log/presentation/widgets/tank_editor.dart`
- `lib/features/dive_log/presentation/widgets/dive_mode_selector.dart`
- `lib/features/dive_log/presentation/widgets/ccr_settings_panel.dart`
- `lib/features/dive_log/presentation/widgets/scr_settings_panel.dart`
- `lib/features/dive_log/presentation/widgets/collapsible_section.dart`
- `lib/features/dive_log/presentation/widgets/dive_map_content.dart`
- `lib/features/dive_log/presentation/widgets/dive_numbering_dialog.dart`
- `lib/features/dive_log/presentation/widgets/gas_colors.dart`

Add page-specific shortcuts:
- Dive Edit: Cmd+S -> save
- Search: Enter -> execute search

Add semantics:
- All form fields already have labels (Flutter default)
- Add tooltips to add/remove tank buttons
- Add labels to dive mode segmented button
- Add labels to collapsible section expand/collapse buttons
- Search filters get descriptive labels

**Verify:** `flutter analyze` passes.

---

## Batch 6: Dive Sites & Maps (13 files)

### Task 16: Annotate Dive Site Pages + Widgets

**Files:**
- `lib/features/dive_sites/presentation/pages/site_list_page.dart`
- `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
- `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- `lib/features/dive_sites/presentation/pages/site_import_page.dart`
- `lib/features/dive_sites/presentation/pages/site_map_page.dart`
- `lib/features/dive_sites/presentation/widgets/site_list_content.dart`
- `lib/features/dive_sites/presentation/widgets/site_summary_widget.dart`
- `lib/features/dive_sites/presentation/widgets/site_map_content.dart`
- `lib/features/dive_sites/presentation/widgets/site_filter_sheet.dart`
- `lib/features/dive_sites/presentation/widgets/location_picker_map.dart`

Add semantics:
- Site list items get labels ("Blue Hole, Belize, 15-40m, Advanced")
- Map markers get semantic labels
- Filter controls get labels
- Location picker map gets description
- Import buttons get tooltips

**Verify:** `flutter analyze` passes.

### Task 17: Annotate Map Pages + Widgets

**Files:**
- `lib/features/maps/presentation/pages/dive_activity_map_page.dart`
- `lib/features/maps/presentation/pages/offline_maps_page.dart`
- `lib/features/maps/presentation/widgets/heat_map_controls.dart`
- `lib/features/maps/presentation/widgets/heat_map_layer.dart`
- `lib/features/maps/presentation/widgets/region_selector.dart`
- `lib/features/maps/presentation/widgets/region_download_dialog.dart`

Add semantics:
- Map gets description ("Dive activity map showing N sites")
- Heat map toggle gets tooltip
- Region selector controls get labels
- Download progress gets live region announcement

**Verify:** `flutter analyze` passes.

---

## Batch 7: Equipment & Gear (8 files)

### Task 18: Annotate Equipment Pages + Widgets

**Files:**
- `lib/features/equipment/presentation/pages/equipment_list_page.dart`
- `lib/features/equipment/presentation/pages/equipment_detail_page.dart`
- `lib/features/equipment/presentation/pages/equipment_edit_page.dart`
- `lib/features/equipment/presentation/pages/equipment_set_list_page.dart`
- `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart`
- `lib/features/equipment/presentation/pages/equipment_set_edit_page.dart`
- `lib/features/equipment/presentation/widgets/equipment_list_content.dart`
- `lib/features/equipment/presentation/widgets/equipment_summary_widget.dart`

Add semantics:
- Equipment list items get labels ("Aqualung BCD, Active, service due in 14 days")
- Service status badges get descriptive labels
- Equipment set items get labels
- All action buttons get tooltips

**Verify:** `flutter analyze` passes.

---

## Batch 8: People - Buddies, Divers, Centers (15 files)

### Task 19: Annotate Buddy Pages + Widgets

**Files:**
- `lib/features/buddies/presentation/pages/buddy_list_page.dart`
- `lib/features/buddies/presentation/pages/buddy_detail_page.dart`
- `lib/features/buddies/presentation/pages/buddy_edit_page.dart`
- `lib/features/buddies/presentation/widgets/buddy_list_content.dart`
- `lib/features/buddies/presentation/widgets/buddy_summary_widget.dart`
- `lib/features/buddies/presentation/widgets/buddy_picker.dart`

Add semantics to list items, action buttons, picker items.

**Verify:** `flutter analyze` passes.

### Task 20: Annotate Diver + Dive Center Pages

**Files:**
- `lib/features/divers/presentation/pages/diver_list_page.dart`
- `lib/features/divers/presentation/pages/diver_detail_page.dart`
- `lib/features/divers/presentation/pages/diver_edit_page.dart`
- `lib/features/divers/presentation/widgets/diver_list_content.dart`
- `lib/features/divers/presentation/widgets/diver_summary_widget.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_list_page.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_edit_page.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_import_page.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_map_page.dart`
- `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`
- `lib/features/dive_centers/presentation/widgets/dive_center_summary_widget.dart`
- `lib/features/dive_centers/presentation/widgets/dive_center_picker.dart`
- `lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart`

Add semantics to list items, action buttons, map markers, import controls.

**Verify:** `flutter analyze` passes.

---

## Batch 9: Certifications, Courses, Trips (16 files)

### Task 21: Annotate Certification Pages + Widgets

**Files:**
- `lib/features/certifications/presentation/pages/certification_list_page.dart`
- `lib/features/certifications/presentation/pages/certification_detail_page.dart`
- `lib/features/certifications/presentation/pages/certification_edit_page.dart`
- `lib/features/certifications/presentation/pages/certification_wallet_page.dart`
- `lib/features/certifications/presentation/widgets/certification_list_content.dart`
- `lib/features/certifications/presentation/widgets/certification_summary_widget.dart`
- `lib/features/certifications/presentation/widgets/certification_wallet_card.dart`
- `lib/features/certifications/presentation/widgets/certification_ecard.dart`
- `lib/features/certifications/presentation/widgets/certification_ecard_stack.dart`
- `lib/features/certifications/presentation/widgets/certification_picker.dart`
- `lib/features/certifications/presentation/widgets/certification_share_sheet.dart`

Add semantics:
- Cert list items: "PADI Open Water, issued 2020, expires 2025"
- Wallet cards get descriptive labels
- eCard images get semantic labels
- Share options get tooltips

**Verify:** `flutter analyze` passes.

### Task 22: Annotate Course + Trip Pages

**Files:**
- `lib/features/courses/presentation/pages/course_list_page.dart`
- `lib/features/courses/presentation/pages/course_detail_page.dart`
- `lib/features/courses/presentation/pages/course_edit_page.dart`
- `lib/features/courses/presentation/widgets/course_list_content.dart`
- `lib/features/courses/presentation/widgets/course_summary_widget.dart`
- `lib/features/courses/presentation/widgets/course_picker.dart`
- `lib/features/courses/presentation/widgets/course_card.dart`
- `lib/features/trips/presentation/pages/trip_list_page.dart`
- `lib/features/trips/presentation/pages/trip_detail_page.dart`
- `lib/features/trips/presentation/pages/trip_edit_page.dart`
- `lib/features/trips/presentation/pages/trip_gallery_page.dart`
- `lib/features/trips/presentation/widgets/trip_list_content.dart`
- `lib/features/trips/presentation/widgets/trip_summary_widget.dart`
- `lib/features/trips/presentation/widgets/trip_picker.dart`
- `lib/features/trips/presentation/widgets/trip_photo_section.dart`

Add semantics to list items, action buttons, pickers, photo sections.

**Verify:** `flutter analyze` passes.

---

## Batch 10: Statistics (14 files)

### Task 23: Annotate Statistics Pages + Widgets

**Files:**
- `lib/features/statistics/presentation/pages/statistics_page.dart`
- `lib/features/statistics/presentation/pages/records_page.dart`
- `lib/features/statistics/presentation/pages/statistics_gas_page.dart`
- `lib/features/statistics/presentation/pages/statistics_profile_page.dart`
- `lib/features/statistics/presentation/pages/statistics_progression_page.dart`
- `lib/features/statistics/presentation/pages/statistics_conditions_page.dart`
- `lib/features/statistics/presentation/pages/statistics_time_patterns_page.dart`
- `lib/features/statistics/presentation/pages/statistics_geographic_page.dart`
- `lib/features/statistics/presentation/pages/statistics_marine_life_page.dart`
- `lib/features/statistics/presentation/widgets/statistics_list_content.dart`
- `lib/features/statistics/presentation/widgets/stat_section_card.dart`
- `lib/features/statistics/presentation/widgets/stat_charts.dart`
- `lib/features/statistics/presentation/widgets/ranking_list.dart`
- `lib/features/statistics/presentation/widgets/statistics_summary_widget.dart`

Add semantics:
- All charts get dynamic summary labels (e.g., "Bar chart: 42 dives in 2025, 38 in 2024")
- Record cards get labels ("Deepest dive: 48m at Blue Hole on Jan 15, 2025")
- Navigation items in stats list get labels
- Stat cards get semantic values

**Verify:** `flutter analyze` passes.

---

## Batch 11: Tools & Calculators (10 files)

### Task 24: Annotate Dive Planner + Calculator Pages

**Files:**
- `lib/features/dive_planner/presentation/pages/dive_planner_page.dart`
- `lib/features/dive_planner/presentation/widgets/segment_editor.dart`
- `lib/features/dive_planner/presentation/widgets/segment_list.dart`
- `lib/features/dive_planner/presentation/widgets/plan_tank_list.dart`
- `lib/features/dive_planner/presentation/widgets/plan_profile_chart.dart`
- `lib/features/dive_planner/presentation/widgets/deco_results_panel.dart`
- `lib/features/dive_planner/presentation/widgets/gas_results_panel.dart`
- `lib/features/dive_planner/presentation/widgets/simple_plan_dialog.dart`
- `lib/features/dive_planner/presentation/widgets/plan_settings_panel.dart`
- `lib/features/deco_calculator/presentation/pages/deco_calculator_page.dart`
- `lib/features/deco_calculator/presentation/widgets/depth_slider.dart`
- `lib/features/deco_calculator/presentation/widgets/time_slider.dart`
- `lib/features/deco_calculator/presentation/widgets/gas_mix_selector.dart`
- `lib/features/deco_calculator/presentation/widgets/gas_warnings_display.dart`

Add semantics:
- Sliders get `semanticLabel` ("Depth: 30 meters")
- Segment editor buttons get tooltips
- Chart gets summary label
- Gas warning display gets live region for screen reader announcements
- All action buttons get tooltips

**Verify:** `flutter analyze` passes.

### Task 25: Annotate Gas Calculators + Tools Hub

**Files:**
- `lib/features/gas_calculators/presentation/pages/gas_calculators_page.dart`
- `lib/features/gas_calculators/presentation/widgets/best_mix_calculator.dart`
- `lib/features/gas_calculators/presentation/widgets/gas_consumption_calculator.dart`
- `lib/features/gas_calculators/presentation/widgets/mod_calculator.dart`
- `lib/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart`
- `lib/features/tools/presentation/pages/tools_page.dart`
- `lib/features/tools/presentation/pages/weight_calculator_page.dart`
- `lib/features/surface_interval_tool/presentation/pages/surface_interval_tool_page.dart`
- `lib/features/surface_interval_tool/presentation/widgets/tissue_recovery_chart.dart`
- `lib/features/surface_interval_tool/presentation/widgets/surface_interval_result.dart`
- `lib/features/surface_interval_tool/presentation/widgets/previous_dive_input.dart`
- `lib/features/surface_interval_tool/presentation/widgets/next_dive_input.dart`

Add semantics:
- Calculator results get semantic labels ("MOD: 33 meters at 1.4 ppO2")
- Input fields already labeled (Flutter default)
- Tool cards on hub page get labels
- Charts get summary labels

**Verify:** `flutter analyze` passes.

---

## Batch 12: Transfer, Import, Settings (20 files)

### Task 26: Annotate Transfer + Universal Import

**Files:**
- `lib/features/transfer/presentation/pages/transfer_page.dart`
- `lib/features/transfer/presentation/widgets/transfer_list_content.dart`
- `lib/features/transfer/presentation/widgets/csv_export_dialog.dart`
- `lib/features/transfer/presentation/widgets/pdf_export_dialog.dart`
- `lib/features/universal_import/presentation/pages/universal_import_page.dart`
- `lib/features/universal_import/presentation/widgets/file_selection_step.dart`
- `lib/features/universal_import/presentation/widgets/source_confirmation_step.dart`
- `lib/features/universal_import/presentation/widgets/field_mapping_step.dart`
- `lib/features/universal_import/presentation/widgets/import_review_step.dart`
- `lib/features/universal_import/presentation/widgets/import_progress_step.dart`
- `lib/features/universal_import/presentation/widgets/import_summary_step.dart`
- `lib/features/universal_import/presentation/widgets/import_entity_card.dart`
- `lib/features/universal_import/presentation/widgets/import_dive_card.dart`
- `lib/features/universal_import/presentation/widgets/batch_tag_field.dart`
- `lib/features/universal_import/presentation/widgets/duplicate_badge.dart`

Add semantics:
- Import wizard steps get semantic labels for progress
- Entity cards get descriptive labels
- Duplicate badges get labels ("Possible duplicate", "Probable duplicate")
- Export dialog options get labels
- Progress indicators get live region announcements

**Verify:** `flutter analyze` passes.

### Task 27: Annotate Dive Import + Settings Pages

**Files:**
- `lib/features/dive_import/presentation/pages/fit_import_page.dart`
- `lib/features/dive_import/presentation/pages/uddf_import_page.dart`
- `lib/features/dive_import/presentation/pages/healthkit_import_page.dart`
- `lib/features/dive_import/presentation/widgets/imported_dive_card.dart`
- `lib/features/dive_import/presentation/widgets/uddf_entity_card.dart`
- `lib/features/settings/presentation/pages/settings_page.dart`
- `lib/features/settings/presentation/pages/appearance_page.dart`
- `lib/features/settings/presentation/pages/storage_settings_page.dart`
- `lib/features/settings/presentation/pages/cloud_sync_page.dart`
- `lib/features/settings/presentation/widgets/settings_list_content.dart`
- `lib/features/settings/presentation/widgets/settings_summary_widget.dart`
- `lib/features/settings/presentation/widgets/import_progress_dialog.dart`
- `lib/features/settings/presentation/widgets/conflict_resolution_dialog.dart`
- `lib/features/settings/presentation/widgets/migration_confirmation_dialog.dart`
- `lib/features/settings/presentation/widgets/migration_progress_dialog.dart`
- `lib/features/settings/presentation/widgets/existing_database_dialog.dart`

Add semantics:
- Settings toggles get descriptive labels
- Cloud sync status gets semantic label
- Import cards get labels
- Dialog actions get tooltips
- Progress dialogs get live region announcements

**Verify:** `flutter analyze` passes.

---

## Batch 13: Media, Signatures, Marine Life (14 files)

### Task 28: Annotate Media + Signature + Marine Life Pages

**Files:**
- `lib/features/media/presentation/pages/photo_viewer_page.dart`
- `lib/features/media/presentation/pages/photo_picker_page.dart`
- `lib/features/media/presentation/pages/trip_photo_viewer_page.dart`
- `lib/features/media/presentation/widgets/dive_media_section.dart`
- `lib/features/media/presentation/widgets/mini_dive_profile_overlay.dart`
- `lib/features/media/presentation/widgets/write_metadata_dialog.dart`
- `lib/features/media/presentation/widgets/scan_results_dialog.dart`
- `lib/features/media/presentation/widgets/photo_gps_suggestion_banner.dart`
- `lib/features/media/presentation/widgets/quick_site_from_gps_dialog.dart`
- `lib/features/signatures/presentation/widgets/signature_capture_widget.dart`
- `lib/features/signatures/presentation/widgets/signature_display_widget.dart`
- `lib/features/signatures/presentation/widgets/buddy_signature_card.dart`
- `lib/features/signatures/presentation/widgets/buddy_signature_request_sheet.dart`
- `lib/features/signatures/presentation/widgets/buddy_signatures_section.dart`
- `lib/features/marine_life/presentation/pages/species_detail_page.dart`
- `lib/features/marine_life/presentation/pages/species_edit_page.dart`
- `lib/features/marine_life/presentation/pages/species_manage_page.dart`
- `lib/features/marine_life/presentation/widgets/species_picker_dialog.dart`
- `lib/features/marine_life/presentation/widgets/site_marine_life_section.dart`

Add semantics:
- Photo viewer controls get tooltips (zoom, swipe hint, metadata toggle)
- Photos get semantic labels ("Photo 3 of 12, dive at Blue Hole")
- Signature canvas gets label ("Draw signature here")
- Signature display gets label ("Instructor signature by John Smith")
- Species list items get labels ("Manta Ray, Mobula birostris, Fish")
- Species picker items get labels

**Verify:** `flutter analyze` passes.

---

## Batch 14: Remaining Pages & Dialogs (~10 files)

### Task 29: Annotate Remaining Pages

**Files:**
- `lib/features/onboarding/presentation/pages/welcome_page.dart`
- `lib/features/planning/presentation/pages/planning_page.dart`
- `lib/features/planning/presentation/widgets/planning_welcome.dart`
- `lib/features/planning/presentation/widgets/planning_shell.dart`
- `lib/features/tank_presets/presentation/pages/tank_presets_page.dart`
- `lib/features/tank_presets/presentation/pages/tank_preset_edit_page.dart`
- `lib/features/dive_types/presentation/pages/dive_types_page.dart`
- `lib/features/dive_computer/presentation/pages/device_list_page.dart`
- `lib/features/dive_computer/presentation/pages/device_detail_page.dart`
- `lib/features/dive_computer/presentation/pages/device_discovery_page.dart`
- `lib/features/dive_computer/presentation/pages/device_download_page.dart`
- `lib/features/dive_computer/presentation/widgets/scan_step_widget.dart`
- `lib/features/dive_computer/presentation/widgets/download_step_widget.dart`
- `lib/features/dive_computer/presentation/widgets/summary_step_widget.dart`
- `lib/features/dive_computer/presentation/widgets/pin_entry_dialog.dart`

Add semantics:
- Welcome page buttons get labels
- Tank preset items get labels
- Dive type items get labels
- Device list items get labels
- BLE scan progress gets live region
- Download progress gets live region

### Task 30: Annotate Tides + Tags Widgets

**Files:**
- `lib/features/tides/presentation/widgets/tide_section.dart`
- `lib/features/tides/presentation/widgets/tide_chart.dart`
- `lib/features/tides/presentation/widgets/tide_cycle_graph.dart`
- `lib/features/tides/presentation/widgets/tide_times_table.dart`
- `lib/features/tides/presentation/widgets/current_tide_indicator.dart`
- `lib/features/tags/presentation/widgets/tag_input_widget.dart`

Add semantics:
- Tide chart gets summary label
- Tide times table cells get labels
- Current tide indicator gets label ("Rising tide, 1.2m")
- Tag input gets semantic label for added tags

**Verify:** `flutter analyze` passes. Run `flutter test` to confirm baseline unchanged.

---

## Batch 15: Accessibility Tests (4 new files)

### Task 31: Write Semantic Label Tests

**File:** `test/accessibility/semantic_labels_test.dart`

Test that key widgets have semantic labels:
- Dashboard stat cards
- Dive list items
- Equipment list items
- IconButtons across shared widgets
- Chart widgets

### Task 32: Write Keyboard Shortcut Tests

**File:** `test/accessibility/keyboard_shortcuts_test.dart`

Test global shortcuts:
- Cmd+/ opens help overlay
- Escape closes help overlay
- ShortcutRegistry contains expected entries

### Task 33: Write Focus Traversal Tests

**File:** `test/accessibility/focus_traversal_test.dart`

Test focus management:
- FocusTraversalGroup exists on pages
- FocusableCard shows focus indicator

### Task 34: Write Shortcuts Help Dialog Tests

**File:** `test/accessibility/shortcuts_help_dialog_test.dart`

Test help overlay:
- Dialog renders all categories
- Shortcuts display correct modifier key per platform
- Dialog dismisses on Escape

**Verify:** All new tests pass. `flutter test` shows increased test count.

---

## Final Verification

After all batches:
1. `flutter analyze` -- zero issues
2. `flutter test` -- all new tests pass, baseline tests unchanged
3. `dart format lib/ test/` -- all code formatted
4. Manual spot-check: run app, verify tooltips appear on hover, Cmd+/ shows overlay

Then use **superpowers:finishing-a-development-branch** to complete.
