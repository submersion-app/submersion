import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

const _suggestion = 'Chris has a profile here. Link this buddy to it?';

void main() {
  late BuddyRepository buddyRepo;
  late SharedPreferences prefs;
  late String ownerId;
  late String chrisId;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    buddyRepo = BuddyRepository();

    final divers = DiverRepository();
    ownerId = (await divers.createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    )).id;
    chrisId = (await divers.createDiver(
      Diver(
        id: '',
        name: 'Chris',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    )).id;
    await prefs.setString(currentDiverIdKey, ownerId);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Buddy> buddyNamed(String name, {String? linkedDiverId}) =>
      buddyRepo.createBuddy(
        Buddy(
          id: '',
          diverId: ownerId,
          linkedDiverId: linkedDiverId,
          name: name,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );

  /// Saves through the app bar action and pumps in bounded steps until the
  /// page reports completion: pumpAndSettle would wait out the success
  /// snackbar's timer and the list-notifier stream.
  Future<void> save(WidgetTester tester, ValueGetter<bool> done) async {
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 30 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Widget harness({required String buddyId, void Function(String)? onSaved}) {
    return ProviderScope(
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
    );
  }

  testWidgets(
    'shows the suggestion when the name matches a profile and links on tap',
    (tester) async {
      final buddy = await buddyNamed('Chris');
      String? savedId;
      await tester.pumpWidget(
        harness(buddyId: buddy.id, onSaved: (id) => savedId = id),
      );
      await tester.pumpAndSettle();

      expect(find.text(_suggestion), findsOneWidget);
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      expect(find.text(_suggestion), findsNothing);
      expect(find.text('Not linked'), findsNothing);

      await save(tester, () => savedId != null);
      expect(savedId, buddy.id);
      expect((await buddyRepo.getBuddyById(buddy.id))?.linkedDiverId, chrisId);
    },
  );

  testWidgets('Not now hides the suggestion without saving a link', (
    tester,
  ) async {
    final buddy = await buddyNamed('Chris');
    String? savedId;
    await tester.pumpWidget(
      harness(buddyId: buddy.id, onSaved: (id) => savedId = id),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text(_suggestion), findsNothing);
    expect(find.text('Not linked'), findsOneWidget);

    await save(tester, () => savedId != null);
    expect(savedId, buddy.id);
    expect((await buddyRepo.getBuddyById(buddy.id))?.linkedDiverId, isNull);
  });

  testWidgets('no suggestion when the profile is already linked in this list', (
    tester,
  ) async {
    await buddyNamed('C', linkedDiverId: chrisId);
    final buddy = await buddyNamed('Chris');
    await tester.pumpWidget(harness(buddyId: buddy.id));
    await tester.pumpAndSettle();
    expect(find.text(_suggestion), findsNothing);
  });

  testWidgets('refuses a link another buddy already holds', (tester) async {
    await buddyNamed('C', linkedDiverId: chrisId);
    final buddy = await buddyNamed('Chris');
    await tester.pumpWidget(harness(buddyId: buddy.id));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('buddy_edit_linked_profile')));
    await tester.pumpAndSettle();
    // The sheet lists the other profile; the page title also says Chris,
    // so pick the tile inside the sheet.
    await tester.tap(find.widgetWithText(ListTile, 'Chris').last);
    await tester.pumpAndSettle();

    await save(
      tester,
      () => find
          .text('C is already linked to this profile.')
          .evaluate()
          .isNotEmpty,
    );
    expect(find.text('C is already linked to this profile.'), findsOneWidget);
    expect((await buddyRepo.getBuddyById(buddy.id))?.linkedDiverId, isNull);
  });

  testWidgets('a linked buddy shows the profile name and can clear it', (
    tester,
  ) async {
    final buddy = await buddyNamed('Chris', linkedDiverId: chrisId);
    String? savedId;
    await tester.pumpWidget(
      harness(buddyId: buddy.id, onSaved: (id) => savedId = id),
    );
    await tester.pumpAndSettle();
    expect(find.text(_suggestion), findsNothing);
    expect(find.text('Not linked'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Not linked'), findsOneWidget);

    await save(tester, () => savedId != null);
    expect(savedId, buddy.id);
    expect((await buddyRepo.getBuddyById(buddy.id))?.linkedDiverId, isNull);
  });
}
