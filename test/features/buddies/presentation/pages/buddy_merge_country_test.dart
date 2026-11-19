import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_merge_page.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Choosing the country when buddies are merged (issue #4457).
void main() {
  late SharedPreferences prefs;
  late String ownerId;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ownerId = (await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    )).id;
    await prefs.setString(currentDiverIdKey, ownerId);
  });
  tearDown(() async => tearDownTestDatabase());

  Future<Buddy> buddy(String name, {String? country}) =>
      BuddyRepository().createBuddy(
        Buddy(
          id: '',
          diverId: ownerId,
          name: name,
          country: country,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );

  Future<void> pumpMerge(WidgetTester tester, List<Buddy> buddies) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 2000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: BuddyMergeForm(buddies: buddies)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder countryField() => find.widgetWithText(TextFormField, 'Country');

  String countryText(WidgetTester tester) =>
      tester.widget<TextFormField>(countryField()).controller!.text;

  testWidgets('the merge starts with the country one buddy has', (
    tester,
  ) async {
    final buddies = await tester.runAsync(
      () async => [await buddy('Marco'), await buddy('M.', country: 'Italy')],
    );
    await pumpMerge(tester, buddies!);
    expect(countryText(tester), 'Italy');
  });

  testWidgets('each distinct country can be chosen', (tester) async {
    final buddies = await tester.runAsync(
      () async => [
        await buddy('Marco', country: 'Italy'),
        await buddy('M.', country: 'Malta'),
      ],
    );
    await pumpMerge(tester, buddies!);
    expect(countryText(tester), 'Italy');
    await tester.tap(
      find.descendant(
        of: countryField(),
        matching: find.byIcon(Icons.sync_alt),
      ),
    );
    await tester.pumpAndSettle();
    expect(countryText(tester), 'Malta');
  });
}
