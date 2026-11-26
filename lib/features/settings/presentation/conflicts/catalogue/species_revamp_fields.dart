import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Conflict labels for species covers and ID practice (issue #5027). Both
/// merge last-writer-wins by clock; the coverage guard keeps every synced
/// column labelled all the same. Keyed by entity, since `box` and the counts
/// mean something particular here.
final Map<String, ConflictField> speciesRevampOverrides = {
  'speciesCovers.identificationId': ConflictField(
    (l) => l.settings_conflict_field_speciesCovers_identificationId,
    FieldKind.opaque,
  ),
  'speciesPractice.box': ConflictField(
    (l) => l.settings_conflict_field_speciesPractice_box,
    FieldKind.number,
  ),
  'speciesPractice.dueAt': ConflictField(
    (l) => l.settings_conflict_field_speciesPractice_dueAt,
    FieldKind.dateTime,
  ),
  'speciesPractice.rightCount': ConflictField(
    (l) => l.settings_conflict_field_speciesPractice_rightCount,
    FieldKind.number,
  ),
  'speciesPractice.wrongCount': ConflictField(
    (l) => l.settings_conflict_field_speciesPractice_wrongCount,
    FieldKind.number,
  ),
  'speciesPractice.lastPractisedAt': ConflictField(
    (l) => l.settings_conflict_field_speciesPractice_lastPractisedAt,
    FieldKind.dateTime,
  ),
};
