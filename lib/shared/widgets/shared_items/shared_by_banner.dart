import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_standing.dart';

/// "Shared by {owner}", shown on a trip or site that another profile owns
/// and shares (issue #2594), so the active profile knows why it can only
/// remove the item from itself. Renders nothing otherwise.
class SharedByBanner extends ConsumerWidget {
  const SharedByBanner({
    super.key,
    required this.ownerId,
    required this.isShared,
  });

  final String? ownerId;
  final bool isShared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing until the active profile has settled, rather than describe
    // the previous profile's standing during a switch.
    final standing = watchSharedItemStanding(ref, ownerId: ownerId);
    final divers = ref.watch(allDiversProvider).value;
    if (divers == null || !isShared || standing != SharedItemStanding.other) {
      return const SizedBox.shrink();
    }
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
              context.l10n.sharedItems_sharedBy(
                sharedItemOwnerName(divers, ownerId, context.l10n),
              ),
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
