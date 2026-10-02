import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/list_view_mode.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_map_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

import '../../../../helpers/mock_providers.dart';

class _MockDCListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDCListNotifier(List<DiveCenter> centers)
    : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _createdAt = DateTime(2026, 1, 1);

DiveCenter _makeCenter(String id, String name, double lat, double lng) {
  return DiveCenter(
    id: id,
    name: name,
    latitude: lat,
    longitude: lng,
    createdAt: _createdAt,
    updatedAt: _createdAt,
  );
}

// Far apart, so the opening fit is wide (zoom well under 10) and neither
// marker clusters with the other. The south-west centre sits away from the
// floating action button in the bottom-right corner.
final _southWest = _makeCenter('dc-sw', 'South West Divers', -30.0, -60.0);
final _northEast = _makeCenter('dc-ne', 'North East Divers', 10.0, 20.0);

/// Pumps the page on a [width] x 900 surface: under 1100 wide it shows the
/// map alone, from 1100 up it adds the list pane.
Future<void> _pumpPage(
  WidgetTester tester,
  List<DiveCenter> centers, {
  double width = 600,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        diveCenterListNotifierProvider.overrideWith(
          (ref) => _MockDCListNotifier(centers),
        ),
        diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
        diveCenterListViewModeProvider.overrideWith(
          (ref) => ListViewMode.detailed,
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveCenterMapPage(),
      ),
    ),
  );
  // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// The live camera of the only map on screen.
MapCamera _camera(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

/// The centre id the page's map-list selection holds.
String? _selectedId(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(DiveCenterMapPage)),
).read(mapListSelectionProvider('dive-centers')).selectedId;

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

void main() {
  testWidgets('renders the DiveCenterMapPage FlutterMap with a center', (
    tester,
  ) async {
    // Phone-sized surface keeps MapListScaffold in mobile mode, which renders
    // only the map pane (no list pane providers to mock).
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime(2026, 1, 1);
    final center = DiveCenter(
      id: 'dc1',
      name: 'Blue Water Dive',
      latitude: 18.5,
      longitude: -77.9,
      createdAt: now,
      updatedAt: now,
    );
    // A second center at the SAME location reliably clusters with the first,
    // exercising the MarkerClusterLayer cluster builder.
    final center2 = DiveCenter(
      id: 'dc2',
      name: 'Blue Water Annex',
      latitude: 18.5,
      longitude: -77.9,
      createdAt: now,
      updatedAt: now,
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveCenterListNotifierProvider.overrideWith(
            (ref) => _MockDCListNotifier([center, center2]),
          ),
          diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveCenterMapPage(),
        ),
      ),
    );

    // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FlutterMap), findsWidgets);
  });

  group('camera moves', () {
    testWidgets('tapping a marker selects it and eases the camera onto it', (
      tester,
    ) async {
      await _pumpPage(tester, [_southWest, _northEast]);
      expect(_camera(tester).zoom, lessThan(10));

      await tester.tap(_onScreen(tester, _markerFor('South West Divers')));
      // Let the 500 ms move finish and flush the map's double-tap timer.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      expect(_selectedId(tester), 'dc-sw');
      final after = _camera(tester);
      expect(after.center.latitude, closeTo(-30.0, 1e-6));
      expect(after.center.longitude, closeTo(-60.0, 1e-6));
      // A wide camera zooms in to 12 on the way.
      expect(after.zoom, closeTo(12.0, 1e-9));
    });

    testWidgets('tapping a centre in the list pane eases the camera onto it', (
      tester,
    ) async {
      await _pumpPage(tester, [_southWest, _northEast], width: 1400);
      expect(_camera(tester).zoom, lessThan(10));

      await tester.tap(find.text('North East Divers'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(_selectedId(tester), 'dc-ne');
      final after = _camera(tester);
      expect(after.center.latitude, closeTo(10.0, 1e-6));
      expect(after.center.longitude, closeTo(20.0, 1e-6));
      expect(after.zoom, closeTo(12.0, 1e-9));
    });

    testWidgets('the fit-all action frames every centre', (tester) async {
      await _pumpPage(tester, [_southWest, _northEast]);

      // Move in close on one centre so the fit has something to undo.
      await tester.tap(_onScreen(tester, _markerFor('South West Divers')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      final before = _camera(tester);
      expect(before.zoom, closeTo(12.0, 1e-9));
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
      await _pumpPage(tester, [
        _southWest,
        _makeCenter('dc-sw2', 'South West Annex', -30.0, -60.0),
        _northEast,
      ]);
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
