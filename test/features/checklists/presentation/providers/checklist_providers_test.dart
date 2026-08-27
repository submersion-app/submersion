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
}
