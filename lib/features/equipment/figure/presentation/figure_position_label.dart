import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';
import 'package:submersion/features/equipment/figure/domain/figure_position.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The spot [item] was moved to on the diver figure (issue #4493), named,
/// or null when the figure places it: none chosen, or one the item has no
/// artwork for any more because its mount or style changed.
String? figurePositionLabelOf(AppLocalizations l10n, EquipmentItem item) {
  final key = item.attrText(EquipmentAttrKeys.figurePosition);
  final zone = figurePositionZone(key);
  if (zone == null ||
      !pickableFigureZones(
        item.type,
        figureAttributesOf(item),
      ).contains(zone)) {
    return null;
  }
  return attributeChoiceLabel(l10n, EquipmentAttrKeys.figurePosition, key!);
}
