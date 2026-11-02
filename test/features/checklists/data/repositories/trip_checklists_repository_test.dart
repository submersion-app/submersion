import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late TripChecklistsRepository repository;
  late TripChecklistRepository itemRepository;
  late TripRepository tripRepository;
  late Trip testTrip;

  setUp(() async {
    await setUpTestDatabase();
    repository = TripChecklistsRepository();
    itemRepository = TripChecklistRepository();
    tripRepository = TripRepository();
    testTrip = await tripRepository.createTrip(
      Trip(
        id: '',
        name: 'Red Sea',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 17),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('createChecklist appends at the end of the trip order', () async {
    final a = await repository.createChecklist(
      tripId: testTrip.id,
      name: 'Dive equipment',
    );
    final b = await repository.createChecklist(
      tripId: testTrip.id,
      name: 'Clothing',
    );
    expect(a.sortOrder, 0);
    expect(b.sortOrder, 1);
    final checklists = await repository.getChecklistsForTrip(testTrip.id);
    expect(checklists.map((c) => c.name).toList(), [
      'Dive equipment',
      'Clothing',
    ]);
  });

  test(
    'checklists sharing a sort order keep one order on every device',
    () async {
      // Two devices that each add a checklist offline assign the same sort
      // order. Inserted newest first, so the tie-break has something to do.
      final db = DatabaseService.instance.database;
      for (final (id, createdAt) in [('b', 2000), ('a', 1000)]) {
        await db.customStatement(
          'INSERT INTO trip_checklists '
          '(id, trip_id, name, sort_order, created_at, updated_at) '
          "VALUES (?, ?, ?, 1, ?, ?)",
          [id, testTrip.id, id, createdAt, createdAt],
        );
      }

      final checklists = await repository.getChecklistsForTrip(testTrip.id);
      expect(checklists.map((c) => c.id).toList(), ['a', 'b']);
    },
  );

  test('renameChecklist updates the name only', () async {
    final checklist = await repository.createChecklist(
      tripId: testTrip.id,
      name: 'Dive equipment',
    );
    await repository.renameChecklist(checklist.id, 'Tec equipment');
    final checklists = await repository.getChecklistsForTrip(testTrip.id);
    expect(checklists.single.name, 'Tec equipment');
    expect(checklists.single.id, checklist.id);
  });

  test('reorderChecklists persists the new order', () async {
    final a = await repository.createChecklist(tripId: testTrip.id, name: 'A');
    final b = await repository.createChecklist(tripId: testTrip.id, name: 'B');
    await repository.reorderChecklists(testTrip.id, [b.id, a.id]);
    final checklists = await repository.getChecklistsForTrip(testTrip.id);
    expect(checklists.map((c) => c.name).toList(), ['B', 'A']);
  });

  test(
    'deleteChecklist removes the checklist, its sections and its items',
    () async {
      final checklist = await repository.createChecklist(
        tripId: testTrip.id,
        name: 'Dive equipment',
      );
      final section = await itemRepository.createSection(
        checklistId: checklist.id,
        title: 'Cells',
      );
      await itemRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'O-rings',
          sectionId: section.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.deleteChecklist(checklist.id);

      expect(await repository.getChecklistsForTrip(testTrip.id), isEmpty);
      expect(
        await itemRepository.getSectionsForChecklist(checklist.id),
        isEmpty,
      );
      expect(await itemRepository.getByChecklistId(checklist.id), isEmpty);
    },
  );

  test(
    'deleteChecklist leaves the trip\'s other checklists untouched',
    () async {
      final keep = await repository.createChecklist(
        tripId: testTrip.id,
        name: 'Keep',
      );
      final drop = await repository.createChecklist(
        tripId: testTrip.id,
        name: 'Drop',
      );
      await repository.deleteChecklist(drop.id);
      final checklists = await repository.getChecklistsForTrip(testTrip.id);
      expect(checklists.map((c) => c.id).toList(), [keep.id]);
    },
  );

  test('deleteAllForTrip removes every checklist of the trip, including '
      'their sections and items', () async {
    final first = await repository.createChecklist(
      tripId: testTrip.id,
      name: 'Dive equipment',
    );
    final second = await repository.createChecklist(
      tripId: testTrip.id,
      name: 'Clothing',
    );
    await itemRepository.createItem(
      TripChecklistItem(
        id: '',
        checklistId: first.id,
        title: 'Mask',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await itemRepository.createItem(
      TripChecklistItem(
        id: '',
        checklistId: second.id,
        title: 'Jacket',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await repository.deleteAllForTrip(testTrip.id);

    expect(await repository.getChecklistsForTrip(testTrip.id), isEmpty);
    expect(await itemRepository.getByChecklistId(first.id), isEmpty);
    expect(await itemRepository.getByChecklistId(second.id), isEmpty);
  });

  test('deleteAllForTrip on a trip with no checklists is a no-op', () async {
    await repository.deleteAllForTrip(testTrip.id);
    expect(await repository.getChecklistsForTrip(testTrip.id), isEmpty);
  });

  test('a trip with no checklists starts empty', () async {
    expect(await repository.getChecklistsForTrip(testTrip.id), isEmpty);
  });
}
