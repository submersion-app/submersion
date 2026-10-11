import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/proxy_controller.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';
import 'package:submersion/core/services/geocoding/nominatim_throttle.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/cached_region.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/region_download_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/network_proxy_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/mock_providers.dart';

/// Answers each tile estimate with what [onEstimate] returns for its call
/// number (0 for the first), so a test can delay or fail a later estimate.
class _FakeTileCache extends Fake implements TileCacheService {
  _FakeTileCache(this.onEstimate);

  final Future<int> Function(int call) onEstimate;
  var _calls = 0;

  @override
  Future<int> estimateTileCount({
    required LatLng southWest,
    required LatLng northEast,
    required int minZoom,
    required int maxZoom,
    required String urlTemplate,
  }) => onEstimate(_calls++);
}

void main() {
  // The dialog suggests a name from the area's place, which asks Nominatim.
  // It answers as offline, as on a device without a network, with no wait.
  setUp(() {
    serveFakeHost('nominatim.openstreetmap.org');
    LocationService.throttle = NominatimThrottle(minimumGap: Duration.zero);
    addTearDown(() => LocationService.throttle = NominatimThrottle());
  });

  Future<void> pumpDialog(
    WidgetTester tester,
    Future<int> Function(int call) onEstimate, {
    EffectiveProxy proxy = const EffectiveProxy.direct(),
  }) async {
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          tileCacheServiceProvider.overrideWithValue(
            _FakeTileCache(onEstimate),
          ),
          cachedRegionsProvider.overrideWith((ref) async => <CachedRegion>[]),
          proxyStateProvider.overrideWith(
            (ref) => Stream.value(
              ProxyControllerState(
                settings: ProxySettings.defaults,
                system: null,
                detecting: false,
                effective: proxy,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          // Pinned: the assertions read English labels, and the host locale
          // would otherwise reach the app.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RegionDownloadDialog(
              southWest: LatLng(0, 0),
              northEast: LatLng(1, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  ChoiceChip chip(WidgetTester tester, String label) =>
      tester.widget(find.widgetWithText(ChoiceChip, label));

  FilledButton downloadButton(WidgetTester tester) =>
      tester.widget(find.byType(FilledButton));

  testWidgets('opens on the Overview preset', (tester) async {
    await pumpDialog(tester, (_) async => 1000);

    expect(chip(tester, 'Overview').selected, isTrue);
    expect(chip(tester, 'Detail').selected, isFalse);
    expect(chip(tester, 'Full').selected, isFalse);
  });

  testWidgets('tapping a preset selects it', (tester) async {
    await pumpDialog(tester, (_) async => 1000);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Detail'));
    await tester.pump();

    expect(chip(tester, 'Detail').selected, isTrue);
    expect(chip(tester, 'Overview').selected, isFalse);
  });

  testWidgets('Download is enabled below the tile limit', (tester) async {
    await pumpDialog(tester, (_) async => 5000);

    expect(downloadButton(tester).onPressed, isNotNull);
    expect(find.textContaining('Over 100,000 tiles'), findsNothing);
  });

  testWidgets('a SOCKS5 proxy disables Download and says why', (tester) async {
    await pumpDialog(
      tester,
      (_) async => 5000,
      proxy: const EffectiveProxy(
        kind: ProxyKind.socks5,
        host: 'proxy.example.test',
        port: 1080,
        source: ProxySource.manual,
      ),
    );

    expect(downloadButton(tester).onPressed, isNull);
    expect(find.textContaining('SOCKS5'), findsOneWidget);
  });

  testWidgets('an HTTP proxy leaves Download enabled', (tester) async {
    await pumpDialog(
      tester,
      (_) async => 5000,
      proxy: const EffectiveProxy(
        kind: ProxyKind.http,
        host: 'proxy.example.test',
        port: 3128,
        source: ProxySource.manual,
      ),
    );

    expect(downloadButton(tester).onPressed, isNotNull);
    expect(find.textContaining('SOCKS5'), findsNothing);
  });

  testWidgets('Download is disabled above the tile limit', (tester) async {
    await pumpDialog(tester, (_) async => 150000);

    expect(downloadButton(tester).onPressed, isNull);
    expect(find.textContaining('Over 100,000 tiles'), findsOneWidget);
    // The 10,000-tile warning is for the range the limit still allows.
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });

  testWidgets('the large-download warning shows between 10,000 and the limit', (
    tester,
  ) async {
    await pumpDialog(tester, (_) async => 50000);

    expect(downloadButton(tester).onPressed, isNotNull);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('Download is disabled while a new estimate is running', (
    tester,
  ) async {
    final slow = Completer<int>();
    await pumpDialog(
      tester,
      (call) => call == 0 ? Future.value(5000) : slow.future,
    );
    expect(downloadButton(tester).onPressed, isNotNull);

    // Overview was under the limit; Full asks for a new count. Until it
    // arrives the old count must not enable Download.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Full'));
    await tester.pump();
    expect(downloadButton(tester).onPressed, isNull);

    slow.complete(150000);
    await tester.pump();
    await tester.pump();
    expect(downloadButton(tester).onPressed, isNull);
    expect(find.textContaining('Over 100,000 tiles'), findsOneWidget);
  });

  testWidgets('Download is disabled when the estimate fails', (tester) async {
    await pumpDialog(tester, (call) async {
      if (call == 0) return 5000;
      throw StateError('count failed');
    });
    expect(downloadButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Full'));
    await tester.pump();
    await tester.pump();

    // No count for the new zoom levels: not the old one, not "unknown".
    expect(downloadButton(tester).onPressed, isNull);
  });

  testWidgets('a slow earlier estimate cannot overwrite a later one', (
    tester,
  ) async {
    final first = Completer<int>();
    await pumpDialog(tester, (call) {
      if (call == 0) return first.future; // the one from initState, still out
      return Future.value(150000);
    });

    await tester.tap(find.widgetWithText(ChoiceChip, 'Full'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Over 100,000 tiles'), findsOneWidget);

    first.complete(10); // arrives late, for the Overview levels
    await tester.pump();

    expect(downloadButton(tester).onPressed, isNull);
    expect(find.textContaining('Over 100,000 tiles'), findsOneWidget);
  });
}
