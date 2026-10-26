import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/settings/data/services/dive_time_migration_service.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveTimeMigrationService', () {
    group('computeShiftedEpoch', () {
      test('shifts epoch forward by positive hours', () {
        // 8:00 AM UTC
        final epoch = DateTime.utc(2024, 6, 15, 8, 0).millisecondsSinceEpoch;
        final shifted = DiveTimeMigrationService.computeShiftedEpoch(epoch, 3);
        final dt = DateTime.fromMillisecondsSinceEpoch(shifted, isUtc: true);
        expect(dt.hour, 11);
      });

      test('shifts epoch backward by negative hours', () {
        final epoch = DateTime.utc(2024, 6, 15, 8, 0).millisecondsSinceEpoch;
        final shifted = DiveTimeMigrationService.computeShiftedEpoch(epoch, -5);
        final dt = DateTime.fromMillisecondsSinceEpoch(shifted, isUtc: true);
        expect(dt.hour, 3);
      });

      test('handles date boundary crossing', () {
        final epoch = DateTime.utc(2024, 6, 15, 23, 0).millisecondsSinceEpoch;
        final shifted = DiveTimeMigrationService.computeShiftedEpoch(epoch, 3);
        final dt = DateTime.fromMillisecondsSinceEpoch(shifted, isUtc: true);
        expect(dt.day, 16);
        expect(dt.hour, 2);
      });
    });

    group('applyOffset', () {
      late AppDatabase db;
      final entry = DateTime.utc(2026, 7, 1, 10);

      setUp(() async {
        await setUpTestDatabase();
        db = DatabaseService.instance.database;
        await DiveRepository().createDive(
          domain.Dive(id: 'd1', dateTime: entry, entryTime: entry),
        );
        for (final (id, primary) in [('uddf', true), ('dc', false)]) {
          await db
              .into(db.diveDataSources)
              .insert(
                DiveDataSourcesCompanion(
                  id: Value(id),
                  diveId: const Value('d1'),
                  isPrimary: Value(primary),
                  entryTime: Value(entry),
                  importedAt: Value(entry),
                  createdAt: Value(entry),
                ),
              );
        }
        await db.delete(db.syncRecords).go();
      });
      tearDown(() {
        applyGlobalTestDefaults();
        return tearDownTestDatabase();
      });

      Future<DateTime?> sourceEntry(String id) async => (await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals(id))).getSingle()).entryTime;

      test('moves the dive and its primary source together (#3655)', () async {
        await DiveTimeMigrationService(
          db,
        ).applyOffset(diveIds: ['d1'], hours: 2);

        final shifted = entry.add(const Duration(hours: 2));
        expect((await DiveRepository().getDiveById('d1'))!.entryTime, shifted);
        expect((await sourceEntry('uddf'))!.isAtSameMomentAs(shifted), isTrue);
        // Another computer's clock is its own and is left alone.
        expect((await sourceEntry('dc'))!.isAtSameMomentAs(entry), isTrue);
      });

      test('marks the dive and the moved source pending for sync', () async {
        await DiveTimeMigrationService(
          db,
        ).applyOffset(diveIds: ['d1'], hours: 2);

        final pending = await db.select(db.syncRecords).get();
        expect(
          {for (final r in pending) '${r.entityType}/${r.recordId}'},
          {'dives/d1', 'diveDataSources/uddf'},
        );
      });
    });
  });
}
