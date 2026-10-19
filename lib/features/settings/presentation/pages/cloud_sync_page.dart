import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/sync/library_moved.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart'
    show StoragePlatformCapabilities, storagePlatformCapabilitiesProvider;
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/pages/troubleshoot_sync_page.dart';
import 'package:submersion/features/settings/presentation/widgets/newer_schema_peer_banner.dart';
import 'package:submersion/features/settings/presentation/widgets/older_schema_peer_banner.dart';
import 'package:submersion/features/settings/presentation/widgets/read_failed_peer_banner.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/features/settings/presentation/widgets/skipped_peer_banner.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_now_action.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_advanced_section.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_using_row.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_resolution_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_settings_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

part 'cloud_sync_page_banners.dart';

class CloudSyncPage extends ConsumerStatefulWidget {
  const CloudSyncPage({super.key});

  @override
  ConsumerState<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends ConsumerState<CloudSyncPage>
    with _SyncBanners {
  @override
  void initState() {
    super.initState();
    // Recompute on entry. SyncState's counts and cursor are otherwise only
    // written by a sync, so without this the page could report the state as of
    // whenever the notifier was built -- the stale reading behind issue #990.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(syncStateProvider.notifier).refreshState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);
    final selectedProvider = ref.watch(selectedCloudProviderTypeProvider);
    // A persisted Google Drive selection must not enable Sync Now on a build
    // where Drive is unavailable (e.g. a desktop build without the OAuth
    // client compiled in): the account sheet offers no Google Drive there,
    // so an enabled Sync Now with no usable provider would be inconsistent.
    final googleDriveAvailable =
        ref.watch(googleDriveAvailableProvider).value ?? false;
    final selectionUsable =
        selectedProvider != CloudProviderType.googledrive ||
        googleDriveAvailable;
    final hasProvider = selectedProvider != null && selectionUsable;
    final isCustomFolderMode = ref.watch(
      isCloudSyncDisabledByCustomFolderProvider,
    );
    final behaviorSettings = ref.watch(syncBehaviorProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_sync_title)),
      body: ListView(
        children: [
          // Show banner when custom folder mode is active
          if (isCustomFolderMode)
            _buildCustomFolderBanner(
              context,
              ref.watch(storagePlatformCapabilitiesProvider),
            ),
          // Surface apparent duplicate diver profiles created across devices.
          _buildDuplicateDiversBanner(context, ref),
          // The account sync uses, first, as on every feature page.
          const SyncUsingRow(),
          _buildSyncStatusCard(context, ref, syncState),
          const Divider(),
          _buildSyncActions(context, ref, syncState, hasProvider),
          if (syncState.conflicts > 0) ...[
            const Divider(),
            _buildConflictsSection(context, ref, syncState),
          ],
          const Divider(),
          SwitchListTile(
            key: const Key('sync-keep-in-step'),
            title: Text(context.l10n.settings_sync_keepInStep),
            subtitle: Text(context.l10n.settings_cloudSync_autoSync_subtitle),
            value: behaviorSettings.autoSyncEnabled,
            onChanged: isCustomFolderMode
                ? null
                : (value) => ref
                      .read(syncBehaviorProvider.notifier)
                      .setAutoSyncEnabled(value),
          ),
          const Divider(),
          SyncAdvancedSection(hasProvider: hasProvider),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard(
    BuildContext context,
    WidgetRef ref,
    SyncState syncState,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Semantics(
      label: [
        _getStatusTitle(l10n, syncState.status),
        if (syncState.lastSync != null)
          l10n.settings_cloudSync_lastSynced(
            _formatDateTime(l10n, syncState.lastSync!),
          ),
        if (syncState.pendingChanges > 0)
          l10n.settings_cloudSync_pendingChanges(syncState.pendingChanges),
      ].join(', '),
      liveRegion: syncState.status == SyncStatus.syncing,
      child: Card(
        margin: const EdgeInsets.all(16),
        // On an error, the whole card is a shortcut into Troubleshoot Sync so a
        // stuck user finds the way out where the error is shown (issue #509).
        child: InkWell(
          onTap: syncState.status == SyncStatus.error
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TroubleshootSyncPage(),
                  ),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(child: _buildStatusIcon(syncState.status)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusTitle(l10n, syncState.status),
                            style: theme.textTheme.titleMedium,
                          ),
                          if (syncState.message != null)
                            Text(
                              syncState.message!,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    if (syncState.status == SyncStatus.error)
                      const Icon(Icons.chevron_right),
                  ],
                ),
                if (syncState.status == SyncStatus.syncing &&
                    syncState.progress != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    label: l10n.settings_cloudSync_syncProgressPercent(
                      (syncState.progress! * 100).toStringAsFixed(0),
                    ),
                    child: LinearProgressIndicator(value: syncState.progress),
                  ),
                ],
                if (syncState.lastSync != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.settings_cloudSync_lastSynced(
                      _formatDateTime(l10n, syncState.lastSync!),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (syncState.pendingChanges > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.settings_cloudSync_pendingChanges(
                      syncState.pendingChanges,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return const Icon(Icons.cloud_outlined, size: 32);
      case SyncStatus.syncing:
        return const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncStatus.success:
        return const Icon(Icons.cloud_done, size: 32, color: Colors.green);
      case SyncStatus.error:
        return const Icon(Icons.cloud_off, size: 32, color: Colors.red);
      case SyncStatus.hasConflicts:
        return const Icon(Icons.warning, size: 32, color: Colors.orange);
    }
  }

  String _getStatusTitle(AppLocalizations l10n, SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return l10n.settings_cloudSync_status_readyToSync;
      case SyncStatus.syncing:
        return l10n.settings_cloudSync_status_syncing;
      case SyncStatus.success:
        return l10n.settings_cloudSync_status_syncComplete;
      case SyncStatus.error:
        return l10n.settings_cloudSync_status_syncError;
      case SyncStatus.hasConflicts:
        return l10n.settings_cloudSync_status_conflictsDetected;
    }
  }

  Widget _buildSyncActions(
    BuildContext context,
    WidgetRef ref,
    SyncState syncState,
    bool hasProvider,
  ) {
    final isSyncing = syncState.status == SyncStatus.syncing;
    final selectedProvider = ref.watch(selectedCloudProviderTypeProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (syncState.replaceAwaitingAdoption)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.restore_page_outlined,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.settings_cloudSync_replace_banner(
                            syncState.replaceMarker?.displayName ?? '?',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (syncState.needsPassphrase)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context
                                  .l10n
                                  .settings_cloudSync_encryption_statusLockedSubtitle,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => runEncryptionUnlockFlow(context, ref),
                        child: Text(
                          context
                              .l10n
                              .settings_cloudSync_encryption_enterPassphrase,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (syncState.firstSyncAwaitingConfirmation)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(
                          context,
                        ).colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.settings_cloudSync_firstSync_banner,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SkippedPeerBanner(peers: syncState.skippedPeerLabels),
          NewerSchemaPeerBanner(
            peers: syncState.newerSchemaPeerLabels,
            releaseChannel: ref.watch(releaseChannelProvider),
          ),
          OlderSchemaPeerBanner(peers: syncState.olderSchemaPeerLabels),
          ReadFailedPeerBanner(peers: syncState.readFailedPeerLabels),
          if (syncState.movedMarker != null)
            _buildMovedBanner(context, ref, syncState.movedMarker!),
          // Not while sync is back on that kind: the delete reaches the kind's
          // one settings instance, which then points at the account sync
          // uses now, not the one left.
          if (syncState.cleanupOldBackendProviderId != null &&
              syncState.cleanupOldBackendProviderId != selectedProvider?.name)
            _buildCleanupOfferBanner(
              context,
              ref,
              syncState.cleanupOldBackendProviderId!,
            ),
          FilledButton.icon(
            onPressed: isSyncing || !hasProvider
                ? null
                : () => _onSyncNowPressed(context, ref),
            icon: isSyncing
                ? const ExcludeSemantics(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Icon(Icons.sync),
            label: Text(
              isSyncing
                  ? context.l10n.settings_cloudSync_status_syncing
                  : context.l10n.settings_cloudSync_syncNow,
            ),
          ),
          if (!hasProvider)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.settings_cloudSync_selectProviderHint,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConflictsSection(
    BuildContext context,
    WidgetRef ref,
    SyncState syncState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                context.l10n.settings_cloudSync_header_conflicts(
                  syncState.conflicts,
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: Colors.orange),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.merge_type),
          title: Text(context.l10n.settings_cloudSync_resolveConflicts),
          subtitle: Text(
            context.l10n.settings_cloudSync_conflictItems(syncState.conflicts),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showConflictResolution(context, ref),
        ),
      ],
    );
  }

  Future<void> _showConflictResolution(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => const ConflictResolutionDialog(),
    );
    // Refresh state after resolving conflicts
    ref.read(syncStateProvider.notifier).refreshState();
  }

  /// The gated sync flow lives in [runSyncNow]: the Home sync chip runs it too.
  Future<void> _onSyncNowPressed(BuildContext context, WidgetRef ref) =>
      runSyncNow(context, ref);

  String _formatDateTime(AppLocalizations l10n, DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return l10n.settings_cloudSync_time_justNow;
    } else if (difference.inHours < 1) {
      return l10n.settings_cloudSync_time_minutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return l10n.settings_cloudSync_time_hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.settings_cloudSync_time_daysAgo(difference.inDays);
    } else {
      // watch, not read: both callers render this into the widget tree, so a
      // preference change while the page is open must repaint it.
      return UnitFormatter(ref.watch(settingsProvider)).formatDate(dateTime);
    }
  }
}
