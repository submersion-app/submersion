import 'package:flutter/material.dart';

import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_route.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// What needs the diver after setup (spec 6.5): an account to sign in to
/// again, a store the library announces that this device has not joined,
/// a store marker that no longer matches. One line each, with the action
/// that resolves it and a per-device dismiss.
class SetUpPendingItems extends StatelessWidget {
  const SetUpPendingItems({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onSignIn,
    required this.onDismiss,
  });

  final List<PendingSetupItem> items;

  /// Opens a settings page through the card's host.
  final ValueChanged<String> onOpen;
  final Future<void> Function(PendingSetupItem item) onSignIn;
  final Future<void> Function(PendingSetupItem item) onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        for (final item in items)
          ListTile(
            contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
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
              SetupItemKind.accountSignIn => _signInLine(l10n, item),
            }),
            // The action sits on its own line, never in trailing, where a
            // translated label would squeeze the sentence (#2717).
            subtitle: switch (item.kind) {
              SetupItemKind.mediaStoreAttach => TileSubtitleAction(
                label: l10n.settings_data_setUp,
                semanticsLabel: l10n.settings_data_setUpFeature(
                  l10n.settings_photosVideos_title,
                ),
                onPressed: () => onOpen(setUpStepRoute(SetUpStep.photos)),
              ),
              SetupItemKind.mediaStoreReconnect => TileSubtitleAction(
                label: l10n.settings_setUpDevice_item_reconnectAction,
                onPressed: () => onOpen(item.route),
              ),
              SetupItemKind.accountSignIn => TileSubtitleAction(
                label: l10n.settings_setUpDevice_item_signInAction,
                onPressed: () => onSignIn(item),
              ),
            },
            trailing: IconButton(
              tooltip: l10n.common_action_dismiss,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onDismiss(item),
            ),
          ),
      ],
    );
  }

  /// Names what stops until the account is signed in again: sync, the
  /// backup copy, both, or neither (a library or the photo copies).
  static String _signInLine(AppLocalizations l10n, PendingSetupItem item) {
    final sync = item.usages.contains(AccountUsageKind.databaseSync);
    final backups = item.usages.contains(AccountUsageKind.backupCopy);
    return switch ((sync, backups)) {
      (true, true) => l10n.settings_setUpDevice_item_signIn(item.label),
      (true, false) => l10n.settings_setUpDevice_item_signInSync(item.label),
      (false, true) => l10n.settings_setUpDevice_item_signInBackups(item.label),
      (false, false) => l10n.settings_setUpDevice_item_signInShort(item.label),
    };
  }
}
