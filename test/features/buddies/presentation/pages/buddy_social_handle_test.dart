import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A buddy's social handle (issue #3728): shown with the contact details,
/// entered on the edit page; the card figures have no field there.
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

  testWidgets('the detail page shows the social handle', (tester) async {
    final buddy = Buddy(
      id: 'b1',
      name: 'Sam',
      socialHandle: '@samdives',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1600);
    addTearDown(tester.view.reset);
    // The shared dives header overflows at phone width, as the detail
    // page's own tests note; only that file's overflow is silenced.
    final previousOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = previousOnError);
    FlutterError.onError = (details) {
      final report = details.toString();
      if (report.contains('overflowed') &&
          report.contains('buddy_shared_dives_section.dart')) {
        return;
      }
      previousOnError?.call(details);
    };
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
          buddyStatsProvider(
            buddy.id,
          ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
          diveIdsForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          buddyCertificationsProvider(buddy.id).overrideWith((ref) async => []),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BuddyDetailPage(buddyId: buddy.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('@samdives'), findsOneWidget);
  });

  testWidgets('the edit page saves the social handle and has no card fields', (
    tester,
  ) async {
    final repo = BuddyRepository();
    final buddy = await repo.createBuddy(
      Buddy(
        id: '',
        diverId: ownerId,
        name: 'Sam',
        cardDiveCount: 118,
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
    expect(find.widgetWithText(TextFormField, 'Dives'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Social handle'),
      '@sam',
    );
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 30 && savedId == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final read = await tester.runAsync(() => repo.getBuddyById(buddy.id));
    expect(read!.socialHandle, '@sam');
    expect(read.cardDiveCount, 118);
  });

  testWidgets('editing only the social handle counts as an unsaved change', (
    tester,
  ) async {
    final buddy = await BuddyRepository().createBuddy(
      Buddy(
        id: '',
        diverId: ownerId,
        name: 'Sam',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
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
            body: BuddyEditPage(buddyId: buddy.id, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    bool canPop() => tester
        .widget<PopScope<Object?>>(
          find.byWidgetPredicate((w) => w is PopScope).first,
        )
        .canPop;
    expect(canPop(), isTrue);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Social handle'),
      '@sam',
    );
    await tester.pump();
    expect(canPop(), isFalse);
  });
}
