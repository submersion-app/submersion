import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
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
  final List<ListViewMode> viewModes;
  final bool hasCardsSection;
  final bool hasDiveCards;
  final bool hasSiteCards;
  final bool hasDiveProfile;
  final bool hasDiveDetails;
  final bool hasDiveTableExtras;

  const _SectionConfig({
    required this.key,
    required this.viewModes,
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
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
    hasCardsSection: true,
    hasDiveCards: true,
    hasDiveProfile: true,
    hasDiveDetails: true,
    hasDiveTableExtras: true,
  ),
  'sites': _SectionConfig(
    key: 'sites',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
    hasCardsSection: true,
    hasSiteCards: true,
  ),
  'buddies': _SectionConfig(
    key: 'buddies',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
  ),
  'trips': _SectionConfig(
    key: 'trips',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
  ),
  'equipment': _SectionConfig(
    key: 'equipment',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
  ),
  'diveCenters': _SectionConfig(
    key: 'diveCenters',
    viewModes: [
      ListViewMode.detailed,
      ListViewMode.compact,
      ListViewMode.table,
    ],
  ),
  'certifications': _SectionConfig(
    key: 'certifications',
    viewModes: [ListViewMode.detailed, ListViewMode.table],
  ),
  'courses': _SectionConfig(
    key: 'courses',
    viewModes: [ListViewMode.detailed, ListViewMode.table],
  ),
};

/// Page title for a section's appearance page.
///
/// Each section owns a fully formed key instead of a
/// `"<name> Appearance"` concatenation, which does not survive
/// translation.
String _sectionAppearanceTitle(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'dives' => l10n.settings_appearance_title_dives,
    'sites' => l10n.settings_appearance_title_sites,
    'buddies' => l10n.settings_appearance_title_buddies,
    'trips' => l10n.settings_appearance_title_trips,
    'equipment' => l10n.settings_appearance_title_equipment,
    'diveCenters' => l10n.settings_appearance_title_diveCenters,
    'certifications' => l10n.settings_appearance_title_certifications,
    'courses' => l10n.settings_appearance_title_courses,
    _ => key,
  };
}

/// Title of the default-list-layout row for a section.
String _sectionListViewTitle(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'dives' => l10n.settings_appearance_listView_dives,
    'sites' => l10n.settings_appearance_listView_sites,
    'buddies' => l10n.settings_appearance_listView_buddies,
    'trips' => l10n.settings_appearance_listView_trips,
    'equipment' => l10n.settings_appearance_listView_equipment,
    'diveCenters' => l10n.settings_appearance_listView_diveCenters,
    'certifications' => l10n.settings_appearance_listView_certifications,
    'courses' => l10n.settings_appearance_listView_courses,
    _ => key,
  };
}

/// Subtitle of the default-list-layout row for a section.
///
/// Fully formed per section: the English original lower-cased the
/// entity name mid-sentence, which is wrong for German nouns and
/// needs a different article or word order in several locales.
String _sectionListViewSubtitle(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'dives' => l10n.settings_appearance_listView_dives_subtitle,
    'sites' => l10n.settings_appearance_listView_sites_subtitle,
    'buddies' => l10n.settings_appearance_listView_buddies_subtitle,
    'trips' => l10n.settings_appearance_listView_trips_subtitle,
    'equipment' => l10n.settings_appearance_listView_equipment_subtitle,
    'diveCenters' => l10n.settings_appearance_listView_diveCenters_subtitle,
    'certifications' =>
      l10n.settings_appearance_listView_certifications_subtitle,
    'courses' => l10n.settings_appearance_listView_courses_subtitle,
    _ => key,
  };
}

/// Label of the "... List Fields" sub-page row for a section.
String _sectionListFieldsLabel(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'dives' => l10n.settings_appearance_listFields_dives,
    'sites' => l10n.settings_appearance_listFields_sites,
    'buddies' => l10n.settings_appearance_listFields_buddies,
    'trips' => l10n.settings_appearance_listFields_trips,
    'equipment' => l10n.settings_appearance_listFields_equipment,
    'diveCenters' => l10n.settings_appearance_listFields_diveCenters,
    'certifications' => l10n.settings_appearance_listFields_certifications,
    'courses' => l10n.settings_appearance_listFields_courses,
    _ => key,
  };
}

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
        _buildSectionHeader(
          context,
          context.l10n.settings_appearance_header_listView,
        ),
        _buildViewModeDropdown(context, ref, config),
        _buildListFieldsTile(context, config),

        // -- Cards section (dives / sites only) --
        if (config.hasCardsSection) ...[
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_cards,
          ),
          if (config.hasDiveCards) ..._buildDiveCardsSettings(context, ref),
          if (config.hasSiteCards) ..._buildSiteCardsSettings(context, ref),
        ],

        // -- Table Mode section --
        const Divider(),
        _buildSectionHeader(
          context,
          context.l10n.settings_appearance_header_tableMode,
        ),
        _buildDetailsPaneToggle(context, ref, config),
        if (config.hasDiveTableExtras) ..._buildDiveTableExtras(context, ref),

        // -- Dive Profile section (dives only) --
        if (config.hasDiveProfile) ...[
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_diveProfile,
          ),
          ..._buildDiveProfileSettings(context, ref),
        ],

        // -- Dive Details section (dives only) --
        if (config.hasDiveDetails) ...[
          const Divider(),
          _buildSectionHeader(
            context,
            context.l10n.settings_appearance_header_diveDetails,
          ),
          ..._buildDiveDetailsSettings(context, ref),
        ],

        const SizedBox(height: 32),
      ],
    );

    if (embedded) {
      return Material(child: body);
    }

    return Scaffold(
      appBar: AppBar(title: Text(_sectionAppearanceTitle(context, config.key))),
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
      title: Text(_sectionListViewTitle(context, config.key)),
      subtitle: Text(_sectionListViewSubtitle(context, config.key)),
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
            child: Text(_getViewModeDisplayName(context, mode)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListFieldsTile(BuildContext context, _SectionConfig config) {
    return ListTile(
      leading: const Icon(Icons.view_column),
      title: Text(_sectionListFieldsLabel(context, config.key)),
      subtitle: Text(context.l10n.settings_appearance_listFields_subtitle),
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
        title: Text(context.l10n.settings_appearance_showDataSourceBadges),
        subtitle: Text(
          context.l10n.settings_appearance_showDataSourceBadges_subtitle,
        ),
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
              child: Text(_getMetricDisplayName(context, metric)),
            );
          }).toList(),
        ),
      ),
      SwitchListTile(
        title: Text(context.l10n.settings_appearance_metricsFollowViewport),
        subtitle: Text(
          context.l10n.settings_appearance_metricsFollowViewport_subtitle,
        ),
        secondary: const Icon(Icons.height),
        value: settings.profileMetricsFollowViewport,
        onChanged: (value) {
          ref
              .read(settingsProvider.notifier)
              .setProfileMetricsFollowViewport(value);
        },
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
        secondary: const Icon(MdiIcons.divingScubaTank),
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
      SwitchListTile(
        title: Text(context.l10n.settings_appearance_gasTimeline),
        subtitle: Text(context.l10n.settings_appearance_gasTimeline_subtitle),
        secondary: const Icon(Icons.timeline),
        value: settings.defaultShowGasTimeline,
        onChanged: (value) {
          ref.read(settingsProvider.notifier).setDefaultShowGasTimeline(value);
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
            _visibleMetricToggles(settings).length,
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

  String _getViewModeDisplayName(BuildContext context, ListViewMode mode) {
    final l10n = context.l10n;
    return switch (mode) {
      ListViewMode.detailed => l10n.enum_listViewMode_detailed,
      ListViewMode.compact => l10n.enum_listViewMode_compact,
      ListViewMode.dense => l10n.enum_listViewMode_dense,
      ListViewMode.table => l10n.enum_listViewMode_table,
    };
  }

  String _getMetricDisplayName(
    BuildContext context,
    ProfileRightAxisMetric metric,
  ) {
    final l10n = context.l10n;
    return switch (metric) {
      ProfileRightAxisMetric.temperature => l10n.enum_profileMetric_temperature,
      ProfileRightAxisMetric.pressure => l10n.enum_profileMetric_pressure,
      ProfileRightAxisMetric.heartRate => l10n.enum_profileMetric_heartRate,
      ProfileRightAxisMetric.sac => l10n.enum_profileMetric_sacRate,
      ProfileRightAxisMetric.ascentRate => l10n.enum_profileMetric_ascentRate,
      ProfileRightAxisMetric.ndl => l10n.enum_profileMetric_ndl,
      ProfileRightAxisMetric.ppO2 => l10n.enum_profileMetric_ppO2,
      ProfileRightAxisMetric.ppN2 => l10n.enum_profileMetric_ppN2,
      ProfileRightAxisMetric.ppHe => l10n.enum_profileMetric_ppHe,
      ProfileRightAxisMetric.gasDensity => l10n.enum_profileMetric_gasDensity,
      ProfileRightAxisMetric.gf => l10n.enum_profileMetric_gf,
      ProfileRightAxisMetric.surfaceGf => l10n.enum_profileMetric_surfaceGf,
      ProfileRightAxisMetric.meanDepth => l10n.enum_profileMetric_meanDepth,
      ProfileRightAxisMetric.tts => l10n.enum_profileMetric_tts,
      ProfileRightAxisMetric.cns => l10n.enum_profileMetric_cns,
      ProfileRightAxisMetric.otu => l10n.enum_profileMetric_otu,
      ProfileRightAxisMetric.o2CellMv => l10n.enum_profileMetric_o2CellMv,
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

  /// One entry per SwitchListTile on [DefaultVisibleMetricsPage], in the same
  /// order, so the enabled/total counts shown in the summary subtitle can
  /// never drift out of sync with what that page actually renders.
  List<bool> _visibleMetricToggles(AppSettings settings) => [
    settings.defaultShowTemperature,
    settings.defaultShowPressure,
    settings.defaultShowHeartRate,
    settings.defaultShowSac,
    settings.defaultShowEvents,
    settings.defaultShowPhotoMarkers,
    settings.showCeilingOnProfile,
    settings.showDecoStopsOnProfile,
    settings.showAscentRateColors,
    settings.defaultShowAscentRateLine,
    settings.showNdlOnProfile,
    settings.defaultShowTts,
    settings.defaultShowCns,
    settings.defaultShowOtu,
    settings.defaultShowPpO2,
    settings.defaultShowPpN2,
    settings.defaultShowPpHe,
    settings.defaultShowGasDensity,
    settings.defaultShowO2CellMv,
    settings.defaultShowGf,
    settings.defaultShowSurfaceGf,
    settings.defaultShowMeanDepth,
  ];

  int _countEnabledMetrics(AppSettings settings) =>
      _visibleMetricToggles(settings).where((v) => v).length;
}
