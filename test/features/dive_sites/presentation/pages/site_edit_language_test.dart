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
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Records the language every geocode was asked for.
class _RecordingLocationService implements LocationService {
  final List<String> languages = [];

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    languages.add(languageCode);
    return const PlaceLookup(country: 'Schweiz', region: 'Luzern');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A settings notifier that starts with German place names.
class _GermanSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _GermanSettings() : super(const AppSettings(placeNameLanguage: 'de'));

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

  testWidgets('seeding a new site geocodes in the place name language', (
    tester,
  ) async {
    final location = _RecordingLocationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => _divers()),
          shareByDefaultProvider.overrideWith((_) async => false),
          settingsProvider.overrideWith((_) => _GermanSettings()),
          locationServiceProvider.overrideWithValue(location),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteEditPage(initialLocation: GeoPoint(47.027631, 8.400640)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(location.languages, ['de']);
    expect(find.text('Schweiz'), findsOneWidget);
  });
}
