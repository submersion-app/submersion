import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/database/database.dart' show NearbyPeer;
import 'package:submersion/features/settings/presentation/providers/nearby_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Rename, sync now or unpair one paired device.
Future<void> showNearbyDeviceSheet(BuildContext context, NearbyPeer peer) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => NearbyDeviceSheet(peer: peer),
    );

class NearbyDeviceSheet extends ConsumerWidget {
  const NearbyDeviceSheet({super.key, required this.peer});

  final NearbyPeer peer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final id = peer.peerDeviceId;

    Future<void> rename() async {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => _RenameDialog(initial: peer.displayName),
      );
      if (name != null && name.isNotEmpty) {
        await ref.read(nearbyPeerStoreProvider).rename(id, name);
      }
      navigator.pop();
    }

    Future<void> syncNow() async {
      navigator.pop();
      final outcome = await ref.read(nearbyLinkManagerProvider).syncNow(id);
      if (outcome == null) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(l10n.settings_nearby_notInRange(peer.displayName)),
          ),
        );
      }
    }

    Future<void> unpair() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(l10n.settings_nearby_unpair_confirm(peer.displayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.common_action_cancel),
            ),
            TextButton(
              key: const Key('nearby-unpair-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.settings_nearby_sheet_unpair),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(nearbyLinkManagerProvider).unpair(id);
      }
      navigator.pop();
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              peer.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            key: const Key('nearby-sheet-rename'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.settings_nearby_sheet_rename),
            onTap: rename,
          ),
          ListTile(
            key: const Key('nearby-sheet-sync'),
            leading: const Icon(Icons.sync),
            title: Text(l10n.settings_cloudSync_syncNow),
            onTap: syncNow,
          ),
          ListTile(
            key: const Key('nearby-sheet-unpair'),
            leading: Icon(
              Icons.link_off,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.settings_nearby_sheet_unpair,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: unpair,
          ),
        ],
      ),
    );
  }
}

/// Owns its controller, so the field outlives the dialog's exit animation.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.settings_nearby_rename_title),
      content: TextField(
        key: const Key('nearby-rename-field'),
        controller: _controller,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
