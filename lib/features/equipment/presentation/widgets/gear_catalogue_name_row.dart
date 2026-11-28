import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_catalogue_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/catalogue_name_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The gear editor's brand and model fields, suggesting names from the
/// built-in equipment catalogue and the diver's own brands (issue #5118).
class GearCatalogueNameRow extends ConsumerWidget {
  const GearCatalogueNameRow({
    super.key,
    required this.type,
    required this.brand,
    required this.model,
  });

  final EquipmentType type;
  final TextEditingController brand;
  final TextEditingController model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final catalogue =
        ref.watch(equipmentCatalogueProvider).value ?? EquipmentCatalogue.empty;
    final diverBrands = <String>[
      for (final item
          in ref.watch(activeEquipmentProvider).value ??
              const <EquipmentItem>[])
        ?item.brand,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CatalogueNameField(
            key: const ValueKey('gear-edit-brand'),
            controller: brand,
            label: l10n.equipment_edit_brandLabel,
            icon: Icons.business,
            suggestionsFor: (typed) =>
                brandSuggestions(catalogue, type, diverBrands, typed),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CatalogueNameField(
            key: const ValueKey('gear-edit-model'),
            controller: model,
            label: l10n.equipment_edit_modelLabel,
            icon: Icons.info_outline,
            suggestionsFor: (typed) =>
                modelSuggestions(catalogue, type, brand.text, typed),
          ),
        ),
      ],
    );
  }
}
