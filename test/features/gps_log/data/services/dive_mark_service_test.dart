import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_draft_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/data/services/dive_mark_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../../../helpers/test_database.dart';

/// "Entered water" and "Surfaced" (issue #637) make and close a draft at the
/// recording's position at the tap.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late DiveDraftRepository drafts;
  var points = <GpsTrackPoint>[];
  var currentDiver = 'a';
  final created = DateTime.utc(2026, 7, 1).millisecondsSinceEpoch;

  DiveMarkService service() => DiveMarkService(
    drafts: drafts,
    currentDiverId: () => currentDiver,
    recordedPoints: () async => points,
  );

  /// A track point at wall-clock [t], flagged UTC as dive times are.
  GpsTrackPoint point(DateTime t, double lat) => GpsTrackPoint(
    timestamp: t.millisecondsSinceEpoch ~/ 1000,
    latitude: lat,
    longitude: 34.3,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    drafts = DiveDraftRepository(dives: dives);
    points = [];
    currentDiver = 'a';
    for (final id in ['a', 'b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: created,
              updatedAt: created,
            ),
          );
    }
  });

  tearDown(() => tearDownTestDatabase());

  test('Entered water makes a draft at the track position', () async {
    final tap = DateTime.utc(2026, 7, 17, 10);
    points = [
      point(tap.subtract(const Duration(seconds: 60)), 27.90),
      point(tap.subtract(const Duration(seconds: 10)), 27.91),
    ];

    final draft = await service().enteredWater(diverId: 'a', at: tap);

    final stored = (await dives.getDiveById(draft.id))!;
    expect(stored.isDraft, isTrue);
    expect(stored.entryTime, tap);
    expect(stored.entryLocation, const GeoPoint(27.91, 34.3));
  });

  test('with no fix yet the draft has no position', () async {
    final draft = await service().enteredWater(
      diverId: 'a',
      at: DateTime.utc(2026, 7, 17, 10),
    );

    expect((await dives.getDiveById(draft.id))!.entryLocation, isNull);
  });

  test('Surfaced closes the open draft at the track position', () async {
    final marks = service();
    final draft = await marks.enteredWater(
      diverId: 'a',
      at: DateTime.utc(2026, 7, 17, 10),
    );
    final out = DateTime.utc(2026, 7, 17, 10, 50);
    points = [point(out.subtract(const Duration(seconds: 5)), 27.95)];

    final closed = await marks.surfaced(at: out);

    expect(closed?.id, draft.id);
    final stored = (await dives.getDiveById(draft.id))!;
    expect(stored.exitTime, out);
    expect(stored.exitLocation, const GeoPoint(27.95, 34.3));
    expect(stored.isDraft, isTrue);
  });

  test('Surfaced closes the draft of the diver who entered, after a diver '
      'switch', () async {
    final marks = service();
    final draft = await marks.enteredWater(
      diverId: 'a',
      at: DateTime.utc(2026, 7, 17, 10),
    );
    currentDiver = 'b';

    final closed = await marks.surfaced(at: DateTime.utc(2026, 7, 17, 10, 50));

    expect(closed?.id, draft.id);
    expect(await drafts.openDraftFor('a'), isNull);
  });

  test(
    'after a restart Surfaced closes the current diver\'s open draft',
    () async {
      final draft = await service().enteredWater(
        diverId: 'a',
        at: DateTime.utc(2026, 7, 17, 10),
      );

      final closed = await service().surfaced(
        at: DateTime.utc(2026, 7, 17, 10, 50),
      );

      expect(closed?.id, draft.id);
    },
  );

  test('Surfaced with no open draft does nothing', () async {
    expect(
      await service().surfaced(at: DateTime.utc(2026, 7, 17, 10, 50)),
      isNull,
    );
  });

  test(
    'a second Entered water while in the water keeps the open draft',
    () async {
      final marks = service();
      final first = await marks.enteredWater(
        diverId: 'a',
        at: DateTime.utc(2026, 7, 17, 10),
      );

      final second = await marks.enteredWater(
        diverId: 'a',
        at: DateTime.utc(2026, 7, 17, 10, 5),
      );

      expect(second.id, first.id);
      expect(await drafts.getDrafts(diverId: 'a'), hasLength(1));
      expect(
        (await dives.getDiveById(first.id))!.entryTime,
        DateTime.utc(2026, 7, 17, 10),
      );
    },
  );

  test('a late dive adopts the plan from its own day, not the next', () async {
    Future<void> plan(String id, DateTime start) => db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: const Value('a'),
            diveDateTime: Value(start.millisecondsSinceEpoch),
            entryTime: Value(start.millisecondsSinceEpoch),
            isPlanned: const Value(true),
            createdAt: Value(created),
            updatedAt: Value(created),
          ),
        );
    await plan('evening', DateTime.utc(2026, 7, 17, 22, 30));
    await plan('after-midnight', DateTime.utc(2026, 7, 18, 0, 30));

    final draft = await service().enteredWater(
      diverId: 'a',
      at: DateTime.utc(2026, 7, 17, 23, 50),
    );

    expect(draft.id, 'evening');
    expect((await dives.getDiveById('after-midnight'))!.isPlanned, isTrue);
  });
}
