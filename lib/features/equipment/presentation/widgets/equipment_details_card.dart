import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_detail_rows.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_sharing_row.dart';
import 'package:submersion/features/equipment/presentation/widgets/installed_in_row.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The equipment detail page's Details card: status, where the item is
/// installed, its dive and trip counts, sharing, identity, specs, colour,
/// custom fields, and the purchase block.
class EquipmentDetailsCard extends ConsumerWidget {
  final EquipmentItem equipment;

  /// The id the page was opened with; the providers are keyed by it.
  final String equipmentId;

  final UnitFormatter units;

  const EquipmentDetailsCard({
    super.key,
    required this.equipment,
    required this.equipmentId,
    required this.units,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diveCountAsync = ref.watch(equipmentDiveCountProvider(equipmentId));
    final tripCountAsync = ref.watch(equipmentTripCountProvider(equipmentId));
    // The item this one is installed in. A parent id naming nothing (a
    // parent row that never arrived) resolves to null and shows no row.
    final parentId = equipment.parentEquipmentId;
    final host = parentId == null
        ? null
        : ref.watch(equipmentItemProvider(parentId)).value;
    final showsInstallAge = InstalledInRow.showsInstallAge(equipment, host);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.equipment_detail_detailsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            EquipmentDetailRow(
              label: context.l10n.equipment_detail_statusLabel,
              value: equipment.status.localizedName(context.l10n),
            ),
            if (host != null)
              InstalledInRow(part: equipment, host: host, units: units),
            _LinkedCountRow(
              countAsync: diveCountAsync,
              label: context.l10n.equipment_detail_divesLabel,
              semanticLabel: context.l10n.equipment_detail_divesSemanticLabel,
              countText: (count) => count == 1
                  ? context.l10n.equipment_detail_divesCountSingular(count)
                  : context.l10n.equipment_detail_divesCountPlural(count),
              onOpen: () {
                ref.read(diveFilterProvider.notifier).state = DiveFilterState(
                  equipmentIds: [equipmentId],
                );
                context.go('/dives');
              },
            ),
            _LinkedCountRow(
              countAsync: tripCountAsync,
              label: context.l10n.equipment_detail_tripsLabel,
              semanticLabel: context.l10n.equipment_detail_tripsSemanticLabel,
              countText: (count) => count == 1
                  ? context.l10n.equipment_detail_tripsCountSingular(count)
                  : context.l10n.equipment_detail_tripsCountPlural(count),
              onOpen: () {
                ref.read(tripFilterProvider.notifier).state = TripFilterState(
                  equipmentId: equipmentId,
                );
                context.go('/trips');
              },
            ),
            EquipmentSharingRow(equipment: equipment),
            if (equipment.brand != null)
              EquipmentDetailRow(
                label: context.l10n.equipment_detail_brandLabel,
                value: equipment.brand!,
              ),
            if (equipment.model != null)
              EquipmentDetailRow(
                label: context.l10n.equipment_detail_modelLabel,
                value: equipment.model!,
              ),
            if (equipment.serialNumber != null)
              EquipmentDetailRow(
                label: context.l10n.equipment_detail_serialNumberLabel,
                value: equipment.serialNumber!,
              ),
            // Curated specs in catalog order, then custom fields. The
            // purchase group is held back to the purchase block below, and
            // the install date to the installed-in row while it shows one.
            for (final def
                in EquipmentAttributeCatalog.attributesFor(
                  equipment.type,
                ).where(
                  (d) =>
                      d.group == AttributeGroup.spec &&
                      !(showsInstallAge &&
                          d.key == EquipmentAttrKeys.installedDate),
                ))
              if (equipment.attributes.firstWhereOrNull(
                    (a) => !a.isCustom && a.key == def.key,
                  )
                  case final attr? when attr.hasValue)
                EquipmentDetailRow(
                  label: attributeLabel(context.l10n, def.key),
                  value: formatAttributeValue(attr, def, units, context.l10n),
                ),
            // The item's colour (issue #2326): its own row with a swatch,
            // only when the stored value is a colour code.
            if (normalizeEquipmentColor(
                  equipment.attrText(EquipmentAttrKeys.color),
                )
                case final code?)
              EquipmentDetailColorRow(code: code),
            for (final attr
                in equipment.attributes.where((a) => a.isCustom).toList()
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
              if (attr.hasValue)
                EquipmentDetailRow(
                  label: attr.key,
                  value: attr.valueText ?? '',
                ),
            if (equipment.purchaseDate != null)
              EquipmentDetailRow(
                label: context.l10n.equipment_detail_purchaseDateLabel,
                value: units.formatDate(equipment.purchaseDate),
              ),
            if (equipment.purchasePrice != null)
              EquipmentDetailRow(
                label: context.l10n.equipment_detail_purchasePriceLabel,
                value: formatMoney(
                  equipment.purchasePrice!,
                  equipment.purchaseCurrency,
                ),
              ),
            // Purchase record (issue #1517): the receipt trail, shown with
            // the date and price rather than among the physical specs.
            for (final def in EquipmentAttributeCatalog.purchase)
              if (equipment.attributes.firstWhereOrNull(
                    (a) => !a.isCustom && a.key == def.key,
                  )
                  case final attr? when attr.hasValue)
                EquipmentPurchaseAttributeRow(
                  def: def,
                  attr: attr,
                  units: units,
                ),
            if (equipment.ownershipDuration != null)
              EquipmentDetailRow(
                label: context.l10n.equipment_detail_ownedForLabel,
                value: _formatDuration(
                  context.l10n,
                  equipment.ownershipDuration!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A count row (dives, trips) that opens the filtered list when there is
/// something to show, with "..." while the count loads and nothing at all
/// if it fails.
class _LinkedCountRow extends StatelessWidget {
  final AsyncValue<int> countAsync;
  final String label;
  final String semanticLabel;
  final String Function(int count) countText;
  final VoidCallback onOpen;

  const _LinkedCountRow({
    required this.countAsync,
    required this.label,
    required this.semanticLabel,
    required this.countText,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return countAsync.when(
      data: (count) => Semantics(
        button: count > 0,
        label: semanticLabel,
        child: InkWell(
          onTap: count > 0 ? onOpen : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      countText(count),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: count > 0
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      loading: () => EquipmentDetailRow(label: label, value: '...'),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

String _formatDuration(AppLocalizations l10n, Duration duration) {
  final days = duration.inDays;
  if (days < 30) return l10n.equipment_detail_durationDays(days);
  if (days < 365) {
    final months = (days / 30).floor();
    return l10n.equipment_detail_durationMonths(months);
  }
  final years = (days / 365).floor();
  final months = ((days % 365) / 30).floor();
  if (months == 0) {
    return years == 1
        ? l10n.equipment_detail_durationYearsSingular(years)
        : l10n.equipment_detail_durationYearsPlural(years);
  }
  if (years == 1 && months == 1) {
    return l10n.equipment_detail_durationYearsMonthsSingularSingular(
      years,
      months,
    );
  }
  if (years == 1) {
    return l10n.equipment_detail_durationYearsMonthsSingularPlural(
      years,
      months,
    );
  }
  if (months == 1) {
    return l10n.equipment_detail_durationYearsMonthsPluralSingular(
      years,
      months,
    );
  }
  return l10n.equipment_detail_durationYearsMonthsPluralPlural(years, months);
}
