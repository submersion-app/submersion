import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_figure_inputs.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_tree_view.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_model_memo.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_selection.dart';
import 'package:submersion/features/equipment/figure/presentation/gear_figure.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dive detail equipment card's content: the gear tree, and above it
/// the diver figure when [showFigure] is on (spec section 11). The figure
/// is drawn from the tree's top-level rows in the tree's order, so its
/// numbers run down the rows, and a tap on either side flashes the other.
class DiveGearWithFigure extends ConsumerStatefulWidget {
  const DiveGearWithFigure({
    super.key,
    required this.dive,
    required this.showFigure,
    required this.showServiceStatus,
    this.onTap,
    this.rowTrailing,
  });

  final Dive dive;

  /// The diver-wide switch (`AppSettings.showDiveFigure`).
  final bool showFigure;
  final bool showServiceStatus;
  final void Function(EquipmentItem item)? onTap;
  final Widget Function(EquipmentItem item)? rowTrailing;

  @override
  ConsumerState<DiveGearWithFigure> createState() => _DiveGearWithFigureState();
}

class _DiveGearWithFigureState extends ConsumerState<DiveGearWithFigure>
    with FigureSelection<DiveGearWithFigure> {
  final _memo = FigureModelMemo();

  @override
  Widget build(BuildContext context) {
    final dive = widget.dive;
    final arrangement = ref.watch(equipmentArrangementProvider);
    final locale = Localizations.localeOf(context);
    // The gear and tank lists compare by identity, so a refreshed dive (a
    // new object from the provider) recomposes while a highlight flash
    // reuses the model.
    final model = widget.showFigure && dive.gear.isNotEmpty
        ? _memo.of(
            (dive.gear, dive.tanks, arrangement, locale),
            () => composeFigure(
              figureInputsForDive([
                for (final group in arrangedDiveGear(
                  dive.gear,
                  arrangement,
                  typeLabel: (type) => type.localizedName(context.l10n),
                ))
                  ...group.items,
              ], tankRolesByItem(dive.tanks)),
            ),
          )
        : null;
    final tree = DiveGearTreeView(
      links: dive.gear,
      showServiceStatus: widget.showServiceStatus,
      onTap: widget.onTap,
      rowTrailing: widget.rowTrailing,
      figureNumbers: model == null
          ? const {}
          : {for (final p in model.numbered) p.item.id: p.number},
      selectedItemId: selectedFigureItemId,
      onNumberTap: model == null
          ? null
          : (id) => selectFigureItem(id, revealFigure: true),
      rowKey: model == null ? null : figureRowKey,
    );
    if (model == null) return tree;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: figureKey,
          child: GearFigure(
            model: model,
            title: context.l10n.diveLog_detail_gearFigureName,
            selectedItemId: selectedFigureItemId,
            selectionSerial: figureSelectionSerial,
            onItemTap: (placed) => selectFigureItem(placed.item.id),
          ),
        ),
        const SizedBox(height: 16),
        tree,
      ],
    );
  }
}
