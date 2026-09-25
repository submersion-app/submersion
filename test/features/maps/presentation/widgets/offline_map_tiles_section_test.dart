import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/maps/data/repositories/offline_map_repository.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/cached_region.dart';
import 'package:submersion/features/maps/presentation/pages/region_picker_page.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/offline_map_tiles_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

CachedRegion _region({required String id, required String name}) =>
    CachedRegion(
      id: id,
      name: name,
      minLat: 20,
      maxLat: 21,
      minLng: -87,
      maxLng: -86,
      minZoom: 8,
      maxZoom: 12,
      tileCount: 900,
      // What a legacy row holds: 900 tiles times a flat 20 KiB, a number that
      // never read the tile cache.
      sizeBytes: 900 * 20 * 1024,
      createdAt: DateTime(2026, 1, 1),
      lastAccessedAt: DateTime(2026, 1, 2),
    );

/// A repository backed by a list, so the page's delete path can run without a
/// database. Only the members the page reaches are implemented.
class _FakeRepository implements OfflineMapRepository {
  _FakeRepository(this.regions);
  List<CachedRegion> regions;

  @override
  Future<List<CachedRegion>> getAllRegions() async => regions;

  @override
  Future<void> deleteRegion(String id) async {
    regions = regions.where((r) => r.id != id).toList();
  }

  @override
  Stream<void> watchRegionsChanges() => const Stream<void>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// A tile cache that cannot say which regions own their tiles, which must read
/// as unprovable rather than as proven either way.
class _UnreadableTileCache implements TileCacheService {
  @override
  Future<Set<String>> getRegionStoreIds() async =>
      throw StateError('tile cache unavailable');

  @override
  Future<void> deleteRegionTiles(String regionId) async {}

  @override
  Future<int> pruneOrphanRegionStores({
    required Future<Set<String>> Function() readKnownRegionIds,
  }) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// A tile cache whose tile removal fails, which is the case the page has to
/// report rather than silently leave the region in place.
class _FailingTileCache implements TileCacheService {
  @override
  Future<void> deleteRegionTiles(String regionId) async =>
      throw StateError('store is locked');

  @override
  Future<void> cancelDownload() async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<Set<String>> getRegionStoreIds() async => {'owns'};

  @override
  Future<int> pruneOrphanRegionStores({
    required Future<Set<String>> Function() readKnownRegionIds,
  }) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// A tile cache whose orphan sweep reclaims stores, which is the one case in
/// which the section has to re-read the statistics it already showed.
class _SweepingTileCache extends _UnreadableTileCache {
  @override
  Future<int> pruneOrphanRegionStores({
    required Future<Set<String>> Function() readKnownRegionIds,
  }) async => 2;
}

/// A download notifier frozen mid-download, so the progress card can be
/// inspected without a tile server, and whose cancel is only recorded.
class _FakeDownloadNotifier extends DownloadProgressNotifier {
  _FakeDownloadNotifier(Ref ref, DownloadState initial)
    : super(_UnreadableTileCache(), _FakeRepository(const []), ref) {
    state = initial;
  }

  int cancelCalls = 0;

  @override
  Future<void> cancelDownload() async => cancelCalls++;
}

const _stats = CacheStats(tileCount: 900, sizeKiB: 8000, hits: 10, misses: 2);

/// The section lives inside the Offline Maps page's scroll view, so the test
/// hosts it the same way rather than giving it a page of its own.
const _host = Scaffold(
  body: SingleChildScrollView(child: OfflineMapTilesSection()),
);

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    required List<CachedRegion> regions,
    required Set<String> regionStoreIds,
  }) async {
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          cachedRegionsProvider.overrideWith((ref) async => regions),
          regionStoreIdsProvider.overrideWith((ref) async => regionStoreIds),
          cacheStatsProvider.overrideWith(
            (ref) async => const CacheStats(
              tileCount: 900,
              sizeKiB: 8000,
              hits: 10,
              misses: 2,
            ),
          ),
        ],
        child: const MaterialApp(
          // flutter_test forwards the host machine's locale list rather than a
          // fixed en_US, and this app supports 11 locales, so an unpinned
          // MaterialApp renders in the contributor's own language and every
          // English assertion below misses.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _host,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpWithOverrides(
    WidgetTester tester,
    List<Override> overrides,
  ) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...base, ...overrides],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _host,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders its header and both tile actions', (tester) async {
    await pumpSection(
      tester,
      regions: [_region(id: 'owns', name: 'Cozumel')],
      regionStoreIds: {'owns'},
    );

    expect(find.text('Map tiles'), findsOneWidget);
    expect(find.text('Download new region'), findsOneWidget);
    expect(find.text('Clear all map tiles'), findsOneWidget);
  });

  testWidgets('a region that owns its tiles shows its measured size', (
    tester,
  ) async {
    await pumpSection(
      tester,
      regions: [_region(id: 'owns', name: 'Cozumel')],
      regionStoreIds: {'owns'},
    );

    expect(find.textContaining('17.6 MB'), findsWidgets);
  });

  testWidgets('a region whose size was never measured says so', (tester) async {
    // Issue #1403: the stored size is a flat 20 KiB per tile that has never
    // read the store, so rendering it as a byte figure is a fabrication that
    // looks authoritative.
    await pumpSection(
      tester,
      regions: [_region(id: 'legacy', name: 'Bonaire')],
      regionStoreIds: const {},
    );

    expect(find.textContaining('17.6 MB'), findsNothing);
    expect(find.textContaining('Unknown'), findsWidgets);
  });

  testWidgets('the delete prompt does not promise bytes it cannot free', (
    tester,
  ) async {
    await pumpSection(
      tester,
      regions: [_region(id: 'legacy', name: 'Bonaire')],
      regionStoreIds: const {},
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('will not reclaim storage'), findsOneWidget);
    expect(find.textContaining('free up'), findsNothing);
  });

  testWidgets('a delete that could not free the tiles says so', (tester) async {
    // The region stays in the list on purpose, so the bytes stay reachable.
    // Without a message that reads as the delete button doing nothing, which
    // is the failure mode this whole issue is about.
    final base = await getBaseOverrides();
    final repository = _FakeRepository([_region(id: 'owns', name: 'Cozumel')]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          offlineMapRepositoryProvider.overrideWithValue(repository),
          tileCacheServiceProvider.overrideWithValue(_FailingTileCache()),
          cacheStatsProvider.overrideWith(
            (ref) async => const CacheStats(
              tileCount: 900,
              sizeKiB: 8000,
              hits: 10,
              misses: 2,
            ),
          ),
        ],
        child: const MaterialApp(
          // flutter_test forwards the host machine's locale list rather than a
          // fixed en_US, and this app supports 11 locales, so an unpinned
          // MaterialApp renders in the contributor's own language and every
          // English assertion below misses.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _host,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('store is locked'), findsOneWidget);
    expect(repository.regions, hasLength(1));
  });

  testWidgets('a clear that could not free everything says so', (tester) async {
    // Clearing one region at a time means a locked store leaves that region
    // behind while the rest go. Without a message the diver reads that as
    // "Clear all" quietly refusing to clear all.
    final base = await getBaseOverrides();
    final repository = _FakeRepository([_region(id: 'owns', name: 'Cozumel')]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          offlineMapRepositoryProvider.overrideWithValue(repository),
          tileCacheServiceProvider.overrideWithValue(_FailingTileCache()),
          cacheStatsProvider.overrideWith(
            (ref) async => const CacheStats(
              tileCount: 900,
              sizeKiB: 8000,
              hits: 10,
              misses: 2,
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _host,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The action sits below the region list, off the default test surface.
    await tester.ensureVisible(find.text('Clear all map tiles'));
    await tester.pump();
    await tester.tap(find.text('Clear all map tiles'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Clear All'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('store is locked'), findsOneWidget);
    expect(repository.regions, hasLength(1));
  });

  testWidgets('the details sheet shows the same resolved size as the list', (
    tester,
  ) async {
    // The sheet is the second place a size is rendered, so a regression there
    // would put the fabricated figure back in front of the diver.
    await pumpSection(
      tester,
      regions: [_region(id: 'legacy', name: 'Bonaire')],
      regionStoreIds: const {},
    );

    await tester.tap(find.text('Bonaire'));
    await tester.pump();
    await tester.pump();

    // The bounds block only exists in the sheet, so this proves it opened
    // rather than matching the list tile behind it.
    expect(find.textContaining('SW:'), findsOneWidget);
    expect(find.textContaining('17.6 MB'), findsNothing);
    expect(find.textContaining('Unknown'), findsWidgets);
  });

  testWidgets('a cache that cannot be read promises nothing', (tester) async {
    // Unprovable is not the same as reclaimable: the prompt must not offer
    // bytes back on the strength of a lookup that failed.
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          cachedRegionsProvider.overrideWith(
            (ref) async => [_region(id: 'owns', name: 'Cozumel')],
          ),
          tileCacheServiceProvider.overrideWithValue(_UnreadableTileCache()),
          cacheStatsProvider.overrideWith(
            (ref) async => const CacheStats(
              tileCount: 900,
              sizeKiB: 8000,
              hits: 10,
              misses: 2,
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _host,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Unknown'), findsWidgets);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('will not reclaim storage'), findsOneWidget);
    expect(find.textContaining('free up'), findsNothing);
  });

  testWidgets('a size still being measured is not reported as unknown', (
    tester,
  ) async {
    // The transient state is its own answer. Showing "Unknown" here would be a
    // claim the app is about to contradict, and a bare ellipsis is neither
    // localized nor meaningful read aloud.
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          cachedRegionsProvider.overrideWith(
            (ref) async => [_region(id: 'owns', name: 'Cozumel')],
          ),
          // Never completes, so the page stays in the measuring state.
          regionStoreIdsProvider.overrideWith(
            (ref) => Completer<Set<String>>().future,
          ),
          cacheStatsProvider.overrideWith(
            (ref) async => const CacheStats(
              tileCount: 900,
              sizeKiB: 8000,
              hits: 10,
              misses: 2,
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _host,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Loading'), findsWidgets);
    expect(find.textContaining('Unknown'), findsNothing);
    expect(find.textContaining('17.6 MB'), findsNothing);
  });

  testWidgets('a running download shows its progress and can be cancelled', (
    tester,
  ) async {
    late _FakeDownloadNotifier notifier;
    await pumpWithOverrides(tester, [
      cachedRegionsProvider.overrideWith((ref) async => const []),
      regionStoreIdsProvider.overrideWith((ref) async => const <String>{}),
      cacheStatsProvider.overrideWith((ref) async => _stats),
      downloadProgressProvider.overrideWith(
        (ref) => notifier = _FakeDownloadNotifier(
          ref,
          const DownloadState(
            isDownloading: true,
            progress: 45,
            downloadedTiles: 450,
            totalTiles: 1000,
            failedTiles: 3,
            tilesPerSecond: 2.5,
            regionName: 'Cozumel',
          ),
        ),
      ),
    ]);

    expect(find.text('Downloading: Cozumel'), findsOneWidget);
    expect(find.text('45.0%'), findsOneWidget);
    expect(find.text('450 / 1000 tiles'), findsOneWidget);
    expect(find.text('2.5 tiles/sec'), findsOneWidget);
    expect(find.text('3 failed'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel Download'));
    await tester.pump();

    expect(notifier.cancelCalls, 1);
  });

  testWidgets('statistics that cannot be read say why', (tester) async {
    await pumpWithOverrides(tester, [
      cachedRegionsProvider.overrideWith((ref) async => const []),
      regionStoreIdsProvider.overrideWith((ref) async => const <String>{}),
      cacheStatsProvider.overrideWith(
        (ref) async => throw StateError('stats unavailable'),
      ),
    ]);

    expect(find.textContaining('Error loading stats'), findsOneWidget);
    expect(find.textContaining('stats unavailable'), findsOneWidget);
  });

  testWidgets('a region list that cannot be read says why', (tester) async {
    await pumpWithOverrides(tester, [
      cachedRegionsProvider.overrideWith(
        (ref) async => throw StateError('regions unavailable'),
      ),
      regionStoreIdsProvider.overrideWith((ref) async => const <String>{}),
      cacheStatsProvider.overrideWith((ref) async => _stats),
    ]);

    expect(find.textContaining('regions unavailable'), findsOneWidget);
  });

  testWidgets('the refresh button re-reads the regions and statistics', (
    tester,
  ) async {
    var regionReads = 0;
    var statsReads = 0;
    await pumpWithOverrides(tester, [
      cachedRegionsProvider.overrideWith((ref) async {
        regionReads++;
        return const [];
      }),
      regionStoreIdsProvider.overrideWith((ref) async => const <String>{}),
      cacheStatsProvider.overrideWith((ref) async {
        statsReads++;
        return _stats;
      }),
    ]);
    expect(regionReads, 1);
    expect(statsReads, 1);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();

    expect(regionReads, 2);
    expect(statsReads, 2);
  });

  testWidgets('a sweep that reclaimed stores re-reads the statistics', (
    tester,
  ) async {
    // The figures on screen were measured before the sweep deleted anything.
    var statsReads = 0;
    await pumpWithOverrides(tester, [
      offlineMapRepositoryProvider.overrideWithValue(_FakeRepository([])),
      tileCacheServiceProvider.overrideWithValue(_SweepingTileCache()),
      cacheStatsProvider.overrideWith((ref) async {
        statsReads++;
        return _stats;
      }),
    ]);

    expect(statsReads, 2);
  });

  testWidgets('cancelling the clear prompt clears nothing', (tester) async {
    final repository = _FakeRepository([_region(id: 'owns', name: 'Cozumel')]);
    await pumpWithOverrides(tester, [
      offlineMapRepositoryProvider.overrideWithValue(repository),
      tileCacheServiceProvider.overrideWithValue(_FailingTileCache()),
      cacheStatsProvider.overrideWith((ref) async => _stats),
    ]);

    await tester.ensureVisible(find.text('Clear all map tiles'));
    await tester.pump();
    await tester.tap(find.text('Clear all map tiles'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(repository.regions, hasLength(1));
  });

  testWidgets('cancelling the delete prompt deletes nothing', (tester) async {
    final repository = _FakeRepository([_region(id: 'owns', name: 'Cozumel')]);
    await pumpWithOverrides(tester, [
      offlineMapRepositoryProvider.overrideWithValue(repository),
      tileCacheServiceProvider.overrideWithValue(_FailingTileCache()),
      cacheStatsProvider.overrideWith((ref) async => _stats),
    ]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.regions, hasLength(1));
  });

  testWidgets('download new region opens the region picker', (tester) async {
    await pumpSection(tester, regions: const [], regionStoreIds: const {});

    await tester.ensureVisible(find.text('Download new region'));
    await tester.pump();
    await tester.tap(find.text('Download new region'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RegionPickerPage), findsOneWidget);
  });
}
