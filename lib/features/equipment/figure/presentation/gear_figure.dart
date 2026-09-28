import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// [DiverFigure] with the app's strings: the summary named by [title], each
/// label read as "3, BCD, Hollis SMS75", the switch counts, and the tray
/// heading. The set page, the set edit page, and the dive card all use it.
class GearFigure extends StatelessWidget {
  const GearFigure({
    super.key,
    required this.model,
    required this.title,
    this.selectedItemId,
    this.selectionSerial = 0,
    this.onItemTap,
  });

  final FigureModel model;

  /// What the picture is of, for its screen-reader summary.
  final String title;
  final String? selectedItemId;
  final int selectionSerial;
  final ValueChanged<PlacedItem>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DiverFigure(
      model: model,
      semanticsLabel: l10n.equipment_figure_summary(title, model.itemCount),
      labelText: (placed) => placed.item.name,
      sideLabel: (view, count) => view == FigureView.front
          ? l10n.equipment_figure_frontCount(count)
          : l10n.equipment_figure_backCount(count),
      selectedItemId: selectedItemId,
      selectionSerial: selectionSerial,
      onItemTap: onItemTap,
      itemSemantics: (placed) => l10n.equipment_figure_itemLabel(
        placed.number,
        placed.item.type.localizedName(l10n),
        placed.item.name,
      ),
      trayTitle: l10n.equipment_figure_trayTitle,
    );
  }
}
