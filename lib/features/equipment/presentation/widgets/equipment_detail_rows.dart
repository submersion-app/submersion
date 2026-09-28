import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_web_link_launcher.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One label and value row in the equipment detail page's details card.
class EquipmentDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const EquipmentDetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          const SizedBox(width: 16),
          // Flexible so long values (e.g. free-text custom fields) wrap
          // instead of overflowing the row.
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// One purchase-record row. A `url` attribute whose stored text resolves
/// to an http(s) link becomes tappable; anything else (including a value
/// [parseWebLink] rejects) renders as plain text, so a garbled link is
/// still visible and editable rather than silently dropped.
class EquipmentPurchaseAttributeRow extends StatelessWidget {
  final EquipmentAttributeDef def;
  final EquipmentAttribute attr;
  final UnitFormatter units;

  const EquipmentPurchaseAttributeRow({
    super.key,
    required this.def,
    required this.attr,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final label = attributeLabel(context.l10n, def.key);
    if (def.kind == AttributeKind.url) {
      final link = parseWebLink(attr.valueText);
      if (link != null) {
        return EquipmentDetailLinkRow(
          label: label,
          value: attr.valueText!,
          link: link,
        );
      }
    }
    return EquipmentDetailRow(
      label: label,
      value: formatAttributeValue(attr, def, units, context.l10n),
    );
  }
}

/// [EquipmentDetailRow] with the value rendered as a tappable link.
class EquipmentDetailLinkRow extends ConsumerWidget {
  final String label;
  final String value;
  final Uri link;

  const EquipmentDetailLinkRow({
    super.key,
    required this.label,
    required this.value,
    required this.link,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: InkWell(
              key: const ValueKey('equipment-detail-web-link'),
              onTap: () => launchEquipmentWebLink(
                context,
                link,
                launch: ref.read(equipmentWebLinkLaunchProvider),
              ),
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The item's colour: its label, then a swatch and the colour's name.
class EquipmentDetailColorRow extends StatelessWidget {
  /// A normalized colour code, as `normalizeEquipmentColor` returns it.
  final String code;

  const EquipmentDetailColorRow({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            attributeLabel(context.l10n, EquipmentAttrKeys.color),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const ValueKey('detail-color-swatch'),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: TagColors.fromHex(code),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                equipmentColorName(context.l10n, code),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
