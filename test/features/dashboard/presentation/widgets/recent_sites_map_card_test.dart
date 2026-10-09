import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_sites_map_card.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Records where a tap navigated.
class NavSpy {
  String? location;
}

Future<NavSpy> pumpMapCard(
  WidgetTester tester,
  List<RecentSitePin> pins,
) async {
  final base = await getBaseOverrides();
  final spy = NavSpy();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: RecentSitesMapCard()),
      ),
      GoRoute(
        path: '/sites',
        builder: (_, _) => Builder(
          builder: (context) {
            spy.location = '/sites';
            return const Scaffold();
          },
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        recentSitesProvider.overrideWith((ref) async => pins),
      ].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  // Tiles are fetched over the network in a real app; pumping frames (not
  // pumpAndSettle) avoids waiting on image futures that never resolve here.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return spy;
}

void main() {
  testWidgets('hidden when no recent dive has a sited GPS fix', (tester) async {
    await pumpMapCard(tester, const []);
    expect(find.text('Recent sites'), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('renders one marker per pin', (tester) async {
    await pumpMapCard(tester, const [
      RecentSitePin(siteName: 'Site A', latitude: 36.0, longitude: 25.0),
      RecentSitePin(siteName: 'Site B', latitude: 35.0, longitude: 24.0),
    ]);

    expect(find.text('Recent sites'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byIcon(Icons.place), findsNWidgets(2));
  });

  testWidgets('a single pin still renders (no bounds fit)', (tester) async {
    await pumpMapCard(tester, const [
      RecentSitePin(siteName: 'Only site', latitude: 36.0, longitude: 25.0),
    ]);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byIcon(Icons.place), findsOneWidget);
  });

  testWidgets('expand button opens the sites tab', (tester) async {
    final spy = await pumpMapCard(tester, const [
      RecentSitePin(siteName: 'Site A', latitude: 36.0, longitude: 25.0),
    ]);

    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(spy.location, '/sites');
  });

  testWidgets('map content is locked, not pannable by a swipe', (tester) async {
    await pumpMapCard(tester, const [
      RecentSitePin(siteName: 'Site A', latitude: 36.0, longitude: 25.0),
    ]);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.interactionOptions.flags, InteractiveFlag.none);
  });

  testWidgets('not wrapped in TrackpadZoomMap, so a trackpad pan-zoom cannot '
      'move the camera or steal the scroll gesture either', (tester) async {
    await pumpMapCard(tester, const [
      RecentSitePin(siteName: 'Site A', latitude: 36.0, longitude: 25.0),
    ]);

    expect(find.byType(TrackpadZoomMap), findsNothing);
  });

  testWidgets('a trackpad pan-zoom gesture does not move the camera', (
    tester,
  ) async {
    await pumpMapCard(tester, const [
      RecentSitePin(siteName: 'Site A', latitude: 36.0, longitude: 25.0),
    ]);

    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    final startZoom = controller.camera.zoom;
    final startCenter = controller.camera.center;
    final center = tester.getCenter(find.byType(FlutterMap));

    // Same gesture shape as the one TrackpadZoomMap turns into a zoom
    // elsewhere (see trackpad_zoom_map_test.dart): scroll plus pinch. Without
    // that wrapper and with InteractiveFlag.none, flutter_map's own gesture
    // handling must leave the camera untouched.
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(center);
    await tester.pump();
    await gesture.panZoomUpdate(center, pan: const Offset(0, 100), scale: 2);
    await tester.pump();
    await gesture.panZoomEnd();
    await tester.pump();

    expect(controller.camera.zoom, startZoom);
    expect(controller.camera.center.latitude, startCenter.latitude);
    expect(controller.camera.center.longitude, startCenter.longitude);
  });
}
