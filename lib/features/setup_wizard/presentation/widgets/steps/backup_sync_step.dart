import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/presentation/pages/s3_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/dropbox_connect_dialog.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Backup schedule plus optional cloud sync provider connection.
class BackupSyncStep extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  /// Fresh-path pivot: called when a just-connected provider already holds
  /// a Submersion library (the shell offers adopting it instead).
  final void Function()? onLibraryFound;

  const BackupSyncStep({super.key, required this.mode, this.onLibraryFound});

  @override
  ConsumerState<BackupSyncStep> createState() => _BackupSyncStepState();
}

class _BackupSyncStepState extends ConsumerState<BackupSyncStep> {
  bool _connecting = false;

  Future<void> _connect(CloudProviderType type) async {
    final notifier = ref.read(setupWizardProvider(widget.mode).notifier);
    setState(() => _connecting = true);
    try {
      if (type == CloudProviderType.dropbox) {
        final connected = await showDialog<bool>(
          context: context,
          builder: (_) => DropboxConnectDialog(
            provider: ref.read(dropboxStorageProviderInstanceProvider),
          ),
        );
        ref.invalidate(dropboxAuthDataProvider);
        if (connected != true) return;
      }
      // Activation contract mirrored from CloudSyncPage._selectProvider.
      ref.read(selectedCloudProviderTypeProvider.notifier).state = type;
      final instance = cloudProviderInstanceFor(type);
      await instance.authenticate();
      await ref.read(syncInitializerProvider).saveProvider(type);
      ref.read(syncStateProvider.notifier).refreshState();
      notifier.setConnectedProvider(type);

      // Fresh-path pivot check: does this account already hold a library?
      if (widget.onLibraryFound != null) {
        final peers = await ref
            .read(syncInitializerProvider)
            .peerSyncFiles(instance);
        if (peers.isNotEmpty && mounted) widget.onLibraryFound!();
      }
    } catch (e) {
      ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
      notifier.setConnectedProvider(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.setup_sync_error(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _disconnect() {
    // Drop the in-wizard selection so the provider cards return; don't
    // persist a backend the user is abandoning.
    ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
    ref.read(syncInitializerProvider).saveProvider(null);
    ref.read(syncStateProvider.notifier).refreshState();
    ref
        .read(setupWizardProvider(widget.mode).notifier)
        .setConnectedProvider(null);
  }

  Future<void> _openS3Config() async {
    // Push on the ROOT navigator, not go_router: during first run the wizard
    // has zero divers, so the router's onboarding redirect bounces any
    // context.push to a real route straight back to /welcome (the fork).
    // S3 config is a modal action within the wizard, not a route destination.
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => const S3ConfigPage()));
    if (!mounted) return;
    // S3ConfigPage activates S3 itself on save; reflect it in the draft.
    final sel = ref.read(selectedCloudProviderTypeProvider);
    if (sel == CloudProviderType.s3) {
      ref
          .read(setupWizardProvider(widget.mode).notifier)
          .setConnectedProvider(sel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final draft = ref.watch(setupWizardProvider(widget.mode));
    final notifier = ref.read(setupWizardProvider(widget.mode).notifier);

    final isApple = ref.watch(isApplePlatformProvider);
    final iCloudAvailability = ref
        .watch(iCloudAvailabilityProvider)
        .valueOrNull;
    final iCloudAvailable =
        isApple && iCloudAvailability != ICloudAvailability.unsupported;
    final dropboxConfigured = ref.watch(dropboxConfiguredProvider);

    // The draft holds the connected provider in both modes: seeded from the
    // active provider on settings re-entry, set by the connect flow at first
    // run. A non-null value renders connected status instead of the cards.
    final connected = draft.connectedProvider;

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setup_backup_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setup_backup_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.setup_backup_scheduleToggle),
            subtitle: Text(l10n.setup_backup_scheduleSubtitle),
            value: draft.backupEnabled,
            onChanged: notifier.setBackupEnabled,
          ),
          if (draft.backupEnabled) ...[
            sectionLabel(l10n.setup_backup_frequency),
            SegmentedButton<BackupFrequency>(
              segments: [
                ButtonSegment(
                  value: BackupFrequency.daily,
                  label: Text(l10n.setup_backup_frequency_daily),
                ),
                ButtonSegment(
                  value: BackupFrequency.weekly,
                  label: Text(l10n.setup_backup_frequency_weekly),
                ),
                ButtonSegment(
                  value: BackupFrequency.monthly,
                  label: Text(l10n.setup_backup_frequency_monthly),
                ),
              ],
              selected: {draft.backupFrequency},
              showSelectedIcon: false,
              onSelectionChanged: (sel) =>
                  notifier.setBackupFrequency(sel.first),
            ),
          ],
          sectionLabel(l10n.setup_sync_header),
          Text(
            l10n.setup_sync_subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (connected != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_done),
              title: Text(
                l10n.setup_sync_connectedTo(_providerName(connected)),
              ),
            ),
            if (widget.mode == SetupWizardMode.settings)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.push('/settings/cloud-sync'),
                  child: Text(l10n.setup_sync_manageInSettings),
                ),
              )
            else
              // First run: let the user disconnect and pick a different
              // backend (e.g. after a failed pull), instead of being locked
              // into the connected provider with no way to change it.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _connecting ? null : _disconnect,
                  child: Text(l10n.setup_sync_changeProvider),
                ),
              ),
          ] else ...[
            Text(
              l10n.setup_sync_notConnected,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (iCloudAvailable)
              _providerCard(
                icon: Icons.cloud,
                name: 'iCloud',
                onTap: _connecting
                    ? null
                    : () => _connect(CloudProviderType.icloud),
              )
            // Apple platform where iCloud can't be used (signed out or a
            // build without the entitlement): explain rather than hide.
            else if (isApple &&
                iCloudAvailability == ICloudAvailability.unsupported)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  enabled: false,
                  leading: const Icon(Icons.cloud_off),
                  title: const Text('iCloud'),
                  subtitle: Text(l10n.setup_sync_icloudUnavailable),
                ),
              ),
            if (dropboxConfigured)
              _providerCard(
                icon: Icons.cloud_queue,
                name: 'Dropbox',
                onTap: _connecting
                    ? null
                    : () => _connect(CloudProviderType.dropbox),
              ),
            _providerCard(
              icon: Icons.storage,
              name: 'S3',
              onTap: _connecting ? null : _openS3Config,
            ),
          ],
          if (connected != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.setup_backup_cloudCopy),
              value: draft.cloudBackupEnabled,
              onChanged: notifier.setCloudBackupEnabled,
            ),
        ],
      ),
    );
  }

  Widget _providerCard({
    required IconData icon,
    required String name,
    required VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(name),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _providerName(CloudProviderType type) {
    switch (type) {
      case CloudProviderType.icloud:
        return 'iCloud';
      case CloudProviderType.dropbox:
        return 'Dropbox';
      case CloudProviderType.s3:
        return 'S3';
      case CloudProviderType.googledrive:
        return 'Google Drive';
    }
  }
}
