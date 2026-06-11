import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  required List<DiveSite> sites,
  LocationResult? currentLocation,
  String? selectedSiteId,
  void Function(DiveSite)? onSiteSelected,
  VoidCallback? onCreateNewSite,
}) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sitesProvider.overrideWith((ref) async => sites)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SitePickerSheet(
            scrollController: ScrollController(),
            selectedSiteId: selectedSiteId,
            currentLocation: currentLocation,
            onSiteSelected: onSiteSelected ?? (_) {},
            onCreateNewSite: onCreateNewSite ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _tileTitles(WidgetTester tester) {
  return tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((tile) => ((tile.title) as Text).data!)
      .toList();
}

void main() {
  testWidgets('sorts by distance with GPS-less sites last', (tester) async {
    await _pump(
      tester,
      sites: const [_farSite, _noGpsSite, _nearSite, _midSite],
      currentLocation: _here,
    );
    expect(find.text('Sorted by distance'), findsOneWidget);
    expect(_tileTitles(tester), [
      'House Reef',
      'Channel',
      'Blue Hole',
      'Mystery Lake',
    ]);
    // Distance captions cover both the meters and kilometers formats.
    expect(find.text('0 m away'), findsOneWidget);
    expect(find.textContaining('km away'), findsNWidgets(2));
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

  testWidgets('search filters the list and clear restores it', (tester) async {
    await _pump(tester, sites: const [_nearSite, _farSite]);
    await tester.enterText(find.byType(TextField), 'blue');
    await tester.pumpAndSettle();
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('House Reef'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('House Reef'), findsOneWidget);
  });

  testWidgets('search with no matches shows the no-results message', (
    tester,
  ) async {
    await _pump(tester, sites: const [_nearSite]);
    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('zzzzz'), findsWidgets);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('empty state offers creating a site', (tester) async {
    var created = 0;
    await _pump(tester, sites: const [], onCreateNewSite: () => created++);
    expect(find.text('No dive sites yet'), findsOneWidget);
    await tester.tap(find.text('Add Dive Site'));
    expect(created, 1);
  });
}
