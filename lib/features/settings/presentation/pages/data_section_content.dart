import 'package:flutter/material.dart';

import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_row_status_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_facts_line.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_health_strip.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_row_status_text.dart';
import 'package:submersion/features/settings/presentation/widgets/data_row_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_device_card.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_route.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_section_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/device_kind.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_enter_dialog.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_exit_confirm.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Settings > Data: the health strip, the Set up this device card and the
/// facts line (#3390, #3482), then the five "Your data" rows, each with the
/// strip's health mark (#3394) and a one-sentence status, then the rarely
/// used rows under "Advanced" (#3482), demo mode's among them (#3736).
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
    // Only whether the card is hidden or complete matters here; a change
    // to its marks rebuilds the card alone.
    final offerSetUpAgain = ref.watch(
      setUpProgressProvider.select((p) => p != null && !p.showsSteps),
    );

    // Demo mode (issue #3708): features that would reach the user's real
    // data stay visible but unavailable.
    final demoActive = ref.watch(demoModeActiveProvider);
    final demoPackage = ref.watch(demoAvailabilityProvider).value;

    Widget feature({
      required IconData icon,
      required String title,
      required DataRowStatus status,
      required String route,
      DataFeature? healthOf,
      SetUpStep? setUpStep,
    }) => DataRowTile(
      icon: icon,
      title: title,
      subtitle: dataRowStatusText(l10n, status, now),
      route: route,
      enabled: !demoActive,
      health: healthOf == null || !status.showsHealthMark
          ? null
          : health[healthOf],
      offersSetUp: status.offersSetUp,
      setUpRoute: setUpStep == null ? null : setUpStepRoute(setUpStep),
    );

    Widget advanced(
      IconData icon,
      String title,
      String subtitle,
      String route, {
      bool sealed = false,
    }) => DataRowTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      route: route,
      enabled: !(sealed && demoActive),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // In demo mode the strip could only recommend sealed backups and
          // sync, so it goes with the set-up card.
          if (!demoActive) ...[
            const DataHealthStrip(),
            const SizedBox(height: 12),
            const SetUpDeviceCard(margin: EdgeInsets.only(bottom: 12)),
          ],
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
            setUpStep: SetUpStep.backups,
          ),
          // Available on every platform (iCloud on Apple devices, other
          // accounts everywhere); the sync page gates which each one sees.
          feature(
            icon: Icons.cloud_sync,
            title: l10n.settings_sync_title,
            status: ref.watch(syncRowStatusProvider),
            route: '/settings/cloud-sync',
            healthOf: DataFeature.sync,
            // Offered only while sync is off, when step 2 has no account to
            // read: the account step starts from the current one.
            setUpStep: SetUpStep.account,
          ),
          feature(
            icon: Icons.perm_media_outlined,
            title: l10n.settings_photosVideos_title,
            status: ref.watch(photosRowStatusProvider),
            route: '/settings/photos-media',
            healthOf: DataFeature.media,
            setUpStep: SetUpStep.photos,
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
            sealed: true,
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
          // Reopens the flow from its first step once the card is hidden or
          // complete; a hidden card shows again.
          if (offerSetUpAgain && !demoActive)
            DataRowTile(
              icon: Icons.restart_alt,
              title: l10n.settings_setUpDevice_again(
                deviceKindArg(deviceKindOf(context)),
              ),
              subtitle: l10n.settings_setUpDevice_againSubtitle,
              route: setUpAgainRoute,
            ),
          // Rarely used, so last under Advanced rather than beside the user's
          // real data (#3736).
          if (demoActive)
            DataRowTile(
              icon: Icons.logout,
              title: l10n.demo_settings_exit_title,
              subtitle: l10n.demo_settings_exit_subtitle,
              onTap: () => confirmAndExitDemo(context, ref),
            )
          else if (demoPackage != null)
            DataRowTile(
              icon: Icons.explore_outlined,
              title: l10n.demo_settings_enter_title,
              subtitle: l10n.demo_settings_enter_subtitle,
              onTap: () => askAndEnterDemo(
                context,
                fromFirstRun: false,
                package: demoPackage,
                units: demoUnitsFromSettings(ref.read(settingsProvider)),
              ),
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
