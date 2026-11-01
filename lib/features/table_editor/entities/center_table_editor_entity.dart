import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/table_editor/domain/column_factories.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/shared/constants/entity_field.dart';

typedef CenterEditorColumn = TableEditorColumn<DiveCenterRow, DiveCenterField>;

/// The centers tab (#3422): plain text, two independent coordinates, a
/// rating and notes. Affiliations and the dive count stay read-only.
class CenterTableEditorEntity
    extends TableEditorEntity<DiveCenterRow, DiveCenterField> {
  final DiveCenterRepository _repo;

  CenterTableEditorEntity({required DiveCenterRepository repo}) : _repo = repo;

  @override
  EntityFieldAdapter<DiveCenterRow, DiveCenterField> get adapter =>
      DiveCenterFieldAdapter.instance;

  @override
  DiveCenterField fieldFromName(String name) => adapter.fieldFromName(name);

  @override
  late final List<CenterEditorColumn> columns = [
    textColumn(
      DiveCenterField.centerName,
      (r) => r.center.name,
      required: true,
    ),
    textColumn(DiveCenterField.street, (r) => r.center.street),
    textColumn(DiveCenterField.city, (r) => r.center.city),
    textColumn(DiveCenterField.stateProvince, (r) => r.center.stateProvince),
    textColumn(DiveCenterField.postalCode, (r) => r.center.postalCode),
    textColumn(DiveCenterField.country, (r) => r.center.country),
    textColumn(DiveCenterField.phone, (r) => r.center.phone),
    textColumn(DiveCenterField.email, (r) => r.center.email),
    textColumn(DiveCenterField.website, (r) => r.center.website),
    degreesColumn(
      DiveCenterField.latitude,
      (r) => r.center.latitude,
      limit: 90,
    ),
    degreesColumn(
      DiveCenterField.longitude,
      (r) => r.center.longitude,
      limit: 180,
    ),
    plainNumberColumn(
      DiveCenterField.rating,
      (r) => r.center.rating,
      min: 0,
      max: 5,
    ),
    textColumn(
      DiveCenterField.notes,
      (r) => r.center.notes.isEmpty ? null : r.center.notes,
    ),
  ];

  @override
  String idOf(DiveCenterRow entity) => entity.center.id;

  @override
  int? numberOf(DiveCenterRow entity) => null;

  @override
  String? nameOf(DiveCenterRow entity) => entity.center.name;

  @override
  Future<List<DiveCenterRow>> reload(List<String> ids) async => [
    for (final id in ids)
      if (await _repo.getDiveCenterById(id) case final center?)
        (center: center, diveCount: 0),
  ];

  @override
  Future<void> save(
    Map<String, List<TableDraft>> draftsByEntity,
    Map<String, DiveCenterRow> fresh,
  ) async {
    for (final entry in draftsByEntity.entries) {
      final current = fresh[entry.key]?.center;
      if (current == null) continue;
      final values = <DiveCenterField, Object?>{
        for (final d in entry.value) fieldFromName(d.fieldName): d.value,
      };
      await _repo.updateDiveCenter(_withValues(current, values));
    }
  }

  /// A copy of [c] with [v]'s values, built through the constructor because
  /// `copyWith` cannot clear a nullable field.
  static DiveCenter _withValues(DiveCenter c, Map<DiveCenterField, Object?> v) {
    T pick<T>(DiveCenterField f, T current) =>
        v.containsKey(f) ? v[f] as T : current;
    return DiveCenter(
      id: c.id,
      diverId: c.diverId,
      name: pick<String>(DiveCenterField.centerName, c.name),
      street: pick<String?>(DiveCenterField.street, c.street),
      city: pick<String?>(DiveCenterField.city, c.city),
      stateProvince: pick<String?>(
        DiveCenterField.stateProvince,
        c.stateProvince,
      ),
      postalCode: pick<String?>(DiveCenterField.postalCode, c.postalCode),
      latitude: pick<double?>(DiveCenterField.latitude, c.latitude),
      longitude: pick<double?>(DiveCenterField.longitude, c.longitude),
      country: pick<String?>(DiveCenterField.country, c.country),
      phone: pick<String?>(DiveCenterField.phone, c.phone),
      email: pick<String?>(DiveCenterField.email, c.email),
      website: pick<String?>(DiveCenterField.website, c.website),
      affiliations: c.affiliations,
      rating: pick<double?>(DiveCenterField.rating, c.rating),
      notes: pick<String?>(DiveCenterField.notes, c.notes) ?? '',
      fillOpensAt: c.fillOpensAt,
      fillClosesAt: c.fillClosesAt,
      isPermanentlyClosed: c.isPermanentlyClosed,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    );
  }
}
