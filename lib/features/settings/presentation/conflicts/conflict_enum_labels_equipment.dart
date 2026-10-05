import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/features/equipment/presentation/utils/service_category_label.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

// Labelers for the enums of equipment, cylinders and service records.

final ConflictEnumLabeler equipmentStatusLabeler = enumLabeler(
  EquipmentStatus.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler observationStatusLabeler = enumLabeler(
  ObservationStatus.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler serviceCategoryLabeler = enumLabeler(
  ServiceCategory.values,
  (l, v) => v.label(l),
);

/// A gear finding's severity uses the same three steps as a dive safety
/// finding, and the same words.
final ConflictEnumLabeler conditionSeverityLabeler = enumLabeler(
  ConditionSeverity.values,
  (l, v) => switch (v) {
    ConditionSeverity.info => l.enum_safetySeverity_info,
    ConditionSeverity.caution => l.enum_safetySeverity_caution,
    ConditionSeverity.significant => l.enum_safetySeverity_significant,
  },
);

final ConflictEnumLabeler fillSourceLabeler = enumLabeler(
  FillSource.values,
  (l, v) => switch (v) {
    FillSource.manual => l.enum_fillSource_manual,
    FillSource.qr => l.enum_fillSource_qr,
    FillSource.nfc => l.enum_fillSource_nfc,
    FillSource.file => l.enum_fillSource_file,
    FillSource.link => l.enum_fillSource_link,
    FillSource.issued => l.enum_fillSource_issued,
  },
);

final ConflictEnumLabeler ownershipEventKindLabeler = enumLabeler(
  EquipmentOwnershipEventKind.values,
  (l, v) => switch (v) {
    EquipmentOwnershipEventKind.shared => l.enum_ownershipEventKind_shared,
    EquipmentOwnershipEventKind.unshared => l.enum_ownershipEventKind_unshared,
    EquipmentOwnershipEventKind.transferred =>
      l.enum_ownershipEventKind_transferred,
  },
);
