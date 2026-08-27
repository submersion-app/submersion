import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_checkbox_slot.dart';
import 'package:submersion/shared/widgets/entity_card/card_slot_resolver.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_stat.dart';

/// Two-line compact card tile for the buddy list, driven by
/// [buddyCompactCardConfigProvider]. No avatar, no chips.
///
/// Line 1: title slot | stat1 | chevron
/// Line 2: subtitle slot | stat2
class CompactBuddyListTile extends ConsumerWidget {
  final BuddyWithDiveCount entry;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isHighlighted;

  const CompactBuddyListTile({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isHighlighted = false,
  });

  Buddy get buddy => entry.buddy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final slots = ref.watch(buddyCompactCardConfigProvider).slots;
    final adapter = BuddyFieldAdapter.instance;
    final secondaryTextColor = colorScheme.onSurfaceVariant;
    final cardColor = (isSelected || isHighlighted)
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : null;

    String? slotText(BuddyField field) {
      final value = adapter.extractValue(field, entry);
      if (value == null) return null;
      final text = adapter.formatValue(field, value, units);
      return text.isEmpty || text == '--' ? null : text;
    }

    final title =
        slotText(resolveCardSlot(slots, 'title', BuddyField.buddyName)) ??
        buddy.name;
    final subtitle = slotText(
      resolveCardSlot(slots, 'subtitle', BuddyField.certificationLevel),
    );
    final stat2Field = resolveCardSlot(slots, 'stat2', BuddyField.lastDive);
    final showSecondLine = subtitle != null || slotText(stat2Field) != null;

    String formatStat(BuddyField field, dynamic value) {
      if (field == BuddyField.diveCount) {
        return l10n.buddies_label_diveCount(value as int);
      }
      return adapter.formatValue(field, value, units);
    }

    Widget stat(BuddyField field) {
      return EntityCardStat<BuddyWithDiveCount, BuddyField>(
        adapter: adapter,
        entity: entry,
        field: field,
        units: units,
        color: secondaryTextColor,
        formatter: formatStat,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      color: cardColor,
      child: Semantics(
        button: true,
        selected: isSelected || isHighlighted,
        label: buddy.name,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SelectionCheckboxSlot(
                  isSelectionMode: isSelectionMode,
                  isChecked: isSelected,
                  onChanged: (_) => onTap?.call(),
                  gap: 8,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          stat(
                            resolveCardSlot(
                              slots,
                              'stat1',
                              BuddyField.diveCount,
                            ),
                          ),
                          ExcludeSemantics(
                            child: Icon(
                              Icons.chevron_right,
                              color: secondaryTextColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      if (showSecondLine) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subtitle ?? '',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: secondaryTextColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            stat(stat2Field),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
