import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide DiveSite;
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// Records each update and each library stamp the service asks for.
class _RecordingSites extends SiteRepository {
  final actingDiverIds = <String?>[];
  final stampedWithUpdate = <bool>[];
  final stamps = <({String before, String after})>[];
  final stampedAfter = <DiveSite>[];

  /// Run before a read of the site made once the sitting's write is done,
  /// in [callerZone]: outside the transaction, whose body drift runs in a
  /// zone of its own. A sync landing after the commit.
  Future<void> Function()? onReadAfterCommit;
  Zone? callerZone;
  bool _wrote = false;

  /// Run as the library stamp is made.
  Future<void> Function()? onStamp;

  @override
  Future<DiveSite?> getSiteById(String id) async {
    final hook = onReadAfterCommit;
    if (hook != null && _wrote && identical(Zone.current, callerZone)) {
      onReadAfterCommit = null;
      await hook();
    }
    return super.getSiteById(id);
  }

  @override
  Future<void> updateSite(
    DiveSite site, {
    SiteClassification? classification,
    String? actingDiverId,
    bool stampLibrary = true,
  }) {
    actingDiverIds.add(actingDiverId);
    stampedWithUpdate.add(stampLibrary);
    _wrote = true;
    return super.updateSite(
      site,
      classification: classification,
      actingDiverId: actingDiverId,
      stampLibrary: stampLibrary,
    );
  }

  @override
  Future<void> stampLibraryEdit(
    DiveSite before,
    DiveSite after, {
    String? actingDiverId,
  }) async {
    stamps.add((before: before.notes, after: after.notes));
    stampedAfter.add(after);
    await onStamp?.call();
  }
}

/// Records the library fields stamped, and fails each stamp: a stamp made
/// inside the sitting's transaction would roll the sitting back with it.
class _FailingStamper extends LibraryEditStamper {
  final stamped = <Set<String>>[];

  @override
  Future<void> stamp(
    String siteId,
    Set<String> fields, {
    String? actingDiverId,
  }) async {
    stamped.add(fields);
    throw StateError('the library store is out of reach');
  }
}

/// A site's editing sitting is saved in one transaction and one change log
/// operation, and writes only what the diver changed onto the site as it is
/// stored at that moment (issue #4527, phase 2).
void main() {
  late AppDatabase db;
  late SiteRepository sites;
  late SiteEditSaveService service;
  final changeLog = ChangeLogRepository();

  Future<DiveSite> stored() async => (await sites.getSiteById('s1'))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  /// The sitting's change: the notes, applied to whatever is stored.
  DiveSite Function(DiveSite) notes(String text) =>
      (site) => site.copyWith(notes: text);

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    sites = SiteRepository();
    service = SiteEditSaveService(sites);
    await insertDiver(db, 'me');
    await sites.createSite(
      const DiveSite(id: 's1', diverId: 'me', name: 'Lake', notes: 'Calm'),
    );
    // What setup wrote is not a sitting.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  // A new site's sitting (issue #4527, phase 2, plan 6): the row, then
  // what the sitting held, as one History entry.
  group('create', () {
    const blueHole = DiveSite(
      id: 'n1',
      diverId: 'me',
      name: 'Blue Hole',
      notes: 'Deep',
    );

    Future<List<Map<String, Object?>>> events(String recordId) async {
      await changeLog.settleAll();
      final rows = await db
          .customSelect(
            'SELECT table_name, action FROM change_log_events '
            'WHERE record_id = ?',
            variables: [Variable<String>(recordId)],
          )
          .get();
      return [for (final row in rows) row.data];
    }

    test('creates the site with its id, as one History entry', () async {
      final created = await service.create(
        site: blueHole,
        changedCardIds: const ['header', 'notes'],
      );

      expect(created.id, 'n1');
      final site = (await sites.getSiteById('n1'))!;
      expect(site.name, 'Blue Hole');
      expect(site.notes, 'Deep');
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(ops.single['source'], 'manual');
      final label = RecordEditLabel.decode(ops.single['label']! as String)!;
      expect(label.table, 'dive_sites');
      expect(label.id, 'n1');
      expect(label.cardIds.toSet(), {'header', 'notes'});
      expect(
        await events('n1'),
        contains(containsPair('table_name', 'dive_sites')),
      );
    });

    test('held writes run after the row, in the same entry', () async {
      String? featureId;
      await service.create(
        site: blueHole,
        changedCardIds: const ['features'],
        alsoWrite: () async {
          expect(await sites.getSiteById('n1'), isNotNull);
          featureId = (await SiteFeatureRepository().addFeature(
            siteId: 'n1',
            typeName: 'mooring',
            latitude: 1,
            longitude: 2,
            stampLibrary: false,
          )).id;
        },
      );

      expect(
        await SiteFeatureRepository().getFeaturesForSite('n1'),
        hasLength(1),
      );
      expect(await operations(), hasLength(1));
      expect(await events(featureId!), isNotEmpty);
    });

    test('a held write that throws leaves nothing', () async {
      await expectLater(
        service.create(
          site: blueHole,
          changedCardIds: const ['features'],
          alsoWrite: () async {
            await SiteFeatureRepository().addFeature(
              siteId: 'n1',
              typeName: 'mooring',
              latitude: 1,
              longitude: 2,
              stampLibrary: false,
            );
            throw StateError('the feature was refused');
          },
        ),
        throwsStateError,
      );

      expect(await sites.getSiteById('n1'), isNull);
      expect(await SiteFeatureRepository().getFeaturesForSite('n1'), isEmpty);
      expect(await operations(), isEmpty);
    });

    test('an id already stored is refused', () async {
      await service.create(site: blueHole, changedCardIds: const ['header']);
      await expectLater(
        service.create(
          site: blueHole.copyWith(name: 'Other'),
          changedCardIds: const ['header'],
        ),
        throwsStateError,
      );

      expect((await sites.getSiteById('n1'))!.name, 'Blue Hole');
      expect(await operations(), hasLength(1));
    });

    test('an empty id is refused, with nothing written', () async {
      await expectLater(
        service.create(
          site: blueHole.copyWith(id: ''),
          changedCardIds: const ['header'],
        ),
        throwsStateError,
      );

      expect(await operations(), isEmpty);
    });
  });

  test('writes the notes as one History entry', () async {
    final result = await service.save(
      siteId: 's1',
      apply: notes('Choppy'),
      changedCardIds: const ['notes'],
    );

    expect((await stored()).notes, 'Choppy');
    expect(result?.after.notes, 'Choppy');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['label'], 'record_edit:dive_sites:s1:notes');
  });

  test('a field the sitting did not touch keeps its newer value', () async {
    // Renamed on another device while the diver edited the notes.
    await sites.updateSite((await stored()).copyWith(name: 'Pond'));

    await service.save(
      siteId: 's1',
      apply: notes('Choppy'),
      changedCardIds: const ['notes'],
    );

    final site = await stored();
    expect(site.name, 'Pond');
    expect(site.notes, 'Choppy');
  });

  test('unchanged returns null and writes nothing', () async {
    final result = await service.save(
      siteId: 's1',
      apply: (site) => site,
      changedCardIds: const ['notes'],
    );

    expect(result, isNull);
    expect(await operations(), isEmpty);
  });

  test('a site that has gone throws', () async {
    await sites.deleteSite('s1');
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');

    await expectLater(
      service.save(
        siteId: 's1',
        apply: notes('Choppy'),
        changedCardIds: const ['notes'],
      ),
      throwsStateError,
    );
    expect(await operations(), isEmpty);
  });

  test('passes the acting diver to the repository', () async {
    final recording = _RecordingSites();
    await SiteEditSaveService(recording).save(
      siteId: 's1',
      apply: notes('Choppy'),
      changedCardIds: const ['notes'],
      actingDiverId: 'me',
    );

    expect(recording.actingDiverIds, ['me']);
  });

  // The right to edit, lost after the sitting began: the site's own write
  // would keep only the private notes and rating, and the held writes would
  // go through, so the whole Save is refused instead.
  test('a profile that may no longer edit the site saves nothing', () async {
    var heldWrites = 0;
    final refusing = SiteEditSaveService(sites, stamper: _MayNotEdit());

    await expectLater(
      refusing.save(
        siteId: 's1',
        apply: notes('Choppy'),
        changedCardIds: const ['notes'],
        alsoWrite: () async => heldWrites++,
      ),
      throwsA(isA<SiteEditRefused>()),
    );

    expect((await stored()).notes, 'Calm');
    expect(heldWrites, 0);
    expect(await operations(), isEmpty);
  });

  // A library reader's Send (plan 5): their notes and rating are their own,
  // written as one History entry; no field of the library's site changes.
  test(
    'privateOnly writes a reader\'s notes and rating and nothing else',
    () async {
      // In a library: there the notes and rating are the reader's own.
      await db.customStatement(
        "UPDATE dive_sites SET shared_library_id = 'L' WHERE id = 's1'",
      );
      // That setup is not the sitting.
      await changeLog.settleAll();
      await db.customStatement('DELETE FROM change_log_operations');
      final reader = SiteEditSaveService(sites, stamper: _MayNotEdit());

      final result = await reader.save(
        siteId: 's1',
        apply: (site) =>
            site.copyWith(notes: 'Choppy', rating: 4, name: 'Big Lake'),
        changedCardIds: const ['notes', 'rating'],
        privateOnly: true,
      );

      expect(result, isNotNull);
      final after = await stored();
      expect(after.notes, 'Choppy');
      expect(after.rating, 4);
      expect(after.name, 'Lake');
      expect(await operations(), hasLength(1));
    },
  );

  // Only a library site keeps notes and rating per member; elsewhere they
  // are the site's own, and the right to edit is asked as for any field.
  test('privateOnly on a site in no library saves nothing', () async {
    final reader = SiteEditSaveService(sites, stamper: _MayNotEdit());

    await expectLater(
      reader.save(
        siteId: 's1',
        apply: notes('Choppy'),
        changedCardIds: const ['notes'],
        privateOnly: true,
      ),
      throwsA(isA<SiteEditRefused>()),
    );

    expect((await stored()).notes, 'Calm');
    expect(await operations(), isEmpty);
  });

  test('a library stamp waits for the sitting to commit', () async {
    final recording = _RecordingSites();
    await SiteEditSaveService(recording).save(
      siteId: 's1',
      apply: notes('Choppy'),
      changedCardIds: const ['notes'],
    );

    // Not stamped inside the transaction, but once it has committed.
    expect(recording.stampedWithUpdate, [false]);
    expect(recording.stamps, [(before: 'Calm', after: 'Choppy')]);
  });

  test('held writes run in the sitting\'s transaction', () async {
    await expectLater(
      service.save(
        siteId: 's1',
        apply: notes('Choppy'),
        changedCardIds: const ['notes'],
        alsoWrite: () async {
          await db.customStatement(
            "UPDATE dive_sites SET name = 'Held' WHERE id = 's1'",
          );
          throw StateError('refused');
        },
      ),
      throwsStateError,
    );

    final site = await stored();
    expect(site.name, 'Lake');
    expect(site.notes, 'Calm');
  });

  test('held library fields are stamped after the commit', () async {
    final stamper = _FailingStamper();
    final result = await SiteEditSaveService(sites, stamper: stamper).save(
      siteId: 's1',
      apply: notes('Choppy'),
      changedCardIds: const ['notes'],
      heldLibraryFields: () => {'features'},
    );

    expect(stamper.stamped, [
      {'features'},
    ]);
    // The stamp failed once the sitting had committed: the save stands.
    expect(result, isNotNull);
    expect((await stored()).notes, 'Choppy');
  });

  test('a failed save stamps no held library fields', () async {
    final stamper = _FailingStamper();
    await expectLater(
      SiteEditSaveService(sites, stamper: stamper).save(
        siteId: 's1',
        apply: notes('Choppy'),
        changedCardIds: const ['notes'],
        heldLibraryFields: () => {'features'},
        alsoWrite: () async => throw StateError('refused'),
      ),
      throwsStateError,
    );

    expect(stamper.stamped, isEmpty);
  });

  test('the stamp is the committed write, not a later reread', () async {
    final recording = _RecordingSites()
      ..callerZone = Zone.current
      ..onReadAfterCommit = () => db.customStatement(
        "UPDATE dive_sites SET name = 'Synced' WHERE id = 's1'",
      );
    await SiteEditSaveService(recording).save(
      siteId: 's1',
      apply: notes('Choppy'),
      changedCardIds: const ['notes'],
    );

    // A write that landed after the commit is not this diver's edit.
    expect(recording.stampedAfter.single.notes, 'Choppy');
    expect(recording.stampedAfter.single.name, 'Lake');
  });

  test('sync is told of the change after the library stamp', () async {
    var told = 0;
    final listening = SyncEventBus.changes.listen((_) => told++);
    addTearDown(listening.cancel);
    var toldAtStamp = -1;
    final recording = _RecordingSites()
      ..onStamp = () async {
        // What was told before the stamp has arrived by now.
        await Future<void>.delayed(Duration.zero);
        toldAtStamp = told;
      };
    await SiteEditSaveService(recording).save(
      siteId: 's1',
      apply: notes('Choppy'),
      changedCardIds: const ['notes'],
    );
    await Future<void>.delayed(Duration.zero);

    // The stamp marks the library's copy for the next sync: one is asked
    // for once it is there, not only from inside the transaction.
    expect(toldAtStamp, isNonNegative);
    expect(told, greaterThan(toldAtStamp));
    // Once, after the stamps: not also from inside the save, before them.
    expect(toldAtStamp, 0);
    expect(told, 1);
  });

  test('a sitting that rolls back leaves no library stamp', () async {
    final recording = _RecordingSites();
    await expectLater(
      SiteEditSaveService(recording).save(
        siteId: 's1',
        apply: notes('Choppy'),
        changedCardIds: const ['notes'],
        alsoWrite: () async => throw StateError('refused'),
      ),
      throwsStateError,
    );

    expect(recording.stamps, isEmpty);
    expect((await stored()).notes, 'Calm');
  });
}

/// Says this profile may not edit the site.
class _MayNotEdit extends LibraryEditStamper {
  @override
  Future<bool> mayEdit(String siteId, {String? actingDiverId}) async => false;
}
