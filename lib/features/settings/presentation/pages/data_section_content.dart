import 'package:flutter/material.dart';

import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_row_status_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_facts_line.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_health_strip.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_row_status_text.dart';
import 'package:submersion/features/settings/presentation/widgets/data_row_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Data: the health strip and facts line (#3390), then the five
/// "Your data" rows, each with the strip's health mark (#3394) and a
/// one-sentence status, then the rarely used rows under "Advanced" (#3482).
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
    final now = DateTime.now();
    final isCustomFolder =
        ref.watch(storageConfigNotifierProvider).config.mode ==
        StorageLocationMode.customFolder;
    final health = {
      for (final h in ref.watch(dataHealthProvider)) h.feature: h,
    };

    Widget feature({
      required IconData icon,
      required String title,
      required DataRowStatus status,
      required String route,
      DataFeature? healthOf,
    }) => DataRowTile(
      icon: icon,
      title: title,
      subtitle: dataRowStatusText(l10n, status, now),
      route: route,
      health: healthOf == null ? null : health[healthOf],
      offersSetUp: status.offersSetUp,
    );

    Widget advanced(
      IconData icon,
      String title,
      String subtitle,
      String route,
    ) =>
        DataRowTile(icon: icon, title: title, subtitle: subtitle, route: route);

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
          _header(context, l10n.settings_data_header_yourData),
          feature(
            icon: Icons.backup,
            title: l10n.settings_backups_title,
            status: ref.watch(backupsRowStatusProvider),
            route: '/settings/backup',
            healthOf: DataFeature.backup,
          ),
          // Available on every platform (iCloud on Apple devices, other
          // accounts everywhere); the sync page gates which each one sees.
          feature(
            icon: Icons.cloud_sync,
            title: l10n.settings_sync_title,
            status: ref.watch(syncRowStatusProvider),
            route: '/settings/cloud-sync',
            healthOf: DataFeature.sync,
          ),
          feature(
            icon: Icons.perm_media_outlined,
            title: l10n.settings_photosVideos_title,
            status: ref.watch(photosRowStatusProvider),
            route: '/settings/photos-media',
            healthOf: DataFeature.media,
          ),
          // Shared site libraries (issue #2567).
          feature(
            icon: Icons.groups_outlined,
            title: l10n.sharedLibrary_settings_title,
            status: ref.watch(librariesRowStatusProvider),
            route: '/settings/shared-libraries',
            healthOf: DataFeature.sharedLibraries,
          ),
          // The accounts behind sync, media storage and shared libraries;
          // its own entry so it is not filed under one of them (#3388).
          feature(
            icon: Icons.account_circle_outlined,
            title: l10n.settings_connectedAccounts_title,
            status: ref.watch(accountsRowStatusProvider),
            route: '/settings/connected-accounts',
          ),
          const SizedBox(height: 16),
          _header(context, l10n.settings_data_header_advanced),
          advanced(
            Icons.folder,
            l10n.settings_data_databaseStorage,
            isCustomFolder
                ? l10n.settings_data_customFolder
                : l10n.settings_data_appDefaultLocation,
            '/settings/storage',
          ),
          advanced(
            Icons.cloud_download,
            l10n.settings_data_offlineMaps,
            l10n.settings_data_offlineMaps_subtitle,
            '/settings/offline-maps',
          ),
          advanced(
            Icons.input,
            l10n.settings_data_importOptions,
            l10n.settings_data_importOptions_subtitle,
            '/settings/import-options',
          ),
          advanced(
            Icons.build_outlined,
            l10n.settings_data_dataTools,
            l10n.settings_data_dataTools_subtitle,
            '/settings/data-tools',
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: buildSettingsSectionHeader(context, title),
  );
}
