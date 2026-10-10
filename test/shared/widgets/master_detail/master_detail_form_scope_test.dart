import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_form_scope.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// Builds a [MasterDetailScaffold] whose master pane prints what
/// [MasterDetailFormScope] tells it, inside a router at [initialLocation] so
/// query params (`?mode=new`) drive the detail pane.
Widget _buildScaffold({
  required String initialLocation,
  bool provideCreateBuilder = true,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: MasterDetailScaffold(
            sectionId: 'test',
            // A Builder, like a real list widget: the scope sits below the
            // context the scaffold hands masterBuilder.
            masterBuilder: (_, _, _) => Builder(
              builder: (context) => Text(
                'form open: ${MasterDetailFormScope.isFormOpenOf(context)}',
              ),
            ),
            detailBuilder: (_, id) => Text('Detail $id'),
            summaryBuilder: (_) => const Text('Summary'),
            editBuilder: (_, id, _, _) => Text('Edit form $id'),
            createBuilder: provideCreateBuilder
                ? (_, _, _) => const Text('Create form')
                : null,
          ),
        ),
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

void main() {
  group('MasterDetailFormScope (issue #3192)', () {
    testWidgets('reads false outside any master-detail scaffold', (
      tester,
    ) async {
      late bool formOpen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            formOpen = MasterDetailFormScope.isFormOpenOf(context);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(formOpen, isFalse);
    });

    testWidgets('tells the master pane no form is open beside the summary', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScaffold(initialLocation: '/test'));
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('form open: false'), findsOneWidget);
    });

    testWidgets('tells the master pane no form is open in view mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScaffold(initialLocation: '/test?selected=1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detail 1'), findsOneWidget);
      expect(find.text('form open: false'), findsOneWidget);
    });

    testWidgets('tells the master pane a create form is open', (tester) async {
      await tester.pumpWidget(
        _buildScaffold(initialLocation: '/test?mode=new'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create form'), findsOneWidget);
      expect(find.text('form open: true'), findsOneWidget);
    });

    testWidgets('tells the master pane an edit form is open', (tester) async {
      await tester.pumpWidget(
        _buildScaffold(initialLocation: '/test?selected=1&mode=edit'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit form 1'), findsOneWidget);
      expect(find.text('form open: true'), findsOneWidget);
    });

    testWidgets('reads false for ?mode=new when no create form is built', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScaffold(
          initialLocation: '/test?mode=new',
          provideCreateBuilder: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create form'), findsNothing);
      expect(find.text('form open: false'), findsOneWidget);
    });
  });
}
