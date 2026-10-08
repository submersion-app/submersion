import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/certification_currency_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/dive_log_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/equipment_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/media_library_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/people_planning_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/site_trip_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_reference_labels.dart';

/// Sync bookkeeping on nearly every record. Never compared, never listed.
const conflictBookkeepingColumns = <String>{
  'id',
  'hlc',
  'deviceId',
  'originDeviceId',
  'syncedAt',
  'createdAt',
  'updatedAt',
};

/// One entry per column name, for names that mean the same thing on every
/// entity. The domain maps are merged here; a name in two of them is a
/// mistake the merge asserts on.
final Map<String, ConflictField> conflictFieldCatalogue = _merge([
  diveLogFields,
  siteTripFields,
  equipmentFields,
  peoplePlanningFields,
  diverSettingsFields,
  mediaLibraryFields,
  certificationCurrencyFields,
]);

/// Entity-specific meanings, keyed `'<entityType>.<column>'`. Checked before
/// [conflictFieldCatalogue].
final Map<String, ConflictField> conflictFieldOverrides = _merge([
  diveLogOverrides,
  siteTripOverrides,
  equipmentOverrides,
  peoplePlanningOverrides,
  diverSettingsOverrides,
  mediaLibraryOverrides,
  certificationCurrencyOverrides,
]);

Map<String, ConflictField> _merge(List<Map<String, ConflictField>> maps) {
  final out = <String, ConflictField>{};
  for (final map in maps) {
    for (final entry in map.entries) {
      assert(
        !out.containsKey(entry.key),
        '${entry.key} is catalogued twice; keep one entry or use an override',
      );
      out[entry.key] = entry.value;
    }
  }
  return Map.unmodifiable(out);
}

/// The label and value kind for [column] on an [entityType] record. A column
/// the catalogue does not know (a newer peer's schema) gets a humanized label
/// and is formatted by its runtime type.
ConflictField conflictFieldFor(String entityType, String column) =>
    conflictFieldOverrides['$entityType.$column'] ??
    conflictFieldCatalogue[column] ??
    ConflictField((_) => humanizeEntityType(column), FieldKind.unknown);

/// Whether the dialog can describe [column] without falling back: it is
/// bookkeeping, a foreign key the reference resolver names, or catalogued.
bool isConflictFieldCovered(String entityType, String column) =>
    conflictBookkeepingColumns.contains(column) ||
    ConflictReferenceResolver.targetTypeFor(entityType, column) != null ||
    conflictFieldOverrides.containsKey('$entityType.$column') ||
    conflictFieldCatalogue.containsKey(column);
