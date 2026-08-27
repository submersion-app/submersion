import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_checkbox_slot.dart';
import 'package:submersion/shared/widgets/entity_card/card_slot_resolver.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_stat.dart';

/// Two-line compact card tile for the site list, driven by
/// [siteCompactCardConfigProvider].
///
/// Line 1: title slot | rating | stat1 | chevron
/// Line 2: subtitle slot | stat2
class CompactSiteListTile extends ConsumerWidget {
  final SiteWithDiveCount entry;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isHighlighted;
  final bool showSharedBadge;

  const CompactSiteListTile({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isHighlighted = false,
    this.showSharedBadge = false,
  });

  String get name => entry.site.name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final slots = ref.watch(siteCompactCardConfigProvider).slots;
    final adapter = SiteFieldAdapter.instance;
    final site = entry.site;
    final cardColor = (isSelected || isHighlighted)
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : null;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    String? slotText(SiteField field) {
      final value = adapter.extractValue(field, entry);
      if (value == null) return null;
      final text = adapter.formatValue(field, value, units);
      return text.isEmpty ? null : text;
    }

    final title =
        slotText(resolveCardSlot(slots, 'title', SiteField.siteName)) ??
        site.name;
    final subtitle = slotText(
      resolveCardSlot(slots, 'subtitle', SiteField.location),
    );
    final stat2Field = resolveCardSlot(slots, 'stat2', SiteField.depthRange);
    final showSecondLine = subtitle != null || slotText(stat2Field) != null;

    String formatStat(SiteField field, dynamic value) {
      if (field == SiteField.diveCount) {
        return l10n.diveSites_list_tile_diveCount(value as int);
      }
      return adapter.formatValue(field, value, units);
    }

    Widget stat(String slotId, SiteField fallback) {
      final field = resolveCardSlot(slots, slotId, fallback);
      if (field == SiteField.diveCount && entry.diveCount == 0) {
        return const SizedBox.shrink();
      }
      return EntityCardStat<SiteWithDiveCount, SiteField>(
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
        label: l10n.diveSites_list_tile_semantics(site.name),
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
                          if (site.rating != null) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              site.rating!.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (showSharedBadge) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: l10n
                                  .accessibility_label_sharedWithAllProfiles,
                              child: Icon(
                                Icons.people_outline,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          stat('stat1', SiteField.diveCount),
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
                            stat('stat2', SiteField.depthRange),
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
