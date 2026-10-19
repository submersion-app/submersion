part of 'cloud_sync_page.dart';

/// The Sync page's conditional banners (spec section 8.1 keeps them all;
/// the old-backend cleanup now asks before deleting), split out so the page
/// stays under the 800-line guide.
mixin _SyncBanners on ConsumerState<CloudSyncPage> {
  Widget _buildCustomFolderBanner(
    BuildContext context,
    StoragePlatformCapabilities platformCaps,
  ) {
    final theme = Theme.of(context);
    // Where the custom folder can only be an app-specific device volume, no
    // sync service can read it, so handing credit to the folder's own sync
    // hides that the library is now syncing nowhere at all (#311).
    final content = platformCaps.customFolderIsDeviceVolumeOnly
        ? context.l10n.settings_storage_customFolder_deviceOnly_noCloudSync
        : context.l10n.settings_cloudSync_disabledBanner_content;

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
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.pushSettingsPage('/settings/storage'),
            icon: const Icon(Icons.settings),
            label: Text(context.l10n.settings_cloudSync_storageSettings),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              side: BorderSide(color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner shown when two or more diver profiles share a name: the typical
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

  /// Advisory banner shown to a straggler still pointed at a backend another
  /// device moved away from. Informational and dismissible: the diver follows
  /// the move with Change on the Using row (a one-tap switch is not offered
  /// because some destinations, e.g. S3, need signing in first).
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
                      // Same secondaryContainer pairing as the peer-update
                      // banner above; kept in step so the two read alike.
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
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
                  providerDisplayNameForId(context, oldProviderId),
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
                    onPressed: () =>
                        _confirmCleanup(context, ref, oldProviderId),
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

  /// Deleting the old backend's files cannot be undone, so it asks first
  /// (spec section 8.1).
  Future<void> _confirmCleanup(
    BuildContext context,
    WidgetRef ref,
    String oldProviderId,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_sync_cleanup_confirmTitle),
        content: Text(
          l10n.settings_sync_cleanup_confirmBody(
            providerDisplayNameForId(context, oldProviderId),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settings_cloudSync_cleanup_delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(syncStateProvider.notifier).cleanupOldBackendData();
    }
  }
}
