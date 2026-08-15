import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/services/sync/sync_cleanup_outcome.dart';
import 'package:submersion/core/services/sync/sync_device_footprint.dart';
import 'package:submersion/features/settings/presentation/providers/sync_device_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_maintenance_progress_dialog.dart';

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
    final devices = ref.watch(syncDeviceFootprintListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices on this backend'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(syncDeviceFootprintListProvider),
          ),
        ],
      ),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.cloud_off,
          text: 'Could not read the backend.\n$e',
        ),
        data: (list) => list.isEmpty
            ? const _Message(
                icon: Icons.cloud_queue,
                text: 'No sync files on this backend.',
              )
            : ListView.separated(
                itemCount: list.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => i == 0
                    ? _Summary(devices: list)
                    : _DeviceTile(device: list[i - 1]),
              ),
      ),
    );
  }
}

/// Totals first: the number the user actually came here for is "how much of my
/// cloud storage is this app using, and how much of that is dead weight".
class _Summary extends StatelessWidget {
  const _Summary({required this.devices});

  final List<SyncDeviceFootprint> devices;

  @override
  Widget build(BuildContext context) {
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
            '${devices.length} device${devices.length == 1 ? '' : 's'}, '
            '$files file${files == 1 ? '' : 's'}, ${_formatBytes(bytes)}',
            style: theme.textTheme.titleMedium,
          ),
          if (removable.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${removable.length} left over from a replaced or retired '
              'library, holding ${_formatBytes(removableBytes)}.',
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
  const _DeviceTile({required this.device});

  final SyncDeviceFootprint device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final when = device.publishedAt ?? device.lastModified;
    return ListTile(
      isThreeLine: true,
      leading: Icon(_icon, color: _color(theme)),
      title: Text(
        device.deviceName ?? 'Device ${device.shortId}',
        style: TextStyle(
          fontWeight: device.isSelf ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stateLabel),
          Text(
            '${device.fileCount} file${device.fileCount == 1 ? '' : 's'}, '
            '${_formatBytes(device.byteCount)}'
            '${when == null ? '' : ' - ${DateFormat.yMMMd().add_jm().format(when.toLocal())}'}',
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
              tooltip: 'Remove this device’s files',
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

  String get _stateLabel => switch (device.state) {
    SyncDeviceFootprintState.active =>
      device.isSelf ? 'This device' : 'Syncing normally',
    SyncDeviceFootprintState.staleEpoch =>
      'Left over from an earlier library - no device reads this',
    SyncDeviceFootprintState.retired => 'Retired',
    SyncDeviceFootprintState.unreadable =>
      'No readable manifest - an unfinished upload, or encrypted',
  };

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final name = device.deviceName ?? 'device ${device.shortId}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $name’s files?'),
        content: Text(
          device.isSafeToRemove
              ? 'This deletes ${device.fileCount} files '
                    '(${_formatBytes(device.byteCount)}) belonging to $name. '
                    'They are left over from a library no device syncs from '
                    'any more. Your dive data is not affected.'
              : 'This deletes ${device.fileCount} files '
                    '(${_formatBytes(device.byteCount)}) belonging to $name.\n\n'
                    'That device is still part of this sync. If it comes back '
                    'online it will rebuild from the backend rather than '
                    'resurrect old data, but any changes it has not yet '
                    'published will be lost. Your dive data on THIS device is '
                    'not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: device.isSafeToRemove
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final outcome = await runWithSyncMaintenanceProgress(
      context: context,
      title: 'Removing $name’s files',
      task: (report) => retireSyncPeer(
        ref,
        device.deviceId,
        onProgress: cleanupPhase(report, 'Deleting'),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_removalMessage(outcome))));
  }

  static String _removalMessage(SyncCleanupOutcome? outcome) {
    if (outcome == null) return 'No cloud backend is configured';
    if (outcome.isComplete) {
      return 'Removed ${outcome.deleted} '
          'file${outcome.deleted == 1 ? '' : 's'}';
    }
    if (outcome.deleted == 0 && outcome.listIncomplete) {
      // retirePeer refuses to delete without a durable fence marker, so this
      // is the "could not reach the backend" case, not a partial deletion.
      return 'Could not reach the backend. Nothing was removed.';
    }
    return 'Removed ${outcome.deleted} files, but ${outcome.failed} could not '
        'be deleted. Try again while online.';
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
