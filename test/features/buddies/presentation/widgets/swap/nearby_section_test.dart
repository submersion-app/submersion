import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/nearby_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _sam = NearbyCardPeer(swapId: 's', name: 'Sam de la Rivera');

Future<void> _pump(
  WidgetTester tester, {
  NearbyAvailability? availability = NearbyAvailability.ready,
  bool failed = false,
  List<NearbyCardPeer> peers = const [_sam],
  Set<String> waitingFor = const {},
  ValueChanged<NearbyCardPeer>? onTap,
  VoidCallback? onRetry,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(
          children: [
            NearbySection(
              availability: availability,
              failed: failed,
              peers: peers,
              waitingFor: waitingFor,
              onTap: onTap ?? (_) {},
              onRetry: onRetry ?? () {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The nearby part of the swap screen (issues #3728, #4598).
void main() {
  testWidgets('a diver without a photo shows the same initials as their '
      'buddy page will', (tester) async {
    await _pump(tester);
    // First and last name, as Buddy.initials gives.
    expect(find.text('SR'), findsOneWidget);
  });

  testWidgets('tapping a diver calls back with them', (tester) async {
    NearbyCardPeer? tapped;
    await _pump(tester, onTap: (peer) => tapped = peer);
    expect(find.text('Nearby'), findsOneWidget);
    expect(find.text('Swap'), findsOneWidget);
    await tester.tap(find.text('Sam de la Rivera'));
    expect(tapped?.swapId, 's');
  });

  testWidgets('a diver already asked shows Waiting, no Swap, and ignores '
      'taps', (tester) async {
    var taps = 0;
    await _pump(tester, waitingFor: {'s'}, onTap: (_) => taps++);
    expect(find.text('Waiting for Sam de la Rivera to answer'), findsOneWidget);
    expect(find.text('Swap'), findsNothing);
    await tester.tap(find.text('Sam de la Rivera'));
    expect(taps, 0);
  });

  testWidgets('the looking line carries the version hint', (tester) async {
    await _pump(tester, peers: const []);
    expect(
      find.text(
        'Looking for divers. Your buddy needs this screen open and '
        'Submersion 1.8.4 or later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Bluetooth off shows the message and Try again calls back', (
    tester,
  ) async {
    var retries = 0;
    await _pump(
      tester,
      availability: NearbyAvailability.bluetoothOff,
      onRetry: () => retries++,
    );
    expect(
      find.text('Turn on Bluetooth to find nearby devices.'),
      findsOneWidget,
    );
    expect(find.text('Sam de la Rivera'), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('unsupported offers no Try again', (tester) async {
    await _pump(tester, availability: NearbyAvailability.unsupported);
    expect(
      find.text('This device has no Bluetooth that Submersion can use.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a start that failed says so with Try again', (tester) async {
    await _pump(tester, availability: null, failed: true);
    expect(
      find.textContaining('Could not look for nearby divers'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('still starting shows a spinner, not the list', (tester) async {
    await _pump(tester, availability: null);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sam de la Rivera'), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('permission refused on a phone offers Open settings', (
    tester,
  ) async {
    await _pump(tester, availability: NearbyAvailability.unauthorized);
    expect(find.text('Try again'), findsOneWidget);
    // No settings plugin in a test: the tap must not throw.
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
