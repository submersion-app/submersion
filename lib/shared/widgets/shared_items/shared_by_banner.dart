import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';

/// "Shared by {owner}", shown on a trip or site that another profile owns
/// and shares with the active profile, with everyone or by name (issues
/// #2594, #2151), so the active profile knows why it can only remove the
/// item from itself. Adds that the item is hidden when the active profile
/// has already removed it (issue #2679). Renders nothing otherwise, also on
/// an item opened by id that is no longer shared with this profile.
class SharedByBanner extends ConsumerWidget {
  const SharedByBanner({
    super.key,
    required this.kind,
    required this.itemId,
    required this.ownerId,
  });

  final SharedItemKind kind;
  final String itemId;
  final String? ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing until the active profile is known, rather than describe the
    // previous profile's standing during a switch (issue #2677 review).
    final activeDiver = ref.watch(validatedCurrentDiverIdProvider);
    final canDestroy = canDestroySharedItemOnceKnown(
      activeDiver,
      ownerId: ownerId,
    );
    final divers = ref.watch(allDiversProvider).value;
    final sharing = ref
        .watch(itemSharingProvider((kind: kind, id: itemId)))
        .value;
    final activeDiverId = activeDiver.value;
    if (divers == null ||
        sharing == null ||
        canDestroy != false ||
        activeDiverId == null ||
        !sharing.reaches(activeDiverId)) {
      return const SizedBox.shrink();
    }
    final hidden = watchHiddenHere(ref, kind, itemId, canDestroy: false);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(
            Icons.people_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              [
                context.l10n.sharedItems_sharedBy(
                  sharedItemOwnerName(divers, ownerId, context.l10n),
                ),
                if (hidden) context.l10n.sharedItems_hiddenHere,
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
