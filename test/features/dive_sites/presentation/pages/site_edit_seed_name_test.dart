import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

import '../../../../helpers/test_database.dart';

Finder _rowField(String label) => find.descendant(
  of: find.ancestor(
    of: find.text(label),
    matching: find.byType(SuggestionFormRow),
  ),
  matching: find.byType(TextFormField),
);

String _nameText(WidgetTester tester) =>
    tester.widget<TextFormField>(_rowField('Site Name *')).controller!.text;

/// Returns an empty placemark, so seeding a location never reaches the real
/// geocoder and never fills a field these tests look at.
class _EmptyLocationService implements LocationService {
  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async => const PlaceLookup();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1000, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => const <Diver>[]),
          shareByDefaultProvider.overrideWith((_) async => false),
          locationServiceProvider.overrideWithValue(_EmptyLocationService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('initialName fills the site name field', (tester) async {
    await pump(tester, const SiteEditPage(initialName: 'Blue Hole'));
    expect(_nameText(tester), 'Blue Hole');
  });

  testWidgets('a seeded name alone does not prompt to discard on cancel', (
    tester,
  ) async {
    var cancelled = false;
    await pump(
      tester,
      Scaffold(
        body: SiteEditPage(
          embedded: true,
          initialName: 'Blue Hole',
          onSaved: (_) {},
          onCancel: () => cancelled = true,
        ),
      ),
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(cancelled, isTrue);
  });

  testWidgets('editing the seeded name still prompts to discard', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: SiteEditPage(
          embedded: true,
          initialName: 'Blue Hole',
          onSaved: (_) {},
          onCancel: () {},
        ),
      ),
    );

    await tester.enterText(_rowField('Site Name *'), 'Blue Hole North');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('fromNewSiteExtra seeds both the name and the location', (
    tester,
  ) async {
    await pump(
      tester,
      SiteEditPage.fromNewSiteExtra(
        const NewSiteSeed(location: GeoPoint(1.5, 2.5), name: 'Blue Hole'),
      ),
    );

    expect(_nameText(tester), 'Blue Hole');
    // Location section is collapsed by default; its summary is "{lat}, {lng}".
    expect(find.text('1.500000, 2.500000'), findsOneWidget);
  });

  testWidgets('fromNewSiteExtra still accepts a bare GeoPoint', (tester) async {
    await pump(tester, SiteEditPage.fromNewSiteExtra(const GeoPoint(1.5, 2.5)));

    expect(_nameText(tester), isEmpty);
    expect(find.text('1.500000, 2.500000'), findsOneWidget);
  });
}
