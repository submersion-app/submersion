import 'package:flutter/material.dart';

import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The pages whose feature stops while an account waits for a sign-in.
const _pausingRoutes = {'/settings/cloud-sync', '/settings/backup'};

/// What needs the diver after setup (spec 6.5): an account to sign in to
/// again, a store the library announces that this device has not joined,
/// a store marker that no longer matches. One line each, with the action
/// that resolves it and a per-device dismiss.
class SetUpPendingItems extends StatelessWidget {
  const SetUpPendingItems({
    super.key,
    required this.items,
    required this.onOpenStep,
    required this.onSignIn,
    required this.onDismiss,
  });

  final List<PendingSetupItem> items;
  final ValueChanged<SetUpStep> onOpenStep;
  final Future<void> Function(PendingSetupItem item) onSignIn;
  final Future<void> Function(PendingSetupItem item) onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        for (final item in items)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 16, right: 4),
            leading: Icon(switch (item.kind) {
              SetupItemKind.mediaStoreAttach => Icons.cloud_upload_outlined,
              SetupItemKind.mediaStoreReconnect => Icons.sync_problem_outlined,
              SetupItemKind.accountSignIn => Icons.account_circle_outlined,
            }),
            title: Text(switch (item.kind) {
              SetupItemKind.mediaStoreAttach =>
                l10n.settings_setUpDevice_item_attach(item.label),
              SetupItemKind.mediaStoreReconnect =>
                l10n.settings_setUpDevice_item_reconnect(item.label),
              SetupItemKind.accountSignIn =>
                _pausingRoutes.contains(item.route)
                    ? l10n.settings_setUpDevice_item_signIn(item.label)
                    : l10n.settings_setUpDevice_item_signInShort(item.label),
            }),
            // The action sits on its own line, never in trailing, where a
            // translated label would squeeze the sentence (#2717).
            subtitle: TileSubtitleAction(
              label: switch (item.kind) {
                SetupItemKind.mediaStoreAttach =>
                  l10n.settings_setUpDevice_item_attachAction,
                SetupItemKind.mediaStoreReconnect =>
                  l10n.settings_setUpDevice_item_reconnectAction,
                SetupItemKind.accountSignIn =>
                  l10n.settings_setUpDevice_item_signInAction,
              },
              onPressed: () => switch (item.kind) {
                SetupItemKind.mediaStoreAttach => onOpenStep(SetUpStep.photos),
                SetupItemKind.mediaStoreReconnect => context.pushSettingsPage(
                  item.route,
                ),
                SetupItemKind.accountSignIn => onSignIn(item),
              },
            ),
            trailing: IconButton(
              tooltip: l10n.settings_setUpDevice_item_dismiss,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onDismiss(item),
            ),
          ),
      ],
    );
  }
}
