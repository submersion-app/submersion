import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/dive_import/data/services/apple_watch_computer.dart';
import 'package:submersion/features/dive_import/data/services/health_dive_writer.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Saving an Apple Health workout as a dive (issue #637). The dive takes the
/// workout's id on every device, so one deleted before may come back.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  final created = DateTime.utc(2026, 7, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'a',
            name: 'a',
            createdAt: created,
            updatedAt: created,
          ),
        );
  });

  tearDown(() => tearDownTestDatabase());

  final workout = ImportedDive(
    sourceId: 'w1',
    source: ImportSource.appleWatch,
    startTime: DateTime.utc(2026, 7, 17, 10),
    endTime: DateTime.utc(2026, 7, 17, 10, 45),
    maxDepth: 18,
    profile: const [],
  );

  test('a workout whose dive was deleted before comes back without its old '
      'tombstone, so sync does not delete it again', () async {
    final id = healthDiveId(diverId: 'a', workoutUuid: 'w1');
    await SyncRepository().logDeletion(entityType: 'dives', recordId: id);

    final dive = await HealthDiveWriter(
      dives: dives,
    ).importAsNew(workout, diverId: 'a');

    expect(dive.id, id);
    expect(await dives.getDiveById(id), isNotNull);
    expect(await SyncRepository().deletedIds('dives', [id]), isEmpty);
  });
}
