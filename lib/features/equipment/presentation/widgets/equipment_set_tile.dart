import 'package:flutter/material.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/markdown/notes_plain_text.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// An equipment set's row: its name, default badge, item count and
/// description.
class EquipmentSetTile extends ConsumerWidget {
  const EquipmentSetTile({
    super.key,
    required this.set,
    required this.onTap,
    this.isSelected = false,
  });

  final EquipmentSet set;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCountText = set.itemCount == 1
        ? context.l10n.equipment_sets_itemCountSingular(set.itemCount)
        : context.l10n.equipment_sets_itemCountPlural(set.itemCount);
    // The count leads the description on one line rather than sitting
    // in a trailing chip: a ListTile lays trailing out at its natural
    // width first, and a chip there starves the set name (issue #2717).
    final description = markdownToPlainText(
      set.description,
    ).replaceAll('\n', ' ');
    final subtitleText = description.isEmpty
        ? itemCountText
        : set.itemCount > 0
        ? '$itemCountText · $description'
        : description;
    return Semantics(
      label: listItemLabel(title: set.name, subtitle: subtitleText),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: isSelected
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        child: ListTile(
          onTap: onTap,
          leading: Builder(
            builder: (context) {
              final accent = resolveFeatureAccent(
                context,
                ref,
                surface: AccentSurface.list,
                featureId: 'equipment',
              );
              return CircleAvatar(
                backgroundColor:
                    accent?.withValues(alpha: 0.15) ??
                    Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.folder,
                  color:
                      accent ??
                      Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              );
            },
          ),
          title: Row(
            children: [
              Flexible(child: Text(set.name)),
              if (set.isDefault) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text(context.l10n.equipment_sets_defaultBadge),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
