import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/widgets/shared_items/share_target_dialog.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// Shares several trips or sites at once (issue #2151): asks who to add,
/// adds them to every one of [ids] that [activeDiverId] owns (an item
/// already shared with everyone is left alone), and reports how many were
/// shared and how many skipped. It never takes an item away from anyone,
/// so it needs no unshare confirmation. [body] replaces the dialog's
/// explanation, as Settings' "Share all..." does.
Future<BulkActionOutcome> shareItemsWithProfiles(
  BuildContext context,
  WidgetRef ref, {
  required SharedItemKind kind,
  required List<String> ids,
  required String? activeDiverId,
  String? body,
}) async {
  if (ids.isEmpty || activeDiverId == null) {
    return BulkActionOutcome.cancelled;
  }
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  // Inside the error handling: a selection action must not throw.
  final List<Diver> divers;
  try {
    divers = await ref.read(allDiversProvider.future);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.common_error_tryAgain)));
    return BulkActionOutcome.failed;
  }
  if (!context.mounted) return BulkActionOutcome.cancelled;
  final chosen = await showShareTargetDialog(
    context,
    title: l10n.sharedItems_shareDialog_title,
    body:
        body ??
        switch (kind) {
          SharedItemKind.trip => l10n.sharedItems_shareDialog_tripBody,
          SharedItemKind.site => l10n.sharedItems_shareDialog_siteBody,
        },
    profiles: [
      for (final d in divers)
        if (d.id != activeDiverId) d,
    ],
    initial: ItemSharing.none,
    confirmLabel: l10n.common_action_share,
    allowEmpty: false,
  );
  if (chosen == null) return BulkActionOutcome.cancelled;
  try {
    final result = await ref
        .read(itemSharesRepositoryProvider)
        .addSharing(kind, ids, chosen, actingDiverId: activeDiverId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.skippedNotOwned == 0
              ? l10n.sharedItems_bulkShare_done(result.itemsShared)
              : l10n.sharedItems_bulkShare_doneSkipped(
                  result.itemsShared,
                  result.skippedNotOwned,
                ),
        ),
      ),
    );
    return BulkActionOutcome.completed;
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.common_error_tryAgain)));
    return BulkActionOutcome.failed;
  }
}
