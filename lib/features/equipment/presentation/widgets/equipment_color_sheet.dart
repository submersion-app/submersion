import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/equipment/domain/models/recent_equipment_colors.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/color_hex.dart';
import 'package:submersion/shared/widgets/color_picker/custom_color_dialog.dart';

/// What the diver picked: a colour code, or a null [hex] for "None".
typedef EquipmentColorChoice = ({String? hex});

/// Opens the item colour sheet (spec section 9). Completes with the choice,
/// or null when the sheet is dismissed without one.
///
/// [recent] is the diver's remembered and gear colours (issue #4537), in the
/// order to offer them; [onRemember] hears each colour picked through the
/// custom colour dialog.
Future<EquipmentColorChoice?> showEquipmentColorSheet(
  BuildContext context, {
  String? selected,
  List<String> recent = const [],
  ValueChanged<String>? onRemember,
}) {
  return showModalBottomSheet<EquipmentColorChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => EquipmentColorSheet(
      selected: selected,
      recent: recent,
      onRemember: onRemember,
    ),
  );
}

/// "None" and the item palette as round swatches, then a Recent row of the
/// diver's custom colours and a "+" swatch for any colour (issue #4537). The
/// palette is the tag colour palette plus Black and White; the tag colour
/// picker's widget is not shared, since it previews a tag chip.
class EquipmentColorSheet extends StatelessWidget {
  const EquipmentColorSheet({
    super.key,
    this.selected,
    this.recent = const [],
    this.onRemember,
  });

  /// The stored colour; null when unset. Any spelling selects its swatch:
  /// the sheet normalises it ([_current]).
  final String? selected;

  /// [selected] as a `#RRGGBB` code, or null when unset or not a code.
  String? get _current => normalizeEquipmentColor(selected);

  /// The diver's remembered and gear colours. The sheet puts [selected]
  /// first when it is off the palette, so opening it never hides the
  /// item's own colour.
  final List<String> recent;

  /// Hears a colour picked through the custom colour dialog, so it can be
  /// remembered. A preset or recent swatch tap is not reported.
  final ValueChanged<String>? onRemember;

  /// Opens the custom colour dialog on the item's colour (Blue for an item
  /// without one) and, on Use, reports the code and picks it.
  Future<void> _pickCustom(BuildContext context) async {
    final l10n = context.l10n;
    final code = await showCustomColorDialog(
      context,
      initial: TagColors.fromHex(_current ?? _customStart),
      title: l10n.common_color_custom,
      preview: (color) => _CustomPreview(color: color),
    );
    if (code == null || !context.mounted) return;
    onRemember?.call(code);
    Navigator.of(context).pop((hex: code));
  }

  /// Where the custom colour dialog starts for an item with no colour: the
  /// palette Blue.
  static const String _customStart = '#3B82F6';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final row = recentEquipmentColorRow(
      current: _current,
      remembered: recent,
      gear: const [],
    );
    final custom = _Swatch(
      key: const ValueKey('color-swatch-custom'),
      color: null,
      icon: Icons.add,
      label: l10n.common_color_custom,
      selected: null,
      onTap: () => _pickCustom(context),
    );
    // Scrolls: a sheet that is not scroll-controlled stops at 9/16 of the
    // screen, which the presets and the Recent row outgrow on a short
    // window or a phone held sideways.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.equipment_color_sheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
                selected: _current == null,
                onTap: () => Navigator.of(context).pop((hex: null)),
              ),
              for (final hex in equipmentColorPalette)
                _Swatch(
                  key: ValueKey('color-swatch-$hex'),
                  color: TagColors.fromHex(hex),
                  label: equipmentColorName(l10n, hex),
                  selected: _current == hex,
                  onTap: () => Navigator.of(context).pop((hex: hex)),
                ),
              if (row.isEmpty) custom,
            ],
          ),
          if (row.isNotEmpty) ...[
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                l10n.equipment_color_recent,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final hex in row)
                  _Swatch(
                    key: ValueKey('color-swatch-recent-$hex'),
                    color: TagColors.fromHex(hex),
                    label: equipmentColorName(l10n, hex),
                    selected: _current == hex,
                    onTap: () => Navigator.of(context).pop((hex: hex)),
                  ),
                custom,
              ],
            ),
          ],
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
    this.icon = Icons.block,
  });

  /// Null draws an outlined circle around [icon]: the "None" swatch's
  /// slash, or the custom swatch's "+".
  final Color? color;
  final IconData icon;
  final String label;

  /// Null for an action rather than a choice (the custom swatch), which
  /// then carries no selected state.
  final bool? selected;
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
                    color: selected == true
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: selected == true ? 3 : 1,
                  ),
                ),
                child: color == null
                    ? Icon(icon, size: 20, color: scheme.onSurfaceVariant)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The custom colour dialog's preview: the swatch and the name the item
/// will show.
class _CustomPreview extends StatelessWidget {
  const _CustomPreview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final code = colorHexOf(color);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(equipmentColorName(context.l10n, code))),
      ],
    );
  }
}
