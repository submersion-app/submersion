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

/// The edit form rebuilds the buddy with the full constructor on save, as it
/// did when it dropped the favourite flag (#638). The buddy card figures
/// (issue #3728) have no form field either and must survive an edit.
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

  testWidgets('saving an edit keeps the buddy card fields', (tester) async {
    final repo = BuddyRepository();
    final buddy = await repo.createBuddy(
      Buddy(
        id: '',
        diverId: ownerId,
        name: 'Sam',
        cardId: 'diver-sam',
        cardDiveCount: 118,
        cardDivingSince: DateTime(2016),
        cardLastDive: DateTime(2026, 10, 3),
        cardReceivedAt: DateTime(2026, 10, 28),
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    String? savedId;
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
              buddyId: buddy.id,
              embedded: true,
              onSaved: (id) => savedId = id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Sam'), 'Sammy');
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 30 && savedId == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final read = await tester.runAsync(() => repo.getBuddyById(buddy.id));
    expect(read!.name, 'Sammy');
    expect(read.cardId, 'diver-sam');
    expect(read.cardDiveCount, 118);
    expect(read.cardDivingSince, DateTime(2016));
    expect(read.cardLastDive, DateTime(2026, 10, 3));
    expect(read.cardReceivedAt, DateTime(2026, 10, 28));
  });
}
