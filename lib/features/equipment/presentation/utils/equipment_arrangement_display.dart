import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for [EquipmentTypeOrder].
///
/// The switch is exhaustive by enum value, so adding an order is a compile
/// error until its localization key is wired in.
extension EquipmentTypeOrderDisplay on EquipmentTypeOrder {
  String localizedName(AppLocalizations l10n) => switch (this) {
    EquipmentTypeOrder.none => l10n.enum_equipmentTypeOrder_none,
    EquipmentTypeOrder.alphabetical =>
      l10n.enum_equipmentTypeOrder_alphabetical,
    EquipmentTypeOrder.headToToe => l10n.enum_equipmentTypeOrder_headToToe,
    EquipmentTypeOrder.dressingOrder =>
      l10n.enum_equipmentTypeOrder_dressingOrder,
    EquipmentTypeOrder.canonical => l10n.enum_equipmentTypeOrder_canonical,
  };
}
