# Appearance Settings Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize Settings > Appearance from a flat 50+ setting page into a clean hub with global settings plus navigation tiles into 8 per-section sub-pages.

**Architecture:** The main `AppearancePage` becomes a lightweight hub (General settings + 8 section navigation tiles). A new `SectionAppearancePage` widget takes a `sectionKey` parameter and renders the appropriate settings for that section. `ColumnConfigPage` gains an `initialSection` parameter so it can be opened pre-scoped to a specific entity. The desktop `_AppearanceSectionContent` in `settings_page.dart` mirrors the same hub/sub-page structure with inline navigation state.

**Tech Stack:** Flutter, Riverpod, go_router, Material 3

---

## File Structure

### Files to Create
| File | Responsibility |
|------|---------------|
| `lib/features/settings/presentation/pages/section_appearance_page.dart` | Parameterized widget that renders appearance settings for a given section (dives, sites, buddies, etc.). Handles both Scaffold-wrapped (mobile route) and embedded (desktop detail pane) modes. |
| `test/features/settings/presentation/pages/section_appearance_page_test.dart` | Tests for all 8 section variants — verifies correct settings render per section key. |

### Files to Modify
| File | Changes |
|------|---------|
| `lib/features/settings/presentation/pages/appearance_page.dart` | Gut current content (~600 lines). Replace with hub layout: General section (Theme, Theme Mode, Language) + Sections list (8 navigation tiles). Keep helper methods `_buildThemeSelector`, `_resolveCurrentThemeName`, `_getThemeModeIcon`, `_getThemeModeName`. Remove everything else. |
| `lib/features/settings/presentation/pages/column_config_page.dart` | Add `initialSection` parameter to constructor. When provided, pre-select that section and hide the section dropdown. |
| `lib/core/router/app_router.dart` | Add 8 new child routes under the existing `appearance` route for each section sub-page. |
| `lib/features/settings/presentation/pages/settings_page.dart` | Rewrite `_AppearanceSectionContent` to show hub by default, with inline navigation state to show section sub-pages and column config within the detail pane. |
| `test/features/settings/presentation/pages/appearance_page_test.dart` | Rewrite tests to verify new hub layout instead of the old flat settings list. |

---

### Task 1: Create SectionAppearancePage Widget

**Files:**
- Create: `lib/features/settings/presentation/pages/section_appearance_page.dart`
- Test: `test/features/settings/presentation/pages/section_appearance_page_test.dart`

This is the core new widget. It renders different settings based on the section key.

- [ ] **Step 1: Write the failing test for the Dives section**

Create the test file with a test that renders the Dives section and verifies its unique settings are present.

```dart
// test/features/settings/presentation/pages/section_appearance_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setDiveListViewMode(ListViewMode mode) async =>
      state = state.copyWith(diveListViewMode: mode);

  @override
  Future<void> setSiteListViewMode(ListViewMode mode) async =>
      state = state.copyWith(siteListViewMode: mode);

  @override
  Future<void> setTripListViewMode(ListViewMode mode) async =>
      state = state.copyWith(tripListViewMode: mode);

  @override
  Future<void> setEquipmentListViewMode(ListViewMode mode) async =>
      state = state.copyWith(equipmentListViewMode: mode);

  @override
  Future<void> setBuddyListViewMode(ListViewMode mode) async =>
      state = state.copyWith(buddyListViewMode: mode);

  @override
  Future<void> setDiveCenterListViewMode(ListViewMode mode) async =>
      state = state.copyWith(diveCenterListViewMode: mode);

  @override
  Future<void> setCardColorAttribute(CardColorAttribute attribute) async =>
      state = state.copyWith(cardColorAttribute: attribute);

  @override
  Future<void> setShowMapBackgroundOnDiveCards(bool value) async =>
      state = state.copyWith(showMapBackgroundOnDiveCards: value);

  @override
  Future<void> setShowMapBackgroundOnSiteCards(bool value) async =>
      state = state.copyWith(showMapBackgroundOnSiteCards: value);

  @override
  Future<void> setShowProfilePanelInTableView(bool value) async =>
      state = state.copyWith(showProfilePanelInTableView: value);

  @override
  Future<void> setShowDataSourceBadges(bool value) async =>
      state = state.copyWith(showDataSourceBadges: value);

  @override
  Future<void> setShowMaxDepthMarker(bool value) async =>
      state = state.copyWith(showMaxDepthMarker: value);

  @override
  Future<void> setShowPressureThresholdMarkers(bool value) async =>
      state = state.copyWith(showPressureThresholdMarkers: value);

  @override
  Future<void> setDefaultShowGasSwitchMarkers(bool value) async =>
      state = state.copyWith(defaultShowGasSwitchMarkers: value);

  @override
  Future<void> setDefaultRightAxisMetric(ProfileRightAxisMetric metric) async =>
      state = state.copyWith(defaultRightAxisMetric: metric);

  @override
  Future<void> setDiveDetailSections(
    List<DiveDetailSectionConfig> sections,
  ) async =>
      state = state.copyWith(diveDetailSections: sections);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestWidget(String sectionKey) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionAppearancePage(sectionKey: sectionKey),
    ),
  );
}

void main() {
  group('SectionAppearancePage - Dives', () {
    testWidgets('shows all dive-specific sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget('dives'));
      await tester.pumpAndSettle();

      // Section headers
      expect(find.text('List View'), findsOneWidget);
      expect(find.text('Cards'), findsOneWidget);
      expect(find.text('Table Mode'), findsOneWidget);
      expect(find.text('Dive Profile'), findsOneWidget);
      expect(find.text('Dive Details'), findsOneWidget);

      // Dive-specific settings
      expect(find.text('Show Profile Panel'), findsOneWidget);
      expect(find.text('Show Data Source Badges'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/pages/section_appearance_page_test.dart`
Expected: FAIL — `section_appearance_page.dart` does not exist.

- [ ] **Step 3: Create the SectionAppearancePage widget**

```dart
// lib/features/settings/presentation/pages/section_appearance_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/gradient_preset_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';

/// Metadata for each app section's appearance settings.
class _SectionConfig {
  final String key;
  final String displayName;
  final List<ListViewMode> viewModes;
  final String listFieldsLabel;
  final bool hasCards;
  final bool hasMapBackground;
  final bool hasDiveProfile;
  final bool hasDiveDetails;
  final bool hasProfilePanel;
  final bool hasDataSourceBadges;

  const _SectionConfig({
    required this.key,
    required this.displayName,
    required this.viewModes,
    required this.listFieldsLabel,
    this.hasCards = false,
    this.hasMapBackground = false,
    this.hasDiveProfile = false,
    this.hasDiveDetails = false,
    this.hasProfilePanel = false,
    this.hasDataSourceBadges = false,
  });
}

const _sectionConfigs = {
  'dives': _SectionConfig(
    key: 'dives',
    displayName: 'Dives',
    viewModes: ListViewMode.values,
    listFieldsLabel: 'Dive List Fields',
    hasCards: true,
    hasMapBackground: true,
    hasDiveProfile: true,
    hasDiveDetails: true,
    hasProfilePanel: true,
    hasDataSourceBadges: true,
  ),
  'sites': _SectionConfig(
    key: 'sites',
    displayName: 'Dive Sites',
    viewModes: ListViewMode.values,
    listFieldsLabel: 'Site List Fields',
    hasMapBackground: true,
  ),
  'buddies': _SectionConfig(
    key: 'buddies',
    displayName: 'Buddies',
    viewModes: [ListViewMode.detailed, ListViewMode.dense],
    listFieldsLabel: 'Buddy List Fields',
  ),
  'trips': _SectionConfig(
    key: 'trips',
    displayName: 'Trips',
    viewModes: ListViewMode.values,
    listFieldsLabel: 'Trip List Fields',
  ),
  'equipment': _SectionConfig(
    key: 'equipment',
    displayName: 'Equipment',
    viewModes: [ListViewMode.detailed, ListViewMode.dense],
    listFieldsLabel: 'Equipment List Fields',
  ),
  'diveCenters': _SectionConfig(
    key: 'diveCenters',
    displayName: 'Dive Centers',
    viewModes: ListViewMode.values,
    listFieldsLabel: 'Dive Center List Fields',
  ),
  'certifications': _SectionConfig(
    key: 'certifications',
    displayName: 'Certifications',
    viewModes: [ListViewMode.detailed, ListViewMode.table],
    listFieldsLabel: 'Certification List Fields',
  ),
  'courses': _SectionConfig(
    key: 'courses',
    displayName: 'Courses',
    viewModes: [ListViewMode.detailed, ListViewMode.table],
    listFieldsLabel: 'Course List Fields',
  ),
};

class SectionAppearancePage extends ConsumerWidget {
  final String sectionKey;

  /// When true, omits the Scaffold/AppBar for embedding in a detail pane.
  final bool embedded;

  /// Optional callback for navigating to column config in embedded mode.
  final VoidCallback? onColumnConfigTap;

  const SectionAppearancePage({
    super.key,
    required this.sectionKey,
    this.embedded = false,
    this.onColumnConfigTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = _sectionConfigs[sectionKey];
    if (config == null) {
      return const Center(child: Text('Unknown section'));
    }

    final settings = ref.watch(settingsProvider);
    final body = ListView(
      children: [
        _buildSectionHeader(context, 'List View'),
        _buildViewModeDropdown(context, ref, settings, config),
        _buildListFieldsTile(context, config),
        if (config.hasCards) ...[
          const Divider(),
          _buildSectionHeader(context, 'Cards'),
          ..._buildCardSettings(context, ref, settings),
        ],
        if (config.hasMapBackground && !config.hasCards) ...[
          const Divider(),
          _buildSectionHeader(context, 'Cards'),
          _buildMapBackgroundToggle(context, ref, settings, isSites: true),
        ],
        const Divider(),
        _buildSectionHeader(context, 'Table Mode'),
        _buildDetailsPaneToggle(context, ref, config.key),
        if (config.hasProfilePanel)
          _buildProfilePanelToggle(context, ref, settings),
        if (config.hasDataSourceBadges)
          _buildDataSourceBadgesToggle(context, ref, settings),
        if (config.hasDiveProfile) ...[
          const Divider(),
          _buildSectionHeader(context, 'Dive Profile'),
          ..._buildDiveProfileSettings(context, ref, settings),
        ],
        if (config.hasDiveDetails) ...[
          const Divider(),
          _buildSectionHeader(context, 'Dive Details'),
          _buildDiveDetailsTile(context),
        ],
        const SizedBox(height: 32),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(title: Text(config.displayName)),
      body: body,
    );
  }

  // ---------------------------------------------------------------------------
  // Section header
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // List View section
  // ---------------------------------------------------------------------------

  Widget _buildViewModeDropdown(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    _SectionConfig config,
  ) {
    final currentMode = _getCurrentViewMode(settings, ref, config.key);
    return ListTile(
      leading: const Icon(Icons.view_list),
      title: const Text('View Mode'),
      trailing: DropdownButton<ListViewMode>(
        value: currentMode,
        underline: const SizedBox(),
        onChanged: (value) {
          if (value != null) {
            _setViewMode(ref, config.key, value);
          }
        },
        items: config.viewModes.map((mode) {
          return DropdownMenuItem(
            value: mode,
            child: Text(_viewModeDisplayName(mode)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListFieldsTile(BuildContext context, _SectionConfig config) {
    return ListTile(
      leading: const Icon(Icons.view_column),
      title: Text(config.listFieldsLabel),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (onColumnConfigTap != null) {
          onColumnConfigTap!();
        } else {
          context.push(
            '/settings/appearance/column-config?section=${config.key}',
          );
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Cards section (Dives only)
  // ---------------------------------------------------------------------------

  List<Widget> _buildCardSettings(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return [
      ListTile(
        leading: const Icon(Icons.palette),
        title: Text(context.l10n.settings_appearance_cardColorAttribute),
        trailing: DropdownButton<CardColorAttribute>(
          value: settings.cardColorAttribute,
          underline: const SizedBox(),
          onChanged: (value) {
            if (value != null) {
              ref.read(settingsProvider.notifier).setCardColorAttribute(value);
            }
          },
          items: CardColorAttribute.values.map((attr) {
            return DropdownMenuItem(
              value: attr,
              child: Text(_attributeDisplayName(context, attr)),
            );
          }).toList(),
        ),
      ),
      if (settings.cardColorAttribute != CardColorAttribute.none)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GradientPresetPicker(
            selectedPreset: settings.cardColorGradientPreset,
            customStart: settings.cardColorGradientStart,
            customEnd: settings.cardColorGradientEnd,
            onPresetSelected: (preset) {
              ref
                  .read(settingsProvider.notifier)
                  .setCardColorGradientPreset(preset);
            },
            onCustomSelected: (start, end) {
              ref
                  .read(settingsProvider.notifier)
                  .setCardColorGradientCustom(start, end);
            },
          ),
        ),
      _buildMapBackgroundToggle(context, ref, settings, isSites: false),
    ];
  }

  Widget _buildMapBackgroundToggle(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings, {
    required bool isSites,
  }) {
    if (isSites) {
      return SwitchListTile(
        title: Text(context.l10n.settings_appearance_mapBackgroundSiteCards),
        subtitle: Text(
          context
              .l10n
              .settings_appearance_mapBackgroundSiteCards_subtitleWithNote,
        ),
        secondary: const Icon(Icons.map),
        value: settings.showMapBackgroundOnSiteCards,
        onChanged: (value) {
          ref
              .read(settingsProvider.notifier)
              .setShowMapBackgroundOnSiteCards(value);
        },
      );
    }
    return SwitchListTile(
      title: Text(context.l10n.settings_appearance_mapBackgroundDiveCards),
      subtitle: Text(
        context
            .l10n
            .settings_appearance_mapBackgroundDiveCards_subtitleWithNote,
      ),
      secondary: const Icon(Icons.map),
      value: settings.showMapBackgroundOnDiveCards,
      onChanged: (value) {
        ref
            .read(settingsProvider.notifier)
            .setShowMapBackgroundOnDiveCards(value);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Table Mode section
  // ---------------------------------------------------------------------------

  Widget _buildDetailsPaneToggle(
    BuildContext context,
    WidgetRef ref,
    String key,
  ) {
    return SwitchListTile(
      title: const Text('Show Details Pane'),
      secondary: const Icon(Icons.vertical_split),
      value: ref.watch(tableDetailsPaneProvider(key)),
      onChanged: (value) {
        ref.read(tableDetailsPaneProvider(key).notifier).state = value;
      },
    );
  }

  Widget _buildProfilePanelToggle(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return SwitchListTile(
      title: const Text('Show Profile Panel'),
      subtitle: const Text(
        'Display dive profile chart above the table by default',
      ),
      secondary: const Icon(Icons.area_chart),
      value: settings.showProfilePanelInTableView,
      onChanged: (value) {
        ref
            .read(settingsProvider.notifier)
            .setShowProfilePanelInTableView(value);
      },
    );
  }

  Widget _buildDataSourceBadgesToggle(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return SwitchListTile(
      title: const Text('Show Data Source Badges'),
      subtitle: const Text('Display source attribution on dive metrics'),
      secondary: const Icon(Icons.label_outline),
      value: settings.showDataSourceBadges,
      onChanged: (value) {
        ref.read(settingsProvider.notifier).setShowDataSourceBadges(value);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Dive Profile section
  // ---------------------------------------------------------------------------

  List<Widget> _buildDiveProfileSettings(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return [
      ListTile(
        leading: const Icon(Icons.show_chart),
        title: Text(context.l10n.settings_appearance_rightYAxisMetric),
        subtitle: Text(
          context.l10n.settings_appearance_rightYAxisMetric_subtitle,
        ),
        trailing: DropdownButton<ProfileRightAxisMetric>(
          value: settings.defaultRightAxisMetric,
          underline: const SizedBox(),
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultRightAxisMetric(value);
            }
          },
          items: ProfileRightAxisMetric.values.map((metric) {
            return DropdownMenuItem(
              value: metric,
              child: Text(metric.displayName),
            );
          }).toList(),
        ),
      ),
      SwitchListTile(
        title: Text(context.l10n.settings_appearance_maxDepthMarker),
        subtitle: Text(
          context.l10n.settings_appearance_maxDepthMarker_subtitleFull,
        ),
        secondary: const Icon(Icons.vertical_align_bottom),
        value: settings.showMaxDepthMarker,
        onChanged: (value) {
          ref.read(settingsProvider.notifier).setShowMaxDepthMarker(value);
        },
      ),
      SwitchListTile(
        title: Text(
          context.l10n.settings_appearance_pressureThresholdMarkers,
        ),
        subtitle: Text(
          context
              .l10n
              .settings_appearance_pressureThresholdMarkers_subtitleFull,
        ),
        secondary: Icon(MdiIcons.divingScubaTank),
        value: settings.showPressureThresholdMarkers,
        onChanged: (value) {
          ref
              .read(settingsProvider.notifier)
              .setShowPressureThresholdMarkers(value);
        },
      ),
      SwitchListTile(
        title: Text(context.l10n.settings_appearance_gasSwitchMarkers),
        subtitle: Text(
          context.l10n.settings_appearance_gasSwitchMarkers_subtitle,
        ),
        secondary: const Icon(Icons.swap_horiz),
        value: settings.defaultShowGasSwitchMarkers,
        onChanged: (value) {
          ref
              .read(settingsProvider.notifier)
              .setDefaultShowGasSwitchMarkers(value);
        },
      ),
      ListTile(
        leading: const Icon(Icons.visibility),
        title: Text(
          context.l10n.settings_appearance_subsection_defaultVisibleMetrics,
        ),
        subtitle: Text(
          context.l10n.settings_appearance_metricsEnabledCount(
            _countEnabledMetrics(settings),
            18,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(context).push('/settings/default-metrics'),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Dive Details section
  // ---------------------------------------------------------------------------

  Widget _buildDiveDetailsTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.reorder),
      title: Text(
        context
            .l10n
            .settings_appearance_diveDetails_sectionOrderVisibility,
      ),
      subtitle: Text(
        context
            .l10n
            .settings_appearance_diveDetails_sectionOrderVisibility_subtitle,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/settings/dive-detail-sections'),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ListViewMode _getCurrentViewMode(
    AppSettings settings,
    WidgetRef ref,
    String key,
  ) {
    return switch (key) {
      'dives' => settings.diveListViewMode,
      'sites' => settings.siteListViewMode,
      'trips' => settings.tripListViewMode,
      'equipment' => settings.equipmentListViewMode,
      'buddies' => settings.buddyListViewMode,
      'diveCenters' => settings.diveCenterListViewMode,
      // Certifications & Courses are runtime-only (not persisted in AppSettings)
      'certifications' => ref.watch(certificationListViewModeProvider),
      'courses' => ref.watch(courseListViewModeProvider),
      _ => ListViewMode.detailed,
    };
  }

  void _setViewMode(WidgetRef ref, String key, ListViewMode mode) {
    final notifier = ref.read(settingsProvider.notifier);
    switch (key) {
      case 'dives':
        notifier.setDiveListViewMode(mode);
        ref.read(diveListViewModeProvider.notifier).state = mode;
      case 'sites':
        notifier.setSiteListViewMode(mode);
        ref.read(siteListViewModeProvider.notifier).state = mode;
      case 'trips':
        notifier.setTripListViewMode(mode);
        ref.read(tripListViewModeProvider.notifier).state = mode;
      case 'equipment':
        notifier.setEquipmentListViewMode(mode);
        ref.read(equipmentListViewModeProvider.notifier).state = mode;
      case 'buddies':
        notifier.setBuddyListViewMode(mode);
        ref.read(buddyListViewModeProvider.notifier).state = mode;
      case 'diveCenters':
        notifier.setDiveCenterListViewMode(mode);
        ref.read(diveCenterListViewModeProvider.notifier).state = mode;
      // Certifications & Courses: runtime-only, no persistence
      case 'certifications':
        ref.read(certificationListViewModeProvider.notifier).state = mode;
      case 'courses':
        ref.read(courseListViewModeProvider.notifier).state = mode;
    }
  }

  String _viewModeDisplayName(ListViewMode mode) {
    return switch (mode) {
      ListViewMode.detailed => 'Detailed',
      ListViewMode.compact => 'Compact',
      ListViewMode.dense => 'Dense',
      ListViewMode.table => 'Table',
    };
  }

  String _attributeDisplayName(
    BuildContext context,
    CardColorAttribute attr,
  ) {
    return switch (attr) {
      CardColorAttribute.none =>
        context.l10n.settings_appearance_cardColorAttribute_none,
      CardColorAttribute.depth =>
        context.l10n.settings_appearance_cardColorAttribute_depth,
      CardColorAttribute.duration =>
        context.l10n.settings_appearance_cardColorAttribute_duration,
      CardColorAttribute.temperature =>
        context.l10n.settings_appearance_cardColorAttribute_temperature,
    };
  }

  int _countEnabledMetrics(AppSettings settings) {
    final values = [
      settings.defaultShowTemperature,
      settings.defaultShowPressure,
      settings.defaultShowHeartRate,
      settings.defaultShowSac,
      settings.defaultShowEvents,
      settings.showCeilingOnProfile,
      settings.showAscentRateColors,
      settings.showNdlOnProfile,
      settings.defaultShowTts,
      settings.defaultShowCns,
      settings.defaultShowOtu,
      settings.defaultShowPpO2,
      settings.defaultShowPpN2,
      settings.defaultShowPpHe,
      settings.defaultShowGasDensity,
      settings.defaultShowGf,
      settings.defaultShowSurfaceGf,
      settings.defaultShowMeanDepth,
    ];
    return values.where((v) => v).length;
  }
}
```

**Important implementation notes:**
- The `_setViewMode` method updates both the persisted setting AND the runtime provider (matching the existing pattern in `appearance_page.dart`).
- **Certifications and Courses are NOT persisted:** Their view mode providers (`certificationListViewModeProvider` at `lib/features/certifications/presentation/providers/certification_providers.dart:232` and `courseListViewModeProvider` at `lib/features/courses/presentation/providers/course_providers.dart:294`) are runtime-only `StateProvider<ListViewMode>` that default to `ListViewMode.detailed` — they do NOT read from `AppSettings`. There are no `settings.certificationListViewMode` / `settings.courseListViewMode` fields, and no `setCertificationListViewMode` / `setCourseListViewMode` methods on `SettingsNotifier`. For the `_getCurrentViewMode` method, read from the runtime provider via `ref` instead of `settings` for these two sections. For `_setViewMode`, only update the runtime provider (no persistence call). To do this, `SectionAppearancePage` needs access to `WidgetRef` in these helpers — which it already has since it's a `ConsumerWidget`. Update `_getCurrentViewMode` to accept `WidgetRef ref` and use `ref.watch(certificationListViewModeProvider)` / `ref.watch(courseListViewModeProvider)` for those two keys. Update `_setViewMode` to skip the notifier call for certifications/courses.
- The `onColumnConfigTap` callback enables the desktop embedded mode to intercept navigation and show column config inline (used in Task 5).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/pages/section_appearance_page_test.dart`
Expected: PASS

- [ ] **Step 5: Add tests for remaining sections**

Add tests for Sites (has map background), a simple section (Buddies), and Certifications (limited view modes):

```dart
// Add to the same test file after the Dives group:

group('SectionAppearancePage - Sites', () {
  testWidgets('shows site-specific sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildTestWidget('sites'));
    await tester.pumpAndSettle();

    expect(find.text('List View'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Table Mode'), findsOneWidget);
    expect(find.text('Site List Fields'), findsOneWidget);
    expect(find.text('Show Details Pane'), findsOneWidget);

    // Should NOT have dive-specific sections
    expect(find.text('Dive Profile'), findsNothing);
    expect(find.text('Dive Details'), findsNothing);
    expect(find.text('Show Profile Panel'), findsNothing);
  });
});

group('SectionAppearancePage - Buddies', () {
  testWidgets('shows minimal sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildTestWidget('buddies'));
    await tester.pumpAndSettle();

    expect(find.text('List View'), findsOneWidget);
    expect(find.text('Table Mode'), findsOneWidget);
    expect(find.text('Buddy List Fields'), findsOneWidget);
    expect(find.text('Show Details Pane'), findsOneWidget);

    // No Cards section for buddies
    expect(find.text('Cards'), findsNothing);
    expect(find.text('Dive Profile'), findsNothing);
  });
});

group('SectionAppearancePage - Certifications', () {
  testWidgets('shows correct view modes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildTestWidget('certifications'));
    await tester.pumpAndSettle();

    expect(find.text('List View'), findsOneWidget);
    expect(find.text('Certification List Fields'), findsOneWidget);
    expect(find.text('View Mode'), findsOneWidget);
  });
});

group('SectionAppearancePage - embedded mode', () {
  testWidgets('omits Scaffold when embedded', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SectionAppearancePage(
              sectionKey: 'buddies',
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should render content without its own AppBar
    expect(find.text('Buddies'), findsNothing); // No AppBar title
    expect(find.text('List View'), findsOneWidget); // Content present
  });
});
```

- [ ] **Step 6: Run all section tests**

Run: `flutter test test/features/settings/presentation/pages/section_appearance_page_test.dart`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add lib/features/settings/presentation/pages/section_appearance_page.dart test/features/settings/presentation/pages/section_appearance_page_test.dart
git commit -m "feat: add SectionAppearancePage for per-section appearance settings"
```

---

### Task 2: Update ColumnConfigPage to Accept Initial Section Parameter

**Files:**
- Modify: `lib/features/settings/presentation/pages/column_config_page.dart:45-100`

- [ ] **Step 1: Add initialSection parameter to ColumnConfigPage**

In `lib/features/settings/presentation/pages/column_config_page.dart`, modify the constructor and state:

```dart
// Change the constructor (around line 45-49):
class ColumnConfigPage extends ConsumerStatefulWidget {
  /// When true, hides the Scaffold/AppBar for embedding in a detail pane.
  final bool embedded;

  /// When provided, pre-selects this section and hides the section dropdown.
  final String? initialSection;

  const ColumnConfigPage({
    super.key,
    this.embedded = false,
    this.initialSection,
  });

  @override
  ConsumerState<ColumnConfigPage> createState() => _ColumnConfigPageState();
}
```

```dart
// Change the state class init (around line 55-57):
class _ColumnConfigPageState extends ConsumerState<ColumnConfigPage> {
  late String _selectedSection = widget.initialSection ?? 'dives';
  ListViewMode _selectedMode = ListViewMode.table;
```

```dart
// In the build method (around line 72-101), wrap the section selector in a
// visibility check:
        // Section selector — hidden when pre-scoped to a specific section
        if (widget.initialSection == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              // ... existing section dropdown code unchanged ...
            ),
          ),
```

- [ ] **Step 2: Update the router to pass query params**

In `lib/core/router/app_router.dart`, update the column-config route (around line 740-744):

```dart
GoRoute(
  path: 'column-config',
  name: 'columnConfig',
  builder: (context, state) => ColumnConfigPage(
    initialSection: state.uri.queryParameters['section'],
  ),
),
```

- [ ] **Step 3: Run existing column config tests**

Run: `flutter test test/features/settings/presentation/pages/column_config_page_test.dart`
Expected: PASS (existing tests should still work since `initialSection` defaults to null)

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/presentation/pages/column_config_page.dart lib/core/router/app_router.dart
git commit -m "feat: add initialSection param to ColumnConfigPage for section-scoped field config"
```

---

### Task 3: Rewrite AppearancePage as Hub

**Files:**
- Modify: `lib/features/settings/presentation/pages/appearance_page.dart`
- Modify: `test/features/settings/presentation/pages/appearance_page_test.dart`

- [ ] **Step 1: Write tests for the new hub layout**

Replace the contents of `test/features/settings/presentation/pages/appearance_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestWidget() {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppearancePage(),
    ),
  );
}

void main() {
  group('AppearancePage hub layout', () {
    testWidgets('shows General section header', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('shows Theme tile', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    });

    testWidgets('shows Theme Mode selector', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Theme mode options
      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('shows Language tile', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('shows Sections header', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sections'), findsOneWidget);
    });

    testWidgets('shows all 8 section navigation tiles', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      for (final name in [
        'Dives',
        'Dive Sites',
        'Buddies',
        'Trips',
        'Equipment',
        'Dive Centers',
        'Certifications',
        'Courses',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('does NOT show old inline settings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Old settings that should no longer appear on the hub
      expect(find.text('Dive List View'), findsNothing);
      expect(find.text('Show Profile Panel in Table View'), findsNothing);
      expect(find.text('Show details pane in table mode'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/pages/appearance_page_test.dart`
Expected: FAIL — tests expect the new hub layout but the old flat layout still exists.

- [ ] **Step 3: Rewrite AppearancePage as hub**

Replace the contents of `lib/features/settings/presentation/pages/appearance_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_section_appearance_title),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'General'),
          // Theme
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.l10n.settings_themes_current),
            subtitle: Text(_resolveCurrentThemeName(context, ref)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/themes'),
          ),
          // Theme Mode
          _buildThemeSelector(context, ref, settings.themeMode),
          // Language
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.l10n.settings_appearance_appLanguage),
            subtitle: Text(
              LanguageSettingsPage.getDisplayName(settings.locale),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/language'),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Sections'),
          for (final entry in _sectionEntries)
            ListTile(
              title: Text(entry.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/settings/appearance/${entry.routeSegment}',
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    return Column(
      children: ThemeMode.values.map((mode) {
        final isSelected = mode == currentMode;
        return Semantics(
          selected: isSelected,
          child: ListTile(
            leading: Icon(_getThemeModeIcon(mode)),
            title: Text(_getThemeModeName(context, mode)),
            trailing: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                    semanticLabel: context.l10n.settings_language_selected,
                  )
                : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode(mode);
            },
          ),
        );
      }).toList(),
    );
  }

  String _getThemeModeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return context.l10n.settings_appearance_theme_system;
      case ThemeMode.light:
        return context.l10n.settings_appearance_theme_light;
      case ThemeMode.dark:
        return context.l10n.settings_appearance_theme_dark;
    }
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  String _resolveCurrentThemeName(BuildContext context, WidgetRef ref) {
    final presetId = ref.watch(settingsProvider.select((s) => s.themePresetId));
    final preset = AppThemeRegistry.findById(presetId);
    final l10n = context.l10n;
    switch (preset.nameKey) {
      case 'theme_submersion':
        return l10n.theme_submersion;
      case 'theme_console':
        return l10n.theme_console;
      case 'theme_tropical':
        return l10n.theme_tropical;
      case 'theme_minimalist':
        return l10n.theme_minimalist;
      case 'theme_deep':
        return l10n.theme_deep;
      default:
        return preset.nameKey;
    }
  }
}

/// Metadata for each section's navigation tile in the hub.
class _SectionEntry {
  final String displayName;
  final String routeSegment;
  const _SectionEntry(this.displayName, this.routeSegment);
}

const _sectionEntries = [
  _SectionEntry('Dives', 'dives'),
  _SectionEntry('Dive Sites', 'sites'),
  _SectionEntry('Buddies', 'buddies'),
  _SectionEntry('Trips', 'trips'),
  _SectionEntry('Equipment', 'equipment'),
  _SectionEntry('Dive Centers', 'dive-centers'),
  _SectionEntry('Certifications', 'certifications'),
  _SectionEntry('Courses', 'courses'),
];
```

- [ ] **Step 4: Run hub tests**

Run: `flutter test test/features/settings/presentation/pages/appearance_page_test.dart`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/appearance_page.dart test/features/settings/presentation/pages/appearance_page_test.dart
git commit -m "refactor: rewrite AppearancePage as hub with section navigation tiles"
```

---

### Task 4: Add Section Routes to Router

**Files:**
- Modify: `lib/core/router/app_router.dart:735-745`

- [ ] **Step 1: Add 8 section routes under the appearance route**

In `lib/core/router/app_router.dart`, expand the `appearance` route's `routes` list (around line 739). Add the section sub-page routes alongside the existing `column-config` route:

```dart
GoRoute(
  path: 'appearance',
  name: 'appearance',
  builder: (context, state) => const AppearancePage(),
  routes: [
    GoRoute(
      path: 'column-config',
      name: 'columnConfig',
      builder: (context, state) => ColumnConfigPage(
        initialSection: state.uri.queryParameters['section'],
      ),
    ),
    GoRoute(
      path: 'dives',
      name: 'appearanceDives',
      builder: (context, state) =>
          const SectionAppearancePage(sectionKey: 'dives'),
    ),
    GoRoute(
      path: 'sites',
      name: 'appearanceSites',
      builder: (context, state) =>
          const SectionAppearancePage(sectionKey: 'sites'),
    ),
    GoRoute(
      path: 'buddies',
      name: 'appearanceBuddies',
      builder: (context, state) =>
          const SectionAppearancePage(sectionKey: 'buddies'),
    ),
    GoRoute(
      path: 'trips',
      name: 'appearanceTrips',
      builder: (context, state) =>
          const SectionAppearancePage(sectionKey: 'trips'),
    ),
    GoRoute(
      path: 'equipment',
      name: 'appearanceEquipment',
      builder: (context, state) =>
          const SectionAppearancePage(sectionKey: 'equipment'),
    ),
    GoRoute(
      path: 'dive-centers',
      name: 'appearanceDiveCenters',
      builder: (context, state) =>
          const SectionAppearancePage(sectionKey: 'diveCenters'),
    ),
    GoRoute(
      path: 'certifications',
      name: 'appearanceCertifications',
      builder: (context, state) =>
          const SectionAppearancePage(sectionKey: 'certifications'),
    ),
    GoRoute(
      path: 'courses',
      name: 'appearanceCourses',
      builder: (context, state) =>
          const SectionAppearancePage(sectionKey: 'courses'),
    ),
  ],
),
```

Don't forget to add the import at the top of `app_router.dart`:

```dart
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
```

- [ ] **Step 2: Run analyze to verify no issues**

Run: `flutter analyze`
Expected: No new issues

- [ ] **Step 3: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat: add routes for 8 appearance section sub-pages"
```

---

### Task 5: Update Desktop Settings Page

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (the `_AppearanceSectionContent` class)

The desktop settings page uses an inline master-detail layout. The `_AppearanceSectionContent` widget needs to show the hub by default, and navigate inline to section sub-pages when tiles are tapped.

- [ ] **Step 1: Rewrite _AppearanceSectionContent**

Replace the `_AppearanceSectionContent` class and `_AppearanceSectionContentState` class in `settings_page.dart` (approximately lines 1083-1761). The new version uses state flags to show either the hub, a section sub-page, or the column config page inline.

```dart
class _AppearanceSectionContent extends ConsumerStatefulWidget {
  const _AppearanceSectionContent();

  @override
  ConsumerState<_AppearanceSectionContent> createState() =>
      _AppearanceSectionContentState();
}

class _AppearanceSectionContentState
    extends ConsumerState<_AppearanceSectionContent> {
  bool _showLanguageList = false;
  String? _activeSectionKey;
  bool _showColumnConfig = false;
  String? _columnConfigSection;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    // Column config sub-page
    if (_showColumnConfig) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _showColumnConfig = false;
                // Go back to the section page, not the hub
              }),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(_activeSectionKey != null
                  ? _getSectionDisplayName(_activeSectionKey!)
                  : 'Appearance'),
            ),
          ),
          Expanded(
            child: ColumnConfigPage(
              embedded: true,
              initialSection: _columnConfigSection,
            ),
          ),
        ],
      );
    }

    // Language sub-page
    if (_showLanguageList) {
      return _buildLanguageSubPage(context, settings);
    }

    // Section sub-page
    if (_activeSectionKey != null) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _activeSectionKey = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Appearance'),
            ),
          ),
          Expanded(
            child: SectionAppearancePage(
              sectionKey: _activeSectionKey!,
              embedded: true,
              onColumnConfigTap: () => setState(() {
                _showColumnConfig = true;
                _columnConfigSection = _activeSectionKey;
              }),
            ),
          ),
        ],
      );
    }

    // Hub view (default)
    return _buildHubContent(context, settings);
  }

  Widget _buildHubContent(BuildContext context, AppSettings settings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'General'),
          // Theme tile
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.l10n.settings_themes_current),
            subtitle: Text(_resolveCurrentThemeName(context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/themes'),
          ),
          // Theme Mode selector
          _buildThemeSelector(context, settings.themeMode),
          // Language tile
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.l10n.settings_appearance_appLanguage),
            subtitle: Text(
              LanguageSettingsPage.getDisplayName(settings.locale),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _showLanguageList = true),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Sections'),
          for (final entry in _sectionHubEntries)
            ListTile(
              title: Text(entry.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => _activeSectionKey = entry.$1),
            ),
        ],
      ),
    );
  }

  // ... keep existing _buildLanguageSubPage, _buildThemeSelector,
  // _resolveCurrentThemeName, _buildSectionHeader helper methods.
  // Remove all the old inline settings code (card coloring, view mode
  // dropdowns, details pane toggles, dive profile settings, etc.).
}

const _sectionHubEntries = [
  ('dives', 'Dives'),
  ('sites', 'Dive Sites'),
  ('buddies', 'Buddies'),
  ('trips', 'Trips'),
  ('equipment', 'Equipment'),
  ('diveCenters', 'Dive Centers'),
  ('certifications', 'Certifications'),
  ('courses', 'Courses'),
];

String _getSectionDisplayName(String key) {
  for (final entry in _sectionHubEntries) {
    if (entry.$1 == key) return entry.$2;
  }
  return key;
}
```

**Key changes:**
- `_activeSectionKey` replaces the old inline settings. When set, shows `SectionAppearancePage(embedded: true)`.
- Back button returns to hub (sets `_activeSectionKey = null`).
- Column config back button returns to the section page, not the hub.
- `_showLanguageList` is preserved for the existing language sub-page pattern.
- All old inline settings code (~600 lines) is removed.

- [ ] **Step 2: Add the SectionAppearancePage import to settings_page.dart**

Add to the imports at the top of `settings_page.dart`:

```dart
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
```

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All PASS. If any existing tests reference the old inline settings in the desktop layout, fix them.

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "refactor: update desktop appearance settings to hub + section sub-page layout"
```

---

### Task 6: Format, Analyze, and Final Verification

- [ ] **Step 1: Format all changed files**

Run: `dart format lib/features/settings/presentation/pages/section_appearance_page.dart lib/features/settings/presentation/pages/appearance_page.dart lib/features/settings/presentation/pages/settings_page.dart lib/features/settings/presentation/pages/column_config_page.dart lib/core/router/app_router.dart`
Expected: No formatting changes (or applies formatting fixes)

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All PASS

- [ ] **Step 4: Fix any issues and commit**

If formatting or analysis found issues, fix and commit:

```bash
git add -A
git commit -m "fix: formatting and analysis fixes for appearance reorganization"
```

---

## Verification Checklist

After all tasks are complete, verify:

- [ ] Main Appearance page shows only General (Theme, Theme Mode, Language) + 8 section tiles
- [ ] Each section tile navigates to the correct sub-page on mobile
- [ ] Dives sub-page shows: List View, Cards (with gradient picker), Table Mode, Dive Profile, Dive Details
- [ ] Sites sub-page shows: List View, Cards (map bg), Table Mode
- [ ] Buddies/Trips/Equipment/Dive Centers show: List View, Table Mode
- [ ] Certifications/Courses show: List View (Detailed + Table only), Table Mode
- [ ] List Fields tile navigates to ColumnConfigPage pre-scoped to the correct section
- [ ] Desktop master-detail shows hub in detail pane, with inline navigation to sections
- [ ] All existing sub-page links still work (Theme Gallery, Language, Default Metrics, Dive Detail Sections)
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
