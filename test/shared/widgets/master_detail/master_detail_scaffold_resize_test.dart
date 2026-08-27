import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// Builds a [MasterDetailScaffold] at desktop width with a single item.
Widget _app() {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => MasterDetailScaffold(
          sectionId: 'test',
          masterBuilder: (context, onSelect, selectedId) =>
              const Text('Master'),
          detailBuilder: (_, id) => Text('Detail $id'),
          summaryBuilder: (_) => const Text('Summary'),
        ),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

/// Builds an app with two routes, each a [MasterDetailScaffold] for a
/// different section, sharing one [GoRouter] so navigation between them can
/// be driven from the test.
(Widget, GoRouter) _twoSectionApp() {
  final router = GoRouter(
    initialLocation: '/a',
    routes: [
      GoRoute(
        path: '/a',
        builder: (context, state) => MasterDetailScaffold(
          sectionId: 'a',
          masterBuilder: (context, onSelect, selectedId) =>
              const Text('Master A'),
          detailBuilder: (_, id) => Text('Detail $id'),
          summaryBuilder: (_) => const Text('Summary A'),
        ),
      ),
      GoRoute(
        path: '/b',
        builder: (context, state) => MasterDetailScaffold(
          sectionId: 'b',
          masterBuilder: (context, onSelect, selectedId) =>
              const Text('Master B'),
          detailBuilder: (_, id) => Text('Detail $id'),
          summaryBuilder: (_) => const Text('Summary B'),
        ),
      ),
    ],
  );

  final app = ProviderScope(
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  return (app, router);
}

double _masterPaneWidth(WidgetTester tester) {
  return tester
      .widget<SizedBox>(find.byKey(const Key('master-detail-master-pane')))
      .width!;
}

/// Sets a real 1200x800 desktop viewport (not just a MediaQuery override) so
/// the master pane's LayoutBuilder sees the width this test expects.
void _setDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('MasterDetailScaffold resize', () {
    testWidgets('dragging the divider right widens the master pane', (
      tester,
    ) async {
      _setDesktopViewport(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final initialWidth = _masterPaneWidth(tester);

      await tester.drag(
        find.byKey(const Key('master-detail-resize-handle')),
        const Offset(80, 0),
      );
      await tester.pump();

      // tester.drag() can split the movement into several update events with
      // touch-slop compensation that isn't pixel-exact, so allow a small
      // tolerance rather than asserting the delta precisely.
      expect(_masterPaneWidth(tester), closeTo(initialWidth + 80, 5));
    });

    testWidgets('dragging the divider left narrows the master pane', (
      tester,
    ) async {
      _setDesktopViewport(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final initialWidth = _masterPaneWidth(tester);

      await tester.drag(
        find.byKey(const Key('master-detail-resize-handle')),
        const Offset(-80, 0),
      );
      await tester.pump();

      expect(_masterPaneWidth(tester), closeTo(initialWidth - 80, 5));
    });

    testWidgets('drag past the minimum clamps the master pane width', (
      tester,
    ) async {
      _setDesktopViewport(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('master-detail-resize-handle')),
        const Offset(-1000, 0),
      );
      await tester.pump();

      expect(_masterPaneWidth(tester), 280);
    });

    testWidgets('drag past the maximum clamps the master pane width', (
      tester,
    ) async {
      _setDesktopViewport(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('master-detail-resize-handle')),
        const Offset(1000, 0),
      );
      await tester.pump();

      // Window is 1200 wide; max is min(700, 1200 - 400) = 700.
      expect(_masterPaneWidth(tester), 700);
    });

    testWidgets(
      'resized width carries over when navigating to another section',
      (tester) async {
        _setDesktopViewport(tester);
        final (app, router) = _twoSectionApp();
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const Key('master-detail-resize-handle')),
          const Offset(80, 0),
        );
        await tester.pump();
        final resizedWidth = _masterPaneWidth(tester);
        expect(resizedWidth, isNot(kMasterPaneWidth));

        router.go('/b');
        await tester.pumpAndSettle();

        expect(find.text('Summary B'), findsOneWidget);
        expect(_masterPaneWidth(tester), resizedWidth);
      },
    );
  });
}
