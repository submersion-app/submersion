import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/presentation/open_chart_dives.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';

/// Issue #3805: every chart link opens the dive list through this one path.
void main() {
  late ProviderContainer container;
  late ChartDiveIdsLoader load;

  Future<void> pumpOpener(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/insights',
      routes: [
        GoRoute(
          path: '/insights',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => openChartDives(
                  context,
                  ref,
                  chart: 'Water type',
                  row: 'Salt',
                  load: load,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(path: '/dives', builder: (_, _) => const Text('dive list')),
        GoRoute(path: '/other', builder: (_, _) => const Text('other page')),
      ],
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...base,
          insightsFilterProvider.overrideWith(
            (ref) => const DiveFilterState(minDepth: 18),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(TextButton)),
    );
  }

  testWidgets('opens the list with the ids and a named label', (tester) async {
    DiveFilterState? scope;
    load = (_, _, s) async {
      scope = s;
      return ['a', 'b'];
    };
    await pumpOpener(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('dive list'), findsOneWidget);
    expect(scope?.minDepth, 18);
    expect(
      container.read(diveFilterProvider),
      const DiveFilterState(
        diveIds: ['a', 'b'],
        diveIdsLabel: 'Water type: Salt',
      ),
    );
  });

  testWidgets('an empty result shows a message and opens nothing', (
    tester,
  ) async {
    load = (_, _, _) async => const [];
    await pumpOpener(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open these dives'), findsOneWidget);
    expect(find.text('dive list'), findsNothing);
  });

  testWidgets('a failed load shows a message and opens nothing', (
    tester,
  ) async {
    load = (_, _, _) async => throw StateError('no database');
    await pumpOpener(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open these dives'), findsOneWidget);
    expect(find.text('dive list'), findsNothing);
  });

  testWidgets('a page closed during the load pushes nothing', (tester) async {
    final pending = Completer<List<String>>();
    load = (_, _, _) => pending.future;
    await pumpOpener(tester);
    await tester.tap(find.text('open'));
    await tester.pump();

    GoRouter.of(tester.element(find.byType(TextButton))).go('/other');
    await tester.pumpAndSettle();
    pending.complete(['a']);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('other page'), findsOneWidget);
    expect(container.read(diveFilterProvider).diveIds, isEmpty);
  });
}
