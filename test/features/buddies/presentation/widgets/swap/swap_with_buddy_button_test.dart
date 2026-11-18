import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/swap_with_buddy_button.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';

import '../../../../../helpers/global_test_defaults.dart';
import '../../../../../helpers/test_app.dart';

/// A router whose start page hosts [child] and whose `/buddies/swap` route
/// stands in for the swap screen.
GoRouter _router(Widget child) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(body: child),
    ),
    GoRoute(
      path: '/buddies/swap',
      builder: (context, state) => const Scaffold(body: Text('SWAP-PAGE')),
    ),
  ],
);

/// The buddy card swap runs over the nearby radios (with NFC and a QR code
/// beside them), none of which a browser has (issue #4121).
void main() {
  tearDown(applyGlobalTestDefaults);

  testWidgets('natively offers the swap', (tester) async {
    await tester.pumpWidget(
      testApp(locale: const Locale('en'), child: const SwapWithBuddyButton()),
    );
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
  });

  testWidgets('a browser has no radios to swap over', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        ],
        child: const SwapWithBuddyButton(),
      ),
    );
    expect(find.byIcon(Icons.swap_horiz), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('the header icon opens the swap too', (tester) async {
    await tester.pumpWidget(
      testAppRouter(
        router: _router(const SwapWithBuddyButton()),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();
    expect(find.text('SWAP-PAGE'), findsOneWidget);
  });

  group('SwapWithBuddyActionButton (issue #4591)', () {
    testWidgets('labelled button opens the swap on top of the current page', (
      tester,
    ) async {
      final router = _router(const SwapWithBuddyActionButton());
      await tester.pumpWidget(
        testAppRouter(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Swap with a buddy'));
      await tester.pumpAndSettle();
      expect(find.text('SWAP-PAGE'), findsOneWidget);
      // Pushed, not gone to: Back returns to the page the button was on.
      expect(router.canPop(), isTrue);
    });

    testWidgets('labelled button is absent in a browser, padding and all', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
          ],
          child: const Column(
            children: [
              SwapWithBuddyActionButton(
                padding: EdgeInsets.only(top: 8),
                expand: true,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(OutlinedButton), findsNothing);
      expect(tester.getSize(find.byType(SwapWithBuddyActionButton)), Size.zero);
    });

    testWidgets('demo mode explains the seal and stays put', (tester) async {
      DemoModeGate.instance.debugActive = true;
      await tester.pumpWidget(
        testAppRouter(
          router: _router(const SwapWithBuddyActionButton()),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Swap with a buddy'));
      await tester.pumpAndSettle();
      expect(find.text('Not available in demo mode'), findsOneWidget);
      expect(find.text('SWAP-PAGE'), findsNothing);
    });
  });
}
