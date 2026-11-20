import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_library_grouping.dart';
import 'package:submersion/features/media/domain/entities/media_library_sort.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_scoped_gallery_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _FakeLibraryRepo implements MediaLibraryRepository {
  final List<(MediaLibraryFilter, MediaLibraryGrouping)> reads = [];
  final changes = StreamController<void>.broadcast();

  @override
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    SortState<MediaSortField> sort = kDefaultMediaSort,
    MediaLibraryGrouping grouping = MediaLibraryGrouping.none,
    MediaLibraryCursor? after,
    int limit = 60,
  }) async {
    reads.add((filter, grouping));
    return MediaLibraryPageResult(
      entries: [
        MediaLibraryEntry(
          item: MediaItem(
            id: 'p1',
            mediaType: MediaType.photo,
            sourceType: MediaSourceType.localFile,
            filePath: 'p1.jpg',
            takenAt: DateTime(2026, 6, 1),
            createdAt: DateTime(2026, 6, 1),
            updatedAt: DateTime(2026, 6, 1),
          ),
        ),
      ],
    );
  }

  @override
  Stream<void> watchLibraryChanges() => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverIdNotifier() : super('d1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsRepo extends AppSettingsRepository {
  @override
  Future<String?> getRawSetting(String key) async => null;

  @override
  Future<void> setRawSetting(String key, String value) async {}
}

/// The focused gallery a detail card opens (issue #4741) pages through its
/// own scope, apart from the Media screen's filter and view.
void main() {
  late _FakeLibraryRepo repo;
  late ProviderContainer container;

  const sitePhotos = MediaLibraryFilter(
    siteId: 's1',
    attachedTo: {MediaAttachmentKind.dive},
  );

  setUp(() {
    repo = _FakeLibraryRepo();
    container = ProviderContainer(
      overrides: [
        mediaLibraryRepositoryProvider.overrideWithValue(repo),
        appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
        currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.changes.close);
  });

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('pages with its own filter and its view\'s grouping', () async {
    const scope = MediaGalleryScope(
      filter: sitePhotos,
      mode: MediaLibraryViewMode.byDive,
    );
    final sub = container.listen(mediaScopedLibraryProvider(scope), (_, _) {});
    addTearDown(sub.close);
    await tick();

    expect(repo.reads.single.$1, sitePhotos);
    expect(repo.reads.single.$2, MediaLibraryGrouping.dive);
    expect(sub.read().entries.single.item.id, 'p1');
  });

  test('the Media screen\'s filter neither reaches nor rebuilds it', () async {
    const scope = MediaGalleryScope(filter: sitePhotos);
    final sub = container.listen(mediaScopedLibraryProvider(scope), (_, _) {});
    addTearDown(sub.close);
    await tick();
    final before = container.read(mediaScopedLibraryProvider(scope).notifier);

    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(tagIds: {'wreck'});
    await tick();

    expect(
      container.read(mediaScopedLibraryProvider(scope).notifier),
      same(before),
    );
    expect(repo.reads, hasLength(1));
    expect(container.read(mediaLibraryFilterProvider).siteId, isNull);
  });

  test('scopes compare by value, so one gallery shares one walk', () {
    expect(
      const MediaGalleryScope(filter: sitePhotos),
      const MediaGalleryScope(filter: sitePhotos),
    );
    expect(
      const MediaGalleryScope(filter: sitePhotos),
      isNot(
        const MediaGalleryScope(
          filter: sitePhotos,
          mode: MediaLibraryViewMode.timeline,
        ),
      ),
    );
  });
}
