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
}
