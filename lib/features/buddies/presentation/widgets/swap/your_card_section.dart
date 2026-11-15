import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/card_summary.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// The top of the swap screen (issue #4598): who you are and what your card
/// carries, so you see what you share before you swap. A null [card] could
/// not be built; the section says so and offers nothing to edit.
class YourCardSection extends ConsumerWidget {
  const YourCardSection({super.key, required this.card, required this.onEdit});

  final BuddyCard? card;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final card = this.card;
    final Widget content;
    if (card == null) {
      content = Text(l10n.buddySwap_cardFailed);
    } else {
      final formatter = ref.watch(unitFormatterProvider);
      final chips = buddyCardChips(card, l10n, formatter.formatDate);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                photo: card.photo,
                initials: Buddy.initialsOf(card.name),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.name, style: theme.textTheme.titleMedium),
                    Text(
                      l10n.buddySwap_yourCard,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: Text(l10n.common_action_edit),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Wrap lays each chip out no wider than the row, so a long
            // email ellipsizes instead of running off the card.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in chips)
                  Chip(
                    label: Text(
                      chip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: content),
      ),
    );
  }
}
