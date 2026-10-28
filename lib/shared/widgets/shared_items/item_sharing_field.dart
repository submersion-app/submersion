import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/shared_items/share_target_dialog.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';

/// "Shared with" on a trip or site edit page (issue #2151), the one place
/// it is shown (#3766): [value] is the page's pending choice, saved with
/// the form. Shown only with two or more profiles. [mayShare] is the owner
/// check: true opens the dialog, false locks it and names [ownerId]'s
/// profile, null (the profile is not known yet) locks it without naming
/// anyone. A choice that takes the item away from a profile that sees it in
/// [original] is confirmed first.
class ItemSharingField extends ConsumerWidget {
  const ItemSharingField({
    super.key,
    required this.kind,
    required this.value,
    required this.original,
    required this.mayShare,
    required this.ownerId,
    required this.itemName,
    required this.onChanged,
  });

  final SharedItemKind kind;
  final ItemSharing value;
  final ItemSharing original;
  final bool? mayShare;

  /// The item's owner; for a new item, the active profile.
  final String? ownerId;
  final String itemName;
  final ValueChanged<ItemSharing> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divers = ref.watch(allDiversProvider).value;
    if (divers == null || divers.length < 2) return const SizedBox.shrink();
    final l10n = context.l10n;
    final names = {for (final d in divers) d.id: d.name};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SharingTile(
          summary: sharingSummary(value, names, l10n),
          onTap: mayShare == true
              ? () async {
                  final chosen = await pickItemSharing(
                    context,
                    kind: kind,
                    profiles: [
                      for (final d in divers)
                        if (d.id != ownerId) d,
                    ],
                    current: value,
                    confirmAgainst: original,
                    itemName: itemName,
                  );
                  if (chosen != null) onChanged(chosen);
                }
              : null,
        ),
        // Only the owner changes sharing (#2594).
        if (mayShare == false)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 16, 8),
            child: Text(
              l10n.sharedItems_shareOwnerOnly(
                sharedItemOwnerName(divers, ownerId, l10n),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// What an edit page says when the repository refuses its sharing change
/// (#3766). The repository refuses a profile that is not the owner at
/// save time: the item changed hands, or the active profile changed, while
/// the page was open. Either way the page's idea of the owner is out of
/// date, so the message names nobody.
String sharingRefusedMessage(AppLocalizations l10n) =>
    l10n.sharedItems_shareOwnerOnly(l10n.sharedItems_ownerUnknown);

/// Opens the share dialog for one trip or site, starting from [current],
/// and confirms first when the choice takes the item away from a profile
/// that sees it in [confirmAgainst] (by default [current]). Returns the
/// confirmed choice, or null when cancelled or unchanged.
Future<ItemSharing?> pickItemSharing(
  BuildContext context, {
  required SharedItemKind kind,
  required List<Diver> profiles,
  required ItemSharing current,
  required String itemName,
  ItemSharing? confirmAgainst,
}) async {
  final l10n = context.l10n;
  final chosen = await showShareTargetDialog(
    context,
    title: l10n.sharedItems_shareDialog_title,
    body: switch (kind) {
      SharedItemKind.trip => l10n.sharedItems_shareDialog_tripBody,
      SharedItemKind.site => l10n.sharedItems_shareDialog_siteBody,
    },
    profiles: profiles,
    initial: current,
    confirmLabel: l10n.common_action_save,
  );
  if (chosen == null || chosen == current || !context.mounted) return null;
  if ((confirmAgainst ?? current).narrowsAmong(chosen, [
        for (final p in profiles) p.id,
      ]) &&
      await confirmUnshare(context, kind, itemName) != true) {
    return null;
  }
  return chosen;
}

/// Asks the owner to confirm taking a trip or site away from profiles that
/// see it now. True when confirmed.
Future<bool?> confirmUnshare(
  BuildContext context,
  SharedItemKind kind,
  String itemName,
) => showDialog<bool>(
  context: context,
  builder: (dialogCtx) {
    final l10n = dialogCtx.l10n;
    return AlertDialog(
      title: Text(switch (kind) {
        SharedItemKind.trip => l10n.trips_unshareConfirm_title,
        SharedItemKind.site => l10n.sites_unshareConfirm_title,
      }),
      content: Text(switch (kind) {
        SharedItemKind.trip => l10n.trips_unshareConfirm_body(itemName),
        SharedItemKind.site => l10n.sites_unshareConfirm_body(itemName),
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(MaterialLocalizations.of(dialogCtx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: Text(l10n.common_action_unshare),
        ),
      ],
    );
  },
);

/// The "Shared with" label, the [summary] of who sees the item, and a
/// chevron when [onTap] is set.
class SharingTile extends StatelessWidget {
  const SharingTile({super.key, required this.summary, this.onTap});

  final String summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: DetailRow(
          icon: Icons.people_outline,
          iconColor: theme.colorScheme.onSurfaceVariant,
          label: context.l10n.sharedItems_sharedWith_label,
          padding: EdgeInsets.zero,
          value: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  summary,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
