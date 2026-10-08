import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_map_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _now = DateTime.now();

DiveCenter _makeCenter({
  required String id,
  required String name,
  double? latitude,
  double? longitude,
}) {
  return DiveCenter(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<List<Override>> _buildOverrides({
  required List<DiveCenter> centers,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    diveCenterListNotifierProvider.overrideWith(
      (ref) => _MockDCListNotifier(centers),
    ),
    diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
  ];
}

class _MockDCListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDCListNotifier(List<DiveCenter> centers)
    : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _host(List<Override> overrides, Widget child) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// The live camera of the only map on screen.
MapCamera _camera(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

/// The marker for the centre called [name].
Finder _markerFor(String name) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'Dive center: $name',
);

/// The copy of [finder] that sits inside the map viewport. The world-wrapped
/// marker layer may also build copies one world to either side.
Finder _onScreen(WidgetTester tester, Finder finder) {
  final mapRect = tester.getRect(find.byType(FlutterMap));
  final count = finder.evaluate().length;
  for (var i = 0; i < count; i++) {
    final candidate = finder.at(i);
    if (mapRect.contains(tester.getCenter(candidate))) return candidate;
  }
  fail('No on-screen match for $finder');
}

// Far apart, so the opening fit is wide (zoom well under 10) and neither
// marker clusters with the other. The south-west centre sits away from the
// fit-all control in the top-right corner.
final _southWest = _makeCenter(
  id: 'dc-sw',
  name: 'South West Divers',
  latitude: -30.0,
  longitude: -60.0,
);
final _northEast = _makeCenter(
  id: 'dc-ne',
  name: 'North East Divers',
  latitude: 10.0,
  longitude: 20.0,
);

void main() {
  testWidgets('renders FlutterMap for dive centers with coordinates', (
    tester,
  ) async {
    final centers = [
      _makeCenter(
        id: 'dc1',
        name: 'Blue Water Dive',
        latitude: 18.5,
        longitude: -77.9,
      ),
      _makeCenter(
        id: 'dc2',
        name: 'Red Sea Divers',
        latitude: 27.9,
        longitude: 34.3,
      ),
    ];

    final overrides = await _buildOverrides(centers: centers);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveCenterMapContent(onItemSelected: (_) {})),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DiveCenterMapContent), findsOneWidget);
    expect(find.byType(FlutterMap), findsWidgets);
  });

  testWidgets('renders FlutterMap with a preselected center', (tester) async {
    final centers = [
      _makeCenter(
        id: 'dc1',
        name: 'Selected Center',
        latitude: 10.0,
        longitude: 20.0,
      ),
    ];

    final overrides = await _buildOverrides(centers: centers);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveCenterMapContent(
              selectedId: 'dc1',
              onItemSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsWidgets);
  });

  testWidgets('renders a cluster marker for co-located centers', (
    tester,
  ) async {
    // Two centers at the SAME location reliably cluster (distance 0 < radius),
    // exercising the MarkerClusterLayer cluster builder.
    final centers = [
      _makeCenter(id: 'dc-a', name: 'A', latitude: 10.0, longitude: 20.0),
      _makeCenter(id: 'dc-b', name: 'B', latitude: 10.0, longitude: 20.0),
    ];

    final overrides = await _buildOverrides(centers: centers);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveCenterMapContent(onItemSelected: (_) {})),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FlutterMap), findsWidgets);

    // Tapping empty map (a corner, away from the centered cluster) clears the
    // selection via the map's onTap. No animation, so this is teardown-safe.
    await tester.tapAt(
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(5, 5),
    );
    // Flush flutter_map's double-tap disambiguation timer before teardown.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FlutterMap), findsWidgets);
  });

  group('camera moves', () {
    testWidgets('tapping a marker selects it and eases the camera onto it', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        centers: [_southWest, _northEast],
      );
      final selections = <String?>[];

      await tester.pumpWidget(
        _host(overrides, DiveCenterMapContent(onItemSelected: selections.add)),
      );
      await tester.pump();

      final before = _camera(tester);
      expect(before.zoom, lessThan(10));

      await tester.tap(_onScreen(tester, _markerFor('South West Divers')));
      // Let the 500 ms move finish and flush the map's double-tap timer.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      expect(selections, ['dc-sw']);
      final after = _camera(tester);
      expect(after.center.latitude, closeTo(-30.0, 1e-6));
      expect(after.center.longitude, closeTo(-60.0, 1e-6));
      // A wide camera zooms in to 12 on the way.
      expect(after.zoom, closeTo(12.0, 1e-9));
    });

    testWidgets('a new selectedId after the map is ready eases onto it', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        centers: [_southWest, _northEast],
      );
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);

      await tester.pumpWidget(
        _host(
          overrides,
          ValueListenableBuilder<String?>(
            valueListenable: selected,
            builder: (context, id, _) =>
                DiveCenterMapContent(selectedId: id, onItemSelected: (_) {}),
          ),
        ),
      );
      // A second frame runs onMapReady, which arms didUpdateWidget.
      await tester.pump();
      await tester.pump();
      expect(_camera(tester).zoom, lessThan(10));

      selected.value = 'dc-ne';
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final after = _camera(tester);
      expect(after.center.latitude, closeTo(10.0, 1e-6));
      expect(after.center.longitude, closeTo(20.0, 1e-6));
      expect(after.zoom, closeTo(12.0, 1e-9));
    });

    testWidgets('the fit-all control frames every centre', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_southWest, _northEast],
      );

      await tester.pumpWidget(
        _host(
          overrides,
          DiveCenterMapContent(selectedId: 'dc-sw', onItemSelected: (_) {}),
        ),
      );
      await tester.pump();

      // A preselected centre opens close in on that centre alone.
      final before = _camera(tester);
      expect(before.zoom, 12.0);
      expect(before.visibleBounds.contains(const LatLng(10.0, 20.0)), isFalse);

      await tester.tap(find.byTooltip('Fit All Centers'));
      await tester.pump();

      final after = _camera(tester);
      expect(after.zoom, lessThan(before.zoom));
      expect(after.visibleBounds.contains(const LatLng(-30.0, -60.0)), isTrue);
      expect(after.visibleBounds.contains(const LatLng(10.0, 20.0)), isTrue);
    });

    testWidgets('tapping a cluster eases the camera onto its bounds', (
      tester,
    ) async {
      // Two co-located centres cluster; a far one keeps the opening fit wide.
      final overrides = await _buildOverrides(
        centers: [
          _southWest,
          _makeCenter(
            id: 'dc-sw2',
            name: 'South West Annex',
            latitude: -30.0,
            longitude: -60.0,
          ),
          _northEast,
        ],
      );

      await tester.pumpWidget(
        _host(overrides, DiveCenterMapContent(onItemSelected: (_) {})),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_camera(tester).zoom, lessThan(10));

      await tester.tap(_onScreen(tester, find.text('2')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      // A zero-size cluster bounds fits at animateToBounds' maxZoom of 14.
      final after = _camera(tester);
      expect(after.center.latitude, closeTo(-30.0, 1e-6));
      expect(after.center.longitude, closeTo(-60.0, 1e-6));
      expect(after.zoom, closeTo(14.0, 1e-9));
    });
  });
}
