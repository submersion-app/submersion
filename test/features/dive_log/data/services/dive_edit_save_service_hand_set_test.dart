import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_filter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// The dive page's Save marks the computer-written values the diver changed,
/// so a later re-parse or resync keeps them (issue #4909).
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late DiveEditSaveService service;
  final changeLog = ChangeLogRepository();

  Future<String?> marks() async =>
      (await db
              .customSelect(
                "SELECT hand_set_fields FROM dives WHERE id = 'dive'",
              )
              .getSingle())
          .readNullable<String>('hand_set_fields');

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    dives = DiveRepository();
    service = DiveEditSaveService(dives, TripRepository());
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await db.customStatement(
      'UPDATE dives SET water_temp = 24, bottom_time = 2700, '
      "max_depth = 30 WHERE id = 'dive'",
    );
  });

  tearDown(tearDownTestDatabase);

  test('a changed water temperature is marked, and nothing else', () async {
    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(waterTemp: 26, notes: 'Cold'),
      changedCardIds: ['environment', 'notes'],
    );
    expect(await marks(), '["waterTemp"]');
  });

  test('a sitting that changes no computer value marks nothing', () async {
    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(notes: 'Cold'),
      changedCardIds: ['notes'],
    );
    expect(await marks(), isNull);
  });

  test('a later sitting adds to the marks', () async {
    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(waterTemp: 26),
      changedCardIds: ['environment'],
    );
    await service.save(
      diveId: 'dive',
      apply: (dive) =>
          dive.copyWith(bottomTime: const Duration(minutes: 40), waterTemp: 25),
      changedCardIds: ['details'],
    );
    expect(await marks(), '["bottomTime","waterTemp"]');
  });

  test('reverting the sitting from History takes its mark back', () async {
    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(waterTemp: 26),
      changedCardIds: ['environment'],
    );
    await changeLog.settleAll();
    // Newest first: the seed's own write is the entry below it.
    final entry = (await changeLog.getFeed(
      diverId: 'me',
      filter: const ChangeLogFilter(rootTable: 'dives', rootId: 'dive'),
    )).first;
    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});

    await revert.execute(await revert.planOperation(entry.id));

    expect(await marks(), isNull);
    expect((await dives.getDiveById('dive'))!.waterTemp, 24);
  });
}
