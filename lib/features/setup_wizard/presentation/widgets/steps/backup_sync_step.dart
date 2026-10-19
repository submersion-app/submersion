import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/cloud_provider_authenticate.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/own_server_form.dart';
import 'package:submersion/features/settings/presentation/widgets/dropbox_connect_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/wizard_surface_style.dart';
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
    // Captured before any await: this controller is container-owned, so it
    // still rolls the selection back if the step is disposed mid-connect,
    // where reading it off `ref` would throw instead.
    final selection = ref.read(selectedCloudProviderTypeProvider.notifier);
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
      if (!mounted) return;
      // Activation contract mirrored from CloudSyncPage._selectProvider.
      selection.state = type;
      // Resolve the backend the way that page does, rather than reaching for
      // the raw singleton: this provider applies account-first credential
      // resolution and the custom-folder check, so the singleton shortcut
      // quietly broke the contract the comment above claims.
      final instance = ref.read(cloudStorageProviderProvider);
      if (instance == null) {
        // Report it the way CloudSyncPage does, rather than throwing: routing
        // this through setup_sync_error would print the exception's own type
        // name into the snackbar alongside the message.
        selection.state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.settings_cloudSync_provider_initFailed(
                _providerName(type),
              ),
            ),
          ),
        );
        return;
      }
      // Desktop Google Drive authenticates through the system browser, which
      // can take as long as the user does. The shared helper keeps a
      // cancellable wait dialog up so the wizard does not sit frozen with no
      // way out; every other provider and platform authenticates directly.
      await authenticateWithBrowserWait(context, instance, type);
      // A desktop browser round trip is user-paced and can easily outlast
      // this step (the user backs out of the wizard while the browser is
      // up). Both `ref` and the autoDispose draft notifier throw once that
      // happens, so stop here rather than at the first of them.
      if (!mounted) return;
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
    } on CloudAuthCancelled {
      // A deliberate cancel: undo the pending selection silently so the cards
      // come back, with no error shown for a choice the user made.
      selection.state = null;
      if (mounted) notifier.setConnectedProvider(null);
    } catch (e) {
      selection.state = null;
      if (mounted) {
        notifier.setConnectedProvider(null);
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

  Future<void> _openS3Config() => _openOwnServer(AccountKind.s3);

  Future<void> _openWebDavConfig() => _openOwnServer(AccountKind.webdav);

  /// The shared My own server form (issue #3482), pushed on the ROOT
  /// navigator: during first run the wizard has zero divers, so the router's
  /// onboarding redirect would bounce a go_router push back to /welcome.
  /// Saving points sync at the server, as the S3 and WebDAV settings pages
  /// did, and the draft reflects it.
  Future<void> _openOwnServer(AccountKind kind) async {
    // The sync folder is shown, as the S3 and WebDAV settings pages showed
    // it: a new device joining a library kept in a custom folder must be
    // able to name that folder.
    final row = await showOwnServerPage(
      context,
      kinds: {kind},
      rootNavigator: true,
      showSyncFolder: true,
    );
    if (!mounted) return;
    if (row != null) {
      await switchSyncToRow(context, ref, row);
      if (!mounted) return;
    }
    final sel = ref.read(selectedCloudProviderTypeProvider);
    if (sel == kind.cloudProviderType) {
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
    // Google Drive is offered wherever it can actually authenticate. On a
    // desktop build without the Desktop-app OAuth client compiled in it is
    // hidden rather than shown broken, the same treatment an unconfigured
    // Dropbox already gets. Read through .value so a provider reload does
    // not flash the card away.
    final googleDriveAvailable =
        ref.watch(googleDriveAvailableProvider).value ?? false;

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
                theme: theme,
                icon: Icons.cloud,
                name: 'iCloud',
                onTap: _connecting
                    ? null
                    : () => _connect(CloudProviderType.icloud),
              )
            // Apple platform running a build without the iCloud entitlement
            // (Developer ID signing cannot carry it): explain rather than
            // hide. Shares the Cloud Sync settings string so both surfaces
            // give the same reason and cannot drift apart.
            else if (isApple &&
                iCloudAvailability == ICloudAvailability.unsupported)
              Card(
                elevation: 0,
                color: WizardSurfaceStyle.optionFill(theme),
                shape: WizardSurfaceStyle.optionShape(theme),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  enabled: false,
                  leading: const Icon(Icons.cloud_off),
                  title: const Text('iCloud'),
                  subtitle: Text(
                    l10n.settings_cloudSync_provider_icloud_unsupportedSubtitle,
                  ),
                ),
              ),
            if (googleDriveAvailable)
              _providerCard(
                theme: theme,
                icon: Icons.add_to_drive,
                name: 'Google Drive',
                onTap: _connecting
                    ? null
                    : () => _connect(CloudProviderType.googledrive),
              ),
            if (dropboxConfigured)
              _providerCard(
                theme: theme,
                icon: Icons.cloud_queue,
                name: 'Dropbox',
                onTap: _connecting
                    ? null
                    : () => _connect(CloudProviderType.dropbox),
              ),
            _providerCard(
              theme: theme,
              icon: Icons.storage,
              name: 'S3',
              onTap: _connecting ? null : _openS3Config,
            ),
            _providerCard(
              theme: theme,
              icon: Icons.folder_shared,
              name: 'WebDAV',
              onTap: _connecting ? null : _openWebDavConfig,
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
    required ThemeData theme,
    required IconData icon,
    required String name,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: WizardSurfaceStyle.optionFill(theme),
      shape: WizardSurfaceStyle.optionShape(theme),
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
      case CloudProviderType.webdav:
        return 'WebDAV';
    }
  }
}
