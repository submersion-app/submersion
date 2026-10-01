import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver picked: a colour code, or a null [hex] for "None".
typedef EquipmentColorChoice = ({String? hex});

/// Opens the item colour sheet (spec section 9). Completes with the choice,
/// or null when the sheet is dismissed without one.
Future<EquipmentColorChoice?> showEquipmentColorSheet(
  BuildContext context, {
  String? selected,
}) {
  return showModalBottomSheet<EquipmentColorChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        EquipmentColorSheet(selected: normalizeEquipmentColor(selected)),
  );
}

/// "None" and the item palette as round swatches. The palette extends the tag
/// colour picker's with Black and White; the picker's widget is not shared,
/// since it previews a tag chip.
class EquipmentColorSheet extends StatelessWidget {
  const EquipmentColorSheet({super.key, this.selected});

  /// The stored colour, already normalised; null when unset.
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.equipment_color_sheetTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _Swatch(
                key: const ValueKey('color-swatch-none'),
                color: null,
                label: l10n.equipment_color_none,
                selected: selected == null,
                onTap: () => Navigator.of(context).pop((hex: null)),
              ),
              for (final hex in equipmentColorPalette)
                _Swatch(
                  key: ValueKey('color-swatch-$hex'),
                  color: TagColors.fromHex(hex),
                  label: equipmentColorName(l10n, hex),
                  selected: selected == hex,
                  onTap: () => Navigator.of(context).pop((hex: hex)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Null draws the "None" swatch: an outlined circle with a slash.
  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: color == null
                    ? Icon(
                        Icons.block,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
