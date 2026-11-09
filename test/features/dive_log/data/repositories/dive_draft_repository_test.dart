import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_draft_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

/// Drafts (issue #637): a dive marked at the site with times and positions
/// and no readings. A tap near a plan of the same day adopts the plan, so
/// one real dive never shows twice; filling or completing a draft numbers
/// it like a promoted plan.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late DiveDraftRepository drafts;
  final created = DateTime.utc(2026, 7, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    drafts = DiveDraftRepository(dives: dives);
    for (final id in ['me', 'other']) {
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

  Future<void> insertDive(
    String id, {
    required DateTime start,
    String diverId = 'me',
    bool isPlanned = false,
    int? diveNumber,
    String? siteId,
    String notes = '',
    String? outingId,
    DateTime? exit,
    int? runtimeSeconds,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          diveDateTime: Value(start.millisecondsSinceEpoch),
          entryTime: Value(start.millisecondsSinceEpoch),
          isPlanned: Value(isPlanned),
          diveNumber: Value(diveNumber),
          siteId: Value(siteId),
          notes: Value(notes),
          outingId: Value(outingId),
          exitTime: Value(exit?.millisecondsSinceEpoch),
          runtime: Value(runtimeSeconds),
          createdAt: Value(created),
          updatedAt: Value(created),
        ),
      );

  test('a draft has its entry and no readings or number', () async {
    final tap = DateTime.utc(2026, 7, 17, 10, 2);

    final draft = await drafts.createDraft(
      diverId: 'me',
      entryTime: tap,
      entryLocation: const GeoPoint(27.9, 34.3),
    );

    final stored = (await dives.getDiveById(draft.id))!;
    expect(stored.isDraft, isTrue);
    expect(stored.isPlanned, isFalse);
    expect(stored.entryTime, tap);
    expect(stored.dateTime, tap);
    expect(stored.exitTime, isNull);
    expect(stored.entryLocation, const GeoPoint(27.9, 34.3));
    expect(stored.diveNumber, isNull);
    expect(stored.runtime, isNull);
    expect(stored.maxDepth, isNull);
    expect(stored.diverId, 'me');
  });

  test('a tap within two hours of a plan that day adopts the plan', () async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: const Value('reef'),
            name: const Value('North wall'),
            createdAt: Value(created),
            updatedAt: Value(created),
          ),
        );
    await insertDive(
      'plan',
      start: DateTime.utc(2026, 7, 17, 10),
      isPlanned: true,
      siteId: 'reef',
      notes: 'Look for the turtle',
    );
    final tap = DateTime.utc(2026, 7, 17, 11, 30);

    final draft = await drafts.createDraft(diverId: 'me', entryTime: tap);

    expect(draft.id, 'plan');
    final stored = (await dives.getDiveById('plan'))!;
    expect(stored.isPlanned, isFalse);
    expect(stored.isDraft, isTrue);
    expect(stored.entryTime, tap);
    expect(stored.site?.id, 'reef');
    expect(stored.notes, 'Look for the turtle');
    expect(await dives.getPlannedDives(diverId: 'me'), isEmpty);
  });

  test(
    'a dive mirrored from a buddy\'s logged dive is never taken over',
    () async {
      final ten = DateTime.utc(2026, 7, 17, 10);
      await insertDive('theirs', start: ten, diverId: 'other', outingId: 'o1');
      await insertDive(
        'mirror',
        start: ten,
        isPlanned: true,
        outingId: 'o1',
        exit: ten.add(const Duration(minutes: 50)),
      );

      final draft = await drafts.createDraft(
        diverId: 'me',
        entryTime: DateTime.utc(2026, 7, 17, 11, 30),
      );

      expect(draft.id, isNot('mirror'));
      final mirror = (await dives.getDiveById('mirror'))!;
      expect(mirror.isPlanned, isTrue);
      expect(mirror.isDraft, isFalse);
    },
  );

  test(
    'an adopted plan drops the exit and runtime it was planned with',
    () async {
      final ten = DateTime.utc(2026, 7, 17, 10);
      await insertDive(
        'plan',
        start: ten,
        isPlanned: true,
        exit: ten.add(const Duration(minutes: 50)),
        runtimeSeconds: 3000,
      );

      final draft = await drafts.createDraft(
        diverId: 'me',
        entryTime: DateTime.utc(2026, 7, 17, 10, 20),
      );

      final stored = (await dives.getDiveById(draft.id))!;
      expect(stored.id, 'plan');
      expect(stored.exitTime, isNull);
      expect(stored.runtime, isNull);
      expect((await drafts.openDraftFor('me'))?.id, 'plan');
    },
  );

  test('a plan on another day, or more than two hours away, is not '
      'adopted', () async {
    await insertDive(
      'yesterday',
      start: DateTime.utc(2026, 7, 16, 11),
      isPlanned: true,
    );
    await insertDive(
      'later',
      start: DateTime.utc(2026, 7, 17, 13, 1),
      isPlanned: true,
    );
    await insertDive(
      'theirs',
      start: DateTime.utc(2026, 7, 17, 11),
      diverId: 'other',
      isPlanned: true,
    );

    final tap = DateTime.utc(2026, 7, 17, 11);
    expect(await drafts.findPlanToAdopt(diverId: 'me', entryTime: tap), isNull);
    final draft = await drafts.createDraft(diverId: 'me', entryTime: tap);
    expect(['yesterday', 'later', 'theirs'], isNot(contains(draft.id)));
  });

  test('a plan just after midnight belongs to its own day', () async {
    await insertDive(
      'night',
      start: DateTime.utc(2026, 7, 17, 23, 30),
      isPlanned: true,
    );

    expect(
      await drafts.findPlanToAdopt(
        diverId: 'me',
        entryTime: DateTime.utc(2026, 7, 18, 0, 10),
      ),
      isNull,
    );
  });

  test('the nearest of two plans is adopted', () async {
    await insertDive(
      'early',
      start: DateTime.utc(2026, 7, 17, 9),
      isPlanned: true,
    );
    await insertDive(
      'close',
      start: DateTime.utc(2026, 7, 17, 10, 20),
      isPlanned: true,
    );

    expect(
      await drafts.findPlanToAdopt(
        diverId: 'me',
        entryTime: DateTime.utc(2026, 7, 17, 10),
      ),
      'close',
    );
  });

  test('closing a draft sets its exit time and position', () async {
    final draft = await drafts.createDraft(
      diverId: 'me',
      entryTime: DateTime.utc(2026, 7, 17, 10),
    );
    final exit = DateTime.utc(2026, 7, 17, 10, 52);

    await drafts.closeDraft(
      draft.id,
      exitTime: exit,
      exitLocation: const GeoPoint(27.91, 34.31),
    );

    final stored = (await dives.getDiveById(draft.id))!;
    expect(stored.exitTime, exit);
    expect(stored.exitLocation, const GeoPoint(27.91, 34.31));
    expect(stored.isDraft, isTrue);
    expect(stored.runtime, isNull);
  });

  test('the open draft is the newest one without an exit', () async {
    final old = await drafts.createDraft(
      diverId: 'me',
      entryTime: DateTime.utc(2026, 7, 17, 8),
    );
    await drafts.closeDraft(old.id, exitTime: DateTime.utc(2026, 7, 17, 8, 50));
    final open = await drafts.createDraft(
      diverId: 'me',
      entryTime: DateTime.utc(2026, 7, 17, 11),
    );
    await drafts.createDraft(
      diverId: 'other',
      entryTime: DateTime.utc(2026, 7, 17, 12),
    );

    expect((await drafts.openDraftFor('me'))?.id, open.id);
    expect((await drafts.getDrafts(diverId: 'me')).map((d) => d.id), [
      open.id,
      old.id,
    ]);
  });

  test('promoting a draft clears the flag and takes the next number', () async {
    await insertDive('logged', start: DateTime.utc(2026, 7, 1), diveNumber: 41);
    final draft = await drafts.createDraft(
      diverId: 'me',
      entryTime: DateTime.utc(2026, 7, 17, 10),
    );

    await drafts.promoteToLoggedDive(draft.id);

    final stored = (await dives.getDiveById(draft.id))!;
    expect(stored.isDraft, isFalse);
    expect(stored.isPlanned, isFalse);
    expect(stored.diveNumber, 42);
  });

  test('promoting a plan still works the way it did', () async {
    await insertDive('logged', start: DateTime.utc(2026, 7, 1), diveNumber: 7);
    await insertDive(
      'plan',
      start: DateTime.utc(2026, 7, 17, 10),
      isPlanned: true,
    );

    await dives.convertPlanToActualDive('plan');

    final stored = (await dives.getDiveById('plan'))!;
    expect(stored.isPlanned, isFalse);
    expect(stored.diveNumber, 8);
  });

  test('marking a draft complete keeps its times', () async {
    final draft = await drafts.createDraft(
      diverId: 'me',
      entryTime: DateTime.utc(2026, 7, 17, 10),
    );
    await drafts.closeDraft(
      draft.id,
      exitTime: DateTime.utc(2026, 7, 17, 10, 45),
    );

    await drafts.markDraftComplete(draft.id);

    final stored = (await dives.getDiveById(draft.id))!;
    expect(stored.isDraft, isFalse);
    expect(stored.entryTime, DateTime.utc(2026, 7, 17, 10));
    expect(stored.exitTime, DateTime.utc(2026, 7, 17, 10, 45));
    expect(stored.diveNumber, 1);
  });

  test('marking a logged dive complete is refused', () async {
    await insertDive('logged', start: DateTime.utc(2026, 7, 1), diveNumber: 1);

    expect(() => drafts.markDraftComplete('logged'), throwsStateError);
  });

  test('the unfilled dives are the diver\'s plans and drafts', () async {
    await insertDive('logged', start: DateTime.utc(2026, 7, 1), diveNumber: 1);
    await insertDive(
      'plan',
      start: DateTime.utc(2026, 7, 18, 9),
      isPlanned: true,
    );
    final draft = await drafts.createDraft(
      diverId: 'me',
      entryTime: DateTime.utc(2026, 7, 17, 10),
    );
    await drafts.createDraft(
      diverId: 'other',
      entryTime: DateTime.utc(2026, 7, 17, 10),
    );

    final unfilled = await dives.getUnfilledDives(diverId: 'me');

    expect(unfilled.map((d) => d.id), unorderedEquals(['plan', draft.id]));
  });
}
