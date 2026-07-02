import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/sync/library_moved.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_resolution_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Localized connection-failure message for a cloud provider. For iCloud the
/// wording reflects the real [iCloudAvailability] state; other providers (and a
/// genuinely-available iCloud that still failed) get the generic message.
///
/// Pure (no `BuildContext`/`ref`) so it is unit-testable on any host.
@visibleForTesting
String connectionErrorMessage(
  AppLocalizations l10n,
  CloudProviderType provider,
  ICloudAvailability? iCloudAvailability,
  String providerName,
  String error,
) {
  if (provider == CloudProviderType.icloud) {
    switch (iCloudAvailability) {
      case ICloudAvailability.unsupported:
        return l10n.settings_cloudSync_error_icloudUnsupported;
      case ICloudAvailability.signedOut:
        return l10n.settings_cloudSync_error_icloudSignedOut;
      case ICloudAvailability.unknown:
      case null:
        return l10n.settings_cloudSync_error_icloudUnknown;
      case ICloudAvailability.available:
        break; // genuine failure despite availability — use the generic message
    }
  }
  return l10n.settings_cloudSync_provider_connectionFailed(providerName, error);
}

class CloudSyncPage extends ConsumerWidget {
  const CloudSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final selectedProvider = ref.watch(selectedCloudProviderTypeProvider);
    final hasProvider = selectedProvider != null;
    final isCustomFolderMode = ref.watch(
      isCloudSyncDisabledByCustomFolderProvider,
    );
    final behaviorSettings = ref.watch(syncBehaviorProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_cloudSync_appBar_title)),
      body: ListView(
        children: [
          // Show banner when custom folder mode is active
          if (isCustomFolderMode) _buildCustomFolderBanner(context),
          // Surface apparent duplicate diver profiles created across devices.
          _buildDuplicateDiversBanner(context, ref),
          _buildSyncStatusCard(context, ref, syncState),
          const Divider(),
          _buildProviderSection(context, ref, selectedProvider),
          const Divider(),
          _buildSyncActions(context, ref, syncState, hasProvider),
          if (syncState.conflicts > 0) ...[
            const Divider(),
            _buildConflictsSection(context, ref, syncState),
          ],
          const Divider(),
          _buildBehaviorSection(
            context,
            ref,
            behaviorSettings,
            isCustomFolderMode,
          ),
          const Divider(),
          _buildAdvancedSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildCustomFolderBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.settings_cloudSync_disabledBanner_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.settings_cloudSync_disabledBanner_content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings/storage'),
            icon: const Icon(Icons.settings),
            label: const Text('Storage Settings'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              side: BorderSide(color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner shown when two or more diver profiles share a name -- the typical
  /// result of each device auto-creating its own owner diver before the first
  /// sync. Offers a one-tap merge per duplicate group.
  Widget _buildDuplicateDiversBanner(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(duplicateDiverGroupsProvider);
    final groups = groupsAsync.asData?.value ?? const [];
    if (groups.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.merge_type, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.settings_cloudSync_duplicateDivers_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settings_cloudSync_duplicateDivers_description,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.settings_cloudSync_duplicateDivers_groupLabel(
                        group.displayName,
                        group.duplicates.length + 1,
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _confirmAndMerge(context, ref, group),
                    child: Text(
                      l10n.settings_cloudSync_duplicateDivers_mergeButton,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAndMerge(
    BuildContext context,
    WidgetRef ref,
    DuplicateDiverGroup group,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogL10n = context.l10n;
        return AlertDialog(
          title: Text(
            dialogL10n.settings_cloudSync_duplicateDivers_confirmTitle,
          ),
          content: Text(
            dialogL10n.settings_cloudSync_duplicateDivers_confirmBody(
              group.duplicates.length,
              group.displayName,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                dialogL10n.settings_cloudSync_duplicateDivers_confirmCancel,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                dialogL10n.settings_cloudSync_duplicateDivers_confirmAction,
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final repo = ref.read(diverMergeRepositoryProvider);
    try {
      // Collect every snapshot so the whole group merge can be undone, not
      // just the last duplicate.
      final snapshots = <DiverMergeSnapshot>[];
      for (final duplicate in group.duplicates) {
        snapshots.add(
          await repo.mergeDivers(
            keeperId: group.keeper.id,
            duplicateId: duplicate.id,
          ),
        );
      }
      ref.invalidate(allDiversProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.settings_cloudSync_duplicateDivers_successSnack(
              group.displayName,
            ),
          ),
          action: SnackBarAction(
            label: l10n.settings_cloudSync_duplicateDivers_undo,
            onPressed: () => _undoMerge(ref, repo, snapshots),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.settings_cloudSync_duplicateDivers_failureSnack(e.toString()),
          ),
        ),
      );
    }
  }

  /// Reverse every snapshot from a group merge, newest first (so a row touched
  /// by two duplicates is restored to its true original).
  Future<void> _undoMerge(
    WidgetRef ref,
    DiverMergeRepository repo,
    List<DiverMergeSnapshot> snapshots,
  ) async {
    for (final snapshot in snapshots.reversed) {
      await repo.undoMerge(snapshot);
    }
    ref.invalidate(allDiversProvider);
  }

  Widget _buildSyncStatusCard(
    BuildContext context,
    WidgetRef ref,
    SyncState syncState,
  ) {
    final theme = Theme.of(context);

    return Semantics(
      label:
          _getStatusTitle(syncState.status) +
          (syncState.lastSync != null
              ? ', last synced ${_formatDateTime(syncState.lastSync!)}'
              : '') +
          (syncState.pendingChanges > 0
              ? ', ${syncState.pendingChanges} pending changes'
              : ''),
      liveRegion: syncState.status == SyncStatus.syncing,
      child: Card(
        margin: const EdgeInsets.all(16),
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
                          _getStatusTitle(syncState.status),
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
                ],
              ),
              if (syncState.status == SyncStatus.syncing &&
                  syncState.progress != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  label:
                      'Sync progress: ${(syncState.progress! * 100).toStringAsFixed(0)} percent',
                  child: LinearProgressIndicator(value: syncState.progress),
                ),
              ],
              if (syncState.lastSync != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Last synced: ${_formatDateTime(syncState.lastSync!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (syncState.pendingChanges > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${syncState.pendingChanges} pending change${syncState.pendingChanges == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
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

  String _getStatusTitle(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Ready to sync';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Sync complete';
      case SyncStatus.error:
        return 'Sync error';
      case SyncStatus.hasConflicts:
        return 'Conflicts detected';
    }
  }

  Widget _buildProviderSection(
    BuildContext context,
    WidgetRef ref,
    CloudProviderType? selectedProvider,
  ) {
    final l10n = context.l10n;
    final isApple = ref.watch(isApplePlatformProvider);
    final iCloudAvailability = ref
        .watch(iCloudAvailabilityProvider)
        .valueOrNull;
    final iCloudUnsupported =
        iCloudAvailability == ICloudAvailability.unsupported;
    final iCloudDisabledSubtitle = isApple
        ? l10n.settings_cloudSync_provider_icloud_unsupportedSubtitle
        : l10n.settings_cloudSync_provider_notAvailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Cloud Provider',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        _buildProviderTile(
          context,
          ref,
          provider: CloudProviderType.icloud,
          title: 'iCloud',
          subtitle: 'Sync via Apple iCloud',
          icon: Icons.cloud,
          isSelected: selectedProvider == CloudProviderType.icloud,
          isAvailable: isApple && !iCloudUnsupported,
          disabledSubtitle: iCloudDisabledSubtitle,
        ),
        _buildGoogleDriveProviderTile(context, ref, selectedProvider),
        _buildS3ProviderTile(context, ref, selectedProvider),
      ],
    );
  }

  Widget _buildProviderTile(
    BuildContext context,
    WidgetRef ref, {
    required CloudProviderType provider,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isAvailable,
    String? disabledSubtitle,
  }) {
    final l10n = context.l10n;
    return Semantics(
      selected: isSelected,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          isAvailable
              ? subtitle
              : (disabledSubtitle ??
                    l10n.settings_cloudSync_provider_notAvailable),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle,
                color: Colors.green,
                semanticLabel: 'Connected',
              )
            : null,
        enabled: isAvailable,
        onTap: isAvailable
            ? () => _selectProvider(context, ref, provider)
            : null,
      ),
    );
  }

  Widget _buildGoogleDriveProviderTile(
    BuildContext context,
    WidgetRef ref,
    CloudProviderType? selectedProvider,
  ) {
    final l10n = context.l10n;
    final isSelected = selectedProvider == CloudProviderType.googledrive;
    // Render from AsyncValue.value so a provider reload does not flash the
    // tile through a disabled state.
    final isAvailable = ref.watch(googleDriveAvailableProvider).value ?? false;
    final email = ref.watch(googleDriveAccountEmailProvider).value;

    return Semantics(
      selected: isSelected,
      child: ListTile(
        leading: const Icon(Icons.add_to_drive),
        title: Text(l10n.settings_cloudSync_provider_googleDrive),
        subtitle: Text(
          !isAvailable
              ? l10n.settings_cloudSync_googleDrive_desktopNotConfigured
              : (isSelected && email != null
                    ? email
                    : l10n.settings_cloudSync_provider_googleDrive_subtitle),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle,
                color: Colors.green,
                semanticLabel: 'Connected',
              )
            : null,
        enabled: isAvailable,
        onTap: isAvailable
            ? () => _selectProvider(context, ref, CloudProviderType.googledrive)
            : null,
      ),
    );
  }

  Widget _buildS3ProviderTile(
    BuildContext context,
    WidgetRef ref,
    CloudProviderType? selectedProvider,
  ) {
    final l10n = context.l10n;
    final S3Config? config = ref.watch(s3ConfigProvider).valueOrNull;
    final isSelected = selectedProvider == CloudProviderType.s3;
    final isConfigured = config != null;

    return Semantics(
      selected: isSelected,
      child: ListTile(
        leading: const Icon(Icons.dns),
        title: Text(l10n.settings_cloudSync_provider_s3_title),
        subtitle: Text(
          isConfigured
              ? '${config.bucket} @ ${config.displayHost}'
              : l10n.settings_cloudSync_provider_s3_subtitle,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                semanticLabel: 'Connected',
              ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings_cloudSync_provider_s3_edit,
              onPressed: () => context.push('/settings/cloud-sync/s3-config'),
            ),
          ],
        ),
        onTap: () {
          if (isConfigured) {
            _selectProvider(context, ref, CloudProviderType.s3);
          } else {
            context.push('/settings/cloud-sync/s3-config');
          }
        },
      ),
    );
  }

  Future<void> _selectProvider(
    BuildContext context,
    WidgetRef ref,
    CloudProviderType provider,
  ) async {
    // Switching AWAY from a backend this device has synced with is a
    // consequential, easy-to-misunderstand action (data is not migrated, peers
    // do not follow automatically, the next sync combines with whatever lives
    // on the new backend). Confirm first, and record the departure so the old
    // backend is marked moved-from and armed for cleanup.
    final current = ref.read(selectedCloudProviderTypeProvider);
    final currentProvider = ref.read(cloudStorageProviderProvider);
    final hasHistory = ref.read(syncStateProvider).lastSync != null;
    if (current != null &&
        current != provider &&
        currentProvider != null &&
        hasHistory) {
      // Resolve the display name before the first await so context is not used
      // across an async gap.
      final toName = _providerDisplayName(context, provider);
      final confirmed = await _confirmBackendSwitch(
        context,
        ref,
        from: current,
        to: provider,
      );
      if (confirmed != true) return;
      await ref
          .read(syncStateProvider.notifier)
          .recordBackendDeparture(
            oldProvider: currentProvider,
            toProviderId: provider.name,
            toProviderName: toName,
          );
      if (!context.mounted) return;
    }

    // Set the provider first so cloudStorageProviderProvider returns the correct instance
    ref.read(selectedCloudProviderTypeProvider.notifier).state = provider;

    // Get the cloud storage provider instance
    final cloudProvider = ref.read(cloudStorageProviderProvider);
    if (cloudProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize ${provider.name} provider'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Authenticate with the provider
      await _authenticateWithBrowserWait(context, cloudProvider, provider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${cloudProvider.providerName}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Persist the provider selection to SharedPreferences
      await ref.read(syncInitializerProvider).saveProvider(provider);

      // Refresh sync state after successful authentication
      ref.read(syncStateProvider.notifier).refreshState();
    } catch (e) {
      // Clear the provider selection on failure
      ref.read(selectedCloudProviderTypeProvider.notifier).state = null;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _connectionErrorMessage(
                context,
                ref,
                provider,
                cloudProvider.providerName,
                e,
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// On desktop, Google Drive authentication round-trips through the
  /// system browser (loopback OAuth); keep a cancellable waiting dialog up
  /// while it completes so the page does not look frozen. Other providers
  /// and platforms authenticate directly.
  Future<void> _authenticateWithBrowserWait(
    BuildContext context,
    CloudStorageProvider cloudProvider,
    CloudProviderType provider,
  ) async {
    final needsDialog =
        provider == CloudProviderType.googledrive &&
        (Platform.isWindows || Platform.isLinux);
    if (!needsDialog) {
      await cloudProvider.authenticate();
      return;
    }

    var dialogUp = true;
    final auth = cloudProvider.authenticate().whenComplete(() {
      if (dialogUp && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(false);
      }
    });
    final cancelled =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              dialogContext
                  .l10n
                  .settings_cloudSync_googleDrive_browserWait_title,
            ),
            content: Text(
              dialogContext
                  .l10n
                  .settings_cloudSync_googleDrive_browserWait_message,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
            ],
          ),
        ) ??
        false;
    dialogUp = false;
    if (cancelled) {
      // Abandon the pending flow; the loopback listener times out on its
      // own. Swallow its eventual error so nothing surfaces later.
      unawaited(auth.catchError((_) {}));
      throw const CloudStorageException('Google Sign-In was cancelled');
    }
    await auth;
  }

  /// Localized connection-failure message. For iCloud, the wording reflects
  /// the real availability state instead of leaking the raw exception.
  String _connectionErrorMessage(
    BuildContext context,
    WidgetRef ref,
    CloudProviderType provider,
    String providerName,
    Object error,
  ) {
    final iCloudAvailability = provider == CloudProviderType.icloud
        ? ref.read(iCloudAvailabilityProvider).valueOrNull
        : null;
    return connectionErrorMessage(
      context.l10n,
      provider,
      iCloudAvailability,
      providerName,
      error.toString(),
    );
  }

  /// Display name for a provider type, for dialogs and banners.
  String _providerDisplayName(BuildContext context, CloudProviderType type) {
    final l10n = context.l10n;
    switch (type) {
      case CloudProviderType.icloud:
        return l10n.settings_cloudSync_provider_icloud;
      case CloudProviderType.googledrive:
        return l10n.settings_cloudSync_provider_googleDrive;
      case CloudProviderType.s3:
        return l10n.settings_cloudSync_provider_s3_title;
    }
  }

  /// Map a stored providerId back to a display name (for the cleanup banner,
  /// which only has the id of the old backend).
  String _providerDisplayNameForId(BuildContext context, String providerId) {
    final type = CloudProviderType.values
        .where((t) => t.name == providerId)
        .firstOrNull;
    return type == null ? providerId : _providerDisplayName(context, type);
  }

  Future<bool?> _confirmBackendSwitch(
    BuildContext context,
    WidgetRef ref, {
    required CloudProviderType from,
    required CloudProviderType to,
  }) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_cloudSync_switch_dialogTitle),
        content: Text(
          l10n.settings_cloudSync_switch_dialogContent(
            _providerDisplayName(context, from),
            _providerDisplayName(context, to),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settings_cloudSync_switch_confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncActions(
    BuildContext context,
    WidgetRef ref,
    SyncState syncState,
    bool hasProvider,
  ) {
    final isSyncing = syncState.status == SyncStatus.syncing;

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
          if (syncState.movedMarker != null)
            _buildMovedBanner(context, ref, syncState.movedMarker!),
          if (syncState.cleanupOldBackendProviderId != null)
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
            label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
          ),
          if (!hasProvider)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Select a cloud provider to enable sync',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  /// Advisory banner shown to a straggler still pointed at a backend another
  /// device moved away from. Informational + dismissible: the user follows the
  /// move by selecting the destination provider tile themselves (a one-tap
  /// switch is not offered because some destinations, e.g. S3, need config).
  Widget _buildMovedBanner(
    BuildContext context,
    WidgetRef ref,
    LibraryMovedMarker marker,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.drive_file_move_outline,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.settings_cloudSync_moved_banner(
                        marker.displayName,
                        marker.toProviderDisplay,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      ref.read(syncStateProvider.notifier).acknowledgeMoved(),
                  child: Text(context.l10n.settings_cloudSync_moved_dismiss),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Offer to delete the orphaned data left on a backend the user switched
  /// away from, shown after the first successful sync on the new backend.
  Widget _buildCleanupOfferBanner(
    BuildContext context,
    WidgetRef ref,
    String oldProviderId,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.settings_cloudSync_cleanup_banner(
                  _providerDisplayNameForId(context, oldProviderId),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ref
                        .read(syncStateProvider.notifier)
                        .dismissOldBackendCleanup(),
                    child: Text(context.l10n.settings_cloudSync_cleanup_keep),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => ref
                        .read(syncStateProvider.notifier)
                        .cleanupOldBackendData(),
                    child: Text(context.l10n.settings_cloudSync_cleanup_delete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBehaviorSection(
    BuildContext context,
    WidgetRef ref,
    SyncBehaviorSettings settings,
    bool isCustomFolderMode,
  ) {
    final disabled = isCustomFolderMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Sync Behavior',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Auto Sync'),
          subtitle: const Text('Sync automatically after changes'),
          value: settings.autoSyncEnabled,
          onChanged: disabled
              ? null
              : (value) => ref
                    .read(syncBehaviorProvider.notifier)
                    .setAutoSyncEnabled(value),
        ),
        SwitchListTile(
          title: const Text('Sync on Launch'),
          subtitle: const Text('Check for updates at startup'),
          value: settings.syncOnLaunch,
          onChanged: disabled
              ? null
              : (value) => ref
                    .read(syncBehaviorProvider.notifier)
                    .setSyncOnLaunch(value),
        ),
        SwitchListTile(
          title: const Text('Sync on Resume'),
          subtitle: const Text('Check for updates when app becomes active'),
          value: settings.syncOnResume,
          onChanged: disabled
              ? null
              : (value) => ref
                    .read(syncBehaviorProvider.notifier)
                    .setSyncOnResume(value),
        ),
      ],
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
                'Conflicts (${syncState.conflicts})',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: Colors.orange),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.merge_type),
          title: const Text('Resolve Conflicts'),
          subtitle: Text(
            '${syncState.conflicts} item${syncState.conflicts == 1 ? '' : 's'} need${syncState.conflicts == 1 ? 's' : ''} attention',
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

  Widget _buildAdvancedSection(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(syncStateProvider).status == SyncStatus.syncing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Advanced',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Reset Sync State'),
          subtitle: const Text('Clear sync history and start fresh'),
          enabled: !isSyncing,
          onTap: isSyncing ? null : () => _confirmResetSyncState(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign Out'),
          subtitle: const Text('Disconnect from cloud provider'),
          onTap: () => _confirmSignOut(context, ref),
        ),
      ],
    );
  }

  /// Run a sync, first handling the two gated cases: a replaced cloud
  /// library awaiting adoption, and the device's first library-combining
  /// contact with existing cloud data.
  Future<void> _onSyncNowPressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(syncStateProvider.notifier);
    final replaceInfo = await notifier.libraryReplaceInfo();
    if (replaceInfo != null) {
      if (!context.mounted) return;
      await showAdoptReplacedLibraryDialog(context, ref, replaceInfo);
      return;
    }
    final info = await notifier.firstSyncMergeInfo();
    if (info == null) {
      await notifier.performSync();
      return;
    }
    if (!context.mounted) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_cloudSync_firstSync_dialogTitle),
        content: Text(
          l10n.settings_cloudSync_firstSync_dialogContent(
            info.peerFileCount,
            info.localDiveCount,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settings_cloudSync_firstSync_dialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await notifier.performSync();
    }
  }

  Future<void> _confirmResetSyncState(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Sync State?'),
        content: const Text(
          'This will clear sync history and give this device a new '
          'sync identity. Your data is not deleted, and the record of '
          'past deletions is kept so deleted items do not come back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(syncStateProvider.notifier).resetSyncState();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sync state reset')));
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    // Cloud backup uploads ride on the sync provider; losing it changes
    // where backups land, which the user must hear about before agreeing.
    final backupWarning = ref.read(backupSettingsProvider).cloudBackupEnabled
        ? '\n\n${context.l10n.settings_cloudSync_signOut_backupWarning}'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settings_cloudSync_signOutDialog_title),
        content: Text(
          '${context.l10n.settings_cloudSync_signOutDialog_content}'
          '$backupWarning',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.settings_cloudSync_signOutDialog_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.settings_cloudSync_signOutDialog_signOut),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(syncStateProvider.notifier).signOut();
      await ref.read(backupSettingsProvider.notifier).disableCloudBackup();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out from cloud provider')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return DateFormat.yMMMd().format(dateTime);
    }
  }
}
