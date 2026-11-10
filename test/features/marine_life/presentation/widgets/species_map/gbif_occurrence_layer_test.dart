import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/data/services/gbif_species_map_service.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/gbif_occurrence_layer.dart';

import 'species_map_harness.dart';

class _CountingService extends GbifSpeciesMapService {
  int calls = 0;
  final int? key;

  _CountingService(this.key);

  @override
  Future<int?> resolveTaxonKey({
    required String speciesId,
    String? scientificName,
  }) async {
    calls++;
    return key;
  }
}

Widget _map() => const FlutterMap(
  options: MapOptions(),
  children: [GbifOccurrenceLayer(speciesId: 'sp_whale_shark')],
);

void main() {
  testWidgets('makes no request while the public layer is off', (tester) async {
    final service = _CountingService(42);
    await tester.pumpWidget(
      await speciesMapHarness(
        child: _map(),
        overrides: [gbifSpeciesMapServiceProvider.overrideWithValue(service)],
      ),
    );
    await tester.pump();

    expect(service.calls, 0);
    expect(find.byType(TileLayer), findsNothing);
  });

  testWidgets('with the layer on and a key draws licence-filtered tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      await speciesMapHarness(
        child: _map(),
        prefs: {kSpeciesMapPublicLayerKey: true},
        overrides: [
          speciesGbifTaxonKeyProvider(
            'sp_whale_shark',
          ).overrideWith((ref) async => 42),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.urlTemplate, GbifSpeciesMapService.tileUrlTemplate(42));
    // Identified like the app's other GBIF requests, not as flutter_map.
    final provider = layer.tileProvider as NetworkTileProvider;
    expect(
      provider.headers['User-Agent'],
      'Submersion/1.0 (https://submersion.app)',
    );
    // A failed tile is reported, so the page can say records did not load.
    expect(layer.errorTileCallback, isNotNull);
    // And dropped once out of view, so panning back asks GBIF again.
    expect(
      layer.evictErrorTileStrategy,
      EvictErrorTileStrategy.notVisibleRespectMargin,
    );
  });

  testWidgets('a failed tile reaches the error callback', (tester) async {
    await tester.pumpWidget(
      await speciesMapHarness(
        child: _map(),
        prefs: {kSpeciesMapPublicLayerKey: true},
        overrides: [
          speciesGbifTaxonKeyProvider(
            'sp_whale_shark',
          ).overrideWith((ref) async => 42),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    final provider = layer.tileProvider as NetworkTileProvider;
    // A silenced failure is drawn as a transparent tile and never reaches
    // errorTileCallback, so the page could never say records did not load.
    // (The tile request itself cannot run here: flutter_map's disk cache
    // waits on path_provider, which a widget test does not provide.)
    expect(provider.silenceExceptions, isFalse);
  });

  testWidgets('the error callback raises the failure flag', (tester) async {
    await tester.pumpWidget(
      await speciesMapHarness(
        child: _map(),
        prefs: {kSpeciesMapPublicLayerKey: true},
        overrides: [
          speciesGbifTaxonKeyProvider(
            'sp_whale_shark',
          ).overrideWith((ref) async => 42),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FlutterMap)),
    );
    final failed = container.listen(
      speciesMapPublicTilesFailedProvider('sp_whale_shark'),
      (_, _) {},
    );
    addTearDown(failed.close);

    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    final tile = TileImage(
      coordinates: const TileCoordinates(0, 0, 0),
      vsync: tester,
      imageProvider: MemoryImage(TileProvider.transparentImage),
      onLoadComplete: (_) {},
      onLoadError: (_, _, _) {},
      tileDisplay: const TileDisplay.instantaneous(),
      errorImage: null,
      cancelLoading: Completer<void>(),
    );
    addTearDown(tile.dispose);
    layer.errorTileCallback!(tile, StateError('HTTP 503'), null);

    expect(failed.read(), isTrue);
  });

  testWidgets('rebuilding the layer keeps the one shared tile client', (
    tester,
  ) async {
    var created = 0;
    await tester.pumpWidget(
      await speciesMapHarness(
        child: _map(),
        prefs: {kSpeciesMapPublicLayerKey: true},
        overrides: [
          speciesGbifTaxonKeyProvider(
            'sp_whale_shark',
          ).overrideWith((ref) async => 42),
          gbifTileHttpClientProvider.overrideWith((ref) {
            created++;
            return MockClient((_) async => http.Response('', 503));
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    final element = tester.element(find.byType(GbifOccurrenceLayer));
    for (var i = 0; i < 3; i++) {
      element.markNeedsBuild();
      await tester.pump();
    }

    expect(created, 1);
  });

  testWidgets('with the layer on and no key draws nothing', (tester) async {
    await tester.pumpWidget(
      await speciesMapHarness(
        child: _map(),
        prefs: {kSpeciesMapPublicLayerKey: true},
        overrides: [
          speciesGbifTaxonKeyProvider(
            'sp_whale_shark',
          ).overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(TileLayer), findsNothing);
  });
}
