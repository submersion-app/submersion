import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_map_providers.dart';

MediaMapPoint _point(String id) => MediaMapPoint(
  entry: MediaLibraryEntry(
    item: MediaItem(
      id: id,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      filePath: p.join('media', id),
      takenAt: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    ),
  ),
  point: const LatLng(1, 2),
  placement: MediaPlacement.ownGps,
);

class _FakeMapRepo implements MediaLibraryRepository {
  final changes = StreamController<void>.broadcast();
  List<MediaMapPoint> points = [];
  int total = 0;
  int loads = 0;
  Object? failWith;
  MediaLibraryFilter? lastFilter;
  String? lastDiverId;

  @override
  Future<List<MediaMapPoint>> getMapPoints({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async {
    loads++;
    lastFilter = filter;
    lastDiverId = diverId;
    final error = failWith;
    if (error != null) throw error;
    return points;
  }

  @override
  Future<int> countInScope({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async => total;

  @override
  Stream<void> watchMapChanges() => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Each getMapPoints call parks on its own completer so a test decides the
/// order in which overlapping loads finish.
class _GatedMapRepo implements MediaLibraryRepository {
  final changes = StreamController<void>.broadcast();
  final pending = <Completer<List<MediaMapPoint>>>[];

  @override
  Future<List<MediaMapPoint>> getMapPoints({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) {
    final gate = Completer<List<MediaMapPoint>>();
    pending.add(gate);
    return gate.future;
  }

  @override
  Future<int> countInScope({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
  }) async => 0;

  @override
  Stream<void> watchMapChanges() => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverIdNotifier() : super('d1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeMapRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeMapRepo();
    container = ProviderContainer(
      overrides: [
        mediaLibraryRepositoryProvider.overrideWithValue(repo),
        currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.changes.close);
  });

  /// Builds the notifier (which starts its first load) and keeps it alive:
  /// autoDispose would otherwise drop it between reads. Called after each
  /// test seeds the fake, so the first load sees the seeded rows.
  Future<void> start() async {
    container.listen(mediaMapPointsProvider, (_, _) {});
    await _settle();
    await _settle();
  }

  test('loads points and derives the unlocated count', () async {
    repo.points = [_point('a'), _point('b')];
    repo.total = 5;

    await start();

    final state = container.read(mediaMapPointsProvider);
    expect(state.isLoading, isFalse);
    expect(state.points.map((p) => p.item.id), ['a', 'b']);
    expect(state.unlocatedCount, 3);
    expect(repo.lastDiverId, 'd1');
    expect(repo.lastFilter, MediaLibraryFilter.none);
  });

  test('reloads on the map change tick', () async {
    await start();
    expect(repo.loads, 1);

    repo.points = [_point('c')];
    repo.changes.add(null);
    await _settle();
    await _settle();

    expect(repo.loads, 2);
    expect(
      container.read(mediaMapPointsProvider).points.map((p) => p.item.id),
      ['c'],
    );
  });

  test('a failed load surfaces the error and keeps the last points', () async {
    repo.points = [_point('a')];
    await start();

    repo.failWith = StateError('boom');
    repo.changes.add(null);
    await _settle();
    await _settle();

    final state = container.read(mediaMapPointsProvider);
    expect(state.error, isA<StateError>());
    expect(state.points.map((p) => p.item.id), ['a']);
    expect(state.isLoading, isFalse);
  });

  test('a filter change rebuilds the notifier with the new filter', () async {
    await start();

    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.video);
    await _settle();
    await _settle();

    expect(repo.lastFilter?.mediaType, MediaType.video);
  });

  test('the unlocated count never goes negative', () async {
    repo.points = [_point('a')];
    repo.total = 0;
    await start();

    expect(container.read(mediaMapPointsProvider).unlocatedCount, 0);
  });

  test(
    'a reload that returns the same points keeps the list instance',
    () async {
      repo.points = [_point('a'), _point('b')];
      await start();
      final before = container.read(mediaMapPointsProvider).points;

      repo.points = [_point('a'), _point('b')];
      repo.changes.add(null);
      await _settle();
      await _settle();

      expect(
        identical(container.read(mediaMapPointsProvider).points, before),
        isTrue,
      );
    },
  );

  test('a favorite toggle is a change, not an equal reload', () async {
    repo.points = [_point('a')];
    await start();
    final before = container.read(mediaMapPointsProvider).points;

    final fav = _point('a');
    repo.points = [
      MediaMapPoint(
        entry: MediaLibraryEntry(item: fav.item.copyWith(isFavorite: true)),
        point: fav.point,
        placement: fav.placement,
      ),
    ];
    repo.changes.add(null);
    await _settle();
    await _settle();

    final after = container.read(mediaMapPointsProvider).points;
    expect(identical(after, before), isFalse);
    expect(after.single.item.isFavorite, isTrue);
  });

  test(
    'an older load that finishes last does not overwrite a newer one',
    () async {
      final gated = _GatedMapRepo();
      addTearDown(gated.changes.close);
      final c = ProviderContainer(
        overrides: [
          mediaLibraryRepositoryProvider.overrideWithValue(gated),
          currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
        ],
      );
      addTearDown(c.dispose);
      c.listen(mediaMapPointsProvider, (_, _) {});
      await _settle();

      // The initial load is pending; a tick starts a second, newer one.
      gated.changes.add(null);
      await _settle();
      expect(gated.pending, hasLength(2));

      gated.pending[1].complete([_point('new')]);
      await _settle();
      await _settle();
      gated.pending[0].complete([_point('old')]);
      await _settle();
      await _settle();

      expect(c.read(mediaMapPointsProvider).points.map((p) => p.item.id), [
        'new',
      ]);
    },
  );

  test('an older load that fails last does not replace newer points with its '
      'error', () async {
    final gated = _GatedMapRepo();
    addTearDown(gated.changes.close);
    final c = ProviderContainer(
      overrides: [
        mediaLibraryRepositoryProvider.overrideWithValue(gated),
        currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
      ],
    );
    addTearDown(c.dispose);
    c.listen(mediaMapPointsProvider, (_, _) {});
    await _settle();
    gated.changes.add(null);
    await _settle();

    gated.pending[1].complete([_point('new')]);
    await _settle();
    await _settle();
    gated.pending[0].completeError(StateError('stale failure'));
    await _settle();
    await _settle();

    final state = c.read(mediaMapPointsProvider);
    expect(state.error, isNull);
    expect(state.points.map((p) => p.item.id), ['new']);
  });

  test('MediaMapState.copyWith replaces only what it is given, and keeps or '
      'clears the error on request', () {
    final base = MediaMapState(
      points: [_point('a')],
      unlocatedCount: 2,
      error: StateError('x'),
    );

    final loading = base.copyWith(isLoading: true);
    expect(loading.isLoading, isTrue);
    expect(loading.points, same(base.points));
    expect(loading.unlocatedCount, 2);
    expect(loading.error, same(base.error));

    final cleared = base.copyWith(clearError: true, unlocatedCount: 5);
    expect(cleared.error, isNull);
    expect(cleared.unlocatedCount, 5);
    expect(cleared.isLoading, isFalse);
  });

  test('a reload that only stamps media-store uploads delivers the fresh '
      'item', () async {
    repo.points = [_point('a')];
    await start();
    final before = container.read(mediaMapPointsProvider).points;

    final stamped = _point('a');
    repo.points = [
      MediaMapPoint(
        entry: MediaLibraryEntry(
          item: stamped.item.copyWith(
            remoteUploadedAt: DateTime.utc(2026, 9, 25),
            updatedAt: DateTime.utc(2026, 9, 25, 12),
          ),
        ),
        point: stamped.point,
        placement: stamped.placement,
      ),
    ];
    repo.changes.add(null);
    await _settle();
    await _settle();

    final after = container.read(mediaMapPointsProvider).points;
    expect(identical(after, before), isFalse);
    expect(after.single.item.remoteUploadedAt, DateTime.utc(2026, 9, 25));
  });
}
