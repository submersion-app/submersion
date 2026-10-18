import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_facts_line.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_health_strip.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/features/settings/presentation/widgets/import_preferences_group.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Data: the health strip and facts line (#3390) above the
/// existing entries, all flat, with the four feature rows marked by the same
/// health symbol as the strip (#3394).
class DataSectionContent extends ConsumerStatefulWidget {
  const DataSectionContent({super.key});

  @override
  ConsumerState<DataSectionContent> createState() => _DataSectionContentState();
}

class _DataSectionContentState extends ConsumerState<DataSectionContent> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The WorkManager backup job writes from another isolate, and the facts
    // are a snapshot: refresh both when the page opens and each time the app
    // comes back while it is showing.
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    // The facts provider is autoDispose, so opening the page loads it fresh.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadBackup());
  }

  void _reloadBackup() {
    if (!mounted) return;
    ref.read(backupSettingsProvider.notifier).reloadFromDisk();
  }

  void _onResume() {
    if (!mounted) return;
    _reloadBackup();
    ref.invalidate(dataFactsProvider);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final storageState = ref.watch(storageConfigNotifierProvider);
    final isCustomFolder =
        storageState.config.mode == StorageLocationMode.customFolder;
    final health = {
      for (final h in ref.watch(dataHealthProvider)) h.feature: h,
    };

    Widget featureTitle(String title, DataFeature feature) {
      final h = health[feature];
      if (h == null || h.level == HealthLevel.notSetUp) return Text(title);
      return Row(
        children: [
          Flexible(child: Text(title)),
          const SizedBox(width: 8),
          HealthSymbol(
            level: h.level,
            size: 16,
            semanticLabel: healthSemanticsLabel(l10n, h),
          ),
        ],
      );
    }

    Widget tile({
      required IconData icon,
      required Widget title,
      Widget? subtitle,
      required String route,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: title,
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.pushSettingsPage(route),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DataHealthStrip(),
          const SizedBox(height: 12),
          const DataFactsLine(),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _header(context, l10n.settings_data_header_backupSync),
          tile(
            icon: Icons.backup,
            title: featureTitle(l10n.settings_data_backup, DataFeature.backup),
            subtitle: _backupSubtitle(context),
            route: '/settings/backup',
          ),
          // Cloud sync is available on every platform (iCloud on Apple
          // devices, S3-compatible storage elsewhere); the Cloud Sync page
          // gates which providers each platform sees.
          tile(
            icon: Icons.cloud_sync,
            title: featureTitle(
              l10n.settings_cloudSync_appBar_title,
              DataFeature.sync,
            ),
            subtitle: _syncSubtitle(context, health[DataFeature.sync]),
            route: '/settings/cloud-sync',
          ),
          // Shared site libraries (issue #2567).
          tile(
            icon: Icons.groups_outlined,
            title: featureTitle(
              l10n.sharedLibrary_settings_title,
              DataFeature.sharedLibraries,
            ),
            subtitle: Text(l10n.sharedLibrary_settings_subtitle),
            route: '/settings/shared-libraries',
          ),
          tile(
            icon: Icons.perm_media_outlined,
            title: featureTitle(
              l10n.settings_photosMedia_title,
              DataFeature.media,
            ),
            subtitle: Text(l10n.settings_photosMedia_subtitle),
            route: '/settings/photos-media',
          ),
          // The accounts behind sync, media storage and shared libraries;
          // its own entry so it is not filed under one of them (issue
          // #3388). This is the only entry point since Photos & Media
          // dropped its link (issue #3460).
          tile(
            icon: Icons.account_circle_outlined,
            title: Text(l10n.settings_connectedAccounts_title),
            subtitle: Text(l10n.settings_connectedAccounts_subtitle),
            route: '/settings/connected-accounts',
          ),
          const SizedBox(height: 16),
          _header(context, l10n.settings_data_header_storage),
          tile(
            icon: Icons.folder,
            title: Text(l10n.settings_data_databaseStorage),
            subtitle: Text(
              isCustomFolder
                  ? l10n.settings_data_customFolder
                  : l10n.settings_data_appDefaultLocation,
            ),
            route: '/settings/storage',
          ),
          tile(
            icon: Icons.cloud_download,
            title: Text(l10n.settings_data_offlineMaps),
            subtitle: Text(l10n.settings_data_offlineMaps_subtitle),
            route: '/settings/offline-maps',
          ),
          const SizedBox(height: 16),
          _header(context, l10n.settings_data_header_import),
          const ImportPreferencesGroup(),
          const SizedBox(height: 16),
          _header(context, l10n.settings_data_header_dataTools),
          tile(
            icon: Icons.access_time,
            title: Text(l10n.settings_fixDiveTimes_title),
            subtitle: Text(l10n.settings_fixDiveTimes_subtitle),
            route: '/settings/fix-dive-times',
          ),
          tile(
            icon: Icons.group_add,
            title: Text(l10n.buddies_linkText_page_title),
            subtitle: Text(l10n.buddies_linkText_page_subtitle),
            route: '/settings/link-buddy-names',
          ),
          tile(
            icon: Icons.category,
            title: Text(l10n.equipment_retypeOther_title),
            subtitle: Text(l10n.equipment_retypeOther_subtitle),
            route: '/settings/retype-other-gear',
          ),
          tile(
            icon: Icons.rule,
            title: Text(l10n.dataQuality_settings_title),
            subtitle: Text(l10n.dataQuality_settings_subtitle),
            route: '/settings/data-quality',
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: buildSettingsSectionHeader(context, title),
  );

  Widget _backupSubtitle(BuildContext context) {
    final l10n = context.l10n;
    final lastBackup = ref.watch(lastBackupTimeProvider);
    if (lastBackup == null) return Text(l10n.settings_data_backup_subtitle);
    return Text(
      l10n.backup_status_lastBackup(
        relativeAgo(l10n, lastBackup, DateTime.now()),
      ),
    );
  }

  /// "Synced 12m ago · 3 devices" while sync is in use. Signing out keeps
  /// the last sync timestamp, so the row follows the strip's verdict rather
  /// than the timestamp alone.
  Widget _syncSubtitle(BuildContext context, FeatureHealth? syncHealth) {
    final l10n = context.l10n;
    final lastSync = ref.watch(lastSyncTimeProvider);
    final inUse =
        syncHealth != null &&
        syncHealth.level != HealthLevel.notSetUp &&
        syncHealth.reason != HealthReason.syncOff;
    if (lastSync == null || !inUse) {
      return Text(l10n.settings_cloudSync_entry_subtitle);
    }
    final when = relativeAgo(l10n, lastSync, DateTime.now());
    final devices = ref.watch(syncedDeviceCountProvider);
    return Text(
      devices > 1
          ? l10n.dataHealth_sync_rowSubtitleDevices(when, devices)
          : l10n.dataHealth_sync_rowSubtitle(when),
    );
  }
}
