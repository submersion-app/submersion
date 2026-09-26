import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A payload built by a source that fetches rather than parses (divelogs.de).
const _payload = ImportPayload(
  entities: {
    ImportEntityType.dives: [
      {'sourceUuid': 'divelogs-1', 'maxDepth': 12.0},
    ],
    ImportEntityType.sites: [
      {'uddfId': 'divelogs-site-reef', 'name': 'Reef'},
    ],
  },
);

void main() {
  late ProviderContainer container;
  late UniversalImportNotifier notifier;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(const AppSettings()),
        ),
      ],
    );
    notifier = container.read(universalImportNotifierProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('installs the payload with every row selected', () async {
    await notifier.setExternalPayload(_payload, remotePhotoCount: 3);

    final state = container.read(universalImportNotifierProvider);
    expect(state.payload!.entitiesOf(ImportEntityType.dives), hasLength(1));
    expect(state.selectionFor(ImportEntityType.dives), {0});
    expect(state.selectionFor(ImportEntityType.sites), {0});
    expect(state.duplicateResult, isNotNull);
    expect(state.remotePhotoCount, 3);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
  });

  test('clears photo decisions left by an earlier import', () async {
    notifier.skipPhotos();

    await notifier.setExternalPayload(_payload, remotePhotoCount: 2);

    final state = container.read(universalImportNotifierProvider);
    expect(state.photosSkipped, isFalse);
    expect(state.bundledPhotoFolderPath, isNull);
    expect(state.photoResolution, isNull);
    expect(state.photoPathsByBaseName, isEmpty);
  });

  test('reset forgets the remote photo count', () async {
    await notifier.setExternalPayload(_payload, remotePhotoCount: 2);

    notifier.reset();

    expect(container.read(universalImportNotifierProvider).remotePhotoCount, 0);
  });
}
