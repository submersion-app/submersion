import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_builder.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card_share_choices.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_swap_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_card_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_swap_providers.dart';
import 'package:submersion/features/buddies/presentation/services/buddy_swap_session.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/mock_providers.dart';

class _FakeSession implements BuddySwapSession {
  _FakeSession(this.availability);

  final NearbyAvailability availability;
  Completer<void>? holdStart;

  /// Thrown by the next start, as a platform error would be.
  Object? startError;
  final controller = StreamController<NearbyCardEvent>.broadcast();
  final requested = <String>[];
  var starts = 0;
  var stops = 0;
  @override
  List<NearbyCardPeer> peers = [];

  @override
  Stream<NearbyCardEvent> get events => controller.stream;

  @override
  Future<NearbyAvailability> start() async {
    starts++;
    await holdStart?.future;
    final error = startError;
    if (error != null) {
      startError = null;
      throw error;
    }
    return availability;
  }

  @override
  Future<void> request(NearbyCardPeer peer) async => requested.add(peer.name);

  @override
  Future<void> stop() async => stops++;

  void see(List<NearbyCardPeer> seen) {
    peers = seen;
    controller.add(CardPeersChanged(seen));
  }
}

const _me = BuddyCard(
  id: 'me',
  name: 'Jordan Blake',
  phone: '+1 555 0199',
  certs: [BuddyCardCert(agency: 'PADI', name: 'Advanced Open Water Diver')],
  dives: 342,
);

const _sam = NearbyCardPeer(
  swapId: 's1',
  name: 'Sam Rivera',
  transportId: 't1',
);

const _alex = NearbyCardPeer(swapId: 'a1', name: 'Alex Kim', transportId: 't2');

/// The nearby list animates a spinner forever, so pumpAndSettle never
/// settles; pump a bounded while instead.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _FakeSession session;

  Future<void> pump(
    WidgetTester tester, {
    NearbyAvailability availability = NearbyAvailability.ready,
    Future<Uint8List?> Function()? pickFile,
    Future<BuddyCard?> Function()? card,
    Completer<void>? holdStart,
    double width = 500,
  }) async {
    session = _FakeSession(availability)..holdStart = holdStart;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1200);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/buddies/swap',
      routes: [
        GoRoute(
          path: '/buddies',
          builder: (_, _) => const Scaffold(body: Text('LIST')),
          routes: [
            GoRoute(path: 'swap', builder: (_, _) => const BuddySwapPage()),
            GoRoute(
              path: 'card',
              builder: (_, state) => Scaffold(
                body: Text(
                  'PREVIEW ${(state.extra as BuddyCardDecoded).card.name}',
                ),
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          myBuddyCardProvider.overrideWith(
            (ref) => card == null ? Future.value(_me) : card(),
          ),
          myBuddyCardChoicesProvider.overrideWith(
            (ref) async => BuddyCardShareChoices.defaults,
          ),
          myBuddyCardFieldsProvider.overrideWith(
            (ref) async => {
              BuddyCardField.phone,
              BuddyCardField.certifications,
              BuddyCardField.diveCount,
            },
          ),
          buddySwapSessionFactoryProvider.overrideWithValue((_) => session),
          buddyCardFilePickerProvider.overrideWithValue(
            pickFile ?? () async => null,
          ),
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

  testWidgets('lists nearby divers and tapping one requests a swap', (
    tester,
  ) async {
    await pump(tester);
    session.see([_sam]);
    await settle(tester);
    expect(find.text('Sam Rivera'), findsOneWidget);
    await tester.tap(find.text('Sam Rivera'));
    await settle(tester);
    expect(session.requested, ['Sam Rivera']);
  });

  testWidgets('a request shows the sheet; Swap accepts', (tester) async {
    await pump(tester);
    bool? answer;
    session.controller.add(CardRequested(_sam, (a) => answer = a));
    await settle(tester);
    expect(find.text('Sam Rivera wants to swap cards'), findsOneWidget);
    expect(find.textContaining("You'll send:"), findsOneWidget);
    // The nearby rows say Swap too; the sheet's answer is the filled one.
    await tester.tap(find.widgetWithText(FilledButton, 'Swap'));
    await settle(tester);
    expect(answer, isTrue);
  });

  testWidgets('a request shows the sheet; Decline declines', (tester) async {
    await pump(tester);
    bool? answer;
    session.controller.add(CardRequested(_sam, (a) => answer = a));
    await settle(tester);
    await tester.tap(find.text('Decline'));
    await settle(tester);
    expect(answer, isFalse);
  });

  testWidgets('a received card opens the preview', (tester) async {
    await pump(tester);
    session.controller.add(
      CardReceived(
        _sam,
        BuddyCardCodec.encodeFull(const BuddyCard(id: 'x', name: 'Sam Rivera')),
      ),
    );
    await settle(tester);
    expect(find.text('PREVIEW Sam Rivera'), findsOneWidget);
  });

  testWidgets('a declined swap says so', (tester) async {
    await pump(tester);
    session.controller.add(
      const CardSwapFailed(_sam, NearbyCardFailure.declined),
    );
    await tester.pump();
    expect(find.text('Sam Rivera declined the swap'), findsOneWidget);
  });

  testWidgets('your card lists what is shared and Edit opens the sheet', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Advanced Open Water Diver'), findsOneWidget);
    expect(find.text('342 dives'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await settle(tester);
    expect(find.text('What you share'), findsOneWidget);
  });

  testWidgets('Bluetooth refused explains and the fallbacks still show', (
    tester,
  ) async {
    await pump(tester, availability: NearbyAvailability.unauthorized);
    expect(
      find.text(
        'Submersion needs Bluetooth permission to find nearby devices.',
      ),
      findsOneWidget,
    );
    expect(find.text('Show my code'), findsOneWidget);
    expect(find.text('Scan their code'), findsOneWidget);
    expect(find.text('Send as a file'), findsOneWidget);
  });

  testWidgets('Tap an Android phone shows on iOS', (tester) async {
    await pump(tester);
    expect(find.text('Tap an Android phone'), findsOneWidget);
    expect(find.text('Receive by tap'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Receive by tap shows on Android', (tester) async {
    await pump(tester);
    expect(find.text('Receive by tap'), findsOneWidget);
    expect(find.text('Tap an Android phone'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the hint about both screens and versions shows', (tester) async {
    await pump(tester);
    expect(
      find.text(
        'Looking for divers. Your buddy needs this screen open and '
        'Submersion 1.8.4 or later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Open a card file opens the preview', (tester) async {
    await pump(
      tester,
      pickFile: () async =>
          BuddyCardCodec.encodeFull(const BuddyCard(id: 'x', name: 'Alex')),
    );
    await tester.tap(find.text('Open a card file'));
    await settle(tester);
    expect(find.text('PREVIEW Alex'), findsOneWidget);
  });

  testWidgets('leaving the page stops the session', (tester) async {
    await pump(tester);
    expect(session.stops, 0);
    GoRouter.of(tester.element(find.byType(BuddySwapPage))).go('/buddies');
    await settle(tester);
    expect(session.stops, greaterThan(0));
  });

  testWidgets('an expired request closes the sheet', (tester) async {
    await pump(tester);
    session.controller.add(CardRequested(_sam, (_) {}));
    await settle(tester);
    expect(find.text('Sam Rivera wants to swap cards'), findsOneWidget);
    session.controller.add(const CardRequestExpired(_sam));
    await settle(tester);
    expect(find.text('Sam Rivera wants to swap cards'), findsNothing);
  });

  testWidgets('an expired request closes its own sheet, not a card '
      'preview opened over it', (tester) async {
    await pump(tester);
    session.controller.add(CardRequested(_sam, (_) {}));
    await settle(tester);
    session.controller.add(
      CardReceived(
        _alex,
        BuddyCardCodec.encodeFull(const BuddyCard(id: 'a', name: 'Alex Kim')),
      ),
    );
    await settle(tester);
    expect(find.text('PREVIEW Alex Kim'), findsOneWidget);

    session.controller.add(const CardRequestExpired(_sam));
    await settle(tester);
    expect(find.text('PREVIEW Alex Kim'), findsOneWidget);
    expect(find.text('Sam Rivera wants to swap cards'), findsNothing);
  });

  testWidgets('a restart frees a row still waiting on the old session', (
    tester,
  ) async {
    await pump(tester);
    session.see([_sam]);
    await settle(tester);
    await tester.tap(find.text('Sam Rivera'));
    await settle(tester);
    expect(find.textContaining('Waiting'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    session.see([_sam]);
    await settle(tester);
    expect(find.textContaining('Waiting'), findsNothing);
  });

  testWidgets('closing the page while the session starts still stops it', (
    tester,
  ) async {
    final hold = Completer<void>();
    await pump(tester, holdStart: hold);
    GoRouter.of(tester.element(find.byType(BuddySwapPage))).go('/buddies');
    await settle(tester);
    hold.complete();
    await settle(tester);
    expect(session.stops, greaterThan(0));
  });

  testWidgets('a card that cannot be built says so, hides nearby and give, '
      'and still offers get', (tester) async {
    await pump(tester, card: () => Future.error(StateError('no diver')));
    expect(find.text('Your buddy card could not be built.'), findsOneWidget);
    expect(find.text('Scan their code'), findsOneWidget);
    expect(find.text('Open a card file'), findsOneWidget);
    expect(find.text('Nearby'), findsNothing);
    expect(find.text('Show my code'), findsNothing);
    expect(session.starts, 0);
  });

  testWidgets('no current diver shows the card failure, not a spinner', (
    tester,
  ) async {
    await pump(tester, card: () async => null);
    expect(find.text('Your buddy card could not be built.'), findsOneWidget);
    expect(find.text('Scan their code'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a card that fails to rebuild drops the old card', (
    tester,
  ) async {
    var builds = 0;
    await pump(
      tester,
      card: () async {
        builds++;
        if (builds > 1) throw StateError('database gone');
        return _me;
      },
    );
    expect(find.text('Jordan Blake'), findsOneWidget);
    ProviderScope.containerOf(
      tester.element(find.byType(BuddySwapPage)),
    ).invalidate(myBuddyCardProvider);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(builds, 2);
    expect(find.text('Your buddy card could not be built.'), findsOneWidget);
    expect(find.text('Jordan Blake'), findsNothing);
    expect(find.text('Show my code'), findsNothing);
  });

  testWidgets('two columns share no primary scroll controller', (tester) async {
    await pump(tester, width: 800);
    // Read above the columns: a primary list hides the controller below it.
    final primary = PrimaryScrollController.of(
      tester.element(
        find
            .ancestor(
              of: find.text('Nearby'),
              matching: find.byType(LayoutBuilder),
            )
            .first,
      ),
    );
    expect(primary.positions.length, lessThanOrEqualTo(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('719 wide is one column, 720 is two', (tester) async {
    await pump(tester, width: 719);
    expect(
      tester.getTopLeft(find.text('Give your card')).dx,
      tester.getTopLeft(find.text('Nearby')).dx,
    );
    await pump(tester, width: 720);
    expect(
      tester.getTopLeft(find.text('Give your card')).dx,
      greaterThan(tester.getTopLeft(find.text('Nearby')).dx),
    );
  });

  testWidgets('a card too long for a code says so', (tester) async {
    await pump(
      tester,
      card: () async => BuddyCard(id: 'me', name: 'x' * 3000),
    );
    await tester.scrollUntilVisible(
      find.text('Show my code'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Show my code'));
    await settle(tester);
    expect(
      find.text(
        'Your card is too long for a code. Try Send as a file instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('leaving and coming back while the card builds starts once', (
    tester,
  ) async {
    final card = Completer<BuddyCard?>();
    await pump(tester, card: () => card.future);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    card.complete(_me);
    await settle(tester);
    expect(session.starts, 1);
  });

  testWidgets('leaving while the card builds starts nothing', (tester) async {
    final card = Completer<BuddyCard?>();
    await pump(tester, card: () => card.future);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    card.complete(_me);
    await settle(tester);
    expect(session.starts, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
  });

  testWidgets('two requests are asked in turn; the first expiring closes '
      'its own sheet', (tester) async {
    await pump(tester);
    bool? alexAnswer;
    session.controller.add(CardRequested(_sam, (_) {}));
    session.controller.add(CardRequested(_alex, (a) => alexAnswer = a));
    await settle(tester);
    expect(find.text('Sam Rivera wants to swap cards'), findsOneWidget);
    expect(find.text('Alex Kim wants to swap cards'), findsNothing);

    session.controller.add(const CardRequestExpired(_sam));
    await settle(tester);
    expect(find.text('Sam Rivera wants to swap cards'), findsNothing);
    expect(find.text('Alex Kim wants to swap cards'), findsOneWidget);
    // The nearby rows say Swap too; the sheet's answer is the filled one.
    await tester.tap(find.widgetWithText(FilledButton, 'Swap'));
    await settle(tester);
    expect(alexAnswer, isTrue);
  });

  testWidgets('a request that expires before its turn is never shown', (
    tester,
  ) async {
    await pump(tester);
    bool? alexAnswer;
    session.controller.add(CardRequested(_sam, (_) {}));
    session.controller.add(CardRequested(_alex, (a) => alexAnswer = a));
    await settle(tester);
    session.controller.add(const CardRequestExpired(_alex));
    await settle(tester);
    await tester.tap(find.text('Decline'));
    await settle(tester);
    expect(find.text('Alex Kim wants to swap cards'), findsNothing);
    expect(alexAnswer, isFalse);
  });

  testWidgets('a start that fails says so and can be tried again', (
    tester,
  ) async {
    final hold = Completer<void>();
    await pump(tester, holdStart: hold);
    session.startError = StateError('no plugin');
    hold.complete();
    await settle(tester);
    expect(
      find.text(
        'Could not look for nearby divers. The other ways to swap still '
        'work.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    // The restart rebuilds the card through Riverpod, off the fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await settle(tester);
    expect(session.starts, 2);
    expect(find.textContaining('Could not look'), findsNothing);
  });

  testWidgets('leaving the screen closes the request sheet and declines it', (
    tester,
  ) async {
    await pump(tester);
    bool? answer;
    session.controller.add(CardRequested(_sam, (a) => answer = a));
    await settle(tester);
    expect(find.text('Sam Rivera wants to swap cards'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester);
    expect(find.text('Sam Rivera wants to swap cards'), findsNothing);
    expect(answer, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
  });

  testWidgets('in demo mode the card is not shown as a code', (tester) async {
    await pump(tester);
    DemoModeGate.instance.debugActive = true;
    addTearDown(applyGlobalTestDefaults);
    await tester.scrollUntilVisible(
      find.text('Show my code'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Show my code'));
    await settle(tester);
    expect(find.text('Your buddy card'), findsNothing);
  });

  test('platform default is restored', () {
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}
