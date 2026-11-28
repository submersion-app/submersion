import 'package:flutter/material.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_offer.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_web_link_launcher.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_catalogue_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_catalogue_review_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// On a linked item's page: the manufacturer's product, manual and support
/// pages, read live from the equipment catalogue record (issue #5118).
/// Nothing is copied into the item, so a corrected link arrives with the
/// next catalogue copy. Hidden when the item is unlinked, its record is not
/// in the catalogue this device holds, the record has no links, or the
/// item's brand and model no longer name it. Brings
/// its own bottom gap, so it takes no room when hidden.
class GearManufacturerCard extends ConsumerWidget {
  const GearManufacturerCard({super.key, required this.item});

  final EquipmentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = item.catalogueId;
    final catalogue = ref.watch(equipmentCatalogueProvider).value;
    final record = id == null ? null : catalogue?.byId(id);
    if (record == null || record.links.isEmpty) return const SizedBox.shrink();
    // A rename outside the editor (an agent write, an import merge) keeps
    // the link; the pages are shown only while the name still names it.
    if (catalogueIdAfterRename(item, catalogue!) != id) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    // The title says whose pages these are; the line dates them by the
    // sources that gave the links.
    final checked = catalogueSourceSummary(
      record,
      fieldPrefix: 'links.',
    )?.checked;
    final source = checked == null
        ? null
        : l10n.equipment_manufacturer_checked(
            ref.watch(unitFormatterProvider).formatDate(checked),
          );
    final links = <(String, String?)>[
      (l10n.equipment_manufacturer_product, record.links.product),
      (l10n.equipment_manufacturer_manual, record.links.manual),
      (l10n.equipment_manufacturer_support, record.links.support),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.factory_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.equipment_manufacturer_title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<void>(
                    key: const ValueKey('gear-manufacturer-menu'),
                    itemBuilder: (_) => [
                      PopupMenuItem<void>(
                        onTap: () => _unlink(ref),
                        child: Text(l10n.equipment_manufacturer_unlink),
                      ),
                    ],
                  ),
                ],
              ),
              if (source != null)
                Text(
                  source,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              for (final (label, url) in links)
                if (parseWebLink(url) case final uri?)
                  _LinkRow(label: label, uri: uri),
            ],
          ),
        ),
      ),
    );
  }

  /// Clears the link through the item's save service, so it is one History
  /// entry like any edit; the values taken from the record stay.
  Future<void> _unlink(WidgetRef ref) async {
    final service = ref.read(gearItemEditSaveServiceProvider);
    await service.save(
      equipmentId: item.id,
      apply: (stored) => gearCatalogueIdField.write(stored, null),
      changedCardIds: [GearItemCardId.details.name],
    );
    ref.invalidate(equipmentItemProvider(item.id));
  }
}

class _LinkRow extends ConsumerWidget {
  const _LinkRow({required this.label, required this.uri});

  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => launchEquipmentWebLink(
        context,
        uri,
        launch: ref.read(equipmentWebLinkLaunchProvider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.open_in_new, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
