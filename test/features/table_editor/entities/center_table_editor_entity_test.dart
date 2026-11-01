import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/entities/center_table_editor_entity.dart';

import '../../../helpers/test_database.dart';

/// The centers tab (#3422): plain columns, coordinates stored as two
/// independent values.
void main() {
  late DiveCenterRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = DiveCenterRepository();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> seed(String id) => repo.createDiveCenter(
    DiveCenter(
      id: id,
      name: 'Center $id',
      latitude: 1,
      longitude: 2,
      phone: '123',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  );

  Future<DiveCenterRow> row(String id) async =>
      (center: (await repo.getDiveCenterById(id))!, diveCount: 0);

  TableDraft draft(String id, DiveCenterField f, Object? original, Object? v) =>
      TableDraft(entityId: id, fieldName: f.name, original: original, value: v);

  test('save clears a coordinate when the draft is null', () async {
    await seed('c1');
    final e = CenterTableEditorEntity(repo: repo);
    final r = await row('c1');

    await e.save(
      {
        'c1': [draft('c1', DiveCenterField.latitude, 1.0, null)],
      },
      {'c1': r},
    );

    final after = (await repo.getDiveCenterById('c1'))!;
    expect(after.latitude, isNull);
    expect(after.longitude, 2);
  });

  test('save writes name, phone and rating', () async {
    await seed('c1');
    final e = CenterTableEditorEntity(repo: repo);
    final r = await row('c1');

    await e.save(
      {
        'c1': [
          draft('c1', DiveCenterField.centerName, 'Center c1', 'Blue Divers'),
          draft('c1', DiveCenterField.phone, '123', '456'),
          draft('c1', DiveCenterField.rating, null, 4.0),
        ],
      },
      {'c1': r},
    );

    final after = (await repo.getDiveCenterById('c1'))!;
    expect(after.name, 'Blue Divers');
    expect(after.phone, '456');
    expect(after.rating, 4);
    expect(e.nameOf(r), 'Center c1');
    expect(e.columnFor(DiveCenterField.diveCount), isNull);
  });

  test('reload returns fresh rows by id', () async {
    await seed('c1');
    final fresh = await CenterTableEditorEntity(repo: repo).reload(['c1']);

    expect(fresh.single.center.id, 'c1');
  });
}
