import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart'
    show NearbyErrorCode;
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';
import 'package:submersion/features/settings/presentation/pages/nearby_pair_page.dart';
import 'package:submersion/features/settings/presentation/providers/nearby_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _Manager implements NearbyLinkManager {
  NearbyAvailability availability = NearbyAvailability.ready;
  final refusals = StreamController<NearbyErrorCode>.broadcast();
  final calls = <String>[];

  /// When set, the availability check waits for it.
  Completer<void>? availabilityGate;

  @override
  Future<NearbyAvailability> checkAvailability() async {
    await availabilityGate?.future;
    return availability;
  }

  @override
  Stream<NearbyErrorCode> get pairingRefusals => refusals.stream;

  @override
  Future<void> enterPairingMode() async => calls.add('enter');

  @override
  Future<void> leavePairingMode() async => calls.add('leave');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Offer implements NearbyPairingOffer {
  _Offer({
    this.bothPopulated = false,
    this.confirmError,
    this.confirming = false,
  });

  @override
  final bool bothPopulated;

  @override
  final bool confirming;
  final Object? confirmError;
  int confirms = 0;
  int rejects = 0;
  final _confirmed = Completer<void>();

  @override
  String get peerName => 'MacBook';

  @override
  String get peerKey => 'nonce-mac';

  @override
  String get code => '482913';

  @override
  Future<void> confirm() {
    confirms++;
    final error = confirmError;
    if (error != null) return Future.error(error);
    return _confirmed.future;
  }

  void otherSideConfirmed() => _confirmed.complete();

  @override
  Future<void> reject() async => rejects++;
}

void main() {
  late _Manager manager;
  late StreamController<List<NearbyPairingOffer>> offers;

  setUp(() {
    manager = _Manager();
    offers = StreamController<List<NearbyPairingOffer>>.broadcast();
  });
  tearDown(() async {
    await offers.close();
    await manager.refusals.close();
  });

  /// A home screen with a button that opens the pairing page, so popping
  /// after a pairing is visible.
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyLinkManagerProvider.overrideWithValue(manager),
          nearbyPendingPairingsProvider.overrideWith((ref) async* {
            yield const <NearbyPairingOffer>[];
            yield* offers.stream;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NearbyPairPage(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('leaving before the Bluetooth check ends never enters pairing '
      'mode', (tester) async {
    manager.availabilityGate = Completer<void>();
    await pump(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    manager.availabilityGate!.complete();
    await tester.pumpAndSettle();
    expect(manager.calls, ['leave']);
  });

  testWidgets('shows Looking and the hint while no device is found', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Looking for devices…'), findsOneWidget);
    expect(
      find.text(
        'Open Submersion on the other device and tap Pair a device there '
        'too.',
      ),
      findsOneWidget,
    );
    expect(manager.calls, ['enter']);
  });

  testWidgets('a found device shows the grouped code and both buttons', (
    tester,
  ) async {
    await pump(tester);
    offers.add([_Offer()]);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Found MacBook. Check that it shows this code, then confirm on both.',
      ),
      findsOneWidget,
    );
    expect(find.text('482 913'), findsOneWidget);
    expect(find.text('Same code'), findsOneWidget);
    expect(find.text('Not mine'), findsOneWidget);
    expect(find.textContaining('Both devices have dives'), findsNothing);
  });

  testWidgets('both devices holding dives shows the merge notice', (
    tester,
  ) async {
    await pump(tester);
    offers.add([_Offer(bothPopulated: true)]);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Both devices have dives. Pairing merges them into one logbook.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Same code waits for the other device, then pops with a '
      'confirmation', (tester) async {
    await pump(tester);
    final offer = _Offer();
    offers.add([offer]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Same code'));
    await tester.pump();
    expect(offer.confirms, 1);
    expect(
      find.text('Waiting for the other device to confirm…'),
      findsOneWidget,
    );

    offer.otherSideConfirmed();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget, reason: 'the page closed');
    expect(find.text('Paired with MacBook'), findsOneWidget);
    expect(manager.calls, ['enter', 'leave']);
  });

  testWidgets('a pairing confirmed before the page was left waits again, '
      'and closes the page when the other device confirms', (tester) async {
    await pump(tester);
    final offer = _Offer(confirming: true);
    offers.add([offer]);
    await tester.pumpAndSettle();
    expect(
      find.text('Waiting for the other device to confirm…'),
      findsOneWidget,
    );
    expect(find.text('Same code'), findsNothing);

    offer.otherSideConfirmed();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget, reason: 'the page closed');
    expect(find.text('Paired with MacBook'), findsOneWidget);
  });

  testWidgets('a pairing the other side rejected says so and stays', (
    tester,
  ) async {
    await pump(tester);
    offers.add([_Offer(confirmError: const NearbyPairingRejected())]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Same code'));
    await tester.pumpAndSettle();
    expect(
      find.text('Pairing did not finish. Try again on both devices.'),
      findsOneWidget,
    );
    expect(find.text('Looking for devices…'), findsNothing);
    expect(find.text('Same code'), findsOneWidget);
  });

  testWidgets('Not mine rejects the pairing', (tester) async {
    await pump(tester);
    final offer = _Offer();
    offers.add([offer]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not mine'));
    await tester.pumpAndSettle();
    expect(offer.rejects, 1);
  });

  testWidgets('a device on another library is explained', (tester) async {
    await pump(tester);
    manager.refusals.add(NearbyErrorCode.differentLibrary);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'That device is on a different library, so it cannot pair with '
        'this one.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('without Bluetooth permission it asks and offers a retry', (
    tester,
  ) async {
    manager.availability = NearbyAvailability.unauthorized;
    await pump(tester);
    expect(
      find.text(
        'Submersion needs Bluetooth permission to find nearby devices.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(manager.calls, isEmpty, reason: 'pairing mode never started');

    manager.availability = NearbyAvailability.ready;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Looking for devices…'), findsOneWidget);
    expect(manager.calls, ['enter']);
  });

  testWidgets('Bluetooth off asks to turn it on', (tester) async {
    manager.availability = NearbyAvailability.bluetoothOff;
    await pump(tester);
    expect(
      find.text('Turn on Bluetooth to find nearby devices.'),
      findsOneWidget,
    );
  });

  testWidgets('leaving the page leaves pairing mode', (tester) async {
    await pump(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(manager.calls, ['enter', 'leave']);
  });
}
