import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_card_preview_page.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const _sam = BuddyCard(
  id: 'diver-sam',
  name: 'Sam Rivera',
  phone: '+1 555 0134',
  dives: 118,
  certs: [BuddyCardCert(agency: 'PADI', name: 'Rescue Diver')],
);

void main() {
  late SharedPreferences prefs;
  late BuddyRepository buddies;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await DiverRepository().createDiver(
      Diver(
        id: 'me',
        name: 'Me',
        isDefault: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await prefs.setString(currentDiverIdKey, 'me');
    buddies = BuddyRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, BuddyCardDecoded decoded) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1400);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/buddies/card',
      routes: [
        GoRoute(
          path: '/buddies',
          builder: (_, _) => const Scaffold(body: Text('LIST')),
          routes: [
            GoRoute(
              path: 'card',
              builder: (_, _) => BuddyCardPreviewPage(decoded: decoded),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) =>
                  Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> seed(WidgetTester tester, String name, {String? cardId}) =>
      tester.runAsync(
        () => buddies.createBuddy(
          Buddy(
            id: '',
            diverId: 'me',
            name: name,
            cardId: cardId,
            cardDiveCount: 100,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );

  testWidgets('new card shows Add <name> as a buddy and its fields', (
    tester,
  ) async {
    await pump(tester, const BuddyCardDecoded(_sam));
    expect(find.text('Add Sam Rivera as a buddy'), findsOneWidget);
    expect(find.text('+1 555 0134'), findsOneWidget);
    expect(find.text('118'), findsOneWidget);
    expect(find.text('PADI Rescue Diver'), findsOneWidget);
    expect(find.text('Add buddy'), findsOneWidget);
  });

  testWidgets('recognised card shows Update <name> and the change list', (
    tester,
  ) async {
    await seed(tester, 'Sam R', cardId: 'diver-sam');
    await pump(tester, const BuddyCardDecoded(_sam));
    expect(find.text('Update Sam R'), findsOneWidget);
    expect(find.text('100 → 118'), findsOneWidget);
    expect(find.text('Update buddy'), findsOneWidget);
  });

  testWidgets('possible match offers Update and Add as new buddy', (
    tester,
  ) async {
    await seed(tester, 'Sam Rivera');
    await pump(tester, const BuddyCardDecoded(_sam));
    expect(find.text('Update Sam Rivera'), findsWidgets);
    expect(find.text('Add as new buddy'), findsOneWidget);
  });

  testWidgets('trimmed card shows the left-out line', (tester) async {
    await pump(tester, const BuddyCardDecoded(_sam, trimmed: true));
    expect(
      find.text('Some details were left out to fit the code.'),
      findsOneWidget,
    );
  });

  testWidgets('newer format shows the newer-app line', (tester) async {
    await pump(tester, const BuddyCardDecoded(_sam, newerFormat: true));
    expect(
      find.text(
        'This card is from a newer version of Submersion. '
        'Some details may be missing.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Discard leaves without writing', (tester) async {
    await pump(tester, const BuddyCardDecoded(_sam));
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(find.text('LIST'), findsOneWidget);
    final all = await tester.runAsync(() => buddies.getAllBuddies());
    expect(all, isEmpty);
  });

  testWidgets('Add saves the buddy and opens it', (tester) async {
    await pump(tester, const BuddyCardDecoded(_sam));
    await tester.tap(find.text('Add buddy'));
    await settle(tester);
    final all = (await tester.runAsync(() => buddies.getAllBuddies()))!;
    expect(all.single.cardId, 'diver-sam');
    expect(find.text('DETAIL ${all.single.id}'), findsOneWidget);
  });
}
