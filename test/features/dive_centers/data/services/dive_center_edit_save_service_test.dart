import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide DiveCenter;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/data/services/dive_center_edit_save_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A dive centre page's sitting is written as one History entry, and
/// writes only what it changed (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late DiveCenterRepository centers;
  late DiveCenterEditSaveService service;
  final changeLog = ChangeLogRepository();

  Future<DiveCenter> stored() async =>
      (await centers.getDiveCenterById('dc1'))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<({DiveCenter before, DiveCenter after})?> save(
    EditSession<DiveCenter> session,
  ) => service.save(
    centerId: 'dc1',
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    centers = DiveCenterRepository();
    service = DiveCenterEditSaveService(centers);
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_centers (id, diver_id, name, city, latitude, '
      'longitude, website, rating, affiliations, created_at, updated_at) '
      "VALUES ('dc1', 'me', 'Reef Divers', 'Dahab', 28.5, 34.5, "
      "'reef.example', 4.0, 'PADI,SSI', 0, 0)",
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('writes a website change as one History entry', () async {
    final session = EditSession(await stored())
      ..set(diveCenterWebsiteField, 'reefdivers.example');

    final result = await save(session);

    expect((await stored()).website, 'reefdivers.example');
    expect(result!.before.website, 'reef.example');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:dive_centers:dc1:contact');
  });

  final census = <String, ({String sql, bool Function(DiveCenter) kept})>{
    'name': (
      sql: "UPDATE dive_centers SET name = 'Reef Divers Dahab'",
      kept: (c) => c.name == 'Reef Divers Dahab',
    ),
    'street': (
      sql: "UPDATE dive_centers SET street = '1 Sea St'",
      kept: (c) => c.street == '1 Sea St',
    ),
    'city': (
      sql: "UPDATE dive_centers SET city = 'Sharm'",
      kept: (c) => c.city == 'Sharm',
    ),
    'state': (
      sql: "UPDATE dive_centers SET state_province = 'South Sinai'",
      kept: (c) => c.stateProvince == 'South Sinai',
    ),
    'postal code': (
      sql: "UPDATE dive_centers SET postal_code = '46617'",
      kept: (c) => c.postalCode == '46617',
    ),
    'coordinates': (
      sql: 'UPDATE dive_centers SET latitude = 27.9, longitude = 34.3',
      kept: (c) => c.latitude == 27.9 && c.longitude == 34.3,
    ),
    'country': (
      sql: "UPDATE dive_centers SET country = 'Egypt'",
      kept: (c) => c.country == 'Egypt',
    ),
    'phone': (
      sql: "UPDATE dive_centers SET phone = '+20 1'",
      kept: (c) => c.phone == '+20 1',
    ),
    'email': (
      sql: "UPDATE dive_centers SET email = 'hi@reef.example'",
      kept: (c) => c.email == 'hi@reef.example',
    ),
    'website': (
      sql: "UPDATE dive_centers SET website = 'new.example'",
      kept: (c) => c.website == 'new.example',
    ),
    'affiliations': (
      sql: "UPDATE dive_centers SET affiliations = 'NAUI'",
      kept: (c) => c.affiliations.single == 'NAUI',
    ),
    'rating': (
      sql: 'UPDATE dive_centers SET rating = 2.5',
      kept: (c) => c.rating == 2.5,
    ),
    'fill hours': (
      sql: 'UPDATE dive_centers SET fill_opens_at = 480, fill_closes_at = 1020',
      kept: (c) => c.fillOpensAt == 480 && c.fillClosesAt == 1020,
    ),
    'closed': (
      sql: 'UPDATE dive_centers SET is_permanently_closed = 1',
      kept: (c) => c.isPermanentlyClosed,
    ),
    'logo': (
      sql: "UPDATE dive_centers SET logo = x'0102'",
      kept: (c) => c.logo?.length == 2,
    ),
    'notes': (
      sql: "UPDATE dive_centers SET notes = 'Newer'",
      kept: (c) => c.notes == 'Newer',
    ),
  };
  for (final MapEntry(key: column, value: change) in census.entries) {
    test('a $column changed underneath keeps its newer value', () async {
      final EditField<DiveCenter, String> touched = column == 'notes'
          ? diveCenterNameField
          : diveCenterNotesField;
      final session = EditSession(await stored())..set(touched, 'Edited');
      await db.customStatement('${change.sql} WHERE id = ?', ['dc1']);

      await save(session);

      final after = await stored();
      expect(change.kept(after), isTrue, reason: column);
      expect(touched.read(after), 'Edited');
    });
  }

  test('clearing the rating stores null', () async {
    final session = EditSession(await stored())
      ..set(diveCenterRatingField, null);

    await save(session);

    expect((await stored()).rating, isNull);
  });

  test('clearing the coordinates stores nulls', () async {
    final session = EditSession(await stored())
      ..set(diveCenterCoordinatesField, null);

    await save(session);

    final after = await stored();
    expect(after.latitude, isNull);
    expect(after.longitude, isNull);
    expect(after.hasCoordinates, isFalse);
  });

  test('the owner and the creation time are kept', () async {
    final before = await stored();
    final session = EditSession(before)..set(diveCenterNotesField, 'Hi');

    await save(session);

    final after = await stored();
    expect(after.diverId, 'me');
    expect(after.createdAt, before.createdAt);
  });

  test('unchanged returns null and writes nothing', () async {
    expect(await save(EditSession(await stored())), isNull);
    expect(await operations(), isEmpty);
  });

  /// A new dive centre's sitting (issue #4527, phase 3, plan 11).
  group('create', () {
    DiveCenter fresh({String id = 'n1'}) => DiveCenter(
      id: id,
      diverId: 'me',
      name: 'Blue Planet',
      city: 'Hurghada',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('creates the centre with its id, as one History entry', () async {
      final created = await service.create(
        center: fresh(),
        changedCardIds: const ['header'],
      );

      expect(created.id, 'n1');
      expect((await centers.getDiveCenterById('n1'))?.city, 'Hurghada');
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(ops.single['source'], 'manual');
      expect(ops.single['label'], 'record_edit:dive_centers:n1:header');
    });

    test('held writes run after the row, in the same entry', () async {
      DiveCenter? seen;
      await service.create(
        center: fresh(),
        changedCardIds: const ['header'],
        alsoWrite: () async => seen = await centers.getDiveCenterById('n1'),
      );

      expect(seen?.name, 'Blue Planet');
      expect(await operations(), hasLength(1));
    });

    test('a held write that throws leaves nothing', () async {
      await expectLater(
        service.create(
          center: fresh(),
          changedCardIds: const ['header'],
          alsoWrite: () async => throw StateError('refused'),
        ),
        throwsStateError,
      );

      expect(await centers.getDiveCenterById('n1'), isNull);
      expect(await operations(), isEmpty);
    });

    test('an empty id or one already stored is refused', () async {
      await expectLater(
        service.create(
          center: fresh(id: ''),
          changedCardIds: const [],
        ),
        throwsStateError,
      );
      await expectLater(
        service.create(
          center: fresh(id: 'dc1'),
          changedCardIds: const [],
        ),
        throwsStateError,
      );

      expect((await stored()).name, 'Reef Divers');
      expect(await operations(), isEmpty);
    });
  });
}
