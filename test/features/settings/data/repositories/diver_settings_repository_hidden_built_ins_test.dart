import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// diver_settings.hidden_built_in_ids round trip (issue #401).
void main() {
  late DiverSettingsRepository repository;

  Future<void> insertDiver(String id) =>
      DatabaseService.instance.database.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('$id', '$id', 1000, 1000)",
      );

  setUp(() async {
    await setUpTestDatabase();
    await insertDiver('d1');
    await insertDiver('d2');
    repository = DiverSettingsRepository();
  });

  tearDown(tearDownTestDatabase);

  test('a new diver hides nothing', () async {
    await repository.createSettingsForDiver('d1');
    final settings = await repository.getSettingsForDiver('d1');
    expect(settings!.hiddenBuiltInIds, isEmpty);
    expect(settings.hiddenBuiltIns(BuiltInCatalog.diveTypes), isEmpty);
  });

  test('create and update round trip the hidden sets', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(
        hiddenBuiltInIds: {
          'diveRoles': {'solo'},
        },
      ),
    );
    var settings = await repository.getSettingsForDiver('d1');
    expect(settings!.hiddenBuiltIns(BuiltInCatalog.diveRoles), {'solo'});

    final updated = settings.copyWith(
      hiddenBuiltInIds: {
        'diveRoles': {'solo'},
        'siteTypes': {'lake', 'quarry'},
        'futureKind': {'x'},
      },
    );
    await repository.updateSettingsForDiver('d1', updated, previous: settings);
    settings = await repository.getSettingsForDiver('d1');
    expect(settings!.hiddenBuiltInIds, {
      'diveRoles': {'solo'},
      'siteTypes': {'lake', 'quarry'},
      'futureKind': {'x'},
    });
  });

  test('hidden sets are per diver', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(
        hiddenBuiltInIds: {
          'diveTypes': {'night'},
        },
      ),
    );
    await repository.createSettingsForDiver('d2');
    expect(
      (await repository.getSettingsForDiver('d2'))!.hiddenBuiltInIds,
      isEmpty,
    );
  });

  test('the same contents in another order store the same settings', () {
    expect(
      DiverSettingsRepository.storesSameSettings(
        const AppSettings(
          hiddenBuiltInIds: {
            'siteTypes': {'wall', 'lake'},
            'diveRoles': {'solo'},
          },
        ),
        const AppSettings(
          hiddenBuiltInIds: {
            'diveRoles': {'solo'},
            'siteTypes': {'lake', 'wall'},
          },
        ),
      ),
      isTrue,
    );
  });
}
