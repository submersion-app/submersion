import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart'
    hide Trip, TripChecklistItem, ChecklistTemplate, ChecklistTemplateItem;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_checklists_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

import '../../../../helpers/test_database.dart';

/// A trip's checklists held in its sitting and written at Save, as one
/// History entry (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late TripChecklistsRepository checklists;
  late TripChecklistRepository items;
  late ChecklistTemplateRepository templates;
  late TripEditSaveService service;
  late SittingList<Trip, TripChecklistsHeld> list;
  final changeLog = ChangeLogRepository();

  Future<Trip> stored() async => (await trips.getTripById('t1'))!;

  Future<List<String>> labels() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT id, label FROM change_log_operations')
        .get();
    // Only sittings' entries: setting up a template writes its own.
    return [
      for (final r in rows)
        if (r.read<String?>('label') case final label?
            when label.startsWith('record_edit:'))
          label,
    ];
  }

  Future<String> onlyOperation() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT id FROM change_log_operations')
        .get();
    return rows.single.read<String>('id');
  }

  Future<void> revert(String operationId) async {
    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(await revert.planOperation(operationId));
  }

  Future<EditSession<Trip>> open() async {
    final session = EditSession<Trip>(await stored());
    await list.load(session);
    return session;
  }

  HeldTripChecklistWrites writesOf(EditSession<Trip> session) =>
      HeldTripChecklistWrites(
        session: session,
        list: list,
        templates: templates,
      );

  Future<void> save(EditSession<Trip> session) => service.save(
    tripId: 't1',
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
    actingDiverId: 'me',
    alsoWrite: session.runHeldWrites,
    alsoWriteIsAChange: session.hasHeldChanges,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    final days = ItineraryDayRepository();
    trips = TripRepository(itineraryDays: days);
    checklists = TripChecklistsRepository();
    items = TripChecklistRepository();
    templates = ChecklistTemplateRepository();
    service = TripEditSaveService(trips, days, LiveaboardDetailsRepository());
    list = tripChecklistsList(checklists: checklists, items: items);
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('me'),
            name: Value('Me'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await trips.createTrip(
      Trip(
        id: 't1',
        diverId: 'me',
        name: 'Red Sea',
        startDate: DateTime(2030, 6, 1),
        endDate: DateTime(2030, 6, 8),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final packing = await checklists.createChecklist(
      tripId: 't1',
      name: 'Packing',
      id: 'c1',
    );
    await items.createSection(checklistId: packing.id, title: 'Gear', id: 's1');
    await items.createItem(
      TripChecklistItem(
        id: 'i1',
        checklistId: 'c1',
        title: 'Mask',
        sectionId: 's1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test(
    'the sitting reads the checklists with their sections and items',
    () async {
      final session = await open();
      final held = heldChecklistsOf(session, list)!;

      expect([for (final c in held.checklists) c.id], ['c1']);
      expect([for (final s in held.sectionsOf('c1')) s.id], ['s1']);
      expect([for (final i in held.itemsOf('c1')) i.title], ['Mask']);
    },
  );

  test('every change waits for Save, and a checklist added and deleted in '
      'one sitting writes nothing', () async {
    final session = await open();
    final writes = writesOf(session);
    final added = await writes.createChecklist('Paperwork');
    await writes.toggleDone('i1', isDone: true);
    await writes.deleteChecklist(added.id);
    await writes.toggleDone('i1', isDone: false);

    expect(await checklists.getChecklistsForTrip('t1'), hasLength(1));
    expect(session.changedCardIds, isEmpty);
  });

  test('a tick sets completedAt, an untick clears it', () async {
    final session = await open();
    final writes = writesOf(session);

    await writes.toggleDone('i1', isDone: true);
    expect(
      heldChecklistsOf(session, list)!.items.single.completedAt,
      isNotNull,
    );
    await writes.toggleDone('i1', isDone: false);
    expect(heldChecklistsOf(session, list)!.items.single.completedAt, isNull);
  });

  test('Save writes created, changed, deleted and reordered rows as one '
      'History entry, and reverting it takes them all back', () async {
    final session = await open();
    final writes = writesOf(session);
    final paperwork = await writes.createChecklist('Paperwork');
    await writes.createItem(
      TripChecklistItem(
        id: '',
        checklistId: paperwork.id,
        title: 'Passport',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await writes.reorderChecklists([paperwork.id, 'c1']);
    await writes.toggleDone('i1', isDone: true);
    await writes.renameChecklist('c1', 'Kit');
    await writes.deleteSection('s1');

    expect(session.changedCardIds, {'checklists'});
    await save(session);

    final after = await checklists.getChecklistsForTrip('t1');
    expect([for (final c in after) c.name], ['Paperwork', 'Kit']);
    expect(await items.getSectionsForChecklist('c1'), isEmpty);
    // The section went with its item.
    expect(await items.getByChecklistId('c1'), isEmpty);
    expect(
      [for (final i in await items.getByChecklistId(paperwork.id)) i.title],
      ['Passport'],
    );
    expect(await labels(), ['record_edit:trips:t1:checklists']);

    await revert(await onlyOperation());

    final reverted = await checklists.getChecklistsForTrip('t1');
    expect([for (final c in reverted) c.name], ['Packing']);
    expect(
      [for (final s in await items.getSectionsForChecklist('c1')) s.id],
      ['s1'],
    );
    final mask = (await items.getByChecklistId('c1')).single;
    expect(mask.title, 'Mask');
    expect(mask.isDone, isFalse);
  });

  test('a checklist from a template, a tick and a section deleted: Cancel '
      'writes nothing', () async {
    final template = await templates.createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Prep',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await templates.saveItems(template.id, [
      ChecklistTemplateItem(
        id: '',
        templateId: template.id,
        title: 'Book flights',
        dueOffsetDays: 30,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    final session = await open();
    final writes = writesOf(session);
    final prep = await writes.createChecklist('Prep');
    final result = await writes.applyTemplate(
      templateId: template.id,
      checklistId: prep.id,
    );
    await writes.toggleDone('i1', isDone: true);
    await writes.deleteSection('s1');

    expect(result.added, 1);
    final flights = heldChecklistsOf(session, list)!.itemsOf(prep.id).single;
    expect(flights.dueDate, DateTime(2030, 5, 2));

    session.dispose();

    expect(await checklists.getChecklistsForTrip('t1'), hasLength(1));
    expect(await items.getByChecklistId('c1'), hasLength(1));
    expect(await labels(), isEmpty);
  });

  test('a template applied in a sitting dates its items from the working '
      'start date', () async {
    final template = await templates.createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Prep',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await templates.saveItems(template.id, [
      ChecklistTemplateItem(
        id: '',
        templateId: template.id,
        title: 'Book flights',
        dueOffsetDays: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    final session = await open();
    session.set(tripDatesField, (
      start: DateTime(2030, 7, 1),
      end: DateTime(2030, 7, 8),
    ));

    await writesOf(
      session,
    ).replaceWithTemplate(templateId: template.id, checklistId: 'c1');

    final held = heldChecklistsOf(session, list)!;
    expect(held.sectionsOf('c1'), isEmpty);
    expect(held.itemsOf('c1').single.dueDate, DateTime(2030, 6, 30));
  });

  test('a row another device added during the sitting survives Save', () async {
    final session = await open();
    await writesOf(session).toggleDone('i1', isDone: true);
    await items.createItem(
      TripChecklistItem(
        id: 'other',
        checklistId: 'c1',
        title: 'Fins',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    await save(session);

    final after = await items.getByChecklistId('c1');
    expect(
      {for (final i in after) i.id: i.isDone},
      {'i1': true, 'other': false},
    );
  });

  test('an unknown template refuses, holding nothing', () async {
    final session = await open();

    await expectLater(
      writesOf(session).applyTemplate(templateId: 'gone', checklistId: 'c1'),
      throwsStateError,
    );
    expect(session.changedCardIds, isEmpty);
  });

  test('sections made in a sitting keep the order they were given', () async {
    final session = await open();
    final writes = writesOf(session);
    await writes.createSection(checklistId: 'c1', title: 'A');
    await writes.createSection(checklistId: 'c1', title: 'B');
    final held = heldChecklistsOf(session, list)!.sectionsOf('c1');
    final a = held.firstWhere((s) => s.title == 'A').id;
    final b = held.firstWhere((s) => s.title == 'B').id;
    await writes.reorderSections('c1', ['s1', b, a]);

    await save(session);

    expect(
      [for (final s in await items.getSectionsForChecklist('c1')) s.title],
      ['Gear', 'B', 'A'],
    );
  });

  test('a checklist moved and moved back is no change, gaps and all', () async {
    await checklists.createChecklist(tripId: 't1', name: 'Gone', id: 'c2');
    await checklists.createChecklist(tripId: 't1', name: 'Paperwork', id: 'c3');
    await checklists.deleteChecklist('c2');
    final session = await open();
    final writes = writesOf(session);

    await writes.reorderChecklists(['c3', 'c1']);
    expect(session.changedCardIds, {'checklists'});
    await writes.reorderChecklists(['c1', 'c3']);

    expect(session.changedCardIds, isEmpty);
  });

  test('items and sections are held through every edit, and written at '
      'Save', () async {
    final session = await open();
    final writes = writesOf(session);

    expect(await writes.isChecklistEmpty('c1'), isFalse);
    // A title that matches a section (any case) is that section.
    expect(await writes.findOrCreateSectionId('c1', ' gear '), 's1');
    expect(await writes.findOrCreateSectionId('c1', '  '), isNull);
    final docs = (await writes.findOrCreateSectionId('c1', 'Docs'))!;
    await writes.createItem(
      TripChecklistItem(
        id: '',
        checklistId: 'c1',
        title: 'Passport',
        sectionId: docs,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    var held = heldChecklistsOf(session, list)!;
    final passport = held
        .itemsOf('c1')
        .firstWhere((i) => i.title == 'Passport');
    await writes.updateItem(passport.copyWith(notes: 'In the bag'));
    await writes.renameSection(docs, 'Papers');
    await writes.moveItem(
      checklistId: 'c1',
      itemId: 'i1',
      targetSectionId: docs,
      orderedIds: [passport.id, 'i1'],
    );
    await writes.deleteSection('s1', moveItemsToSectionId: docs);

    held = heldChecklistsOf(session, list)!;
    expect([for (final s in held.sectionsOf('c1')) s.title], ['Papers']);
    expect([for (final i in held.itemsOf('c1')) i.title], ['Passport', 'Mask']);
    expect({for (final i in held.itemsOf('c1')) i.sectionId}, {docs});

    await save(session);

    final sections = await items.getSectionsForChecklist('c1');
    expect([for (final s in sections) s.title], ['Papers']);
    final stored = await items.getByChecklistId('c1');
    expect([for (final i in stored) i.title], ['Passport', 'Mask']);
    expect(stored.first.notes, 'In the bag');
    expect({for (final i in stored) i.sectionId}, {docs});
  });

  test('clearing and deleting items in a sitting keeps the sections', () async {
    final session = await open();
    final writes = writesOf(session);
    await writes.deleteItem('i1');
    expect(heldChecklistsOf(session, list)!.itemsOf('c1'), isEmpty);
    await writes.createItem(
      TripChecklistItem(
        id: '',
        checklistId: 'c1',
        title: 'Fins',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await writes.clearItems('c1');

    await save(session);

    expect(await items.getByChecklistId('c1'), isEmpty);
    expect(await items.getSectionsForChecklist('c1'), hasLength(1));
  });

  test("a section deleted with its items moved takes another device's item "
      'stored there meanwhile along, and one deleted with them takes it '
      'too', () async {
    final session = await open();
    final writes = writesOf(session);
    final docs = (await writes.findOrCreateSectionId('c1', 'Docs'))!;
    await writes.deleteSection('s1', moveItemsToSectionId: docs);
    await items.createItem(
      TripChecklistItem(
        id: 'other',
        checklistId: 'c1',
        title: 'Fins',
        sectionId: 's1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    await save(session);

    final stored = await items.getByChecklistId('c1');
    expect(
      {for (final i in stored) i.id: i.sectionId},
      {'i1': docs, 'other': docs},
    );
  });

  test('an item deleted before its section is deleted with its items moved '
      'stays deleted', () async {
    final session = await open();
    final writes = writesOf(session);
    final docs = (await writes.findOrCreateSectionId('c1', 'Docs'))!;
    await writes.deleteItem('i1');
    await writes.deleteSection('s1', moveItemsToSectionId: docs);

    await save(session);

    expect(await items.getByChecklistId('c1'), isEmpty);
    expect(
      [for (final s in await items.getSectionsForChecklist('c1')) s.title],
      ['Docs'],
    );
  });

  test('a section whose items were moved to a section deleted later takes '
      'them with it', () async {
    final session = await open();
    final writes = writesOf(session);
    final docs = (await writes.findOrCreateSectionId('c1', 'Docs'))!;
    await writes.deleteSection('s1', moveItemsToSectionId: docs);
    await writes.deleteSection(docs);

    await save(session);

    expect(await items.getByChecklistId('c1'), isEmpty);
    expect(await items.getSectionsForChecklist('c1'), isEmpty);
  });
}
