import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_library_sort.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _FakeSettingsRepo extends AppSettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> getRawSetting(String key) async => values[key];

  @override
  Future<void> setRawSetting(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late _FakeSettingsRepo settings;

  ProviderContainer buildContainer() => ProviderContainer(
    overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
  );

  setUp(() => settings = _FakeSettingsRepo());

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  group('encode and decode', () {
    test('round-trips every field and direction', () {
      for (final field in MediaSortField.values) {
        for (final direction in SortDirection.values) {
          final sort = SortState(field: field, direction: direction);
          expect(decodeMediaSort(encodeMediaSort(sort)), sort);
        }
      }
    });

    test('returns null for malformed or unknown values', () {
      // A value written by a newer build, or a corrupted setting, must not
      // throw and take the library down with it.
      expect(decodeMediaSort(''), isNull);
      expect(decodeMediaSort('dateTaken'), isNull);
      expect(decodeMediaSort('dateTaken:sideways'), isNull);
      expect(decodeMediaSort('shutterCount:ascending'), isNull);
      expect(decodeMediaSort('a:b:c'), isNull);
    });
  });

  group('MediaLibrarySortNotifier', () {
    test('starts at date descending before anything is loaded', () {
      final container = buildContainer();
      addTearDown(container.dispose);

      expect(container.read(mediaLibrarySortProvider), kDefaultMediaSort);
      expect(kDefaultMediaSort.field, MediaSortField.dateTaken);
      expect(kDefaultMediaSort.direction, SortDirection.descending);
    });

    test('primes from the persisted setting', () async {
      settings.values[MediaLibrarySortNotifier.settingKey] =
          'fileName:ascending';
      final container = buildContainer();
      addTearDown(container.dispose);

      container.read(mediaLibrarySortProvider);
      await tick();

      expect(
        container.read(mediaLibrarySortProvider),
        const SortState(
          field: MediaSortField.fileName,
          direction: SortDirection.ascending,
        ),
      );
    });

    test('keeps the default when the persisted value is unreadable', () async {
      settings.values[MediaLibrarySortNotifier.settingKey] = 'garbage';
      final container = buildContainer();
      addTearDown(container.dispose);

      container.read(mediaLibrarySortProvider);
      await tick();

      expect(container.read(mediaLibrarySortProvider), kDefaultMediaSort);
    });

    test('setSort updates state and persists it', () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      await container
          .read(mediaLibrarySortProvider.notifier)
          .setSort(MediaSortField.fileSize, SortDirection.ascending);

      expect(
        container.read(mediaLibrarySortProvider),
        const SortState(
          field: MediaSortField.fileSize,
          direction: SortDirection.ascending,
        ),
      );
      expect(
        settings.values[MediaLibrarySortNotifier.settingKey],
        'fileSize:ascending',
      );
    });
  });
}
