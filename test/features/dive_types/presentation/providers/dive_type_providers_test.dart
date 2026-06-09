import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

Diver _makeDiver({String name = 'Default', bool isDefault = true}) {
  final now = DateTime.now();
  return Diver(
    id: '',
    name: name,
    isDefault: isDefault,
    createdAt: now,
    updatedAt: now,
  );
}

DiveTypeEntity _makeDiveType({String name = 'Custom Type', String? diverId}) {
  return DiveTypeEntity.create(id: '', name: name, diverId: diverId);
}

/// Fake repository whose `getAllDiveTypes` throws, to drive the error path.
/// `watchDiveTypesChanges()` is inherited from the real repository and works
/// against the in-memory test DB set up in [setUp].
class _ThrowingDiveTypeRepository extends DiveTypeRepository {
  @override
  Future<List<DiveTypeEntity>> getAllDiveTypes({String? diverId}) async {
    throw Exception('boom');
  }
}

void main() {
  late SharedPreferences prefs;
  late DiverRepository diverRepo;
  late DiveTypeRepository diveTypeRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    diverRepo = DiverRepository();
    diveTypeRepo = DiveTypeRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  /// Creates a default diver and marks it current so diver-scoped custom dive
  /// types resolve. Returns the diver id.
  Future<String> seedCurrentDiver() async {
    final diver = await diverRepo.createDiver(_makeDiver());
    await prefs.setString(currentDiverIdKey, diver.id);
    return diver.id;
  }

  group('diveTypesProvider (base FutureProvider)', () {
    test(
      'auto-refreshes after a write to the dive_types table (sync scenario)',
      () async {
        final diverId = await seedCurrentDiver();

        final container = makeContainer();
        addTearDown(container.dispose);

        // An active listener keeps the provider (and its table-change
        // subscription) alive, mirroring a widget watching the dive-type list.
        final sub = container.listen(diveTypesProvider, (_, _) {});
        addTearDown(sub.close);

        // Initial resolve: only built-in types, no custom rows yet.
        final initial = await container.read(diveTypesProvider.future);
        expect(initial.map((t) => t.name), isNot(contains('Synced Type')));

        // A sync applies a remote custom dive type straight to the DB (no
        // notifier mutation). The watchDiveTypesChanges tick must invalidate
        // the provider so the new row appears.
        await diveTypeRepo.createDiveType(
          _makeDiveType(name: 'Synced Type', diverId: diverId),
        );

        // Poll until the tick -> invalidateSelf -> rebuild settles.
        var names = <String>[];
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          names = (await container.read(
            diveTypesProvider.future,
          )).map((t) => t.name).toList();
          if (names.contains('Synced Type')) break;
        }

        expect(
          names,
          contains('Synced Type'),
          reason:
              'diveTypesProvider should auto-refresh after the table write '
              'without any manual invalidation',
        );
      },
    );
  });

  group('diveTypeListNotifierProvider '
      '(DiveTypeListNotifier._silentReloadDiveTypes)', () {
    test('silently reloads the list when a dive type is written directly to '
        'the DB (sync scenario)', () async {
      final diverId = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the notifier (and its table-change subscription)
      // alive, mirroring the on-screen list.
      final sub = container.listen(diveTypeListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      // Wait for the initial load to settle (built-in types only).
      while (container.read(diveTypeListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      final initialNames =
          (container.read(diveTypeListNotifierProvider).value ?? [])
              .map((t) => t.name)
              .toList();
      expect(initialNames, isNot(contains('Synced Type')));

      // A sync applies a remote custom dive type straight to the DB (no
      // notifier mutation call). The watchDiveTypesChanges tick must silently
      // reload via _silentReloadDiveTypes so the list reflects the new row.
      await diveTypeRepo.createDiveType(
        _makeDiveType(name: 'Synced Type', diverId: diverId),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (container.read(diveTypeListNotifierProvider).value ?? [])
            .map((t) => t.name)
            .toList();
        if (names.contains('Synced Type')) break;
      }

      expect(
        names,
        contains('Synced Type'),
        reason:
            'DiveTypeListNotifier should silently reload after a direct DB '
            'write without any manual refresh() call',
      );
    });

    test('reports AsyncError when the initial load throws', () async {
      await seedCurrentDiver();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diveTypeRepositoryProvider.overrideWithValue(
            _ThrowingDiveTypeRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(diveTypeListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      // The initial load already fails; poll until the error state settles.
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (container.read(diveTypeListNotifierProvider).hasError) break;
      }

      expect(container.read(diveTypeListNotifierProvider).hasError, isTrue);
    });
  });
}
