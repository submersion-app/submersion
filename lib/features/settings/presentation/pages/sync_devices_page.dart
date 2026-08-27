import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/services/sync/sync_cleanup_outcome.dart';
import 'package:submersion/core/services/sync/sync_device_footprint.dart';
import 'package:submersion/features/settings/presentation/providers/sync_device_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_maintenance_progress_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lists every device holding files on the sync backend, so a user can see
/// where their cloud space went and remove the leftovers.
///
/// Issue #1032: a user with one syncing device found 400+ files on Dropbox and
/// had no way to tell which belonged to what. Their only recourse was the
/// all-or-nothing wipe, which took six minutes and broke sync. This page is the
/// scalpel that wipe was standing in for.
class SyncDevicesPage extends ConsumerWidget {
  const SyncDevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devices = ref.watch(syncDeviceFootprintListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_syncDevices_appBar_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.settings_syncDevices_appBar_refreshTooltip,
            onPressed: () => ref.invalidate(syncDeviceFootprintListProvider),
          ),
        ],
      ),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.cloud_off,
          text: l10n.settings_syncDevices_readError('$e'),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _Message(
              icon: Icons.cloud_queue,
              text: l10n.settings_syncDevices_empty,
            );
          }
          final shared = duplicatedSyncDeviceNames(list);
          return ListView.separated(
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => i == 0
                ? _Summary(devices: list)
                : _DeviceTile(
                    device: list[i - 1],
                    // Two phones of the same model, or two iPhones on iOS 16+
                    // (which hands out the model as the name), publish the
                    // same name. Identical rows are what the device id
                    // fallback was protecting against, so keep that guarantee
                    // by qualifying the name instead of dropping it.
                    disambiguate: shared.contains(list[i - 1].deviceName),
                  ),
          );
        },
      ),
    );
  }
}

/// Names published by more than one device in [devices]. Rendering those
/// unqualified would show two rows a user cannot tell apart.
@visibleForTesting
Set<String> duplicatedSyncDeviceNames(List<SyncDeviceFootprint> devices) {
  final seen = <String>{};
  final duplicated = <String>{};
  for (final device in devices) {
    final name = device.deviceName;
    if (name == null) continue;
    if (!seen.add(name)) duplicated.add(name);
  }
  return duplicated;
}

/// Totals first: the number the user actually came here for is "how much of my
/// cloud storage is this app using, and how much of that is dead weight".
class _Summary extends StatelessWidget {
  const _Summary({required this.devices});

  final List<SyncDeviceFootprint> devices;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final files = devices.fold<int>(0, (a, d) => a + d.fileCount);
    final bytes = devices.fold<int>(0, (a, d) => a + d.byteCount);
    final removable = devices.where((d) => d.isSafeToRemove).toList();
    final removableBytes = removable.fold<int>(0, (a, d) => a + d.byteCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settings_syncDevices_summary(
              devices.length,
              files,
              _formatBytes(bytes),
            ),
            style: theme.textTheme.titleMedium,
          ),
          if (removable.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.settings_syncDevices_summary_removable(
                removable.length,
                _formatBytes(removableBytes),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device, this.disambiguate = false});

  final SyncDeviceFootprint device;

  /// Whether another device published the same name, in which case the short
  /// id is shown alongside it.
  final bool disambiguate;

  /// The published name, qualified by the short id when it is not unique, or
  /// [fallback] when this device published no name at all. The two callers
  /// pass different fallbacks: a tile title is title-case, a sentence is not.
  String _displayName(AppLocalizations l10n, {required String fallback}) {
    final name = device.deviceName;
    if (name == null) return fallback;
    return disambiguate
        ? l10n.settings_syncDevices_nameWithId(name, device.shortId)
        : name;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final when = device.publishedAt ?? device.lastModified;
    final size = _formatBytes(device.byteCount);
    return ListTile(
      isThreeLine: true,
      leading: Icon(_icon, color: _color(theme)),
      title: Text(
        _displayName(
          l10n,
          fallback: l10n.settings_syncDevices_unnamedDevice(device.shortId),
        ),
        style: TextStyle(
          fontWeight: device.isSelf ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stateLabel(l10n)),
          Text(
            when == null
                ? l10n.settings_syncDevices_tile_filesSize(
                    device.fileCount,
                    size,
                  )
                : l10n.settings_syncDevices_tile_filesSizeSeen(
                    device.fileCount,
                    size,
                    DateFormat.yMMMd().add_jm().format(when.toLocal()),
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: device.isSelf
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.settings_syncDevices_removeTooltip,
              onPressed: () => _confirmRemove(context, ref),
            ),
    );
  }

  IconData get _icon => switch (device.state) {
    SyncDeviceFootprintState.active => Icons.devices,
    SyncDeviceFootprintState.staleEpoch => Icons.history_toggle_off,
    SyncDeviceFootprintState.retired => Icons.do_not_disturb_on_outlined,
    SyncDeviceFootprintState.unreadable => Icons.help_outline,
  };

  Color? _color(ThemeData theme) => switch (device.state) {
    SyncDeviceFootprintState.active => theme.colorScheme.primary,
    SyncDeviceFootprintState.staleEpoch => theme.colorScheme.error,
    _ => theme.colorScheme.onSurfaceVariant,
  };

  String _stateLabel(AppLocalizations l10n) => switch (device.state) {
    SyncDeviceFootprintState.active =>
      device.isSelf
          ? l10n.settings_syncDevices_state_thisDevice
          : l10n.settings_syncDevices_state_active,
    SyncDeviceFootprintState.staleEpoch =>
      l10n.settings_syncDevices_state_staleEpoch,
    SyncDeviceFootprintState.retired => l10n.settings_syncDevices_state_retired,
    SyncDeviceFootprintState.unreadable =>
      l10n.settings_syncDevices_state_unreadable,
  };

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final name = _displayName(
      l10n,
      fallback: l10n.settings_cloudSync_peerNeedsAdopt_unnamedDevice(
        device.shortId,
      ),
    );
    final size = _formatBytes(device.byteCount);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_syncDevices_removeDialog_title(name)),
        content: Text(
          device.isSafeToRemove
              ? l10n.settings_syncDevices_removeDialog_bodySafe(
                  device.fileCount,
                  size,
                  name,
                )
              : l10n.settings_syncDevices_removeDialog_bodyRisky(
                  device.fileCount,
                  size,
                  name,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            style: device.isSafeToRemove
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.common_action_remove),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final outcome = await runWithSyncMaintenanceProgress(
      context: context,
      title: l10n.settings_syncDevices_removeProgressTitle(name),
      task: (report) => retireSyncPeer(
        ref,
        device.deviceId,
        onProgress: cleanupPhase(
          report,
          l10n.settings_syncMaintenance_phase_deleting,
        ),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_removalMessage(l10n, outcome))));
  }

  static String _removalMessage(
    AppLocalizations l10n,
    SyncCleanupOutcome? outcome,
  ) {
    if (outcome == null) return l10n.settings_syncDevices_removal_noBackend;
    if (outcome.isComplete) {
      return l10n.settings_syncMaintenance_removedFiles(outcome.deleted);
    }
    if (outcome.deleted == 0 && outcome.listIncomplete) {
      // retirePeer refuses to delete without a durable fence marker, so this
      // is the "could not reach the backend" case, not a partial deletion.
      return l10n.settings_syncDevices_removal_unreachable;
    }
    return l10n.settings_syncMaintenance_removedFilesPartial(
      outcome.deleted,
      l10n.settings_syncMaintenance_trouble_failed(outcome.failed),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sizes are a floor: providers that report no size for a file count zero.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}
