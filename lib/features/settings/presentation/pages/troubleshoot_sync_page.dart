import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Recovery actions for a wedged Cloud Sync state (issue #509). Reached from
/// the Cloud Sync page's Advanced section and by tapping the sync-error banner.
/// Actions escalate in severity; each explains itself in plain language.
class TroubleshootSyncPage extends ConsumerWidget {
  const TroubleshootSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Troubleshoot Sync')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.healing),
            title: const Text('Repair Sync'),
            subtitle: const Text(
              'Fix a stuck sync. Clears this device’s sync state and gives it '
              'a fresh sync identity, then reconnects on the next sync. Your '
              'dive data is not affected.',
            ),
            onTap: () => _confirmRepair(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Rebuild backend from this device'),
            subtitle: const Text(
              'Use if sync is stuck waiting on a library that another device '
              'replaced but never finished uploading (that device may be '
              'offline). Publishes this device’s library as the current one.',
            ),
            onTap: () => _confirmRebuild(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Remove this device’s cloud files'),
            subtitle: const Text(
              'Free this device’s space on the backend. Other devices keep '
              'syncing. Your dive data is not affected.',
            ),
            onTap: () => _confirmRemoveThisDevice(context, ref),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Wipe all sync data on this backend'),
            subtitle: const Text(
              'Delete every device’s sync data from this backend, including '
              'the library markers. Every device re-establishes from scratch. '
              'Your dive data is not affected.',
            ),
            onTap: () => _confirmWipeAll(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRepair(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repair Sync?'),
        content: const Text(
          'This clears all local sync state and gives this device a new sync '
          'identity, then reconnects fresh on the next sync. Your dive data is '
          'safe and is not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Repair'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(syncStateProvider.notifier).repairSync();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sync repaired')));
    }
  }

  Future<void> _confirmRebuild(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rebuild backend from this device?'),
        content: const Text(
          'This makes this device’s library the current one on the backend and '
          'republishes it, so other devices sync from you. Use it when a '
          'replacement from another device is stuck. Your dive data is not '
          'affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rebuild'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(syncStateProvider.notifier).rebuildBackendFromThisDevice();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rebuilt backend from this device')),
      );
    }
  }

  Future<void> _confirmRemoveThisDevice(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this device’s cloud files?'),
        content: const Text(
          'This deletes only this device’s sync files from the backend. Other '
          'devices keep syncing, and your dive data is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(syncStateProvider.notifier).removeThisDeviceCloudFiles();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed this device’s cloud files')),
      );
    }
  }

  /// Destructive full-backend wipe: guarded by typing the word WIPE so it
  /// cannot be triggered by a single mis-tap.
  Future<void> _confirmWipeAll(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final armed = controller.text.trim() == 'WIPE';
          return AlertDialog(
            title: const Text('Wipe all sync data?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This deletes EVERY device’s sync data from this backend, '
                  'including the library markers. Every device must '
                  're-establish sync from scratch. Your dive data is not '
                  'affected.\n\nType WIPE to confirm.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'WIPE',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: armed ? () => Navigator.pop(context, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Wipe everything'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (ok != true) return;
    await ref.read(syncStateProvider.notifier).wipeAllCloudSyncData();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wiped all sync data')));
    }
  }
}
