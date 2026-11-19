import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/database/database.dart' hide Species;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/species_edit_save_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A species page's sitting is written as one History entry, and writes
/// only what it changed (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late SpeciesRepository species;
  late SpeciesEditSaveService service;
  final changeLog = ChangeLogRepository();

  Future<Species> stored() async => (await species.getSpeciesById('manta'))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  /// Saves what [session] changed onto the species as stored now.
  Future<({Species before, Species after})?> save(
    EditSession<Species> session,
  ) => service.save(
    speciesId: 'manta',
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    species = SpeciesRepository();
    service = SpeciesEditSaveService(species);
    await db.customStatement(
      'INSERT INTO species (id, common_name, scientific_name, category, '
      "taxonomy_class, description) VALUES ('manta', 'Manta', "
      "'Mobula birostris', 'ray', 'Elasmobranchii', 'Big')",
    );
    // What setup wrote is not a sitting.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('writes the changed names as one History entry', () async {
    final session = EditSession(await stored())
      ..set(speciesCommonNameField, 'Giant manta');

    final result = await save(session);

    expect((await stored()).commonName, 'Giant manta');
    expect(result!.before.commonName, 'Manta');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:species:manta:header');
  });

  // One case per column the species' update writes: a value changed in
  // storage during the sitting, on a field the diver did not touch,
  // survives the Save.
  final census = <String, ({String sql, bool Function(Species) kept})>{
    'common name': (
      sql: "UPDATE species SET common_name = 'Oceanic manta'",
      kept: (s) => s.commonName == 'Oceanic manta',
    ),
    'scientific name': (
      sql: "UPDATE species SET scientific_name = 'Mobula alfredi'",
      kept: (s) => s.scientificName == 'Mobula alfredi',
    ),
    'category': (
      sql: "UPDATE species SET category = 'shark'",
      kept: (s) => s.category == SpeciesCategory.shark,
    ),
    'taxonomy class': (
      sql: "UPDATE species SET taxonomy_class = 'Chondrichthyes'",
      kept: (s) => s.taxonomyClass == 'Chondrichthyes',
    ),
    'description': (
      sql: "UPDATE species SET description = 'Huge'",
      kept: (s) => s.description == 'Huge',
    ),
  };
  for (final MapEntry(key: column, value: change) in census.entries) {
    test('a $column changed underneath keeps its newer value', () async {
      // The sitting changes a field other than the one changed underneath.
      final EditField<Species, String?> touched = column == 'description'
          ? speciesTaxonomyClassField
          : speciesDescriptionField;
      final session = EditSession(await stored())..set(touched, 'Edited');
      await db.customStatement('${change.sql} WHERE id = ?', ['manta']);

      await save(session);

      final after = await stored();
      expect(change.kept(after), isTrue, reason: column);
      expect(touched.read(after), 'Edited');
    });
  }

  test('clearing the scientific name stores null', () async {
    final session = EditSession(await stored())
      ..set(speciesScientificNameField, '');

    await save(session);

    expect((await stored()).scientificName, isNull);
  });

  test('unchanged returns null and writes nothing', () async {
    final result = await save(EditSession(await stored()));

    expect(result, isNull);
    expect(await operations(), isEmpty);
  });

  test('a species that has gone throws', () async {
    final session = EditSession(await stored())
      ..set(speciesCommonNameField, 'Giant manta');
    await db.customStatement("DELETE FROM species WHERE id = 'manta'");
    // The delete is another device's, not this sitting.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');

    await expectLater(save(session), throwsStateError);
    expect(await operations(), isEmpty);
  });
}
