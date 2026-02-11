import 'dart:io';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_resolution_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class CloudSyncPage extends ConsumerWidget {
  const CloudSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final selectedProvider = ref.watch(selectedCloudProviderTypeProvider);
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
          _buildSyncStatusCard(context, ref, syncState),
          const Divider(),
          _buildProviderSection(context, ref, selectedProvider),
          const Divider(),
          _buildSyncActions(context, ref, syncState),
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
          isAvailable: Platform.isIOS || Platform.isMacOS,
        ),
        _buildProviderTile(
          context,
          ref,
          provider: CloudProviderType.googledrive,
          title: 'Google Drive',
          subtitle: 'Sync via Google Drive',
          icon: Icons.cloud_circle,
          isSelected: selectedProvider == CloudProviderType.googledrive,
          isAvailable: true,
        ),
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
  }) {
    return Semantics(
      selected: isSelected,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          isAvailable ? subtitle : 'Not available on this platform',
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

  Future<void> _selectProvider(
    BuildContext context,
    WidgetRef ref,
    CloudProviderType provider,
  ) async {
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
      await cloudProvider.authenticate();

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
              '${cloudProvider.providerName} connection failed: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSyncActions(
    BuildContext context,
    WidgetRef ref,
    SyncState syncState,
  ) {
    final isSyncing = syncState.status == SyncStatus.syncing;
    final hasProvider = ref.watch(selectedCloudProviderTypeProvider) != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: isSyncing || !hasProvider
                ? null
                : () => ref.read(syncStateProvider.notifier).performSync(),
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
          onTap: () => _confirmResetSyncState(context, ref),
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

  Future<void> _confirmResetSyncState(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Sync State?'),
        content: const Text(
          'This will clear all sync history and start fresh. '
          'Your data will not be deleted, but you may need to resolve '
          'conflicts on the next sync.',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'This will disconnect from the cloud provider. '
          'Your local data will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(syncStateProvider.notifier).signOut();
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
