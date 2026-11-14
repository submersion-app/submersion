import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_color_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/equipment/domain/models/recent_equipment_colors.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_color_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/list_arrangement_writes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The item form's colour row: the swatch and name of [hex], or a
/// placeholder, opening the colour sheet on tap. Laid out like the form's
/// date field, with a clear button once a colour is set.
///
/// The sheet's Recent row (issue #4537) is the diver's remembered colours,
/// then the colours on their gear, which the field keeps watched.
class EquipmentColorField extends ConsumerWidget {
  const EquipmentColorField({
    super.key,
    required this.label,
    required this.hex,
    required this.onChanged,
    required this.onCleared,
  });

  final String label;

  /// The stored value; anything that is not a colour code reads as unset.
  final String? hex;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = normalizeEquipmentColor(hex);
    // Watched, not read on tap: a watched provider stays live, so a gear
    // colour an import or a sync pull just wrote is already in the next
    // sheet, and the sheet opens at once rather than after a query. A gear
    // read still loading or failed offers the remembered colours alone.
    final gear = ref.watch(equipmentGearColorsProvider).value ?? const [];
    return InkWell(
      onTap: () async {
        final recent = recentEquipmentColorRow(
          remembered: decodeRecentEquipmentColors(
            ref.read(settingsProvider).listArrangements.recentEquipmentColors,
          ),
          gear: gear,
        );
        final choice = await showEquipmentColorSheet(
          context,
          selected: code,
          recent: recent,
          onRemember: (picked) => logFailure(
            ref
                .read(settingsProvider.notifier)
                .updateRecentEquipmentColors(
                  (current) => rememberEquipmentColor(current, picked),
                ),
            EquipmentColorField,
            'remember a custom equipment colour',
          ),
        );
        if (choice == null) return;
        switch (choice.hex) {
          case final picked?:
            onChanged(picked);
          case null:
            onCleared();
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: code == null
              ? const Icon(Icons.palette_outlined)
              : IconButton(icon: const Icon(Icons.clear), onPressed: onCleared),
        ),
        child: code == null
            ? Text(context.l10n.common_placeholder_noValue)
            : Row(
                children: [
                  Container(
                    key: const ValueKey('color-field-swatch'),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: TagColors.fromHex(code),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(equipmentColorName(context.l10n, code))),
                ],
              ),
      ),
    );
  }
}
