import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Stub geocoder: the altitude path must not depend on reverse geocoding.
class _StubLocationService implements LocationService {
  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async => const PlaceLookup.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Diver> _divers() => [
  Diver(
    id: 'd1',
    name: 'Me',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  ),
];

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

  Future<void> pumpSiteEdit(
    WidgetTester tester, {
    GeoPoint? initialLocation,
    required List<Uri> requests,
    bool fail = false,
  }) async {
    tester.view.physicalSize = const Size(1000, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => _divers()),
          shareByDefaultProvider.overrideWith((_) async => false),
          locationServiceProvider.overrideWithValue(_StubLocationService()),
          weatherHttpClientProvider.overrideWithValue(
            MockClient((request) async {
              requests.add(request.url);
              if (fail) return http.Response('oops', 500);
              return http.Response(
                jsonEncode({
                  'elevation': [740.2],
                }),
                200,
              );
            }),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteEditPage(initialLocation: initialLocation),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('seeded coordinates fill an empty altitude field', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpSiteEdit(
      tester,
      initialLocation: const GeoPoint(46.4, 8.0),
      requests: requests,
    );

    // Let the 1-second debounce elapse, then the lookup complete.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // The collapsed Location summary is "{lat}, {lng} - {altitude} {symbol}".
    expect(requests, hasLength(1));
    expect(
      find.textContaining('740 m', findRichText: true),
      findsOneWidget,
      reason: 'altitude should appear in the collapsed location summary',
    );
  });

  testWidgets('a failed lookup leaves altitude empty', (tester) async {
    final requests = <Uri>[];
    await pumpSiteEdit(
      tester,
      initialLocation: const GeoPoint(46.4, 8.0),
      requests: requests,
      fail: true,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(find.textContaining('740 m'), findsNothing);
  });

  testWidgets('no coordinates means no lookup', (tester) async {
    final requests = <Uri>[];
    await pumpSiteEdit(tester, requests: requests);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
  });
}
