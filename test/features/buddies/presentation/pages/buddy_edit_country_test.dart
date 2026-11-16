import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The buddy edit page's Country field (issue #4457).
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

  Future<String> createBuddy({String? country}) async =>
      (await BuddyRepository().createBuddy(
        Buddy(
          id: '',
          diverId: ownerId,
          name: 'Marco',
          country: country,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      )).id;

  Future<void> pumpEdit(
    WidgetTester tester,
    String buddyId, {
    void Function(String id)? onSaved,
  }) async {
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
          home: Scaffold(
            body: BuddyEditPage(
              buddyId: buddyId,
              embedded: true,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder countryField() => find.widgetWithText(TextFormField, 'Country');

  testWidgets('the field shows the stored country', (tester) async {
    final id = await tester.runAsync(() => createBuddy(country: 'Malta'));
    await pumpEdit(tester, id!);
    expect(countryField(), findsOneWidget);
    expect(find.text('Malta'), findsOneWidget);
  });

  testWidgets('the field sits after the social handle', (tester) async {
    final id = await tester.runAsync(() => createBuddy());
    await pumpEdit(tester, id!);
    final social = tester.getTopLeft(
      find.widgetWithText(TextFormField, 'Social handle'),
    );
    final country = tester.getTopLeft(countryField());
    expect(country.dy, greaterThan(social.dy));
  });

  testWidgets('typing offers matching countries', (tester) async {
    final id = await tester.runAsync(() => createBuddy());
    await pumpEdit(tester, id!);
    await tester.enterText(countryField(), 'Ita');
    await tester.pumpAndSettle();
    expect(find.text('Italy'), findsWidgets);
  });

  testWidgets('saving stores the country and the code read from it', (
    tester,
  ) async {
    final id = await tester.runAsync(() => createBuddy());
    String? savedId;
    await pumpEdit(tester, id!, onSaved: (saved) => savedId = saved);
    await tester.enterText(countryField(), 'Italy');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 30 && savedId == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final read = await tester.runAsync(
      () => BuddyRepository().getBuddyById(id),
    );
    expect(read!.country, 'Italy');
    expect(read.countryCode, 'IT');
  });

  testWidgets('submitting the field takes the first suggestion', (
    tester,
  ) async {
    final id = await tester.runAsync(() => createBuddy());
    await pumpEdit(tester, id!);
    await tester.enterText(countryField(), 'Ital');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(countryField()).controller!.text,
      'Italy',
    );
  });
}
