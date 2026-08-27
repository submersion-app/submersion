import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiveWithGps(String id, {required bool withGps}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
            entryLatitude: withGps
                ? const Value(12.34567)
                : const Value.absent(),
            entryLongitude: withGps
                ? const Value(98.76543)
                : const Value.absent(),
            exitLatitude: withGps
                ? const Value(12.34612)
                : const Value.absent(),
            exitLongitude: withGps
                ? const Value(98.76489)
                : const Value.absent(),
          ),
        );
  }

  group('DiveRepository GPS hydration', () {
    test('getDiveById hydrates entry/exit GeoPoints from the row', () async {
      await insertDiveWithGps('gps-1', withGps: true);

      final dive = await repository.getDiveById('gps-1');

      expect(dive, isNotNull);
      expect(dive!.entryLocation, const GeoPoint(12.34567, 98.76543));
      expect(dive.exitLocation, const GeoPoint(12.34612, 98.76489));
    });

    test('getDiveById returns null GPS when columns are null', () async {
      await insertDiveWithGps('gps-2', withGps: false);

      final dive = await repository.getDiveById('gps-2');

      expect(dive, isNotNull);
      expect(dive!.entryLocation, isNull);
      expect(dive.exitLocation, isNull);
    });

    test('getAllDives hydrates GPS (bulk mapper path)', () async {
      await insertDiveWithGps('gps-3', withGps: true);

      final all = await repository.getAllDives();
      final dive = all.firstWhere((d) => d.id == 'gps-3');

      expect(dive.entryLocation, const GeoPoint(12.34567, 98.76543));
      expect(dive.exitLocation, const GeoPoint(12.34612, 98.76489));
    });
  });

  group('DiveRepository.setDiveGps (fills only NULL columns)', () {
    Future<Dive> readRow(String id) async =>
        (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

    test('fills all four coordinates when the dive has none', () async {
      await insertDiveWithGps('set-1', withGps: false);

      await repository.setDiveGps(
        'set-1',
        entryLatitude: 10.5,
        entryLongitude: 20.5,
        exitLatitude: 10.8,
        exitLongitude: 20.8,
      );

      final row = await readRow('set-1');
      expect(row.entryLatitude, 10.5);
      expect(row.entryLongitude, 20.5);
      expect(row.exitLatitude, 10.8);
      expect(row.exitLongitude, 20.8);
    });

    test('preserves an existing exit fix while filling entry', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'set-2',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
              exitLatitude: const Value(50.0),
              exitLongitude: const Value(60.0),
            ),
          );

      await repository.setDiveGps(
        'set-2',
        entryLatitude: 10.5,
        entryLongitude: 20.5,
        exitLatitude: 11.0,
        exitLongitude: 21.0,
      );

      final row = await readRow('set-2');
      expect(row.entryLatitude, 10.5);
      expect(row.entryLongitude, 20.5);
      // Computer-provided exit fix is untouched.
      expect(row.exitLatitude, 50.0);
      expect(row.exitLongitude, 60.0);
    });

    test('is a no-op when every target column is already set', () async {
      await insertDiveWithGps('set-3', withGps: true);
      final before = await readRow('set-3');

      await repository.setDiveGps(
        'set-3',
        entryLatitude: 1.0,
        entryLongitude: 2.0,
        exitLatitude: 3.0,
        exitLongitude: 4.0,
      );

      final after = await readRow('set-3');
      expect(after.entryLatitude, before.entryLatitude);
      expect(after.exitLatitude, before.exitLatitude);
      // updatedAt is not bumped when nothing changed.
      expect(after.updatedAt, before.updatedAt);
    });

    test('is a no-op when the dive does not exist', () async {
      await repository.setDiveGps(
        'missing',
        entryLatitude: 1.0,
        entryLongitude: 2.0,
      );
      final rows = await db.select(db.dives).get();
      expect(rows, isEmpty);
    });
  });
}
