import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late TripChecklistRepository repository;
  late ChecklistTemplateRepository templateRepository;
  late TripRepository tripRepository;
  late Trip testTrip;

  final tripStart = DateTime(2026, 9, 10);

  /// Builds an item, resolving [category] to a section through the
  /// repository exactly as the item editor's picker will (issue #3360):
  /// an existing section with that title, case-insensitively, or a new one.
  /// Kept named `category` here so the tests below, written against the
  /// pre-sections free-text field, read the same way; only the resolution
  /// step changed.
  Future<TripChecklistItem> item({
    String title = 'Service regulator',
    String? category,
    DateTime? dueDate,
  }) async => TripChecklistItem(
    id: '',
    tripId: testTrip.id,
    title: title,
    sectionId: await repository.findOrCreateSectionId(testTrip.id, category),
    dueDate: dueDate,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  /// The title of the section [item] is grouped under, or null, for
  /// assertions that used to read `item.category` directly.
  Future<String?> sectionTitleOf(TripChecklistItem item) async {
    if (item.sectionId == null) return null;
    final sections = await repository.getSectionsForTrip(testTrip.id);
    return sections.firstWhere((s) => s.id == item.sectionId).title;
  }

  setUp(() async {
    await setUpTestDatabase();
    repository = TripChecklistRepository();
    templateRepository = ChecklistTemplateRepository();
    tripRepository = TripRepository();
    // Parent trip satisfies the FK constraint (foreign_keys = ON in tests).
    testTrip = await tripRepository.createTrip(
      Trip(
        id: '',
        name: 'Red Sea',
        startDate: tripStart,
        endDate: tripStart.add(const Duration(days: 7)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('CRUD', () {
    test('create, read ordered, update, toggle, delete', () async {
      final a = await repository.createItem(await item(title: 'A'));
      await repository.createItem(await item(title: 'B', category: 'Gear'));
      var items = await repository.getByTripId(testTrip.id);
      expect(items.map((i) => i.title).toList(), ['A', 'B']);

      await repository.updateItem(a.copyWith(notes: 'annual service'));
      items = await repository.getByTripId(testTrip.id);
      expect(items.first.notes, 'annual service');

      await repository.toggleDone(a.id, isDone: true);
      items = await repository.getByTripId(testTrip.id);
      expect(items.first.isDone, isTrue);
      expect(items.first.completedAt, isNotNull);

      await repository.toggleDone(a.id, isDone: false);
      items = await repository.getByTripId(testTrip.id);
      expect(items.first.isDone, isFalse);
      expect(items.first.completedAt, isNull);

      await repository.deleteItem(a.id);
      expect(await repository.getByTripId(testTrip.id), hasLength(1));
    });
  });

  group('applyTemplate', () {
    late ChecklistTemplate template;

    setUp(() async {
      template = await templateRepository.createTemplate(
        ChecklistTemplate(
          id: '',
          name: 'Prep',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await templateRepository.saveItems(template.id, [
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Book flights',
          sectionId: await templateRepository.findOrCreateSectionId(
            template.id,
            'Bookings',
          ),
          dueOffsetDays: 60,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Pack wetsuit',
          sectionId: await templateRepository.findOrCreateSectionId(
            template.id,
            'Gear',
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
    });

    test('copies items resolving offsets to absolute due dates', () async {
      final result = await repository.applyTemplate(
        templateId: template.id,
        trip: testTrip,
      );
      expect(result.added, 2);
      expect(result.skipped, 0);

      final items = await repository.getByTripId(testTrip.id);
      expect(items, hasLength(2));
      final flights = items.firstWhere((i) => i.title == 'Book flights');
      expect(flights.dueDate, tripStart.subtract(const Duration(days: 60)));
      final wetsuit = items.firstWhere((i) => i.title == 'Pack wetsuit');
      expect(wetsuit.dueDate, isNull);
      expect(items.every((i) => !i.isDone), isTrue);
    });

    test('re-apply skips items with matching title and category', () async {
      await repository.applyTemplate(templateId: template.id, trip: testTrip);
      final second = await repository.applyTemplate(
        templateId: template.id,
        trip: testTrip,
      );
      expect(second.added, 0);
      expect(second.skipped, 2);
      expect(await repository.getByTripId(testTrip.id), hasLength(2));
      // A fully-skipped re-apply must not create duplicate (or any new)
      // sections as a side effect of resolving each skipped item's section.
      final sections = await repository.getSectionsForTrip(testTrip.id);
      expect(sections.map((s) => s.title).toSet(), {'Bookings', 'Gear'});
    });

    test('throws StateError when template does not exist', () async {
      await expectLater(
        repository.applyTemplate(templateId: 'missing', trip: testTrip),
        throwsStateError,
      );
      expect(await repository.getByTripId(testTrip.id), isEmpty);
    });

    test(
      'does not treat a pipe in the title as a collision with a '
      'different (title, category) pair whose pipe-joined string matches',
      () async {
        // Old pipe-joined key: 'A|B' + '|' + 'C' == 'A' + '|' + 'B|C'.
        // These are different (title, category) pairs and must not collide.
        // The repository now keys on a (title, sectionId) tuple rather than
        // a joined string, so this collision class cannot occur structurally
        // any more; the test stays to pin that down.
        await repository.createItem(await item(title: 'A', category: 'B|C'));

        final pipeTemplate = await templateRepository.createTemplate(
          ChecklistTemplate(
            id: '',
            name: 'Pipe test',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await templateRepository.saveItems(pipeTemplate.id, [
          ChecklistTemplateItem(
            id: '',
            templateId: pipeTemplate.id,
            title: 'A|B',
            sectionId: await templateRepository.findOrCreateSectionId(
              pipeTemplate.id,
              'C',
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ]);

        final result = await repository.applyTemplate(
          templateId: pipeTemplate.id,
          trip: testTrip,
        );
        expect(result.added, 1);
        expect(result.skipped, 0);
        final items = await repository.getByTripId(testTrip.id);
        final match = items.where((i) => i.title == 'A|B').toList();
        expect(match, hasLength(1));
        expect(await sectionTitleOf(match.single), 'C');
      },
    );

    test(
      'empty-string category now collapses to the same "no section" as '
      'null (deliberate change from the pre-sections free-text field, '
      'where NULL and the empty string were distinct column values)',
      () async {
        await repository.createItem(
          await item(title: 'Dup item', category: ''),
        );

        final nullCategoryTemplate = await templateRepository.createTemplate(
          ChecklistTemplate(
            id: '',
            name: 'Null category test',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await templateRepository.saveItems(nullCategoryTemplate.id, [
          ChecklistTemplateItem(
            id: '',
            templateId: nullCategoryTemplate.id,
            title: 'Dup item',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ]);

        final result = await repository.applyTemplate(
          templateId: nullCategoryTemplate.id,
          trip: testTrip,
        );
        // Both resolve to sectionId null, so the (title, sectionId) tuple
        // now matches: this is correctly treated as the same item.
        expect(result.added, 0);
        expect(result.skipped, 1);
      },
    );

    test('two new template items sharing a new section resolve to the same '
        'section, not one each', () async {
      final sharedSectionTemplate = await templateRepository.createTemplate(
        ChecklistTemplate(
          id: '',
          name: 'Shared section test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final sectionId = await templateRepository.findOrCreateSectionId(
        sharedSectionTemplate.id,
        'Documents',
      );
      await templateRepository.saveItems(sharedSectionTemplate.id, [
        ChecklistTemplateItem(
          id: '',
          templateId: sharedSectionTemplate.id,
          title: 'Passport',
          sectionId: sectionId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ChecklistTemplateItem(
          id: '',
          templateId: sharedSectionTemplate.id,
          title: 'Visa',
          sectionId: sectionId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final result = await repository.applyTemplate(
        templateId: sharedSectionTemplate.id,
        trip: testTrip,
      );

      expect(result.added, 2);
      final sections = await repository.getSectionsForTrip(testTrip.id);
      expect(sections.where((s) => s.title == 'Documents'), hasLength(1));
      final items = await repository.getByTripId(testTrip.id);
      final passport = items.firstWhere((i) => i.title == 'Passport');
      final visa = items.firstWhere((i) => i.title == 'Visa');
      expect(passport.sectionId, visa.sectionId);
    });

    test(
      'skips a genuine duplicate with matching title and category',
      () async {
        await repository.createItem(
          await item(title: 'Book flights', category: 'Bookings'),
        );
        final result = await repository.applyTemplate(
          templateId: template.id,
          trip: testTrip,
        );
        expect(result.added, 1);
        expect(result.skipped, 1);
      },
    );
  });

  group('saveAsTemplate', () {
    test('converts absolute due dates back to offsets', () async {
      await repository.createItem(
        await item(
          title: 'Book flights',
          category: 'Bookings',
          dueDate: tripStart.subtract(const Duration(days: 60)),
        ),
      );
      await repository.createItem(await item(title: 'Pack wetsuit'));

      final tpl = await repository.saveAsTemplate(
        tripId: testTrip.id,
        tripStartDate: testTrip.startDate,
        name: 'My prep',
      );
      final items = await templateRepository.getItemsForTemplate(tpl.id);
      expect(items, hasLength(2));
      final flights = items.firstWhere((i) => i.title == 'Book flights');
      expect(flights.dueOffsetDays, 60);
      final wetsuit = items.firstWhere((i) => i.title == 'Pack wetsuit');
      expect(wetsuit.dueOffsetDays, isNull);
    });

    test('due date after trip start is stored dateless', () async {
      await repository.createItem(
        await item(
          title: 'Rinse gear',
          category: 'Gear',
          dueDate: tripStart.add(const Duration(days: 2)),
        ),
      );

      final tpl = await repository.saveAsTemplate(
        tripId: testTrip.id,
        tripStartDate: testTrip.startDate,
        name: 'My prep',
      );
      final items = await templateRepository.getItemsForTemplate(tpl.id);
      expect(items, hasLength(1));
      expect(items.single.dueOffsetDays, isNull);
    });
  });

  group('progress and cascade', () {
    test('getProgress counts done vs total', () async {
      final a = await repository.createItem(await item(title: 'A'));
      await repository.createItem(await item(title: 'B'));
      await repository.toggleDone(a.id, isDone: true);
      final progress = await repository.getProgress(testTrip.id);
      expect(progress.done, 1);
      expect(progress.total, 2);
    });

    test('getProgressForTrips batches counts and omits empty trips', () async {
      final other = await tripRepository.createTrip(
        Trip(
          id: '',
          name: 'Truk',
          startDate: tripStart.add(const Duration(days: 40)),
          endDate: tripStart.add(const Duration(days: 47)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final empty = await tripRepository.createTrip(
        Trip(
          id: '',
          name: 'Nothing packed yet',
          startDate: tripStart.add(const Duration(days: 80)),
          endDate: tripStart.add(const Duration(days: 87)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final a = await repository.createItem(await item(title: 'A'));
      await repository.createItem(await item(title: 'B'));
      await repository.toggleDone(a.id, isDone: true);
      await repository.createItem(
        TripChecklistItem(
          id: '',
          tripId: other.id,
          title: 'Passport',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final progress = await repository.getProgressForTrips([
        testTrip.id,
        other.id,
        empty.id,
      ]);

      expect(progress[testTrip.id], (done: 1, total: 2));
      expect(progress[other.id], (done: 0, total: 1));
      // GROUP BY yields no row for a trip with no items, and callers read
      // that absence as "nothing to show".
      expect(progress.containsKey(empty.id), isFalse);
    });

    test('getProgressForTrips on an empty id list is a no-op', () async {
      expect(await repository.getProgressForTrips([]), isEmpty);
    });

    test('deleteByTripId removes all items and sections', () async {
      await repository.createItem(await item(title: 'A'));
      await repository.createItem(await item(title: 'B'));
      await repository.createSection(tripId: testTrip.id, title: 'Gear');
      await repository.deleteByTripId(testTrip.id);
      expect(await repository.getByTripId(testTrip.id), isEmpty);
      expect(await repository.getSectionsForTrip(testTrip.id), isEmpty);
    });

    test(
      'deleteByTripId removes sections even when there are no items',
      () async {
        await repository.createSection(tripId: testTrip.id, title: 'Gear');
        await repository.deleteByTripId(testTrip.id);
        expect(await repository.getSectionsForTrip(testTrip.id), isEmpty);
      },
    );
  });

  group('sections', () {
    test('createSection appends at the end of the trip order', () async {
      final a = await repository.createSection(
        tripId: testTrip.id,
        title: 'Assembly',
      );
      final b = await repository.createSection(
        tripId: testTrip.id,
        title: 'Cells',
      );
      expect(a.sortOrder, 0);
      expect(b.sortOrder, 1);
      final sections = await repository.getSectionsForTrip(testTrip.id);
      expect(sections.map((s) => s.title).toList(), ['Assembly', 'Cells']);
    });

    test('renameSection updates the title only', () async {
      final section = await repository.createSection(
        tripId: testTrip.id,
        title: 'Assembly',
      );
      await repository.renameSection(section.id, 'Assembly checks');
      final sections = await repository.getSectionsForTrip(testTrip.id);
      expect(sections.single.title, 'Assembly checks');
      expect(sections.single.id, section.id);
    });

    test('reorderSections persists the new order', () async {
      final a = await repository.createSection(tripId: testTrip.id, title: 'A');
      final b = await repository.createSection(tripId: testTrip.id, title: 'B');
      await repository.reorderSections(testTrip.id, [b.id, a.id]);
      final sections = await repository.getSectionsForTrip(testTrip.id);
      expect(sections.map((s) => s.title).toList(), ['B', 'A']);
    });

    test('moveItem reorders items within the same section', () async {
      final section = await repository.createSection(
        tripId: testTrip.id,
        title: 'Cells',
      );
      final a = await repository.createItem(
        TripChecklistItem(
          id: '',
          tripId: testTrip.id,
          title: 'Cell 1',
          sectionId: section.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final b = await repository.createItem(
        TripChecklistItem(
          id: '',
          tripId: testTrip.id,
          title: 'Cell 2',
          sectionId: section.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.moveItem(
        tripId: testTrip.id,
        itemId: b.id,
        targetSectionId: section.id,
        orderedIds: [b.id, a.id],
      );

      final items = await repository.getByTripId(testTrip.id);
      expect(items.map((i) => i.id).toList(), [b.id, a.id]);
      expect(items.every((i) => i.sectionId == section.id), isTrue);
    });

    test('moveItem reassigns an item to a different section', () async {
      final cells = await repository.createSection(
        tripId: testTrip.id,
        title: 'Cells',
      );
      final bottles = await repository.createSection(
        tripId: testTrip.id,
        title: 'Bottles',
      );
      final cellItem = await repository.createItem(
        TripChecklistItem(
          id: '',
          tripId: testTrip.id,
          title: 'Cell 1',
          sectionId: cells.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final bottleItem = await repository.createItem(
        TripChecklistItem(
          id: '',
          tripId: testTrip.id,
          title: 'Bottle 1',
          sectionId: bottles.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.moveItem(
        tripId: testTrip.id,
        itemId: cellItem.id,
        targetSectionId: bottles.id,
        orderedIds: [bottleItem.id, cellItem.id],
      );

      final items = await repository.getByTripId(testTrip.id);
      final moved = items.firstWhere((i) => i.id == cellItem.id);
      expect(moved.sectionId, bottles.id);
      expect(items.map((i) => i.id).toList(), [bottleItem.id, cellItem.id]);
    });

    test('deleteSection without a target deletes its items too', () async {
      final section = await repository.createSection(
        tripId: testTrip.id,
        title: 'Assembly',
      );
      await repository.createItem(
        TripChecklistItem(
          id: '',
          tripId: testTrip.id,
          title: 'Check O-rings',
          sectionId: section.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.deleteSection(section.id);

      expect(await repository.getSectionsForTrip(testTrip.id), isEmpty);
      expect(await repository.getByTripId(testTrip.id), isEmpty);
    });

    test('deleteSection with moveItemsToSectionId reassigns items instead of '
        'deleting them', () async {
      final assembly = await repository.createSection(
        tripId: testTrip.id,
        title: 'Assembly',
      );
      final cells = await repository.createSection(
        tripId: testTrip.id,
        title: 'Cells',
      );
      final created = await repository.createItem(
        TripChecklistItem(
          id: '',
          tripId: testTrip.id,
          title: 'Check O-rings',
          sectionId: assembly.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await repository.deleteSection(
        assembly.id,
        moveItemsToSectionId: cells.id,
      );

      final sections = await repository.getSectionsForTrip(testTrip.id);
      expect(sections.map((s) => s.id), [cells.id]);
      final survivors = await repository.getByTripId(testTrip.id);
      expect(survivors.single.id, created.id);
      expect(survivors.single.sectionId, cells.id);
    });

    test(
      'findOrCreateSectionId matches an existing title case-insensitively',
      () async {
        final created = await repository.createSection(
          tripId: testTrip.id,
          title: 'Cells',
        );
        final resolved = await repository.findOrCreateSectionId(
          testTrip.id,
          'cells',
        );
        expect(resolved, created.id);
        expect(await repository.getSectionsForTrip(testTrip.id), hasLength(1));
      },
    );

    test('findOrCreateSectionId returns null for blank input', () async {
      expect(await repository.findOrCreateSectionId(testTrip.id, null), isNull);
      expect(await repository.findOrCreateSectionId(testTrip.id, '  '), isNull);
      expect(await repository.getSectionsForTrip(testTrip.id), isEmpty);
    });

    test('applyTemplate places a new section after the highest sortOrder, '
        'not at the section count, once a section was deleted', () async {
      await repository.createSection(tripId: testTrip.id, title: 'A');
      final b = await repository.createSection(tripId: testTrip.id, title: 'B');
      final c = await repository.createSection(tripId: testTrip.id, title: 'C');
      await repository.deleteSection(b.id);
      expect(c.sortOrder, 2);

      final template = await templateRepository.createTemplate(
        ChecklistTemplate(
          id: '',
          name: 'New section',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final sectionId = await templateRepository.findOrCreateSectionId(
        template.id,
        'Documents',
      );
      await templateRepository.saveItems(template.id, [
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Passport',
          sectionId: sectionId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      await repository.applyTemplate(templateId: template.id, trip: testTrip);

      final sections = await repository.getSectionsForTrip(testTrip.id);
      expect(sections.map((s) => s.title), ['A', 'C', 'Documents']);
      expect(sections.map((s) => s.sortOrder).toSet(), hasLength(3));
    });

    test('moveItem rewrites only the rows whose position changes', () async {
      final section = await repository.createSection(
        tripId: testTrip.id,
        title: 'Gear',
      );
      final created = <TripChecklistItem>[];
      for (final title in ['One', 'Two', 'Three']) {
        created.add(
          await repository.createItem(
            TripChecklistItem(
              id: '',
              tripId: testTrip.id,
              title: title,
              sectionId: section.id,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
        );
      }
      final before = await repository.getByTripId(testTrip.id);
      final third = before.firstWhere((i) => i.title == 'Three');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Swap the first two; the third keeps its position.
      await repository.moveItem(
        tripId: testTrip.id,
        itemId: created[1].id,
        targetSectionId: section.id,
        orderedIds: [created[1].id, created[0].id, created[2].id],
      );

      final after = await repository.getByTripId(testTrip.id);
      expect(after.map((i) => i.title), ['Two', 'One', 'Three']);
      expect(
        after.firstWhere((i) => i.title == 'Three').updatedAt,
        third.updatedAt,
      );
    });
  });
}
