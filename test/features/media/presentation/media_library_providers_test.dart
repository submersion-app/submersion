import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

MediaLibraryEntry entry(String id) => MediaLibraryEntry(
  item: MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id',
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  ),
);

class _FakeLibraryRepo implements MediaLibraryRepository {
  int pageCalls = 0;
  MediaLibraryFilter? lastFilter;
  String? lastDiverId;
  final changes = StreamController<void>.broadcast();

  @override
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    MediaLibraryCursor? after,
    int limit = 60,
  }) async {
    pageCalls++;
    lastFilter = filter;
    lastDiverId = diverId;
    if (after == null) {
      return MediaLibraryPageResult(
        entries: [entry('a'), entry('b')],
        nextCursor: const MediaLibraryCursor(sortKey: 100, id: 'b'),
      );
    }
    return MediaLibraryPageResult(entries: [entry('c')]);
  }

  @override
  Future<int> countUnlinked() async => 4;

  @override
  Future<int> countMissing() async => 9;

  @override
  Stream<void> watchMediaChanges() => changes.stream;

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
  final Map<String, String> values = {};

  @override
  Future<String?> getRawSetting(String key) async => values[key];

  @override
  Future<void> setRawSetting(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late _FakeLibraryRepo fakeRepo;
  late _FakeSettingsRepo fakeSettings;
  late ProviderContainer container;

  ProviderContainer buildContainer() => ProviderContainer(
    overrides: [
      mediaLibraryRepositoryProvider.overrideWithValue(fakeRepo),
      appSettingsRepositoryProvider.overrideWithValue(fakeSettings),
      currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
    ],
  );

  setUp(() {
    fakeRepo = _FakeLibraryRepo();
    fakeSettings = _FakeSettingsRepo();
    container = buildContainer();
    addTearDown(container.dispose);
    addTearDown(fakeRepo.changes.close);
  });

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('loadFirstPage then loadMore accumulates entries', () async {
    final notifier = container.read(mediaLibraryNotifierProvider.notifier);
    await notifier.loadFirstPage();
    expect(container.read(mediaLibraryNotifierProvider).entries, hasLength(2));
    expect(fakeRepo.lastDiverId, 'd1');

    await notifier.loadMore();
    final state = container.read(mediaLibraryNotifierProvider);
    expect(state.entries, hasLength(3));
    expect(state.nextCursor, isNull);
  });

  test('loadMore is a no-op at end of data', () async {
    final notifier = container.read(mediaLibraryNotifierProvider.notifier);
    await notifier.loadFirstPage();
    await notifier.loadMore();
    final callsAfterEnd = fakeRepo.pageCalls;
    await notifier.loadMore();
    expect(fakeRepo.pageCalls, callsAfterEnd);
  });

  test('changing the filter reloads page one with the new filter', () async {
    await container.read(mediaLibraryNotifierProvider.notifier).loadFirstPage();
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.video);
    await tick();
    // The provider rebuilds with the new filter and auto-loads page one.
    container.read(mediaLibraryNotifierProvider);
    await tick();
    expect(fakeRepo.lastFilter?.mediaType, MediaType.video);
  });

  test('media change stream triggers a refresh', () async {
    final notifier = container.read(mediaLibraryNotifierProvider.notifier);
    await notifier.loadFirstPage();
    final before = fakeRepo.pageCalls;
    fakeRepo.changes.add(null);
    await tick();
    expect(fakeRepo.pageCalls, greaterThan(before));
  });

  test('view mode defaults to grid and persists on change', () async {
    expect(
      container.read(mediaLibraryViewModeProvider),
      MediaLibraryViewMode.grid,
    );
    await container
        .read(mediaLibraryViewModeProvider.notifier)
        .setMode(MediaLibraryViewMode.timeline);
    expect(fakeSettings.values['media_library_view_mode'], 'timeline');
  });

  test('view mode primes from the stored setting', () async {
    fakeSettings.values['media_library_view_mode'] = 'byDive';
    final fresh = buildContainer();
    addTearDown(fresh.dispose);
    fresh.read(mediaLibraryViewModeProvider);
    await tick();
    expect(
      fresh.read(mediaLibraryViewModeProvider),
      MediaLibraryViewMode.byDive,
    );
  });

  test('count providers read the repository', () async {
    expect(await container.read(unlinkedCountProvider.future), 4);
    expect(await container.read(missingCountProvider.future), 9);
  });
}
