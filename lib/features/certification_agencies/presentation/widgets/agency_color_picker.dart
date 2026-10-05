import 'package:flutter/material.dart';

import 'package:submersion/features/certification_agencies/domain/agency_colors.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/agency_swatch.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Card colour choice for a custom agency (issue #690): the tag palette,
/// each shown as the card gradient it produces.
class AgencyColorPicker extends StatelessWidget {
  const AgencyColorPicker({
    super.key,
    required this.selectedArgb,
    required this.onSelected,
  });

  final int selectedArgb;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hex in TagColors.predefined)
          _swatch(
            TagColors.fromHex(hex),
            equipmentColorName(context.l10n, hex),
          ),
      ],
    );
  }

  Widget _swatch(Color color, String name) {
    final argb = color.toARGB32();
    return Semantics(
      label: name,
      button: true,
      selected: argb == selectedArgb,
      child: InkResponse(
        onTap: () => onSelected(argb),
        radius: 22,
        child: AgencySwatch(
          primary: color,
          secondary: secondaryAgencyColor(color),
          size: 32,
          selected: argb == selectedArgb,
        ),
      ),
    );
  }
}
