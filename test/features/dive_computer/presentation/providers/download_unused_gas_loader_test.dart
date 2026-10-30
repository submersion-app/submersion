import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The loader `diveImportServiceProvider` hands to `DiveImportService` for
/// the skip-unused-bailout-gases switch (issue #3668): the switch of the
/// diver the download is filed under.
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

  Future<bool> load({
    AppSettings active = const AppSettings(),
    String? diverId,
    String? activeDiverId,
    DiverSettingsRepository? repository,
  }) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(active)),
        validatedCurrentDiverIdProvider.overrideWith(
          (ref) async => activeDiverId,
        ),
        if (repository != null)
          diverSettingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final probe = FutureProvider<bool>(
      (ref) => loadOmitUnusedOcGasesForDownloads(ref, diverId: diverId),
    );
    return container.read(probe.future);
  }

  Future<void> addDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: id,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('reads the live setting for the active diver', () async {
    expect(
      await load(active: const AppSettings(omitUnusedOcGases: true)),
      isTrue,
    );
    expect(await load(), isFalse);
  });

  test("reads another diver's saved setting, not the active diver's", () async {
    await addDiver('mitchell');
    await DiverSettingsRepository().createSettingsForDiver(
      'mitchell',
      settings: const AppSettings(omitUnusedOcGases: true),
    );

    expect(await load(diverId: 'mitchell', activeDiverId: 'bill'), isTrue);
  });

  test('a diver with no saved settings gets the default (off)', () async {
    await addDiver('mitchell');

    expect(
      await load(
        active: const AppSettings(omitUnusedOcGases: true),
        diverId: 'mitchell',
      ),
      isFalse,
    );
  });

  test('an unreadable settings row means off, not a failed import', () async {
    expect(
      await load(
        active: const AppSettings(omitUnusedOcGases: true),
        diverId: 'mitchell',
        repository: _ThrowingSettingsRepository(),
      ),
      isFalse,
    );
  });
}

class _ThrowingSettingsRepository extends DiverSettingsRepository {
  @override
  Future<AppSettings?> getSettingsForDiver(String diverId) async =>
      throw StateError('database is locked');
}
