import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';

import '../../../helpers/test_app.dart';

Widget app({List<dynamic>? overrides}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: SizedBox(height: 400, child: QuickActionsCard()),
        ),
      ),
      GoRoute(
        path: '/tracks',
        builder: (context, state) => const Scaffold(body: Text('TRACKS-PAGE')),
      ),
      GoRoute(
        path: '/buddies/swap',
        builder: (context, state) => const Scaffold(body: Text('SWAP-PAGE')),
      ),
    ],
  );
  return testAppRouter(
    router: router,
    locale: const Locale('en'),
    overrides: overrides,
  );
}

void main() {
  testWidgets('Tracks quick action navigates to /tracks', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tracks'));
    await tester.pumpAndSettle();
    expect(find.text('TRACKS-PAGE'), findsOneWidget);
  });

  testWidgets('there is no Underwater Routes quick action', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.route), findsNothing);
    expect(find.textContaining('nderwater'), findsNothing);
  });

  group('Swap with a buddy (issue #4591)', () {
    testWidgets('sits between Plan Dive and Insights', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final plan = tester.getTopLeft(find.text('Plan Dive')).dy;
      final swap = tester.getTopLeft(find.text('Swap with a buddy')).dy;
      final insights = tester.getTopLeft(find.text('Insights')).dy;
      expect(plan, lessThan(swap));
      expect(swap, lessThan(insights));
    });

    testWidgets('opens the swap screen', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Swap with a buddy'));
      await tester.pumpAndSettle();
      expect(find.text('SWAP-PAGE'), findsOneWidget);
    });

    testWidgets('a browser shows no swap action', (tester) async {
      await tester.pumpWidget(
        app(
          overrides: [
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Swap with a buddy'), findsNothing);
      // The swap's gap goes with it: Plan Dive and Insights sit one 8 px
      // gap apart, as they did before the swap was added.
      Finder button(String label) => find.ancestor(
        of: find.text(label),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(
        tester.getTopLeft(button('Insights')).dy -
            tester.getBottomLeft(button('Plan Dive')).dy,
        8,
      );
    });
  });
}
