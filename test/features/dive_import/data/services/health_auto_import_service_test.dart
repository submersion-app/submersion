import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/features/dive_import/data/services/apple_watch_computer.dart';
import 'package:submersion/features/dive_import/data/services/health_auto_import_service.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

class _Health extends Fake implements HealthImportService {
  List<ImportedDive> workouts = [];
  HealthPermissionStatus status = HealthPermissionStatus.granted;
  int fetches = 0;

  @override
  Future<HealthPermissionStatus> permissionStatus() async => status;

  @override
  Future<List<ImportedDive>> fetchDives({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    fetches++;
    // HealthKit reads by true instant and hands back wall-clock times.
    return [
      for (final w in workouts)
        if (!fromWallClockUtc(w.startTime).isBefore(startDate) &&
            !fromWallClockUtc(w.startTime).isAfter(endDate))
          w,
    ];
  }

  @override
  ImportSource get source => ImportSource.appleWatch;
}

/// The automatic Apple Health import (issue #637): each new workout fills a
/// draft, joins a downloaded dive or imports as new; a plan's day or an
/// unclear match waits for the diver and is announced once.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late SharedPreferences prefs;
  late _Health health;
  String? bound = 'a';
  // Wall clock flagged UTC, as dive times are.
  final ten = DateTime.utc(2026, 7, 17, 10);
  // A true instant, as the app's clock is: 13:00 on the device.
  final now = DateTime(2026, 7, 17, 13);
  final created = DateTime.utc(2026, 7, 1).millisecondsSinceEpoch;

  ImportedDive workout(String id, DateTime start) => ImportedDive(
    sourceId: id,
    source: ImportSource.appleWatch,
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    maxDepth: 18,
    profile: const [],
  );

  HealthAutoImportService service() => HealthAutoImportService(
    health: health,
    prefs: prefs,
    boundDiverId: () => bound,
    dives: dives,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    health = _Health();
    bound = 'a';
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

  test('with the switch off nothing is read or written', () async {
    bound = null;
    health.workouts = [workout('w1', ten)];

    final result = await service().run(now: now);

    expect(health.fetches, 0);
    expect(result.newDiveIds, isEmpty);
  });

  test('a new workout imports as a numbered watch dive', () async {
    health.workouts = [workout('w1', ten)];

    final result = await service().run(now: now);

    final id = healthDiveId(diverId: 'a', workoutUuid: 'w1');
    expect(result.newDiveIds, [id]);
    final dive = (await dives.getDiveById(id))!;
    expect(dive.maxDepth, 18);
    expect(dive.diveNumber, 1);
    expect(await dives.getComputerIdForDive(id), isNotNull);
  });

  test('a workout already imported is not imported again', () async {
    health.workouts = [workout('w1', ten)];

    await service().run(now: now);
    final again = await service().run(now: now.add(const Duration(hours: 1)));

    expect(again.newDiveIds, isEmpty);
    expect(await dives.getAllDives(diverId: 'a'), hasLength(1));
  });

  test('a workout fills the draft its taps cover', () async {
    final draft = await dives.createDive(
      Dive(
        id: '',
        diverId: 'a',
        dateTime: ten,
        entryTime: ten,
        exitTime: ten.add(const Duration(minutes: 50)),
        notes: 'turtle at the wall',
        isDraft: true,
      ),
    );
    health.workouts = [workout('w1', ten.add(const Duration(minutes: 2)))];

    final result = await service().run(now: now);

    expect(result.filledDraftIds, hasLength(1));
    final filled = (await dives.getDiveById(result.filledDraftIds.single))!;
    expect(filled.isDraft, isFalse);
    expect(filled.notes, 'turtle at the wall');
    expect(filled.maxDepth, 18);
    expect(filled.diveNumber, isNotNull);
    final remaining = await dives.getAllDives(diverId: 'a');
    expect(remaining.where((d) => d.isDraft), isEmpty);
    expect(remaining, hasLength(1));
    expect(draft.id, isNotEmpty);
  });

  test(
    'a workout joins the downloaded dive it matches, which stays main',
    () async {
      final downloaded = await dives.createDive(
        Dive(
          id: '',
          diverId: 'a',
          dateTime: ten,
          entryTime: ten,
          exitTime: ten.add(const Duration(minutes: 45)),
          runtime: const Duration(minutes: 45),
          maxDepth: 18.2,
          diveNumber: 1,
        ),
      );
      health.workouts = [workout('w1', ten)];

      final result = await service().run(now: now);

      expect(result.consolidatedIds, [downloaded.id]);
      expect(result.newDiveIds, isEmpty);
      expect(await dives.getAllDives(diverId: 'a'), hasLength(1));
      expect((await dives.getDiveById(downloaded.id))!.maxDepth, 18.2);
    },
  );

  test('a dive downloaded two hours ago is found east of UTC too, with the '
      'app\'s own clock (run this file under TZ=Australia/Sydney)', () async {
    final start = asWallClockUtc(
      DateTime.now().subtract(const Duration(hours: 2)),
    );
    final downloaded = await dives.createDive(
      Dive(
        id: '',
        diverId: 'a',
        dateTime: start,
        entryTime: start,
        exitTime: start.add(const Duration(minutes: 45)),
        runtime: const Duration(minutes: 45),
        maxDepth: 18.2,
        diveNumber: 1,
      ),
    );
    health.workouts = [workout('w1', start)];

    final result = await service().run();

    expect(result.consolidatedIds, [downloaded.id]);
    expect(result.newDiveIds, isEmpty);
  });

  test(
    'a workout merged into a dive on another device is not merged again',
    () async {
      final downloaded = await dives.createDive(
        Dive(
          id: '',
          diverId: 'a',
          dateTime: ten,
          entryTime: ten,
          exitTime: ten.add(const Duration(minutes: 45)),
          runtime: const Duration(minutes: 45),
          maxDepth: 18.2,
          diveNumber: 1,
        ),
      );
      // The other device's merge reached this one as the watch dive's
      // tombstone.
      await SyncRepository().logDeletion(
        entityType: 'dives',
        recordId: healthDiveId(diverId: 'a', workoutUuid: 'w1'),
      );
      health.workouts = [workout('w1', ten)];

      final result = await service().run(now: now);

      expect(result.consolidatedIds, isEmpty);
      expect(result.newDiveIds, isEmpty);
      expect(await dives.getAllDives(diverId: 'a'), [
        isA<Dive>().having((d) => d.id, 'id', downloaded.id),
      ]);
    },
  );

  test('a workout that fits two drafts is reported, not written', () async {
    for (final (entry, exit) in [
      (
        ten.subtract(const Duration(minutes: 20)),
        ten.add(const Duration(minutes: 5)),
      ),
      (
        ten.add(const Duration(minutes: 20)),
        ten.add(const Duration(minutes: 60)),
      ),
    ]) {
      await dives.createDive(
        Dive(
          id: '',
          diverId: 'a',
          dateTime: entry,
          entryTime: entry,
          exitTime: exit,
          isDraft: true,
        ),
      );
    }
    health.workouts = [workout('w1', ten)];

    final result = await service().run(now: now);

    expect(result.reviewWorkoutIds, ['w1']);
    expect(result.newDiveIds, isEmpty);
    expect(
      (await dives.getAllDives(diverId: 'a')).where((d) => d.isDraft),
      hasLength(2),
    );
  });

  test('a plan of the day is held for the diver, never filled here', () async {
    final plan = await dives.createPlannedDive(
      Dive(
        id: '',
        diverId: 'a',
        dateTime: ten.subtract(const Duration(hours: 1)),
      ),
    );
    health.workouts = [workout('w1', ten)];

    final result = await service().run(now: now);

    expect(result.planReviewWorkoutIds, ['w1']);
    expect(result.newDiveIds, isEmpty);
    expect((await dives.getDiveById(plan.id))!.isPlanned, isTrue);
  });

  test('a held workout is announced once', () async {
    await dives.createPlannedDive(
      Dive(
        id: '',
        diverId: 'a',
        dateTime: ten.subtract(const Duration(hours: 1)),
      ),
    );
    health.workouts = [workout('w1', ten)];

    await service().run(now: now);
    final again = await service().run(now: now.add(const Duration(hours: 1)));

    expect(again.planReviewWorkoutIds, isEmpty);
  });

  test('the next run starts from this one', () async {
    await service().run(now: now);

    expect(
      prefs.getInt(SettingsKeys.healthImportWatermark),
      now.millisecondsSinceEpoch,
    );
  });

  test('without read access nothing is fetched', () async {
    health.status = HealthPermissionStatus.denied;
    health.workouts = [workout('w1', ten)];

    final result = await service().run(now: now);

    expect(health.fetches, 0);
    expect(result.newDiveIds, isEmpty);
  });
}
