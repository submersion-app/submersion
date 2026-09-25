import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/maps/data/repositories/offline_map_repository.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/cached_region.dart';
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
}
