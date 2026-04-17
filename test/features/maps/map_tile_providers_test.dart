import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';

void main() {
  group('mapTileUrlProvider reacts to mapStyle changes', () {
    test('returns OSM URL for default mapStyle', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(mapTileUrlProvider),
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
    });

    test('updates when mapStyle flips to OpenTopoMap', () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setMapStyle(MapStyle.openTopoMap);

      expect(
        container.read(mapTileUrlProvider),
        'https://tile.opentopomap.org/{z}/{x}/{y}.png',
      );
    });

    test('updates when mapStyle flips to Esri Satellite', () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setMapStyle(MapStyle.esriSatellite);

      expect(
        container.read(mapTileUrlProvider),
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      );
    });
  });

  group('mapTileMaxZoomProvider reacts to mapStyle changes', () {
    test('returns 19 for OpenStreetMap (default)', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(mapTileMaxZoomProvider), 19.0);
    });

    test('returns 17 for OpenTopoMap', () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setMapStyle(MapStyle.openTopoMap);

      expect(container.read(mapTileMaxZoomProvider), 17.0);
    });

    test('returns 18 for Esri Satellite', () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setMapStyle(MapStyle.esriSatellite);

      expect(container.read(mapTileMaxZoomProvider), 18.0);
    });
  });

  group('mapTileAttributionProvider reacts to mapStyle changes', () {
    test('returns OSM attribution by default', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(mapTileAttributionProvider),
        contains('OpenStreetMap'),
      );
    });

    test('updates when mapStyle flips to OpenTopoMap', () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setMapStyle(MapStyle.openTopoMap);

      expect(
        container.read(mapTileAttributionProvider),
        contains('OpenTopoMap'),
      );
    });

    test('updates when mapStyle flips to Esri Satellite', () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setMapStyle(MapStyle.esriSatellite);

      expect(container.read(mapTileAttributionProvider), contains('Esri'));
    });
  });
}
