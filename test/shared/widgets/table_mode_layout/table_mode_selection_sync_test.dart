import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';

/// Settings notifier that never touches the database.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Issue #2982: with the details pane open, a table row selection reached the
/// detail pane only after a fixed 500ms debounce, so every click lagged.
void main() {
  late ValueNotifier<String?> highlighted;
  late GoRouter router;

  // The state of the top route: a pushed page's location, where the
  // delegate's configuration keeps reporting the base route under it.
  String location() => router.state.uri.toString();

  Future<void> pumpLayout(
    WidgetTester tester, {
    String initialLocation = '/test',
  }) async {
    highlighted = ValueNotifier<String?>(null);
    addTearDown(highlighted.dispose);

    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/test',
          builder: (context, state) => MediaQuery(
            data: const MediaQueryData(size: Size(1400, 900)),
            child: ValueListenableBuilder<String?>(
              valueListenable: highlighted,
              builder: (context, id, _) => TableModeLayout(
                sectionKey: 'dives',
                appBarTitle: 'Dives',
                tableContent: const Text('Table Content'),
                detailBuilder: (_, id) => Text('Detail $id'),
                summaryBuilder: (_) => const Text('Summary'),
                selectedId: id,
                onEntitySelected: (id) => highlighted.value = id,
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  Text('Full page ${state.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          tableDetailsPaneProvider('dives').overrideWith((_) => true),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a row selection opens in the detail pane on the next frame', (
    tester,
  ) async {
    await pumpLayout(tester);
    expect(find.text('Summary'), findsOneWidget);

    highlighted.value = 'a';
    // One frame rebuilds the table with the new highlight, the next shows the
    // detail pane for the route the first one went to. No timer is involved.
    await tester.pump();
    await tester.pump();

    expect(location(), '/test?selected=a');
    expect(find.text('Detail a'), findsOneWidget);
  });

  testWidgets('stepping through rows follows each selection without delay', (
    tester,
  ) async {
    await pumpLayout(tester);

    for (final id in ['a', 'b', 'c', 'b']) {
      highlighted.value = id;
      await tester.pump();
      await tester.pump();
      expect(location(), '/test?selected=$id');
      expect(find.text('Detail $id'), findsOneWidget);
    }
  });

  testWidgets('a double-tap push is not clobbered by the selection sync', (
    tester,
  ) async {
    await pumpLayout(tester);

    // First tap's pointer-down highlights the row; the second tap of the
    // double-tap pushes the full page well inside kDoubleTapTimeout.
    highlighted.value = 'a';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    router.push('/test/a');
    await tester.pumpAndSettle();

    // Long after any former debounce would have fired.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(location(), '/test/a');
    expect(find.text('Full page a'), findsOneWidget);
  });

  testWidgets('clearing the highlight closes the detail pane', (tester) async {
    await pumpLayout(tester);

    highlighted.value = 'a';
    await tester.pump();
    await tester.pump();
    expect(find.text('Detail a'), findsOneWidget);

    highlighted.value = null;
    await tester.pump();
    await tester.pump();

    expect(location(), '/test');
    expect(find.text('Summary'), findsOneWidget);
  });

  testWidgets('does not navigate when the pane already shows the selection', (
    tester,
  ) async {
    // The embedded detail page steps to a neighbour by setting the highlight
    // and going to the route itself; the bridge must not go there again.
    await pumpLayout(tester, initialLocation: '/test?selected=a');
    var notifications = 0;
    void onRouteChange() => notifications++;
    router.routerDelegate.addListener(onRouteChange);
    addTearDown(() => router.routerDelegate.removeListener(onRouteChange));

    highlighted.value = 'a';
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(notifications, 0);
    expect(location(), '/test?selected=a');
  });
}
