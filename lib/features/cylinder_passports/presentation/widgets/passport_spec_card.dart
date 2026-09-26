import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_metrics.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Volume, working pressure, material and valve from the attributes; free
/// gas and buoyancy derived through the diver's gas model and the tank
/// physics (spec section 8, Cylinder card).
class PassportSpecCard extends ConsumerWidget {
  const PassportSpecCard({super.key, required this.equipment});

  final EquipmentItem equipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final newest = ref.watch(newestFillProvider(equipment.id)).value;
    final metrics = PassportSpecMetrics.compute(
      volumeL: equipment.volumeL,
      workingPressureBar: equipment.workingPressureBar,
      material: equipment.tankMaterial,
      o2Percent: newest?.o2Percent ?? 21,
      hePercent: newest?.hePercent ?? 0,
      gasModel: settings.gasModel,
    );
    final valve = equipment.attrText('valve_type');
    final rows = <(String, String)>[
      if (equipment.volumeL != null)
        (
          attributeLabel(l10n, EquipmentAttrKeys.volumeL),
          units.formatVolume(equipment.volumeL),
        ),
      if (equipment.workingPressureBar != null)
        (
          attributeLabel(l10n, EquipmentAttrKeys.workingPressureBar),
          units.formatPressure(equipment.workingPressureBar),
        ),
      if (equipment.tankMaterial != null)
        (
          attributeLabel(l10n, EquipmentAttrKeys.tankMaterial),
          attributeChoiceLabel(
            l10n,
            EquipmentAttrKeys.tankMaterial,
            equipment.attrText(EquipmentAttrKeys.tankMaterial) ?? '',
          ),
        ),
      if (valve != null)
        (
          attributeLabel(l10n, 'valve_type'),
          attributeChoiceLabel(l10n, 'valve_type', valve),
        ),
      if (metrics.freeGasLiters != null)
        (
          l10n.passport_spec_freeGas(
            units.formatPressure(equipment.workingPressureBar),
          ),
          units.formatVolume(metrics.freeGasLiters),
        ),
      if (metrics.emptyBuoyancyKg != null)
        (
          l10n.passport_spec_buoyancyEmpty,
          units.formatWeight(metrics.emptyBuoyancyKg),
        ),
      if (metrics.fullBuoyancyKg != null)
        (
          l10n.passport_spec_buoyancyFull,
          units.formatWeight(metrics.fullBuoyancyKg),
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.passport_spec_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
