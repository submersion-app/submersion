import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_catalogue_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

String _file(String generatedAt, String model) => jsonEncode({
  'format': 1,
  'generatedAt': generatedAt,
  'records': [
    {
      'id': 'maker-$model',
      'manufacturer': 'Maker',
      'model': model,
      'equipmentType': 'computer',
      'sources': [],
    },
  ],
});

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer container({String? bundled, String? cached}) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        equipmentCatalogueBundledTextProvider.overrideWith(
          (ref) async => bundled,
        ),
        equipmentCatalogueCachedTextProvider.overrideWith(
          (ref) async => cached,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the bundled copy when nothing was downloaded', () async {
    final c = container(bundled: _file('2026-11-01T00:00:00Z', 'Bundled'));
    final catalogue = await c.read(equipmentCatalogueProvider.future);
    expect(catalogue.byId('maker-Bundled'), isNotNull);
  });

  test('a newer downloaded copy wins', () async {
    final c = container(
      bundled: _file('2026-11-01T00:00:00Z', 'Bundled'),
      cached: _file('2026-11-20T00:00:00Z', 'Downloaded'),
    );
    final catalogue = await c.read(equipmentCatalogueProvider.future);
    expect(catalogue.byId('maker-Downloaded'), isNotNull);
    expect(catalogue.byId('maker-Bundled'), isNull);
  });

  test('an older downloaded copy loses to a newer bundled one', () async {
    final c = container(
      bundled: _file('2026-11-20T00:00:00Z', 'Bundled'),
      cached: _file('2026-11-01T00:00:00Z', 'Downloaded'),
    );
    final catalogue = await c.read(equipmentCatalogueProvider.future);
    expect(catalogue.byId('maker-Bundled'), isNotNull);
  });

  test('nothing readable gives the empty catalogue, never an error', () async {
    final c = container(bundled: '{broken', cached: 'also broken');
    final catalogue = await c.read(equipmentCatalogueProvider.future);
    expect(catalogue.isEmpty, isTrue);
  });

  test('a cache that cannot be read leaves the bundled copy', () async {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        equipmentCatalogueBundledTextProvider.overrideWith(
          (ref) async => _file('2026-11-01T00:00:00Z', 'Bundled'),
        ),
        equipmentCatalogueCachedTextProvider.overrideWith(
          (ref) async => throw StateError('no support directory'),
        ),
      ],
    );
    addTearDown(c.dispose);
    final catalogue = await c.read(equipmentCatalogueProvider.future);
    expect(catalogue.byId('maker-Bundled'), isNotNull);
  });

  test('the download switch defaults on and persists per device', () async {
    final c = container();
    expect(c.read(equipmentCatalogueUpdatesEnabledProvider), isTrue);
    await c
        .read(equipmentCatalogueUpdatesEnabledProvider.notifier)
        .setEnabled(false);
    expect(c.read(equipmentCatalogueUpdatesEnabledProvider), isFalse);
    expect(prefs.getBool(SettingsKeys.equipmentCatalogueUpdates), isFalse);
  });

  group('equipmentCatalogueRefreshProvider', () {
    ProviderContainer refreshing({
      required http.Client client,
      required List<String> written,
      bool browser = false,
    }) {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          equipmentCatalogueHttpClientProvider.overrideWithValue(client),
          equipmentCatalogueCacheWriterProvider.overrideWithValue(
            (json) async => written.add(json),
          ),
          if (browser)
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a downloaded release is kept', () async {
      final written = <String>[];
      final body = _file('2026-11-20T00:00:00Z', 'Downloaded');
      final c = refreshing(
        client: MockClient((_) async => http.Response(body, 200)),
        written: written,
      );
      await c.read(equipmentCatalogueRefreshProvider)();
      expect(written, [body]);
    });

    test('a browser never downloads', () async {
      final written = <String>[];
      var requests = 0;
      final c = refreshing(
        client: MockClient((_) async {
          requests++;
          return http.Response('', 404);
        }),
        written: written,
        browser: true,
      );
      await c.read(equipmentCatalogueRefreshProvider)();
      expect(requests, 0);
      expect(written, isEmpty);
    });
  });
}
