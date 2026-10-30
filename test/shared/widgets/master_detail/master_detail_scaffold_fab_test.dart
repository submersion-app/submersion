import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// Builds a [MasterDetailScaffold] with an "Add Item" FAB inside a router at
/// [initialLocation], so query params (`?mode=new`) drive the detail pane.
///
/// The desktop (master-detail) layout requires width >= 800.
Widget _buildScaffold({
  required String initialLocation,
  bool provideCreateBuilder = true,
  double width = 1200,
  Widget? fab,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: MasterDetailScaffold(
            sectionId: 'test',
            masterBuilder: (_, _, _) => const Text('Master'),
            detailBuilder: (_, id) => Text('Detail $id'),
            summaryBuilder: (_) => const Text('Summary'),
            editBuilder: (_, id, _, _) => Text('Edit form $id'),
            createBuilder: provideCreateBuilder
                ? (_, _, _) => const Text('Create form')
                : null,
            floatingActionButton:
                fab ??
                FloatingActionButton.extended(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
          ),
        ),
      ),
      GoRoute(
        path: '/test/new',
        builder: (_, _) => const Scaffold(body: Text('Full-page create')),
      ),
    ],
  );
  addTearDown(router.dispose);

  return ProviderScope(
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

class _OwnFab extends StatelessWidget implements MasterDetailCreateFab {
  const _OwnFab({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget withOnPressed(VoidCallback onPressed) => _OwnFab(onPressed: onPressed);

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: onPressed, child: const Text('Own button'));
}

void main() {
  group('MasterDetailScaffold create FAB (issue #3174)', () {
    testWidgets('shows beside the summary', (tester) async {
      await tester.pumpWidget(_buildScaffold(initialLocation: '/test'));
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);
    });

    testWidgets('shows beside an item in view mode', (tester) async {
      await tester.pumpWidget(
        _buildScaffold(initialLocation: '/test?selected=1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detail 1'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);
    });

    testWidgets('is hidden while the create form is open', (tester) async {
      await tester.pumpWidget(
        _buildScaffold(initialLocation: '/test?mode=new'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create form'), findsOneWidget);
      expect(find.text('Add Item'), findsNothing);
    });

    testWidgets('is hidden while an edit form is open', (tester) async {
      await tester.pumpWidget(
        _buildScaffold(initialLocation: '/test?selected=1&mode=edit'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit form 1'), findsOneWidget);
      expect(find.text('Add Item'), findsNothing);
    });

    testWidgets('comes back once the create form is cancelled', (tester) async {
      await tester.pumpWidget(
        _buildScaffold(initialLocation: '/test?mode=new'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Item'), findsNothing);

      GoRouter.of(tester.element(find.text('Create form'))).go('/test');
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);
    });

    testWidgets('shows when ?mode=new has no create pane to open', (
      tester,
    ) async {
      // With no createBuilder the pane falls back to the summary, so there
      // is no form for the FAB to sit beside.
      await tester.pumpWidget(
        _buildScaffold(
          initialLocation: '/test?mode=new',
          provideCreateBuilder: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);
    });

    testWidgets('shows on the phone list, which never holds a form', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScaffold(initialLocation: '/test', width: 400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Master'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);
    });
  });

  group('MasterDetailScaffold with a MasterDetailCreateFab', () {
    for (final width in <double>[1200, 400]) {
      testWidgets('takes the create handler unwrapped at $width px', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _buildScaffold(
            initialLocation: '/test',
            width: width,
            fab: const _OwnFab(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Create new item'), findsNothing);
        expect(
          find.ancestor(
            of: find.text('Own button'),
            matching: find.byWidgetPredicate(
              (w) => w is AbsorbPointer && w.absorbing,
            ),
          ),
          findsNothing,
        );
        final button = tester.widget<TextButton>(find.byType(TextButton));
        expect(button.onPressed, isNotNull);
        semantics.dispose();
      });
    }

    testWidgets('opens the create pane when pressed', (tester) async {
      await tester.pumpWidget(
        _buildScaffold(initialLocation: '/test', fab: const _OwnFab()),
      );
      await tester.pumpAndSettle();

      tester.widget<TextButton>(find.byType(TextButton)).onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('Create form'), findsOneWidget);
    });
  });
}
