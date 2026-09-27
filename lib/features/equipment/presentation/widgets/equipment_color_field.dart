import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_color_sheet.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The item form's colour row: the swatch and name of [hex], or a
/// placeholder, opening the colour sheet on tap. Laid out like the form's
/// date field, with a clear button once a colour is set.
class EquipmentColorField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final code = normalizeEquipmentColor(hex);
    return InkWell(
      onTap: () async {
        final choice = await showEquipmentColorSheet(context, selected: code);
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
