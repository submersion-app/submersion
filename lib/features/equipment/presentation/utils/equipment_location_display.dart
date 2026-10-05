import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The reader-facing name and icon of a place kind, one per kind wherever a
/// place is shown.
extension EquipmentLocationKindDisplay on EquipmentLocationKind {
  String localizedName(AppLocalizations l10n) => switch (this) {
    EquipmentLocationKind.storage => l10n.equipment_location_kind_storage,
    EquipmentLocationKind.serviceShop =>
      l10n.equipment_location_kind_serviceShop,
    EquipmentLocationKind.person => l10n.equipment_location_kind_person,
    EquipmentLocationKind.other => l10n.equipment_location_kind_other,
  };

  IconData get icon => switch (this) {
    EquipmentLocationKind.storage => Icons.inventory_2_outlined,
    EquipmentLocationKind.serviceShop => Icons.build_outlined,
    EquipmentLocationKind.person => Icons.person_outline,
    EquipmentLocationKind.other => Icons.place_outlined,
  };
}
