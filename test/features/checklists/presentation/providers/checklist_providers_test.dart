import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // validatedCurrentDiverIdProvider depends on sharedPreferencesProvider,
  // which throws UnimplementedError unless overridden -- mirrors the setup
  // in tank_preset_providers_test.dart.
  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  test(
    'tripChecklistProvider returns items and progress provider counts',
    () async {
      final trip = await TripRepository().createTrip(
        Trip(
          id: '',
          name: 'Providers',
          startDate: DateTime(2026, 9, 10),
          endDate: DateTime(2026, 9, 17),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      final repo = container.read(tripChecklistRepositoryProvider);
      final created = await repo.createItem(
        TripChecklistItem(
          id: '',
          tripId: trip.id,
          title: 'Check insurance',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await repo.toggleDone(created.id, isDone: true);
      await repo.createItem(
        TripChecklistItem(
          id: '',
          tripId: trip.id,
          title: 'Book nitrox',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final items = await container.read(tripChecklistProvider(trip.id).future);
      expect(items, hasLength(2));

      final progress = await container.read(
        tripChecklistProgressProvider(trip.id).future,
      );
      expect(progress.done, 1);
      expect(progress.total, 2);
    },
  );

  test('checklistTemplatesProvider starts empty', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final templates = await container.read(checklistTemplatesProvider.future);
    expect(templates, isEmpty);
  });

  test('checklistTemplateProvider and checklistTemplateItemsProvider read a '
      'seeded template by id', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    final templateRepo = container.read(checklistTemplateRepositoryProvider);
    final created = await templateRepo.createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Liveaboard packing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await templateRepo.saveItems(created.id, [
      ChecklistTemplateItem(
        id: '',
        templateId: created.id,
        title: 'Wetsuit',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    final fetched = await container.read(
      checklistTemplateProvider(created.id).future,
    );
    expect(fetched?.name, 'Liveaboard packing');

    final missing = await container.read(
      checklistTemplateProvider('no-such-id').future,
    );
    expect(missing, isNull);

    final items = await container.read(
      checklistTemplateItemsProvider(created.id).future,
    );
    expect(items.map((i) => i.title).toList(), ['Wetsuit']);
  });

  group('homeTripChecklistProvider', () {
    Future<Trip> makeTrip(String name, DateTime start, DateTime end) =>
        TripRepository().createTrip(
          Trip(
            id: '',
            name: name,
            startDate: start,
            endDate: end,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    Future<void> addItem(ProviderContainer c, String tripId) async {
      await c
          .read(tripChecklistRepositoryProvider)
          .createItem(
            TripChecklistItem(
              id: '',
              tripId: tripId,
              title: 'Pack regs',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
    }

    test('surfaces the next upcoming trip that has items', () async {
      final now = DateTime.now();
      final soon = await makeTrip(
        'Soon',
        now.add(const Duration(days: 7)),
        now.add(const Duration(days: 14)),
      );
      await makeTrip(
        'Later',
        now.add(const Duration(days: 60)),
        now.add(const Duration(days: 67)),
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      await addItem(container, soon.id);

      final result = await container.read(homeTripChecklistProvider.future);
      expect(result, isNotNull);
      expect(result!.trip.id, soon.id);
      expect(result.total, 1);
      expect(result.done, 0);
    });

    test('a trip already under way wins over one still ahead', () async {
      final now = DateTime.now();
      final running = await makeTrip(
        'Running',
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 3)),
      );
      final ahead = await makeTrip(
        'Ahead',
        now.add(const Duration(days: 2)),
        now.add(const Duration(days: 9)),
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      await addItem(container, running.id);
      await addItem(container, ahead.id);

      final result = await container.read(homeTripChecklistProvider.future);
      expect(result!.trip.id, running.id);
    });

    test('an empty nearer trip does not hide a later one with items', () async {
      // The date-best candidate has nothing on its list. Picking by date and
      // only then checking for items returned null here and hid the home row
      // even though a perfectly good checklist existed one trip along.
      final now = DateTime.now();
      await makeTrip(
        'Empty and sooner',
        now.add(const Duration(days: 3)),
        now.add(const Duration(days: 6)),
      );
      final later = await makeTrip(
        'Stocked and later',
        now.add(const Duration(days: 30)),
        now.add(const Duration(days: 37)),
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      await addItem(container, later.id);

      final result = await container.read(homeTripChecklistProvider.future);
      expect(result, isNotNull);
      expect(result!.trip.id, later.id);
      expect(result.total, 1);
    });

    test(
      'an empty in-progress trip falls through to an upcoming one',
      () async {
        final now = DateTime.now();
        await makeTrip(
          'Running but empty',
          now.subtract(const Duration(days: 1)),
          now.add(const Duration(days: 3)),
        );
        final ahead = await makeTrip(
          'Ahead with items',
          now.add(const Duration(days: 10)),
          now.add(const Duration(days: 17)),
        );

        final container = makeContainer();
        addTearDown(container.dispose);
        await addItem(container, ahead.id);

        final result = await container.read(homeTripChecklistProvider.future);
        expect(result!.trip.id, ahead.id);
      },
    );

    test('a trip with an empty checklist is not surfaced', () async {
      final now = DateTime.now();
      await makeTrip(
        'Empty',
        now.add(const Duration(days: 5)),
        now.add(const Duration(days: 12)),
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      expect(await container.read(homeTripChecklistProvider.future), isNull);
    });

    test('no trips at all is null, not an error', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      expect(await container.read(homeTripChecklistProvider.future), isNull);
    });
  });
}
