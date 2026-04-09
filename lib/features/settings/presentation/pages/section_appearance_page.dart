import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/gradient_preset_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';

/// Per-section metadata used to drive the appearance page layout.
class _SectionConfig {
  final String key;
  final String displayName;
  final List<ListViewMode> viewModes;
  final String listFieldsLabel;
  final bool hasCardsSection;
  final bool hasDiveCards;
  final bool hasSiteCards;
  final bool hasDiveProfile;
  final bool hasDiveDetails;
  final bool hasDiveTableExtras;

  const _SectionConfig({
    required this.key,
    required this.displayName,
    required this.viewModes,
    required this.listFieldsLabel,
    this.hasCardsSection = false,
    this.hasDiveCards = false,
    this.hasSiteCards = false,
    this.hasDiveProfile = false,
    this.hasDiveDetails = false,
    this.hasDiveTableExtras = false,
  });
}

const _sectionConfigs = <String, _SectionConfig>{
  'dives': _SectionConfig(
    key: 'dives',
    displayName: 'Dives',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
    listFieldsLabel: 'Dive List Fields',
    hasCardsSection: true,
    hasDiveCards: true,
    hasDiveProfile: true,
    hasDiveDetails: true,
    hasDiveTableExtras: true,
  ),
  'sites': _SectionConfig(
    key: 'sites',
    displayName: 'Dive Sites',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
    listFieldsLabel: 'Site List Fields',
    hasCardsSection: true,
    hasSiteCards: true,
  ),
  'buddies': _SectionConfig(
    key: 'buddies',
    displayName: 'Buddies',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
    listFieldsLabel: 'Buddy List Fields',
  ),
  'trips': _SectionConfig(
    key: 'trips',
    displayName: 'Trips',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
    listFieldsLabel: 'Trip List Fields',
  ),
  'equipment': _SectionConfig(
    key: 'equipment',
    displayName: 'Equipment',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
    listFieldsLabel: 'Equipment List Fields',
  ),
  'diveCenters': _SectionConfig(
    key: 'diveCenters',
    displayName: 'Dive Centers',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
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

/// Renders appearance settings for a given app section.
///
/// When [embedded] is true, omits the Scaffold/AppBar for embedding in a
/// desktop detail pane. When [onColumnConfigTap] is provided, calls that
/// instead of navigating to the column config route.
class SectionAppearancePage extends ConsumerWidget {
  final String sectionKey;
  final bool embedded;
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
      return const SizedBox.shrink();
    }

    final body = ListView(
      children: [
        // -- List View section --
        _buildSectionHeader(context, 'List View'),
        _buildViewModeDropdown(context, ref, config),
        _buildListFieldsTile(context, config),

        // -- Cards section (dives / sites only) --
        if (config.hasCardsSection) ...[
          const Divider(),
          _buildSectionHeader(context, 'Cards'),
          if (config.hasDiveCards) ..._buildDiveCardsSettings(context, ref),
          if (config.hasSiteCards) ..._buildSiteCardsSettings(context, ref),
        ],

        // -- Table Mode section --
        const Divider(),
        _buildSectionHeader(context, 'Table Mode'),
        _buildDetailsPaneToggle(context, ref, config),
        if (config.hasDiveTableExtras) ..._buildDiveTableExtras(context, ref),

        // -- Dive Profile section (dives only) --
        if (config.hasDiveProfile) ...[
          const Divider(),
          _buildSectionHeader(context, 'Dive Profile'),
          ..._buildDiveProfileSettings(context, ref),
        ],

        // -- Dive Details section (dives only) --
        if (config.hasDiveDetails) ...[
          const Divider(),
          _buildSectionHeader(context, 'Dive Details'),
          ..._buildDiveDetailsSettings(context, ref),
        ],

        const SizedBox(height: 32),
      ],
    );

    if (embedded) {
      return Material(child: body);
    }

    return Scaffold(
      appBar: AppBar(title: Text('${config.displayName} Appearance')),
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
    _SectionConfig config,
  ) {
    final currentMode = _getCurrentViewMode(ref, config.key);

    return ListTile(
      leading: const Icon(Icons.view_list),
      title: Text('${config.displayName} List View'),
      subtitle: Text(
        'Default layout for the ${config.displayName.toLowerCase()} list',
      ),
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
            child: Text(_getViewModeDisplayName(mode)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListFieldsTile(BuildContext context, _SectionConfig config) {
    return ListTile(
      leading: const Icon(Icons.view_column),
      title: Text(config.listFieldsLabel),
      subtitle: const Text('Customize fields shown in list views'),
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
  // Cards section
  // ---------------------------------------------------------------------------

  List<Widget> _buildDiveCardsSettings(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return [
      ListTile(
        leading: const Icon(Icons.palette),
        title: Text(context.l10n.settings_appearance_cardColorAttribute),
        subtitle: Text(
          context.l10n.settings_appearance_cardColorAttribute_subtitle,
        ),
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
              child: Text(_getAttributeDisplayName(context, attr)),
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
      SwitchListTile(
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
      ),
    ];
  }

  List<Widget> _buildSiteCardsSettings(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return [
      SwitchListTile(
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
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Table Mode section
  // ---------------------------------------------------------------------------

  Widget _buildDetailsPaneToggle(
    BuildContext context,
    WidgetRef ref,
    _SectionConfig config,
  ) {
    final showDetailsPane = ref.watch(tableDetailsPaneProvider(config.key));

    return SwitchListTile(
      title: Text(context.l10n.settings_appearance_showDetailsPane),
      subtitle: Text(context.l10n.settings_appearance_showDetailsPane_subtitle),
      secondary: const Icon(Icons.vertical_split),
      value: showDetailsPane,
      onChanged: (value) {
        ref.read(tableDetailsPaneProvider(config.key).notifier).state = value;
        ref
            .read(settingsProvider.notifier)
            .setShowDetailsPaneForSection(config.key, value);
      },
    );
  }

  List<Widget> _buildDiveTableExtras(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return [
      SwitchListTile(
        title: Text(context.l10n.settings_appearance_showProfilePanel),
        subtitle: Text(
          context.l10n.settings_appearance_showProfilePanel_subtitle,
        ),
        secondary: const Icon(Icons.area_chart),
        value: settings.showProfilePanelInTableView,
        onChanged: (value) {
          ref
              .read(settingsProvider.notifier)
              .setShowProfilePanelInTableView(value);
        },
      ),
      SwitchListTile(
        title: const Text('Show data source badges'),
        subtitle: const Text('Display source attribution on dive metrics'),
        secondary: const Icon(Icons.label_outline),
        value: settings.showDataSourceBadges,
        onChanged: (value) {
          ref.read(settingsProvider.notifier).setShowDataSourceBadges(value);
        },
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Dive Profile section
  // ---------------------------------------------------------------------------

  List<Widget> _buildDiveProfileSettings(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

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
        title: Text(context.l10n.settings_appearance_pressureThresholdMarkers),
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
        onTap: () => context.push('/settings/default-metrics'),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Dive Details section
  // ---------------------------------------------------------------------------

  List<Widget> _buildDiveDetailsSettings(BuildContext context, WidgetRef ref) {
    return [
      ListTile(
        leading: const Icon(Icons.reorder),
        title: Text(
          context.l10n.settings_appearance_diveDetails_sectionOrderVisibility,
        ),
        subtitle: Text(
          context
              .l10n
              .settings_appearance_diveDetails_sectionOrderVisibility_subtitle,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/dive-detail-sections'),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // View mode helpers
  // ---------------------------------------------------------------------------

  ListViewMode _getCurrentViewMode(WidgetRef ref, String key) {
    return switch (key) {
      'dives' => ref.watch(settingsProvider).diveListViewMode,
      'sites' => ref.watch(settingsProvider).siteListViewMode,
      'trips' => ref.watch(settingsProvider).tripListViewMode,
      'equipment' => ref.watch(settingsProvider).equipmentListViewMode,
      'buddies' => ref.watch(settingsProvider).buddyListViewMode,
      'diveCenters' => ref.watch(settingsProvider).diveCenterListViewMode,
      'certifications' => ref.watch(certificationListViewModeProvider),
      'courses' => ref.watch(courseListViewModeProvider),
      _ => ListViewMode.detailed,
    };
  }

  void _setViewMode(WidgetRef ref, String key, ListViewMode mode) {
    switch (key) {
      case 'dives':
        ref.read(settingsProvider.notifier).setDiveListViewMode(mode);
        ref.read(diveListViewModeProvider.notifier).state = mode;
      case 'sites':
        ref.read(settingsProvider.notifier).setSiteListViewMode(mode);
        ref.read(siteListViewModeProvider.notifier).state = mode;
      case 'trips':
        ref.read(settingsProvider.notifier).setTripListViewMode(mode);
        ref.read(tripListViewModeProvider.notifier).state = mode;
      case 'equipment':
        ref.read(settingsProvider.notifier).setEquipmentListViewMode(mode);
        ref.read(equipmentListViewModeProvider.notifier).state = mode;
      case 'buddies':
        ref.read(settingsProvider.notifier).setBuddyListViewMode(mode);
        ref.read(buddyListViewModeProvider.notifier).state = mode;
      case 'diveCenters':
        ref.read(settingsProvider.notifier).setDiveCenterListViewMode(mode);
        ref.read(diveCenterListViewModeProvider.notifier).state = mode;
      case 'certifications':
        // Runtime-only, not persisted
        ref.read(certificationListViewModeProvider.notifier).state = mode;
      case 'courses':
        // Runtime-only, not persisted
        ref.read(courseListViewModeProvider.notifier).state = mode;
    }
  }

  // ---------------------------------------------------------------------------
  // Display name helpers
  // ---------------------------------------------------------------------------

  String _getViewModeDisplayName(ListViewMode mode) {
    return switch (mode) {
      ListViewMode.detailed => 'Detailed',
      ListViewMode.compact => 'Compact',
      ListViewMode.dense => 'Dense',
      ListViewMode.table => 'Table',
    };
  }

  String _getAttributeDisplayName(
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
