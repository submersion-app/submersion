import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_panel.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';

import '../../../helpers/test_app.dart';

Widget app({List<dynamic>? overrides, WidgetBuilder? body}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body:
              body?.call(context) ??
              const SizedBox(height: 400, child: QuickActionsCard()),
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

  // Issue #5003: the card returns, as it was, as an optional Home panel.
  testWidgets('shows all six original actions in order', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Quick Actions'), findsOneWidget);
    final labels = [
      'Log Dive',
      'Plan Dive',
      'Swap with a buddy',
      'Insights',
      'Tracks',
      'Emergency card',
    ];
    final tops = [for (final l in labels) tester.getTopLeft(find.text(l)).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i - 1], lessThan(tops[i]), reason: labels[i]);
    }
  });

  for (final (width, scale) in [(320.0, 2.0), (320.0, 1.0), (420.0, 1.0)]) {
    testWidgets(
      'quick actions card fits its row at $width wide, text scale $scale',
      (tester) async {
        await tester.pumpWidget(
          app(
            body: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Builder(
                builder: (context) => Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    height: homeRowHeight(HomePanelHeight.extraTall, context),
                    child: const QuickActionsCard(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Emergency card'), findsOneWidget);
      },
    );
  }
}
