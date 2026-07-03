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

  TripChecklistItem item({
    String title = 'Service regulator',
    String? category,
    DateTime? dueDate,
  }) => TripChecklistItem(
    id: '',
    tripId: testTrip.id,
    title: title,
    category: category,
    dueDate: dueDate,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

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
      final a = await repository.createItem(item(title: 'A'));
      await repository.createItem(item(title: 'B', category: 'Gear'));
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
          category: 'Bookings',
          dueOffsetDays: 60,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Pack wetsuit',
          category: 'Gear',
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
        await repository.createItem(item(title: 'A', category: 'B|C'));

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
            category: 'C',
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
        expect(
          items.where((i) => i.title == 'A|B' && i.category == 'C'),
          hasLength(1),
        );
      },
    );

    test(
      'treats null category as distinct from empty-string category',
      () async {
        await repository.createItem(item(title: 'Dup item', category: ''));

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
            category: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ]);

        final result = await repository.applyTemplate(
          templateId: nullCategoryTemplate.id,
          trip: testTrip,
        );
        expect(result.added, 1);
        expect(result.skipped, 0);
      },
    );

    test(
      'skips a genuine duplicate with matching title and category',
      () async {
        await repository.createItem(
          item(title: 'Book flights', category: 'Bookings'),
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
        item(
          title: 'Book flights',
          category: 'Bookings',
          dueDate: tripStart.subtract(const Duration(days: 60)),
        ),
      );
      await repository.createItem(item(title: 'Pack wetsuit'));

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
        item(
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
      final a = await repository.createItem(item(title: 'A'));
      await repository.createItem(item(title: 'B'));
      await repository.toggleDone(a.id, isDone: true);
      final progress = await repository.getProgress(testTrip.id);
      expect(progress.done, 1);
      expect(progress.total, 2);
    });

    test('deleteByTripId removes all items', () async {
      await repository.createItem(item(title: 'A'));
      await repository.createItem(item(title: 'B'));
      await repository.deleteByTripId(testTrip.id);
      expect(await repository.getByTripId(testTrip.id), isEmpty);
    });
  });
}
