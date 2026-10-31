import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const _switchLabel = 'Leave out of buddy rankings';
const _detailLine = 'Left out of buddy rankings';

/// Issue #3624: the form sets the rankings exclusion and the detail page says
/// when it is on.
void main() {
  late BuddyRepository buddyRepo;
  late SharedPreferences prefs;
  late String ownerId;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    buddyRepo = BuddyRepository();
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

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Buddy> buddyNamed(String name, {bool excluded = false}) =>
      buddyRepo.createBuddy(
        Buddy(
          id: '',
          diverId: ownerId,
          name: name,
          excludedFromRankings: excluded,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );

  Widget form({
    String? buddyId,
    List<Buddy>? mergeBuddies,
    void Function(String)? onSaved,
  }) => ProviderScope(
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
          mergeBuddies: mergeBuddies,
          embedded: true,
          onSaved: onSaved,
        ),
      ),
    ),
  );

  Finder rankingSwitch() => find.widgetWithText(SwitchListTile, _switchLabel);

  bool switchValue(WidgetTester tester) =>
      tester.widget<SwitchListTile>(rankingSwitch()).value;

  Future<void> flip(WidgetTester tester) async {
    await tester.ensureVisible(rankingSwitch());
    await tester.pumpAndSettle();
    await tester.tap(rankingSwitch());
    await tester.pump();
  }

  /// Bounded pumps until the page reports completion, as the linked profile
  /// tests do: pumpAndSettle would wait out the success snackbar's timer.
  Future<void> save(WidgetTester tester, ValueGetter<bool> done) async {
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 30 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('the form', () {
    testWidgets('a new buddy starts ranked and can be excluded', (
      tester,
    ) async {
      String? savedId;
      await tester.pumpWidget(form(onSaved: (id) => savedId = id));
      await tester.pumpAndSettle();

      expect(switchValue(tester), isFalse);

      await tester.enterText(find.byType(TextFormField).first, 'Unknown');
      await flip(tester);
      expect(switchValue(tester), isTrue);
      await save(tester, () => savedId != null);

      final saved = await tester.runAsync(
        () => buddyRepo.getBuddyById(savedId!),
      );
      expect(saved?.excludedFromRankings, isTrue);
    });

    testWidgets('an unrelated edit keeps the exclusion', (tester) async {
      final buddy = await buddyNamed('Unknown', excluded: true);
      String? savedId;
      await tester.pumpWidget(
        form(buddyId: buddy.id, onSaved: (id) => savedId = id),
      );
      await tester.pumpAndSettle();

      expect(switchValue(tester), isTrue);

      await tester.enterText(find.byType(TextFormField).first, 'Unknown 2');
      await save(tester, () => savedId != null);

      final saved = await tester.runAsync(
        () => buddyRepo.getBuddyById(buddy.id),
      );
      expect(saved?.name, 'Unknown 2');
      expect(saved?.excludedFromRankings, isTrue);
    });

    testWidgets('turning it off ranks the buddy again', (tester) async {
      final buddy = await buddyNamed('Anna', excluded: true);
      String? savedId;
      await tester.pumpWidget(
        form(buddyId: buddy.id, onSaved: (id) => savedId = id),
      );
      await tester.pumpAndSettle();

      await flip(tester);
      await save(tester, () => savedId != null);

      final saved = await tester.runAsync(
        () => buddyRepo.getBuddyById(buddy.id),
      );
      expect(saved?.excludedFromRankings, isFalse);
    });

    testWidgets('a merge starts ranked when any buddy is ranked', (
      tester,
    ) async {
      final anna = await buddyNamed('Anna');
      final unknown = await buddyNamed('Unknown', excluded: true);
      await tester.pumpWidget(form(mergeBuddies: [unknown, anna]));
      await tester.pumpAndSettle();

      expect(switchValue(tester), isFalse);
    });

    testWidgets('a merge starts excluded when every buddy is excluded', (
      tester,
    ) async {
      final one = await buddyNamed('Unknown', excluded: true);
      final two = await buddyNamed('No Name', excluded: true);
      await tester.pumpWidget(form(mergeBuddies: [one, two]));
      await tester.pumpAndSettle();

      expect(switchValue(tester), isTrue);
    });
  });

  group('the detail page', () {
    Future<void> pumpDetail(WidgetTester tester, Buddy buddy) async {
      tester.view.devicePixelRatio = 1.0;
      // Wide enough for the shared dives header, which overflows on a phone.
      tester.view.physicalSize = const Size(800, 2000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(
              buddy.id,
            ).overrideWith((ref) async => const BuddyStats(totalDives: 3)),
            diveIdsForBuddyProvider(
              buddy.id,
            ).overrideWith((ref) async => const []),
            divesForBuddyProvider(
              buddy.id,
            ).overrideWith((ref) async => const []),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyDetailPage(buddyId: buddy.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Buddy detailBuddy({required bool excluded}) => Buddy(
      id: 'buddy-1',
      name: 'Unknown',
      excludedFromRankings: excluded,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    testWidgets('says so when the buddy is left out', (tester) async {
      await pumpDetail(tester, detailBuddy(excluded: true));

      expect(find.text(_detailLine), findsOneWidget);
    });

    testWidgets('says nothing for a ranked buddy', (tester) async {
      await pumpDetail(tester, detailBuddy(excluded: false));

      expect(find.text(_detailLine), findsNothing);
    });
  });
}
