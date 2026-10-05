import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _nearSite = DiveSite(
  id: 'near',
  name: 'House Reef',
  location: GeoPoint(10.0, 10.0),
);
const _midSite = DiveSite(
  id: 'mid',
  name: 'Channel',
  location: GeoPoint(10.05, 10.0),
);
const _farSite = DiveSite(
  id: 'far',
  name: 'Blue Hole',
  location: GeoPoint(11.0, 10.0),
);
const _noGpsSite = DiveSite(id: 'nogps', name: 'Mystery Lake');

const _here = LocationResult(latitude: 10.0, longitude: 10.0);

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake device GPS. [LocationService] has a private constructor, so the fake
/// implements the interface rather than extending it.
class _FakeLocationService implements LocationService {
  _FakeLocationService({this.result, this.pending});

  /// Resolved fix, or null for "no fix available".
  final LocationResult? result;

  /// When set, [getCurrentLocation] hangs on this instead of resolving, so a
  /// test can observe the in-progress state.
  final Completer<LocationResult?>? pending;

  int calls = 0;

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) {
    calls++;
    return pending?.future ?? Future.value(result);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester, {
  required List<DiveSite> sites,
  LocationResult? currentLocation,
  GeoPoint? diveLocation,
  AppSettings settings = const AppSettings(),
  String? selectedSiteId,
  void Function(DiveSite)? onSiteSelected,
  void Function(String query)? onCreateNewSite,
  VoidCallback? onClear,
  bool useDeviceLocation = true,
  LocationService? locationService,
}) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sitesProvider.overrideWith((ref) async => sites),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
        // Default to "no fix" so no test reaches the real platform channel.
        locationServiceProvider.overrideWithValue(
          locationService ?? _FakeLocationService(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Every assertion below is an English literal. flutter_test forwards
        // the host machine's locale list, so without this the UI resolves to
        // the developer's own language and 6 of these tests miss.
        locale: const Locale('en'),
        home: Scaffold(
          body: SitePickerSheet(
            scrollController: ScrollController(),
            selectedSiteId: selectedSiteId,
            currentLocation: currentLocation,
            diveLocation: diveLocation,
            onSiteSelected: onSiteSelected ?? (_) {},
            onCreateNewSite: onCreateNewSite,
            onClear: onClear,
            useDeviceLocation: useDeviceLocation,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Titles of the site rows in the picker list, top to bottom.
List<String> _rowTitles(WidgetTester tester) => tester
    .widgetList<ListTile>(
      find.descendant(
        of: find.byKey(sitePickerListKey),
        matching: find.byType(ListTile),
      ),
    )
    .map((tile) => (tile.title! as Text).data!)
    .toList();

const _auSite = DiveSite(
  id: 'au1',
  name: 'Cod Hole',
  country: 'Australia',
  region: 'Queensland',
);
const _egSite = DiveSite(
  id: 'eg1',
  name: 'Blue Hole',
  country: 'Egypt',
  city: 'Dahab',
  bodyOfWater: 'Red Sea',
);
const _mxSite = DiveSite(id: 'mx1', name: 'Angelita', country: 'Mexico');

void main() {
  testWidgets('lists sites within 50 km under Nearby, nearest first', (
    tester,
  ) async {
    await _pump(
      tester,
      sites: const [_farSite, _noGpsSite, _midSite, _nearSite],
      currentLocation: _here,
    );
    expect(find.text('Sorted by distance'), findsOneWidget);
    expect(find.text('Nearby'), findsOneWidget);
    // Nearby holds near and mid; then the single No country group lists every
    // site in the order the provider gave them.
    expect(_rowTitles(tester), [
      'House Reef',
      'Channel',
      'Blue Hole',
      'Mystery Lake',
      'Channel',
      'House Reef',
    ]);
    // Distance captions cover both the meters and kilometers formats.
    expect(find.text('0 m away'), findsOneWidget);
    expect(find.textContaining('km away'), findsOneWidget);
    expect(find.text('No country'), findsOneWidget);
  });

  testWidgets('a GPS site with no country is in Nearby and in No country', (
    tester,
  ) async {
    await _pump(tester, sites: const [_nearSite], currentLocation: _here);
    expect(_rowTitles(tester), ['House Reef', 'House Reef']);
  });

  testWidgets('groups by country, collapsed except the selected country', (
    tester,
  ) async {
    await _pump(tester, selectedSiteId: 'au1', sites: const [_auSite, _egSite]);
    expect(find.text('Australia'), findsOneWidget);
    expect(find.text('Queensland'), findsOneWidget);
    expect(_rowTitles(tester), ['Cod Hole']);
    expect(find.text('Egypt'), findsOneWidget);

    await tester.tap(find.text('Egypt'));
    await tester.pumpAndSettle();
    expect(_rowTitles(tester), ['Cod Hole', 'Blue Hole']);
    expect(find.text('Dahab · Red Sea'), findsOneWidget);

    await tester.tap(find.text('Australia'));
    await tester.pumpAndSettle();
    expect(_rowTitles(tester), ['Blue Hole']);
  });

  testWidgets('searching opens every group with a match', (tester) async {
    await _pump(tester, sites: const [_auSite, _egSite, _mxSite]);
    expect(_rowTitles(tester), isEmpty);

    await tester.enterText(find.byType(TextField), 'hole');
    await tester.pumpAndSettle();
    expect(_rowTitles(tester), ['Cod Hole', 'Blue Hole']);
    expect(find.text('Mexico'), findsNothing);

    await tester.enterText(find.byType(TextField), 'red sea');
    await tester.pumpAndSettle();
    expect(_rowTitles(tester), ['Blue Hole']);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(_rowTitles(tester), isEmpty);
    expect(find.text('Mexico'), findsOneWidget);
  });

  testWidgets(
    'a header tapped while searching closes until the query changes',
    (tester) async {
      await _pump(tester, sites: const [_auSite, _egSite]);
      await tester.enterText(find.byType(TextField), 'hole');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Egypt'));
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['Cod Hole']);

      await tester.enterText(find.byType(TextField), 'hol');
      await tester.pumpAndSettle();
      expect(_rowTitles(tester), ['Cod Hole', 'Blue Hole']);
    },
  );

  testWidgets('a whitespace-only query keeps the manual expansion', (
    tester,
  ) async {
    await _pump(tester, sites: const [_auSite, _egSite]);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pumpAndSettle();
    expect(_rowTitles(tester), isEmpty);
    expect(find.text('Australia'), findsOneWidget);
  });

  testWidgets('filter mode offers an All sites row that clears', (
    tester,
  ) async {
    var cleared = 0;
    await _pump(tester, sites: const [_farSite], onClear: () => cleared++);
    await tester.tap(find.text('All sites'));
    expect(cleared, 1);
  });

  testWidgets('without onClear there is no All sites row', (tester) async {
    await _pump(tester, sites: const [_farSite]);
    expect(find.text('All sites'), findsNothing);
  });

  testWidgets('a selected id that no longer exists checks nothing', (
    tester,
  ) async {
    await _pump(tester, sites: const [_farSite], selectedSiteId: 'deleted');
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(_rowTitles(tester), ['Blue Hole']);
  });

  testWidgets('does not ask for the device location when told not to', (
    tester,
  ) async {
    final service = _FakeLocationService(result: _here);
    await _pump(
      tester,
      sites: const [_nearSite],
      locationService: service,
      useDeviceLocation: false,
    );
    expect(service.calls, 0);
    expect(find.text('Nearby'), findsNothing);
  });

  testWidgets('marks the selected site and selects on tap', (tester) async {
    DiveSite? selected;
    await _pump(
      tester,
      sites: const [_nearSite, _farSite],
      selectedSiteId: 'far',
      onSiteSelected: (site) => selected = site,
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.text('House Reef'));
    expect(selected?.id, 'near');
  });

  testWidgets('search with no matches shows the no-results message', (
    tester,
  ) async {
    await _pump(tester, sites: const [_nearSite]);
    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('zzzzz'), findsWidgets);
    expect(find.byKey(sitePickerListKey), findsNothing);
  });

  testWidgets('empty state offers creating a site', (tester) async {
    var created = 0;
    await _pump(tester, sites: const [], onCreateNewSite: (_) => created++);
    expect(find.text('No dive sites yet'), findsOneWidget);
    await tester.tap(find.text('Add Dive Site'));
    expect(created, 1);
  });

  testWidgets('empty state hides the create button without a callback', (
    tester,
  ) async {
    await _pump(tester, sites: const []);
    expect(find.text('No dive sites yet'), findsOneWidget);
    expect(find.text('Add Dive Site'), findsNothing);
  });

  testWidgets('header offers creating a site', (tester) async {
    var created = 0;
    await _pump(
      tester,
      sites: const [_nearSite],
      onCreateNewSite: (_) => created++,
    );
    await tester.tap(find.text('New Dive Site'));
    expect(created, 1);
  });

  testWidgets('header create passes the trimmed search text', (tester) async {
    final queries = <String>[];
    await _pump(tester, sites: const [_nearSite], onCreateNewSite: queries.add);

    await tester.enterText(find.byType(TextField), '  Blue Corner  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Dive Site'));

    expect(queries, ['Blue Corner']);
  });

  testWidgets('header create passes an empty query without a search', (
    tester,
  ) async {
    final queries = <String>[];
    await _pump(tester, sites: const [_nearSite], onCreateNewSite: queries.add);

    await tester.tap(find.text('New Dive Site'));

    expect(queries, ['']);
  });

  testWidgets('empty-state create passes the search text too', (tester) async {
    final queries = <String>[];
    await _pump(tester, sites: const [], onCreateNewSite: queries.add);

    await tester.enterText(find.byType(TextField), 'Blue Hole');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Dive Site'));

    expect(queries, ['Blue Hole']);
  });

  testWidgets('header hides the create button without a callback', (
    tester,
  ) async {
    await _pump(tester, sites: const [_nearSite]);
    expect(find.text('New Dive Site'), findsNothing);
  });

  testWidgets('measures Nearby from diveLocation when provided', (
    tester,
  ) async {
    await _pump(
      tester,
      sites: const [_farSite, _nearSite, _midSite],
      diveLocation: const GeoPoint(10.0, 10.0),
    );
    expect(_rowTitles(tester).take(2), ['House Reef', 'Channel']);
    expect(find.text('Sorted by distance from this dive'), findsOneWidget);
  });

  testWidgets('falls back to currentLocation when diveLocation is null', (
    tester,
  ) async {
    await _pump(
      tester,
      sites: const [_farSite, _nearSite, _midSite],
      currentLocation: _here,
    );
    expect(_rowTitles(tester).take(2), ['House Reef', 'Channel']);
    expect(find.text('Sorted by distance'), findsOneWidget);
    expect(find.text('Sorted by distance from this dive'), findsNothing);
  });

  // #965: a dive computer import produces a dive with no GPS, and the edit
  // page captures device GPS only for new dives, so the sheet used to receive
  // no anchor at all and offered no nearby sites.
  testWidgets('falls back to device location when the caller gives none', (
    tester,
  ) async {
    await _pump(
      tester,
      sites: const [_farSite, _noGpsSite, _nearSite, _midSite],
      locationService: _FakeLocationService(result: _here),
    );
    expect(find.text('Nearby'), findsOneWidget);
    expect(_rowTitles(tester).take(2), ['House Reef', 'Channel']);
    expect(find.text('Sorted by distance'), findsOneWidget);
  });

  testWidgets('keeps the provided order when no device fix is available', (
    tester,
  ) async {
    await _pump(
      tester,
      sites: const [_farSite, _nearSite, _midSite],
      locationService: _FakeLocationService(),
    );
    expect(find.text('Nearby'), findsNothing);
    expect(_rowTitles(tester), ['Blue Hole', 'House Reef', 'Channel']);
    expect(find.text('Sorted by distance'), findsNothing);
  });

  testWidgets('does not request device location when the dive has GPS', (
    tester,
  ) async {
    final service = _FakeLocationService(result: _here);
    await _pump(
      tester,
      sites: const [_farSite, _nearSite],
      diveLocation: const GeoPoint(10.0, 10.0),
      locationService: service,
    );
    expect(service.calls, 0);
  });

  testWidgets('shows a progress caption while the device fix resolves', (
    tester,
  ) async {
    final pending = Completer<LocationResult?>();
    await _pump(
      tester,
      sites: const [_farSite, _nearSite],
      locationService: _FakeLocationService(pending: pending),
    );
    expect(find.text('Getting location...'), findsOneWidget);

    pending.complete(_here);
    await tester.pumpAndSettle();
    expect(find.text('Getting location...'), findsNothing);
    expect(find.text('Nearby'), findsOneWidget);
    expect(_rowTitles(tester).first, 'House Reef');
  });

  testWidgets('distance readout respects imperial units', (tester) async {
    await _pump(
      tester,
      sites: const [_midSite],
      diveLocation: const GeoPoint(10.0, 10.0),
      settings: const AppSettings(
        depthUnit: DepthUnit.feet,
        distanceUnit: DistanceUnit.miles,
      ),
    );
    expect(find.textContaining('mi away'), findsOneWidget);
    expect(find.textContaining('km'), findsNothing);
  });

  // Only the Nearby section is ordered by distance; with nothing within
  // 50 km the list is purely by country, so the caption would be false.
  testWidgets('no distance caption when no site is nearby', (tester) async {
    await _pump(
      tester,
      sites: const [_farSite, _noGpsSite],
      diveLocation: const GeoPoint(10.0, 10.0),
    );
    expect(find.text('Nearby'), findsNothing);
    expect(find.text('Sorted by distance from this dive'), findsNothing);
  });

  testWidgets('a search that hides every nearby site drops the caption', (
    tester,
  ) async {
    await _pump(
      tester,
      sites: const [_nearSite, _farSite],
      diveLocation: const GeoPoint(10.0, 10.0),
    );
    expect(find.text('Sorted by distance from this dive'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'blue');
    await tester.pumpAndSettle();
    expect(find.text('Nearby'), findsNothing);
    expect(find.text('Sorted by distance from this dive'), findsNothing);
  });

  // A filter whose site was deleted, with no sites left, must still be
  // clearable from the sheet.
  testWidgets('filter mode offers All sites even with no sites', (
    tester,
  ) async {
    var cleared = 0;
    await _pump(
      tester,
      sites: const [],
      selectedSiteId: 'deleted',
      onClear: () => cleared++,
    );
    expect(find.text('No dive sites yet'), findsOneWidget);
    await tester.tap(find.text('All sites'));
    expect(cleared, 1);
  });

  testWidgets('filter mode keeps All sites when a search finds nothing', (
    tester,
  ) async {
    var cleared = 0;
    await _pump(tester, sites: const [_farSite], onClear: () => cleared++);
    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('zzzzz'), findsWidgets);
    await tester.tap(find.text('All sites'));
    expect(cleared, 1);
  });
}
