import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/tank_presets/data/repositories/tank_preset_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../helpers/test_database.dart';

/// Searches and by-name lookups lowercase the needle in Dart and the column
/// in SQL, and SQLite's LOWER() folds ASCII only: a name that starts with an
/// accented capital was unreachable from its first word, typed in any case
/// (#3032).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Diver', 1000, 1000)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<void> insert(String sql) =>
      DatabaseService.instance.database.customStatement(sql);

  const queries = ['Épave', 'épave', 'ÉPAVE'];

  test('courses', () async {
    await insert(
      "INSERT INTO courses (id, diver_id, name, agency, start_date, "
      "created_at, updated_at) "
      "VALUES ('c1', 'diver-1', 'Épave avancée', 'padi', 1000, 1000, 1000)",
    );
    for (final q in queries) {
      expect(await CourseRepository().searchCourses(q), hasLength(1));
    }
  });

  test('certifications', () async {
    await insert(
      "INSERT INTO certifications (id, name, agency, created_at, updated_at) "
      "VALUES ('c1', 'Épave avancée', 'padi', 1000, 1000)",
    );
    for (final q in queries) {
      expect(
        await CertificationRepository().searchCertifications(q),
        hasLength(1),
        reason: q,
      );
    }
  });

  test('trips', () async {
    await insert(
      "INSERT INTO trips (id, name, start_date, end_date, created_at, "
      "updated_at) VALUES ('t1', 'Épaves de Malte', 1000, 2000, 1000, 1000)",
    );
    for (final q in queries) {
      expect(await TripRepository().searchTrips(q), hasLength(1), reason: q);
    }
  });

  test('dive centers', () async {
    await insert(
      "INSERT INTO dive_centers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'Épave Plongée', 1000, 1000)",
    );
    for (final q in queries) {
      expect(
        await DiveCenterRepository().searchDiveCenters(q),
        hasLength(1),
        reason: q,
      );
    }
  });

  test('equipment', () async {
    await insert(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Épave light', 'light', 1000, 1000)",
    );
    for (final q in queries) {
      expect(
        await EquipmentRepository().searchEquipment(q),
        hasLength(1),
        reason: q,
      );
    }
  });

  group('by-name lookups', () {
    Future<void> insertDiveType(String id, String name) => insert(
      "INSERT INTO dive_types (id, name, created_at, updated_at) "
      "VALUES ('$id', '$name', 1000, 1000)",
    );

    Future<void> insertPreset(String id, String name) => insert(
      "INSERT INTO tank_presets (id, diver_id, name, display_name, "
      "volume_liters, working_pressure_bar, material, created_at, updated_at) "
      "VALUES ('$id', 'diver-1', '$name', '$name', 11.1, 207, 'aluminum', "
      "1000, 1000)",
    );

    test('dive type', () async {
      await insertDiveType('t1', 'Épave');
      final found = await DiveTypeRepository().getDiveTypeByName('épave');
      expect(found?.id, 't1');
    });

    test('dive type: two names folding equal pick the lowest id', () async {
      await insertDiveType('t2', 'épave');
      await insertDiveType('t1', 'Épave');
      final found = await DiveTypeRepository().getDiveTypeByName('ÉPAVE');
      expect(found?.id, 't1');
    });

    test('tank preset', () async {
      await insertPreset('p1', 'Épave 11');
      final found = await TankPresetRepository().getPresetByName(
        'épave 11',
        diverId: 'diver-1',
      );
      expect(found?.id, 'p1');
    });

    test('tank preset: two names folding equal pick the lowest id', () async {
      await insertPreset('p2', 'épave 11');
      await insertPreset('p1', 'Épave 11');
      final found = await TankPresetRepository().getPresetByName(
        'ÉPAVE 11',
        diverId: 'diver-1',
      );
      expect(found?.id, 'p1');
    });
  });
}
