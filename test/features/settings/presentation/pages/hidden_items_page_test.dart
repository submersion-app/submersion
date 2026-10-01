import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/settings/presentation/pages/hidden_items_page.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Settings > Shared data lists the shared trips and sites hidden from the
/// active profile, each with Unhide (issue #2594).
void main() {
  late SharedPreferences prefs;
  final alice = Diver(
    id: 'a',
    name: 'Alice',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
  final items = [
    HiddenItem(
      kind: SharedItemKind.trip,
      id: 'bonaire',
      name: 'Bonaire',
      ownerId: 'a',
      location: 'Kralendijk',
      startDate: DateTime(2024, 3, 9),
      endDate: DateTime(2024, 3, 16),
    ),
    const HiddenItem(
      kind: SharedItemKind.site,
      id: 'pier',
      name: 'Salt Pier',
      ownerId: 'a',
    ),
  ];

  // A trip's date range is formatted by intl, which reads the process-wide
  // Intl.defaultLocale, not MaterialApp.locale. Pin it, and restore it so
  // the global stays contained (as unit_formatter_date_test does).
  late String? previousLocale;
  setUpAll(() => initializeDateFormatting('en'));

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  Future<(_Trips, _Sites)> pumpPage(
    WidgetTester tester,
    List<HiddenItem> hidden,
  ) async {
    final trips = _Trips();
    final sites = _Sites();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          hiddenItemsProvider.overrideWith((ref) async => hidden),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allDiversProvider.overrideWith((_) async => [alice]),
          tripListNotifierProvider.overrideWith((ref) => trips),
          siteListNotifierProvider.overrideWith((ref) => sites),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HiddenItemsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (trips, sites);
  }

  testWidgets('groups hidden trips and sites and unhides them', (tester) async {
    final (trips, sites) = await pumpPage(tester, items);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Sites'), findsOneWidget);
    expect(find.text('Bonaire'), findsOneWidget);
    expect(find.text('Salt Pier'), findsOneWidget);
    expect(find.textContaining('Shared by Alice'), findsNWidgets(2));
    // A trip's dates tell two same-named trips apart (issue #2594 review).
    expect(find.textContaining('Mar 9 - Mar 16, 2024'), findsOneWidget);

    await tester.tap(find.text('Unhide').first);
    await tester.pumpAndSettle();
    expect(trips.unhidden, ['bonaire']);
    await tester.tap(find.text('Unhide').last);
    await tester.pumpAndSettle();
    expect(sites.unhidden, ['pier']);
  });

  testWidgets('says so when nothing is hidden', (tester) async {
    await pumpPage(tester, const []);
    expect(find.text('Nothing is hidden from this profile.'), findsOneWidget);
  });

  Future<void> pumpSection(WidgetTester tester, List<HiddenItem> hidden) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          shareByDefaultProvider.overrideWith((ref) async => false),
          hiddenItemsProvider.overrideWith((ref) async => hidden),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SharedDataSectionContent()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Shared data shows the hidden row with its count', (
    tester,
  ) async {
    await pumpSection(tester, items);
    expect(find.text('Hidden from this profile'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Shared data has no hidden row when nothing is hidden', (
    tester,
  ) async {
    await pumpSection(tester, const []);
    expect(find.text('Hidden from this profile'), findsNothing);
  });
}

class _Trips extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _Trips() : super(const AsyncValue.data([]));

  final unhidden = <String>[];

  @override
  Future<void> unhideTrip(String id) async => unhidden.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sites extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _Sites() : super(const AsyncValue.data([]));

  final unhidden = <String>[];

  @override
  Future<void> unhideSites(List<String> ids) async => unhidden.addAll(ids);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
