import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/equipment/presentation/widgets/profile_checklist_dialog.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/core/utils/app_version.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/settings/presentation/widgets/altitude_distance_unit_pickers.dart';
import 'package:submersion/features/settings/presentation/widgets/notification_permission_card.dart';
import 'package:submersion/features/settings/presentation/pages/data_section_content.dart';
import 'package:submersion/features/settings/presentation/pages/manage_section_content.dart';
import 'package:submersion/features/settings/presentation/pages/data_settings_pane.dart';
import 'package:submersion/features/settings/presentation/pages/column_config_page.dart';
import 'package:submersion/features/settings/presentation/pages/safety_hub_page.dart';
import 'package:submersion/features/settings/presentation/pages/security_settings_page.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/widgets/coordinate_format_picker.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/place_name_language_picker.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_value_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/visibility_scale_picker.dart';
import 'package:submersion/features/settings/presentation/pages/home_appearance_page.dart';
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
import 'package:submersion/features/settings/presentation/widgets/appearance_settings_tiles.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_hub_page.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/features/settings/presentation/widgets/diagnostics_card.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/settings_root_set_up_card.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_list_content.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/features/settings/presentation/settings_legacy_links.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_summary_widget.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_import_providers.dart';
import 'package:submersion/features/auto_update/domain/beta_program_links.dart';
import 'package:submersion/features/auto_update/domain/entities/release_channel.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
import 'package:submersion/features/settings/presentation/pages/debug_log_viewer_page.dart';
import 'package:submersion/features/settings/presentation/pages/network_settings_page.dart';
import 'package:submersion/features/settings/presentation/format_enum_display.dart';
import 'package:submersion/shared/widgets/label_with_control.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/shared/widgets/shared_items/item_bulk_share.dart';

/// The URL for the GitHub issues page, used by [launchReportIssue].
const reportIssueUrl = 'https://github.com/submersion-app/submersion/issues';

/// Opens the GitHub issues page in an external browser. Falls back to a
/// snackbar with a copy-link action if the launch fails.
Future<void> launchReportIssue(BuildContext context) async {
  final uri = Uri.parse(reportIssueUrl);
  var didLaunch = false;

  // No canLaunchUrl guard: it false-negatives for https on Android 11+
  // unless the scheme is declared in the manifest <queries> block.
  try {
    didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    didLaunch = false;
  }

  if (!didLaunch && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.settings_about_reportIssue_snackbar),
        action: SnackBarAction(
          label: context.l10n.settings_about_reportIssue_copy,
          onPressed: () =>
              Clipboard.setData(const ClipboardData(text: reportIssueUrl)),
        ),
      ),
    );
  }
}

/// Main settings page with master-detail layout on desktop.
///
/// On desktop (>=800px): Shows a split view with section list on left,
/// selected section content on right.
/// On narrower screens (<800px): Shows section list with navigation.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterDetail = ResponsiveBreakpoints.isMasterDetail(context);
    Uri? uri;
    try {
      uri = GoRouterState.of(context).uri;
    } catch (_) {
      // GoRouter not available (e.g., in tests)
    }

    // An old link (Decompression before it moved under Safety, or Safety
    // itself on a phone, where it is a full page) is sent on after this
    // frame: navigating during build is not allowed.
    final legacyTarget = uri == null
        ? null
        : resolveLegacySettingsLocation(uri, masterDetail: masterDetail);
    if (legacyTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (masterDetail) {
          context.goInPlace(legacyTarget);
        } else {
          context.go(legacyTarget);
        }
      });
    }

    if (masterDetail) {
      return MasterDetailScaffold(
        sectionId: 'settings',
        masterBuilder: (context, onItemSelected, selectedId) =>
            SettingsListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, sectionId) =>
            _buildSectionContent(context, ref, sectionId),
        summaryBuilder: (context) => const SettingsSummaryWidget(),
      );
    }

    // Mobile: Check for selected section via query param
    final selectedSection = uri?.queryParameters['selected'];

    // Until the redirect lands, show the list rather than wrapping a full
    // page in the section wrapper for a frame.
    if (selectedSection != null && legacyTarget == null) {
      // Show section detail page
      return SettingsSectionDetailPage(sectionId: selectedSection);
    }

    // Mobile: Show section list
    return const SettingsMobileContent();
  }

  /// Builds the appropriate section content based on section ID.
  Widget _buildSectionContent(
    BuildContext context,
    WidgetRef ref,
    String sectionId,
  ) {
    switch (sectionId) {
      case 'profile':
        return const DiverProfileHubPage();
      case 'safety':
        return const SafetySettingsPane();
      case 'security':
        return const SecuritySettingsPage();
      case 'units':
        return _UnitsSectionContent(ref: ref);
      case 'appearance':
        return const _AppearanceSectionContent();
      case 'network':
        return const NetworkSettingsPage();
      case 'notifications':
        return _NotificationsSectionContent(ref: ref);
      case 'manage':
        return const ManageSectionContent();
      case 'data':
        return const DataSettingsPane();
      case 'dataSources':
        return const _DataSourcesSectionContent();
      case 'about':
        return const _AboutSectionContent();
      case 'sharedData':
        return const SharedDataSectionContent();
      case 'debug':
        return const DebugLogViewerPage();
      case 'decompression':
        // An old link to the retired root section. build() redirects it to
        // Safety after this frame; until then show nothing rather than the
        // unknown-section fallback.
        return const SizedBox.shrink();
      default:
        return Center(child: Text('Unknown section: $sectionId'));
    }
  }
}

/// Mobile content showing section list for navigation.
class SettingsMobileContent extends ConsumerWidget {
  const SettingsMobileContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugEnabled = ref.watch(debugModeNotifierProvider);
    final allDiversAsync = ref.watch(allDiversProvider);
    final diverCount = allDiversAsync.valueOrNull?.length ?? 0;

    final sections = settingsSections
        .where((s) => s.id != 'dataSources' || Platform.isIOS)
        .where((s) => s.id != 'sharedData' || diverCount >= 2)
        .toList();

    // Insert Debug section just before About when debug mode is enabled
    if (debugEnabled) {
      final aboutIndex = sections.indexWhere((s) => s.id == 'about');
      final insertIndex = aboutIndex >= 0 ? aboutIndex : sections.length;
      sections.insert(
        insertIndex,
        const SettingsSection(
          id: 'debug',
          icon: Icons.bug_report_outlined,
          title: 'Debug',
          subtitle: 'Logs & diagnostics',
        ),
      );
    }

    // The setup card rides inside the list (row 0) so it scrolls away and
    // can never overflow the viewport when it carries many items.
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_appBar_title)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sections.length + 1,
        separatorBuilder: (context, index) =>
            index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == 0) return const SettingsRootSetUpCard.phone();
          final section = sections[index - 1];
          return _MobileSettingsTile(section: section);
        },
      ),
    );
  }
}

/// Settings sections that render a page of their own, mapped to that page's
/// route.
///
/// [SettingsSectionDetailPage] supplies a Scaffold and an AppBar, so sections
/// whose content is itself a Scaffold with an AppBar (Diver Profile, Safety,
/// Debug) would show two stacked app bars inside it. Appearance is listed too
/// because it has a dedicated page, keeping that route canonical, and
/// Decompression because it is no longer a root section: it lives under
/// Safety, so a link to the old section lands on its new page.
///
/// Used both by the settings list tile and by the '/settings/section/:id'
/// route's redirect, so a deep link to that path cannot bypass it.
const settingsSectionDedicatedRoutes = <String, String>{
  'profile': '/settings/diver-profile',
  'appearance': '/settings/appearance',
  'safety': '/settings/safety',
  // Moved under Safety (#3395); old links to the section follow it.
  'decompression': '/settings/safety/decompression',
  'debug': '/settings/debug-logs',
};

/// Mobile detail page for a single settings section.
///
/// Reached by pushing the '/settings/section/:sectionId' child route, which
/// go_router wraps in a platform-adaptive page so the section slides in like
/// every other sub-page. Also rendered directly by [SettingsPage] for legacy
/// `/settings?selected=<id>` deep links.
class SettingsSectionDetailPage extends ConsumerWidget {
  final String sectionId;

  const SettingsSectionDetailPage({super.key, required this.sectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find the section title (use localized string)
    final title = _getLocalizedSectionTitle(context, sectionId);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.settings_backToSettings_tooltip,
          // Pop the pushed section route; fall back to go() for deep links
          // where the detail page is the root of the stack.
          onPressed: () {
            // maybePop, not pop: a section with unsaved edits (Network)
            // can ask before its route closes.
            if (context.canPop()) {
              unawaited(() async {
                // maybePop bubbles (false) for the first route of a nested
                // navigator; the router can still pop a parent then.
                final handled = await Navigator.of(context).maybePop();
                if (!handled && context.mounted) context.pop();
              }());
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: _buildContent(context, ref),
    );
  }

  String _getLocalizedSectionTitle(BuildContext context, String id) {
    return switch (id) {
      'profile' => context.l10n.settings_section_diverProfile_title,
      'units' => context.l10n.settings_section_units_title,
      'appearance' => context.l10n.settings_section_appearance_title,
      'network' => context.l10n.settings_section_network_title,
      'notifications' => context.l10n.settings_section_notifications_title,
      'manage' => context.l10n.settings_section_manage_title,
      'data' => context.l10n.settings_section_data_title,
      'about' => context.l10n.settings_section_about_title,
      'dataSources' => context.l10n.settings_section_dataSources_title,
      'sharedData' => context.l10n.settings_sharedData_sectionTitle,
      'debug' => context.l10n.settings_section_debug_title,
      _ => context.l10n.settings_appBar_title,
    };
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    switch (sectionId) {
      case 'profile':
        return const DiverProfileHubPage();
      case 'safety':
        return const SafetyHubPage();
      case 'security':
        return const SecuritySettingsPage();
      case 'units':
        return _UnitsSectionContent(ref: ref);
      case 'appearance':
        return const _AppearanceSectionContent();
      case 'network':
        return const NetworkSettingsPage();
      case 'notifications':
        return _NotificationsSectionContent(ref: ref);
      case 'manage':
        return const ManageSectionContent();
      case 'data':
        return const DataSectionContent();
      case 'dataSources':
        return const _DataSourcesSectionContent();
      case 'about':
        return const _AboutSectionContent();
      case 'sharedData':
        return const SharedDataSectionContent();
      case 'debug':
        return const DebugLogViewerPage();
      default:
        return Center(child: Text('Unknown section: $sectionId'));
    }
  }
}

class _MobileSettingsTile extends StatelessWidget {
  final SettingsSection section;

  const _MobileSettingsTile({required this.section});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = settingsSectionColor(context, section.id);

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(section.icon, color: color, size: 24),
      ),
      title: Text(
        _getLocalizedTitle(context, section),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _getLocalizedSubtitle(context, section),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: () => _navigateToSection(context, section.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  String _getLocalizedTitle(BuildContext context, SettingsSection section) {
    return switch (section.id) {
      'profile' => context.l10n.settings_section_diverProfile_title,
      'units' => context.l10n.settings_section_units_title,
      'appearance' => context.l10n.settings_section_appearance_title,
      'network' => context.l10n.settings_section_network_title,
      'notifications' => context.l10n.settings_section_notifications_title,
      'manage' => context.l10n.settings_section_manage_title,
      'data' => context.l10n.settings_section_data_title,
      'about' => context.l10n.settings_section_about_title,
      'dataSources' => context.l10n.settings_section_dataSources_title,
      'sharedData' => context.l10n.settings_sharedData_sectionTitle,
      'safety' => context.l10n.settings_section_safety_title,
      'security' => context.l10n.settings_section_security_title,
      'debug' => context.l10n.settings_section_debug_title,
      _ => section.title,
    };
  }

  String _getLocalizedSubtitle(BuildContext context, SettingsSection section) {
    return switch (section.id) {
      'profile' => context.l10n.settings_section_diverProfile_subtitle,
      'units' => context.l10n.settings_section_units_subtitle,
      'appearance' => context.l10n.settings_section_appearance_subtitle,
      'network' => context.l10n.settings_section_network_subtitle,
      'notifications' => context.l10n.settings_section_notifications_subtitle,
      'manage' => context.l10n.settings_section_manage_subtitle,
      'data' => context.l10n.settings_section_data_tagline,
      'about' => context.l10n.settings_section_about_subtitle,
      'dataSources' => context.l10n.settings_section_dataSources_subtitle,
      'safety' => context.l10n.settings_section_safety_subtitle,
      'security' => context.l10n.settings_section_security_subtitle,
      'debug' => context.l10n.settings_section_debug_subtitle,
      _ => section.subtitle,
    };
  }

  void _navigateToSection(BuildContext context, String sectionId) {
    // Sections without a page of their own get the shared section route.
    // PUSH (not go): go() replaces the location in place, leaving nothing on
    // the stack for the system back gesture to pop, so Android closed the
    // whole app (#647).
    //
    // This pushes a child route rather than '/settings?selected=<id>'. The
    // latter re-matched the '/settings' tab root, whose pageBuilder returns a
    // NoTransitionPage so bottom-nav tab switches do not animate -- which
    // also robbed every pushed section of its slide-in.
    context.push(
      settingsSectionDedicatedRoutes[sectionId] ??
          '/settings/section/$sectionId',
    );
  }
}

// ============================================================================
// SECTION CONTENT WIDGETS
// ============================================================================

/// Units section content
class _UnitsSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _UnitsSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_units_header_unitSystem,
          ),
          const SizedBox(height: 8),
          _buildUnitPresetSelector(context, ref, settings),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_units_header_individualUnits,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_depth,
                  value: settings.depthUnit.symbol,
                  onTap: () =>
                      _showDepthUnitPicker(context, ref, settings.depthUnit),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_temperature,
                  value: '°${settings.temperatureUnit.symbol}',
                  onTap: () => _showTempUnitPicker(
                    context,
                    ref,
                    settings.temperatureUnit,
                  ),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_pressure,
                  value: settings.pressureUnit.symbol,
                  onTap: () => _showPressureUnitPicker(
                    context,
                    ref,
                    settings.pressureUnit,
                  ),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_volume,
                  value: settings.volumeUnit.symbol,
                  onTap: () =>
                      _showVolumeUnitPicker(context, ref, settings.volumeUnit),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_weight,
                  value: settings.weightUnit.symbol,
                  onTap: () =>
                      _showWeightUnitPicker(context, ref, settings.weightUnit),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_altitude,
                  value: settings.altitudeUnit.symbol,
                  onTap: () => showAltitudeUnitPicker(
                    context,
                    ref,
                    settings.altitudeUnit,
                  ),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_distance,
                  value: settings.distanceUnit.symbol,
                  onTap: () => showDistanceUnitPicker(
                    context,
                    ref,
                    settings.distanceUnit,
                  ),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_gasConsumption,
                  value: switch (settings.gasConsumptionDisplay) {
                    GasConsumptionDisplay.sac =>
                      '${context.l10n.gasConsumption_sac} '
                          '(${UnitFormatter(settings).sacSymbol})',
                    GasConsumptionDisplay.rmv =>
                      '${context.l10n.gasConsumption_rmv} '
                          '(${UnitFormatter(settings).rmvSymbol})',
                    GasConsumptionDisplay.both =>
                      context.l10n.settings_units_gasConsumption_both,
                  },
                  onTap: () =>
                      _showGasConsumptionPicker(context, ref, settings),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_gasModel,
                  value: settings.gasModel == GasModel.ideal
                      ? context.l10n.settings_units_gasModel_ideal
                      : context.l10n.settings_units_gasModel_real,
                  onTap: () =>
                      _showGasModelPicker(context, ref, settings.gasModel),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_waterType,
                  value: _plannerWaterTypeLabel(
                    context,
                    settings.defaultPlannerWaterType,
                  ),
                  onTap: () => _showPlannerWaterTypePicker(
                    context,
                    ref,
                    settings.defaultPlannerWaterType,
                  ),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_defaultCurrency,
                  value: settings.defaultCurrency,
                  onTap: () => _showCurrencyPicker(
                    context,
                    ref,
                    settings.defaultCurrency,
                  ),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_visibilityScale_title,
                  subtitle: context.l10n.settings_visibilityScale_subtitle,
                  value: visibilityPresetLabel(
                    context.l10n,
                    settings.visibilityScalePreset,
                  ),
                  onTap: () =>
                      showVisibilityScalePicker(context, ref, settings),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_coordinateFormat_title,
                  value: coordinateFormatLabel(
                    context.l10n,
                    settings.coordinateFormat,
                  ),
                  onTap: () =>
                      showCoordinateFormatPicker(context, ref, settings),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_placeNameLanguage_title,
                  subtitle: context.l10n.settings_placeNameLanguage_subtitle,
                  value: placeNameLanguageLabel(settings.placeNameLanguage),
                  onTap: () =>
                      unawaited(_pickPlaceNameLanguage(context, ref, settings)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_units_header_timeDateFormat,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_timeFormat,
                  value: settings.timeFormat.localizedName(context.l10n),
                  onTap: () =>
                      _showTimeFormatPicker(context, ref, settings.timeFormat),
                ),
                const Divider(height: 1),
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_dateFormat,
                  value: settings.dateFormat.example,
                  onTap: () =>
                      _showDateFormatPicker(context, ref, settings.dateFormat),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitPresetSelector(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.settings_units_quickSelect,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            SegmentedButton<UnitPreset>(
              segments: [
                ButtonSegment(
                  value: UnitPreset.metric,
                  label: Text(context.l10n.settings_units_metric),
                ),
                ButtonSegment(
                  value: UnitPreset.imperial,
                  label: Text(context.l10n.settings_units_imperial),
                ),
                ButtonSegment(
                  value: UnitPreset.custom,
                  label: Text(context.l10n.settings_units_custom),
                ),
              ],
              selected: {settings.unitPreset},
              onSelectionChanged: (selected) {
                final preset = selected.first;
                switch (preset) {
                  case UnitPreset.metric:
                    ref.read(settingsProvider.notifier).setMetric();
                    break;
                  case UnitPreset.imperial:
                    ref.read(settingsProvider.notifier).setImperial();
                    break;
                  case UnitPreset.custom:
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return SettingsValueTile(
      title: title,
      subtitle: subtitle,
      value: value,
      onTap: onTap,
    );
  }

  void _showDepthUnitPicker(
    BuildContext context,
    WidgetRef ref,
    DepthUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_depthUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DepthUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == DepthUnit.meters
                    ? context.l10n.settings_units_depth_meters
                    : context.l10n.settings_units_depth_feet,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setDepthUnit(unit);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTempUnitPicker(
    BuildContext context,
    WidgetRef ref,
    TemperatureUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_temperatureUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TemperatureUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == TemperatureUnit.celsius
                    ? context.l10n.settings_units_temperature_celsius
                    : context.l10n.settings_units_temperature_fahrenheit,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setTemperatureUnit(unit);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPressureUnitPicker(
    BuildContext context,
    WidgetRef ref,
    PressureUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_pressureUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PressureUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == PressureUnit.bar
                    ? context.l10n.settings_units_pressure_bar
                    : context.l10n.settings_units_pressure_psi,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setPressureUnit(unit);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showVolumeUnitPicker(
    BuildContext context,
    WidgetRef ref,
    VolumeUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_volumeUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: VolumeUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == VolumeUnit.liters
                    ? context.l10n.settings_units_volume_liters
                    : context.l10n.settings_units_volume_cubicFeet,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setVolumeUnit(unit);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showWeightUnitPicker(
    BuildContext context,
    WidgetRef ref,
    WeightUnit currentUnit,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_weightUnit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: WeightUnit.values.map((unit) {
            final isSelected = unit == currentUnit;
            return ListTile(
              title: Text(
                unit == WeightUnit.kilograms
                    ? context.l10n.settings_units_weight_kilograms
                    : context.l10n.settings_units_weight_pounds,
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setWeightUnit(unit);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showGasConsumptionPicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final l10n = context.l10n;
    final current = settings.gasConsumptionDisplay;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Widget option(
          GasConsumptionDisplay value,
          String title,
          String subtitle,
        ) {
          return ListTile(
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: current == value
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              ref
                  .read(settingsProvider.notifier)
                  .setGasConsumptionDisplay(value);
              Navigator.of(dialogContext).pop();
            },
          );
        }

        return AlertDialog(
          title: Text(l10n.settings_units_dialog_gasConsumption),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(
                GasConsumptionDisplay.sac,
                l10n.gasConsumption_sac,
                l10n.settings_units_gasConsumption_sac_subtitle(
                  UnitFormatter(settings).sacSymbol,
                ),
              ),
              option(
                GasConsumptionDisplay.rmv,
                l10n.gasConsumption_rmv,
                l10n.settings_units_gasConsumption_rmv_subtitle(
                  UnitFormatter(settings).rmvSymbol,
                ),
              ),
              option(
                GasConsumptionDisplay.both,
                l10n.settings_units_gasConsumption_both,
                l10n.settings_units_gasConsumption_both_subtitle,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Pick the equation of state behind every pressure-to-volume conversion.
  ///
  /// The dialog spells out the consequence, because the difference between the
  /// two answers is what divers read as a bug when their hand calculation
  /// disagrees with the app (issue #828).
  void _showGasModelPicker(
    BuildContext context,
    WidgetRef ref,
    GasModel currentModel,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_gasModel),
        // Scrollable: unlike the sibling unit pickers this one carries an
        // explanatory paragraph above two subtitled options, which overflows
        // a short dialog on small screens or at large text scales.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  context.l10n.settings_units_gasModel_explanation,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              ListTile(
                title: Text(context.l10n.settings_units_gasModel_real),
                subtitle: Text(
                  context.l10n.settings_units_gasModel_real_subtitle,
                ),
                trailing: currentModel == GasModel.real
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setGasModel(GasModel.real);
                  Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                title: Text(context.l10n.settings_units_gasModel_ideal),
                subtitle: Text(
                  context.l10n.settings_units_gasModel_ideal_subtitle,
                ),
                trailing: currentModel == GasModel.ideal
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setGasModel(GasModel.ideal);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _plannerWaterTypeLabel(BuildContext context, PlannerWaterType type) {
    final l10n = context.l10n;
    return switch (type) {
      PlannerWaterType.salt => WaterType.salt.localizedName(l10n),
      PlannerWaterType.fresh => WaterType.fresh.localizedName(l10n),
      PlannerWaterType.custom => l10n.decoCalculator_waterType_custom,
    };
  }

  void _showPlannerWaterTypePicker(
    BuildContext context,
    WidgetRef ref,
    PlannerWaterType current,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final l10n = context.l10n;
        Widget option(PlannerWaterType value, String title) {
          return ListTile(
            title: Text(title),
            trailing: current == value
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              ref
                  .read(settingsProvider.notifier)
                  .setDefaultPlannerWaterType(value);
              Navigator.of(dialogContext).pop();
            },
          );
        }

        return AlertDialog(
          title: Text(l10n.settings_units_dialog_waterType),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(PlannerWaterType.salt, WaterType.salt.localizedName(l10n)),
              option(
                PlannerWaterType.fresh,
                WaterType.fresh.localizedName(l10n),
              ),
              option(
                PlannerWaterType.custom,
                l10n.decoCalculator_waterType_custom,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    String currentCode,
  ) {
    final current = currentCode.trim().toUpperCase();
    final codes = currencyCodesWith(current);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_defaultCurrency),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final code in codes)
                ListTile(
                  title: Text('$code  ${currencySymbol(code)}'),
                  trailing: code == current
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setDefaultCurrency(code);
                    Navigator.of(dialogContext).pop();
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.common_action_cancel),
          ),
        ],
      ),
    );
  }

  void _showTimeFormatPicker(
    BuildContext context,
    WidgetRef ref,
    TimeFormat currentFormat,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_timeFormat),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TimeFormat.values.map((format) {
            final isSelected = format == currentFormat;
            return ListTile(
              title: Text(format.localizedName(context.l10n)),
              subtitle: Text(format.example),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setTimeFormat(format);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDateFormatPicker(
    BuildContext context,
    WidgetRef ref,
    DateFormatPreference currentFormat,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_units_dialog_dateFormat),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: DateFormatPreference.values.map((format) {
              final isSelected = format == currentFormat;
              return ListTile(
                title: Text(format.displayName),
                subtitle: Text(format.example),
                trailing: isSelected
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setDateFormat(format);
                  Navigator.of(dialogContext).pop();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Appearance section content: the tablet and desktop counterpart of
/// AppearancePage, sharing its tiles from appearance_settings_tiles.dart.
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
    // Priority 1: Column config sub-page
    if (_showColumnConfig) {
      final backLabel = _columnConfigSection != null
          ? appearanceSectionDisplayName(context, _columnConfigSection!)
          : context.l10n.settings_section_appearance_title;
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('columnConfigBackButton'),
              onPressed: () => setState(() => _showColumnConfig = false),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(backLabel),
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

    // Priority 2: Language sub-page
    if (_showLanguageList) {
      return _buildLanguageSubPage(context);
    }

    // Priority 3: Section appearance sub-page
    if (_activeSectionKey != null) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('sectionBackButton'),
              onPressed: () => setState(() => _activeSectionKey = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(context.l10n.settings_section_appearance_title),
            ),
          ),
          Expanded(
            child: _activeSectionKey == 'home'
                ? const HomeAppearancePage(embedded: true)
                : SectionAppearancePage(
                    sectionKey: _activeSectionKey!,
                    embedded: true,
                    onColumnConfigTap: () {
                      setState(() {
                        _showColumnConfig = true;
                        _columnConfigSection = _activeSectionKey;
                      });
                    },
                  ),
          ),
        ],
      );
    }

    // Default: Hub view
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_appearance_general,
          ),
          const SizedBox(height: 8),
          Card(
            child: AppearanceGeneralTiles(
              separator: const Divider(height: 1),
              onLanguageTap: () => setState(() => _showLanguageList = true),
            ),
          ),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_appearance_colorAccents,
          ),
          const SizedBox(height: 8),
          const Card(
            child: AppearanceAccentTiles(separator: Divider(height: 1)),
          ),
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_appearance_sections,
          ),
          const SizedBox(height: 8),
          Card(
            child: AppearanceSectionTiles(
              separator: const Divider(height: 1),
              onSectionTap: (key) => setState(() => _activeSectionKey = key),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSubPage(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  setState(() {
                    _showLanguageList = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.settings_language_appBar_title,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Card(child: LanguageOptionTiles()),
        ],
      ),
    );
  }
}

/// Notifications section content
class _NotificationsSectionContent extends ConsumerWidget {
  final WidgetRef ref;

  const _NotificationsSectionContent({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final permissionAsync = ref.watch(notificationPermissionProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_notifications_header_serviceReminders,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    context.l10n.settings_notifications_enableServiceReminders,
                  ),
                  subtitle: Text(
                    context
                        .l10n
                        .settings_notifications_enableServiceReminders_subtitle,
                  ),
                  secondary: const Icon(Icons.notifications_active),
                  value: settings.notificationsEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Request permission when enabling
                      final granted = await NotificationService.instance
                          .requestPermission();
                      if (!granted && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context
                                  .l10n
                                  .settings_notifications_permissionRequired,
                            ),
                          ),
                        );
                        return;
                      }
                    }
                    ref
                        .read(settingsProvider.notifier)
                        .setNotificationsEnabled(value);
                  },
                ),
                if (settings.notificationsEnabled) ...[
                  const Divider(height: 1),
                  permissionAsync.when(
                    data: (granted) {
                      if (!granted) {
                        return const NotificationPermissionCard();
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
          if (settings.notificationsEnabled) ...[
            const SizedBox(height: 24),
            buildSettingsSectionHeader(
              context,
              context.l10n.settings_notifications_header_reminderSchedule,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.settings_notifications_remindBeforeDue,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [7, 14, 30].map((days) {
                        final isSelected = settings.serviceReminderDays
                            .contains(days);
                        return FilterChip(
                          label: Text(
                            context.l10n.settings_notifications_days(days),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            ref
                                .read(settingsProvider.notifier)
                                .toggleReminderDay(days);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(context.l10n.settings_notifications_reminderTime),
                subtitle: Text(
                  '${settings.reminderTime.hour.toString().padLeft(2, '0')}:${settings.reminderTime.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTimePicker(context, ref, settings),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.luggage),
                title: LabelWithControl(
                  label: Text(
                    context.l10n.settings_notifications_tripLeadTitle,
                  ),
                  control: DropdownButton<int>(
                    value: settings.tripServiceLeadDays,
                    underline: const SizedBox.shrink(),
                    // Always include the persisted value so a non-standard lead
                    // time (a future UI, manual edit, or migration) never trips
                    // DropdownButton's "value must appear in items" assertion.
                    items:
                        ({7, 14, 21, 30, settings.tripServiceLeadDays}.toList()
                              ..sort())
                            .map(
                              (days) => DropdownMenuItem(
                                value: days,
                                child: Text('$days'),
                              ),
                            )
                            .toList(),
                    onChanged: (days) {
                      if (days != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .setTripServiceLeadDays(days);
                      }
                    },
                  ),
                ),
                subtitle: Text(
                  context.l10n.settings_notifications_tripLeadDays(
                    settings.tripServiceLeadDays,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            buildSettingsInfoCard(
              context,
              context.l10n.settings_notifications_howItWorks_title,
              context.l10n.settings_notifications_howItWorks_content,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showTimePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: settings.reminderTime,
    );
    if (time != null) {
      ref.read(settingsProvider.notifier).setReminderTime(time);
    }
  }
}

// ============================================================================
// SHARED DATA SECTION
// ============================================================================

/// Shares every site the active profile owns with the profiles it picks
/// (issue #2151): Everyone, or chosen profiles. Adds only: a site already
/// shared keeps its sharing, and one site's sharing is changed on its page.
Future<void> _confirmAndBulkShareSites(
  BuildContext context,
  WidgetRef ref,
) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  if (diverId == null || !context.mounted) return;
  final owned = [
    for (final site
        in await ref.read(siteRepositoryProvider).getAllSites(diverId: diverId))
      if (site.diverId == diverId && !site.isLibrarySite) site.id,
  ];
  if (!context.mounted) return;
  if (owned.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settings_shareAll_noneToShare)),
    );
    return;
  }
  await shareItemsWithProfiles(
    context,
    ref,
    kind: SharedItemKind.site,
    ids: owned,
    activeDiverId: diverId,
    body: context.l10n.settings_shareAllSites_confirm(owned.length),
  );
}

/// Shares every item the active diver owns with the profiles picked in
/// the checklist (issue #2046). Per profile, unlike sites and trips, which
/// share with every profile at once.
Future<void> _confirmAndBulkShareEquipment(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final errorColor = Theme.of(context).colorScheme.errorContainer;
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return;
  final visible = await ref.read(allEquipmentProvider.future);
  final ownedCount = visible.where((e) => e.diverId == diverId).length;
  if (ownedCount == 0) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settings_shareAll_noneToShare)),
    );
    return;
  }
  final divers = await ref.read(allDiversProvider.future);
  final others = [
    for (final d in divers)
      if (d.id != diverId) d,
  ];
  if (others.isEmpty || !context.mounted) return;
  final chosen = await showProfileChecklistDialog(
    context,
    title: l10n.settings_shareAllEquipment_title,
    body: l10n.settings_shareAllEquipment_body(ownedCount),
    profiles: others,
    initiallySelected: const {},
    confirmLabel: l10n.common_action_share,
    allowEmpty: false,
  );
  if (chosen == null) return;
  try {
    final result = await ref
        .read(equipmentShareRepositoryProvider)
        .shareAllForDiver(ownerId: diverId, diverIds: chosen.toList());
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.equipment_bulkShare_done(result.itemsChanged)),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.common_error_tryAgain),
        backgroundColor: errorColor,
      ),
    );
  }
}

/// Shares every trip the active profile owns with the profiles it picks
/// (issue #2151): Everyone, or chosen profiles. Adds only: a trip already
/// shared keeps its sharing, and one trip's sharing is changed on its page.
Future<void> _confirmAndBulkShareTrips(
  BuildContext context,
  WidgetRef ref,
) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  if (diverId == null || !context.mounted) return;
  final owned = [
    for (final trip
        in await ref.read(tripRepositoryProvider).getAllTrips(diverId: diverId))
      if (trip.diverId == diverId) trip.id,
  ];
  if (!context.mounted) return;
  if (owned.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settings_shareAll_noneToShare)),
    );
    return;
  }
  await shareItemsWithProfiles(
    context,
    ref,
    kind: SharedItemKind.trip,
    ids: owned,
    activeDiverId: diverId,
    body: context.l10n.settings_shareAllTrips_confirm(owned.length),
  );
}

/// Shared data section content: default-sharing toggle and bulk-share actions.
///
/// Visible only when 2+ diver profiles exist. Contains:
///   1. A toggle to share new sites and trips by default.
///   2. An action to share all existing private sites.
///   3. An action to share all existing private trips.
class SharedDataSectionContent extends ConsumerWidget {
  const SharedDataSectionContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shareByDefaultAsync = ref.watch(shareByDefaultProvider);
    // A profile's hidden shared trips and sites (issue #2594).
    final hidden = ref.watch(hiddenItemsProvider).value ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_sharedData_sectionTitle,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                shareByDefaultAsync.when(
                  data: (shareByDefault) => SwitchListTile(
                    title: Text(context.l10n.settings_shareByDefault_title),
                    value: shareByDefault,
                    onChanged: (value) async {
                      try {
                        await ref
                            .read(appSettingsRepositoryProvider)
                            .setShareByDefault(value);
                        ref.invalidate(shareByDefaultProvider);
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.common_error_tryAgain),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.errorContainer,
                          ),
                        );
                      }
                    },
                  ),
                  loading: () => SwitchListTile(
                    title: Text(context.l10n.settings_shareByDefault_title),
                    value: false,
                    onChanged: null,
                  ),
                  error: (e, st) => SwitchListTile(
                    title: Text(context.l10n.settings_shareByDefault_title),
                    value: false,
                    onChanged: null,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(context.l10n.settings_shareAllSites_title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmAndBulkShareSites(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(context.l10n.settings_shareAllTrips_title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmAndBulkShareTrips(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(context.l10n.settings_shareAllEquipment_title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmAndBulkShareEquipment(context, ref),
                ),
                if (hidden.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: Text(context.l10n.settings_hiddenItems_title),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${hidden.length}'),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.push('/settings/hidden-items'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Data Sources section - surfaces HealthKit integration for App Store compliance.
///
/// Explicitly identifies Apple HealthKit usage per App Store Guideline 2.5.1:
/// - Shows "Apple HealthKit" branding prominently
/// - Lists specific HealthKit data types read (Workouts, Heart Rate)
/// - Displays current HealthKit permission status
/// - Provides clear privacy disclosure
class _DataSourcesSectionContent extends ConsumerWidget {
  const _DataSourcesSectionContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final permissionsAsync = ref.watch(healthImportPermissionStatusProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_dataSources_header,
          ),
          const SizedBox(height: 8),
          // HealthKit branding card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context
                                  .l10n
                                  .settings_dataSources_appleHealth_title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              context
                                  .l10n
                                  .settings_dataSources_appleHealth_subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Permission status
                  permissionsAsync.when(
                    data: (status) =>
                        _buildPermissionStatus(context, status: status),
                    loading: () => _buildPermissionStatus(context),
                    error: (_, _) => _buildPermissionStatus(
                      context,
                      status: HealthPermissionStatus.undetermined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.settings_dataSources_appleHealth_description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Data types card
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_dataSources_appleHealth_dataTypesHeader,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.scuba_diving),
                  title: Text(
                    context
                        .l10n
                        .settings_dataSources_appleHealth_dataTypeWorkouts,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.vertical_align_bottom),
                  title: Text(
                    context.l10n.settings_dataSources_appleHealth_dataTypeDepth,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.thermostat),
                  title: Text(
                    context
                        .l10n
                        .settings_dataSources_appleHealth_dataTypeWaterTemp,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.monitor_heart),
                  title: Text(
                    context
                        .l10n
                        .settings_dataSources_appleHealth_dataTypeHeartRate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Import action card
          Card(
            child: ListTile(
              leading: const Icon(Icons.watch),
              title: Text(
                context.l10n.settings_dataSources_appleHealth_importAction,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/wearable-import'),
            ),
          ),
          const SizedBox(height: 16),
          // Privacy and attribution
          Card(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.settings_dataSources_appleHealth_privacy,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.settings_dataSources_appleHealth_poweredBy,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Permission row for the Apple Health card.
  ///
  /// A null [status] means the check is still running. Apple never discloses
  /// read access, so [HealthPermissionStatus.undetermined] is the normal
  /// steady state on iOS and must not be painted as a refusal.
  Widget _buildPermissionStatus(
    BuildContext context, {
    HealthPermissionStatus? status,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (status == null) {
      return Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.settings_dataSources_appleHealth_permissionChecking,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final (icon, color, label) = switch (status) {
      HealthPermissionStatus.granted => (
        Icons.check_circle,
        Colors.green,
        context.l10n.settings_dataSources_appleHealth_permissionGranted,
      ),
      HealthPermissionStatus.denied => (
        Icons.cancel,
        colorScheme.error,
        context.l10n.settings_dataSources_appleHealth_permissionNotGranted,
      ),
      HealthPermissionStatus.unsupported => (
        Icons.info_outline,
        colorScheme.onSurfaceVariant,
        context.l10n.settings_dataSources_appleHealth_permissionUnsupported,
      ),
      HealthPermissionStatus.undetermined => (
        Icons.health_and_safety,
        colorScheme.onSurfaceVariant,
        context.l10n.settings_dataSources_appleHealth_permissionManagedInHealth,
      ),
    };

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// About section content with optional auto-update controls.
///
/// When [UpdateChannelConfig.isAutoUpdateEnabled] is true (non-store builds),
/// an Updates card is shown with check-for-update, auto-update toggle,
/// and last-checked timestamp.
class _AboutSectionContent extends ConsumerStatefulWidget {
  const _AboutSectionContent();

  @override
  ConsumerState<_AboutSectionContent> createState() =>
      _AboutSectionContentState();
}

class _AboutSectionContentState extends ConsumerState<_AboutSectionContent> {
  int _tapCount = 0;

  @override
  Widget build(BuildContext context) {
    final packageInfoAsync = ref.watch(packageInfoProvider);
    final isBetaChannel =
        UpdateChannelConfig.isAutoUpdateEnabled &&
        ref.watch(releaseChannelProvider) == ReleaseChannel.beta;
    final versionString = packageInfoAsync.when(
      data: (info) {
        final version = formatAppVersion(info);
        final base = context.l10n.settings_about_version(version);
        return isBetaChannel
            ? context.l10n.settings_updates_channelBadgeBeta(base)
            : base;
      },
      loading: () => '',
      error: (_, _) => '',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_about_header,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(context.l10n.settings_about_aboutSubmersion),
                  onTap: () => _showAboutDialog(context, versionString),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(context.l10n.settings_about_openSourceLicenses),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: context.l10n.settings_about_appName,
                      applicationVersion: versionString,
                    );
                  },
                ),
                // Beta enrollment signpost for store builds: the app cannot
                // switch channels itself there, so link to the store's beta
                // program. Null on every build that has its own updater, and
                // on platforms whose program is not live.
                if (betaEnrollUrl case final enrollUrl?) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: Text(context.l10n.settings_updates_joinBeta),
                    subtitle: Text(
                      context.l10n.settings_updates_joinBetaSubtitle,
                    ),
                    onTap: () => launchUrl(
                      Uri.parse(enrollUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: Text(context.l10n.settings_about_reportIssue),
                  onTap: () => launchReportIssue(context),
                ),
                // The CC BY bathymetry credit lives on the license page
                // (BathymetryAttribution), not in this card.
              ],
            ),
          ),
          // Auto-update section (only for non-store builds)
          if (UpdateChannelConfig.isAutoUpdateEnabled) ...[
            const SizedBox(height: 24),
            buildSettingsSectionHeader(
              context,
              context.l10n.settings_updates_header,
            ),
            const SizedBox(height: 8),
            _buildUpdatesCard(context),
          ],
          const SizedBox(height: 24),
          buildSettingsSectionHeader(
            context,
            context.l10n.settings_diagnostics_header,
          ),
          const SizedBox(height: 8),
          const DiagnosticsCard(),
          const SizedBox(height: 24),
          // App info card
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.settings_about_appName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    _tapCount++;
                    if (_tapCount >= 5) {
                      _tapCount = 0;
                      ref.read(debugModeNotifierProvider.notifier).enable();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debug mode enabled'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Text(
                    versionString,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesCard(BuildContext context) {
    final updateStatus = ref.watch(updateStatusProvider);
    final prefs = ref.watch(updatePreferencesProvider);
    final channel = ref.watch(releaseChannelProvider);

    final statusText = switch (updateStatus) {
      UpToDate() => context.l10n.settings_updates_upToDate,
      Checking() => context.l10n.settings_updates_checking,
      UpdateAvailable(:final version) =>
        context.l10n.settings_updates_versionAvailable(version),
      Downloading(:final progress) => context.l10n.settings_updates_downloading(
        (progress * 100).toInt().toString(),
      ),
      ReadyToInstall(:final version) =>
        context.l10n.settings_updates_readyToInstall(version),
      UpdateError(:final message) => context.l10n.settings_updates_error(
        message,
      ),
    };

    // #1512: this stamp was hand-rolled as M/D/YYYY with a 24-hour clock, so
    // it ignored both the date and the time preference.
    final units = UnitFormatter(ref.watch(settingsProvider));
    final lastCheck = prefs.lastCheckTime;
    final lastCheckText = lastCheck != null
        ? units.formatDateTime(lastCheck, l10n: context.l10n)
        : context.l10n.settings_updates_never;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(context.l10n.settings_updates_checkForUpdates),
            subtitle: Text(statusText),
            onTap: updateStatus is Checking
                ? null
                : () => ref
                      .read(updateStatusProvider.notifier)
                      .checkForUpdateInteractively(),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.auto_mode),
            title: Text(context.l10n.settings_updates_automaticUpdates),
            subtitle: Text(
              context.l10n.settings_updates_automaticUpdatesSubtitle,
            ),
            value: prefs.autoUpdateEnabled,
            onChanged: (value) async {
              await prefs.setAutoUpdateEnabled(value);
              ref.invalidate(updatePreferencesProvider);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.alt_route),
            title: Text(context.l10n.settings_updates_channel),
            subtitle: Text(
              channel == ReleaseChannel.beta
                  ? context.l10n.settings_updates_channelBeta
                  : context.l10n.settings_updates_channelStable,
            ),
            onTap: () => _showChannelPicker(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(context.l10n.settings_updates_lastChecked),
            subtitle: Text(lastCheckText),
          ),
        ],
      ),
    );
  }

  Future<void> _showChannelPicker(BuildContext context) async {
    final current = ref.read(releaseChannelProvider);
    final selected = await showDialog<ReleaseChannel>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.settings_updates_channel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final channel in ReleaseChannel.values)
              ListTile(
                title: Text(switch (channel) {
                  ReleaseChannel.stable =>
                    ctx.l10n.settings_updates_channelStable,
                  ReleaseChannel.beta => ctx.l10n.settings_updates_channelBeta,
                }),
                subtitle: Text(switch (channel) {
                  ReleaseChannel.stable =>
                    ctx.l10n.settings_updates_channelStableSubtitle,
                  ReleaseChannel.beta =>
                    ctx.l10n.settings_updates_channelBetaSubtitle,
                }),
                trailing: channel == current
                    ? Icon(
                        Icons.check,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(channel),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == current || !context.mounted) return;

    // Both directions are confirmed. Leaving beta keeps this build, and the
    // dive log it may have upgraded, until stable catches up, and stable
    // peers cannot read its changes meanwhile (issue #2619).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(switch (selected) {
          ReleaseChannel.beta => ctx.l10n.settings_updates_betaDialogTitle,
          ReleaseChannel.stable => ctx.l10n.settings_updates_stableDialogTitle,
        }),
        content: Text(switch (selected) {
          ReleaseChannel.beta => ctx.l10n.settings_updates_betaDialogBody,
          ReleaseChannel.stable => ctx.l10n.settings_updates_stableDialogBody,
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(switch (selected) {
              ReleaseChannel.beta =>
                ctx.l10n.settings_updates_betaDialogConfirm,
              ReleaseChannel.stable =>
                ctx.l10n.settings_updates_stableDialogConfirm,
            }),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = ref.read(updatePreferencesProvider);
    await prefs.setReleaseChannel(selected);
    ref.invalidate(updatePreferencesProvider);
    // releaseChannelProvider and updateServiceProvider re-derive from the
    // invalidated preferences; the fresh service applies the new feed on
    // its next check.
    if (!mounted || !context.mounted) return;
    await ref.read(updateStatusProvider.notifier).checkForUpdate();
  }

  void _showAboutDialog(BuildContext context, String versionString) {
    showAboutDialog(
      context: context,
      applicationName: context.l10n.settings_about_appName,
      applicationVersion: versionString,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/icon/icon.png', width: 64, height: 64),
      ),
      children: [Text(context.l10n.settings_about_description)],
    );
  }
}

/// Picks the place name language and, when it changed, offers to look the
/// diver's sites up again in the new language.
///
/// Without that offer a change quietly splits the database: sites geocoded
/// before it keep their old names, so statistics group one region under two
/// spellings (issue #1187). The refresh flow asks for confirmation itself,
/// so a diver who only wants the language changed can decline.
Future<void> _pickPlaceNameLanguage(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
) async {
  final previous = settings.placeNameLanguage;
  final chosen = await showPlaceNameLanguagePicker(context, ref, settings);
  if (chosen == null || chosen == previous || !context.mounted) return;
  await showSiteLocationBackfillFlow(
    context,
    ref,
    mode: SiteLocationLookupMode.refreshAll,
  );
}
