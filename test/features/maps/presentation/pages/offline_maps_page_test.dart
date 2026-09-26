import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/pages/offline_maps_page.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    void Function()? onRegionsRead,
    void Function()? onStatsRead,
  }) async {
    // Tall enough that the lazily built list lays out both sections, so the
    // order assertions below compare real positions.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          cachedRegionsProvider.overrideWith((ref) async {
            onRegionsRead?.call();
            return const [];
          }),
          regionStoreIdsProvider.overrideWith((ref) async => const <String>{}),
          cacheStatsProvider.overrideWith((ref) async {
            onStatsRead?.call();
            return const CacheStats(
              tileCount: 0,
              sizeKiB: 0,
              hits: 0,
              misses: 0,
            );
          }),
          bathymetryRepositoryProvider.overrideWithValue(null),
          swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
          knownDiveSiteLocationsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OfflineMapsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('shows the map tiles section above the 3D terrain section', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Offline Maps'), findsOneWidget);
    expect(find.text('Map tiles'), findsOneWidget);
    expect(find.text('3D terrain'), findsOneWidget);
    expect(top(tester, 'Map tiles'), lessThan(top(tester, '3D terrain')));
  });

  testWidgets('the tile actions sit inside the map tiles section', (
    tester,
  ) async {
    // Both actions used to be page chrome (a floating button and an app bar
    // icon). On a page that also holds 3D terrain data, a page-wide "clear
    // all" would read as clearing that too, so they live in their section.
    await pumpPage(tester);

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Clear All Cache'), findsNothing);

    final terrainTop = top(tester, '3D terrain');
    expect(top(tester, 'Download new region'), lessThan(terrainTop));
    expect(top(tester, 'Clear all map tiles'), lessThan(terrainTop));
    expect(top(tester, 'Reload map data'), greaterThan(terrainTop));
  });

  testWidgets('pulling down re-reads the tile regions and statistics', (
    tester,
  ) async {
    var regionReads = 0;
    var statsReads = 0;
    await pumpPage(
      tester,
      onRegionsRead: () => regionReads++,
      onStatsRead: () => statsReads++,
    );
    expect(regionReads, 1);
    expect(statsReads, 1);

    await tester.fling(find.text('Map tiles'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(regionReads, 2);
    expect(statsReads, 2);
  });
}
