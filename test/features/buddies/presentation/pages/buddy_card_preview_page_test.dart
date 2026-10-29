import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_importer.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_card_preview_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_card_providers.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
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

  Future<void> pump(
    WidgetTester tester,
    BuddyCardDecoded decoded, {
    BuddyCardImporter? importer,
    bool overList = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1400);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: overList ? '/buddies' : '/buddies/card',
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
          if (importer != null)
            buddyCardImporterProvider.overrideWithValue(importer),
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
    if (overList) {
      unawaited(router.push('/buddies/card'));
      await settle(tester);
    }
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
    expect(find.text('118 (was 100)'), findsOneWidget);
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

  testWidgets('Add saves the buddy and says so', (tester) async {
    await pump(tester, const BuddyCardDecoded(_sam));
    await tester.tap(find.text('Add buddy'));
    await settle(tester);
    final all = (await tester.runAsync(() => buddies.getAllBuddies()))!;
    expect(all.single.cardId, 'diver-sam');
    expect(find.text('Sam Rivera added to your buddies'), findsOneWidget);
  });

  testWidgets('a possible match shows what updating would change', (
    tester,
  ) async {
    await seed(tester, 'Sam Rivera');
    await pump(tester, const BuddyCardDecoded(_sam));
    expect(find.text('118 (was 100)'), findsOneWidget);
  });

  testWidgets('the same card again shows nothing new', (tester) async {
    await tester.runAsync(
      () => BuddyCardImporter(
        buddies: buddies,
        certifications: CertificationRepository(),
      ).addNew(_sam, diverId: 'me'),
    );
    await pump(tester, const BuddyCardDecoded(_sam));
    expect(find.text('Nothing on this card is new.'), findsOneWidget);
    expect(find.text('PADI Rescue Diver'), findsNothing);
  });

  testWidgets('your own card is not offered as a buddy', (tester) async {
    await pump(tester, const BuddyCardDecoded(BuddyCard(id: 'me', name: 'Me')));
    expect(
      find.text('This is your own card. Swap with a buddy to get theirs.'),
      findsOneWidget,
    );
    expect(find.text('Add buddy'), findsNothing);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('a card opened over another screen goes back to it after '
      'saving, with a way to the buddy', (tester) async {
    await pump(tester, const BuddyCardDecoded(_sam), overList: true);
    await tester.tap(find.text('Add buddy'));
    await settle(tester);
    // Back where the card arrived (the swap screen, on the boat), so the
    // next swap is a tap away.
    expect(find.text('LIST'), findsOneWidget);
    final all = (await tester.runAsync(() => buddies.getAllBuddies()))!;
    await tester.tap(find.text('View'));
    await settle(tester);
    expect(find.text('DETAIL ${all.single.id}'), findsOneWidget);
  });

  testWidgets('a failed save says so and stays on the preview', (tester) async {
    await pump(
      tester,
      const BuddyCardDecoded(_sam),
      importer: _FailingImporter(),
    );
    await tester.tap(find.text('Add buddy'));
    await settle(tester);
    expect(find.text('The buddy could not be saved.'), findsOneWidget);
    expect(find.text('Add buddy'), findsOneWidget);
  });
}

class _FailingImporter extends BuddyCardImporter {
  _FailingImporter()
    : super(
        buddies: BuddyRepository(),
        certifications: CertificationRepository(),
      );

  @override
  Future<Buddy> addNew(BuddyCard card, {required String diverId}) async =>
      throw StateError('disk full');
}
