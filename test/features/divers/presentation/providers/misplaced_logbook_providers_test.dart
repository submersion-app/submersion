import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/misplaced_logbook.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/misplaced_logbook_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id, {int createdAt = 0}) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(createdAt),
            updatedAt: Value(createdAt),
          ),
        );
  }

  Future<void> insertDive(String id, String diverId) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: const Value(0),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
  }

  Future<ProviderContainer> containerWithActive(String activeId) async {
    await prefs.setString(currentDiverIdKey, activeId);
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<MisplacedLogbook?> settle(
    ProviderContainer container,
    bool Function(MisplacedLogbook?) until,
  ) async {
    final sub = container.listen(misplacedLogbookProvider, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 100; i++) {
      final value = await container.read(misplacedLogbookProvider.future);
      if (until(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('misplacedLogbookProvider never settled');
  }

  test(
    'names the profile holding the dives when the active one is empty',
    () async {
      await insertDiver('empty');
      await insertDiver('main');
      await insertDive('d1', 'main');
      await insertDive('d2', 'main');
      final container = await containerWithActive('empty');

      final found = await settle(container, (v) => v != null);

      expect(found!.target.id, 'main');
      expect(found.targetDiveCount, 2);
    },
  );

  test('keep both hides the pair and survives a restart', () async {
    await insertDiver('empty');
    await insertDiver('main');
    await insertDive('d1', 'main');
    final container = await containerWithActive('empty');
    await settle(container, (v) => v != null);

    await container
        .read(misplacedLogbookKeptBothProvider.notifier)
        .keepBoth('empty', 'main');

    expect(await settle(container, (v) => v == null), isNull);

    final restarted = await containerWithActive('empty');
    expect(await settle(restarted, (_) => true), isNull);
  });

  test('clears once the active profile gains a dive', () async {
    await insertDiver('empty');
    await insertDiver('main');
    await insertDive('d1', 'main');
    final container = await containerWithActive('empty');
    await settle(container, (v) => v != null);

    await insertDive('d2', 'empty');

    expect(await settle(container, (v) => v == null), isNull);
  });
}
