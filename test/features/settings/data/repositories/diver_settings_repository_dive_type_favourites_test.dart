import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// diver_settings.favourite_dive_type_ids round trip (issue #4413).
void main() {
  late DiverSettingsRepository repository;

  Future<void> insertDiver(String id) =>
      DatabaseService.instance.database.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('$id', '$id', 1000, 1000)",
      );

  Future<void> storeRaw(String diverId, String raw) =>
      DatabaseService.instance.database.customStatement(
        'UPDATE diver_settings SET favourite_dive_type_ids = ? '
        'WHERE diver_id = ?',
        [raw, diverId],
      );

  setUp(() async {
    await setUpTestDatabase();
    await insertDiver('d1');
    await insertDiver('d2');
    repository = DiverSettingsRepository();
  });

  tearDown(tearDownTestDatabase);

  test('a new diver has no favourites', () async {
    await repository.createSettingsForDiver('d1');
    final settings = await repository.getSettingsForDiver('d1');
    expect(settings!.favouriteDiveTypeIds, isEmpty);
  });

  test('create and update round trip the favourites', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(favouriteDiveTypeIds: {'shore'}),
    );
    var settings = await repository.getSettingsForDiver('d1');
    expect(settings!.favouriteDiveTypeIds, {'shore'});

    final updated = settings.copyWith(favouriteDiveTypeIds: {'shore', 'dry'});
    await repository.updateSettingsForDiver('d1', updated, previous: settings);
    settings = await repository.getSettingsForDiver('d1');
    expect(settings!.favouriteDiveTypeIds, {'shore', 'dry'});
  });

  test('favourites are per diver', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: const AppSettings(favouriteDiveTypeIds: {'night'}),
    );
    await repository.createSettingsForDiver('d2');
    expect(
      (await repository.getSettingsForDiver('d2'))!.favouriteDiveTypeIds,
      isEmpty,
    );
    expect((await repository.getSettingsForDiver('d1'))!.favouriteDiveTypeIds, {
      'night',
    });
  });

  test('a malformed stored value reads as no favourites', () async {
    await repository.createSettingsForDiver('d1');
    await storeRaw('d1', 'not json');
    expect(
      (await repository.getSettingsForDiver('d1'))!.favouriteDiveTypeIds,
      isEmpty,
    );
    await storeRaw('d1', '{"a":1}');
    expect(
      (await repository.getSettingsForDiver('d1'))!.favouriteDiveTypeIds,
      isEmpty,
    );
  });

  test('the same favourites in another order store the same settings', () {
    expect(
      DiverSettingsRepository.storesSameSettings(
        const AppSettings(favouriteDiveTypeIds: {'wreck', 'cave'}),
        const AppSettings(favouriteDiveTypeIds: {'cave', 'wreck'}),
      ),
      isTrue,
    );
    expect(
      DiverSettingsRepository.storesSameSettings(
        const AppSettings(favouriteDiveTypeIds: {'wreck'}),
        const AppSettings(),
      ),
      isFalse,
    );
  });
}
