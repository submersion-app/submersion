import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/buddies/presentation/utils/open_buddy_card.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/global_test_defaults.dart';

void main() {
  Future<BuildContext> pump(WidgetTester tester) async {
    late BuildContext captured;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) {
            captured = context;
            return const Scaffold(body: Text('HOME'));
          },
        ),
        GoRoute(
          path: '/buddies/card',
          builder: (_, state) => Scaffold(
            body: Text(
              'PREVIEW ${(state.extra as BuddyCardDecoded).card.name}',
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    return captured;
  }

  testWidgets('a decoded card opens the preview', (tester) async {
    final context = await pump(tester);
    openBuddyCard(
      context,
      const BuddyCardDecoded(BuddyCard(id: 'x', name: 'Sam')),
    );
    await tester.pumpAndSettle();
    expect(find.text('PREVIEW Sam'), findsOneWidget);
  });

  testWidgets('demo mode explains the seal and opens nothing', (tester) async {
    final context = await pump(tester);
    DemoModeGate.instance.debugActive = true;
    addTearDown(applyGlobalTestDefaults);
    openBuddyCard(
      context,
      const BuddyCardDecoded(BuddyCard(id: 'x', name: 'Sam')),
    );
    await tester.pumpAndSettle();
    expect(find.text('PREVIEW Sam'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a passport or other link says it is not a card', (tester) async {
    final context = await pump(tester);
    openBuddyCard(
      context,
      const BuddyCardRejected(BuddyCardRejectReason.notACard),
    );
    await tester.pump();
    expect(find.text('That is not a Submersion buddy card.'), findsOneWidget);
  });

  testWidgets('a broken card says it could not be read', (tester) async {
    final context = await pump(tester);
    openBuddyCard(
      context,
      const BuddyCardRejected(BuddyCardRejectReason.malformed),
    );
    await tester.pump();
    expect(find.text('This buddy card could not be read.'), findsOneWidget);
  });
}
