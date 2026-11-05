import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/utils/saved_plan_rows.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_series_dive_lines.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Each dive's line in the saved plans list links to its entry in the log
/// (issue #3565, phase 2b).
void main() {
  final day = DateTime.utc(2026, 11, 4);

  DivePlanSummary dive(
    String id, {
    String? linkedDiveId,
    bool linkedDiveIsPlanned = false,
    int? linkedDiveNumber,
  }) => DivePlanSummary(
    id: id,
    name: 'Reef day',
    updatedAt: day,
    seriesId: 's1',
    linkedDiveId: linkedDiveId,
    linkedDiveIsPlanned: linkedDiveIsPlanned,
    linkedDiveNumber: linkedDiveNumber,
  );

  Future<void> pump(WidgetTester tester, List<DivePlanSummary> dives) async {
    final router = GoRouter(
      initialLocation: '/plans',
      routes: [
        GoRoute(
          path: '/plans',
          builder: (context, _) => Scaffold(
            body: SavedSeriesDiveLines(
              row: SavedPlanRow(plan: dives.first, dives: dives),
              units: const UnitFormatter(AppSettings()),
              onOpen: (_) {},
              onOpenInLog: (id) => context.push('/dives/$id'),
            ),
          ),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (_, state) => Text('DIVE ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a dive in the log as planned opens its entry there', (
    tester,
  ) async {
    await pump(tester, [
      dive('a'),
      dive('b', linkedDiveId: 'entry-b', linkedDiveIsPlanned: true),
    ]);

    expect(find.text('Waiting for the dive'), findsOneWidget);
    await tester.tap(find.byTooltip('Open in dive log'));
    await tester.pumpAndSettle();

    expect(find.text('DIVE entry-b'), findsOneWidget);
  });

  testWidgets('a dived dive opens its logged dive', (tester) async {
    await pump(tester, [
      dive('a', linkedDiveId: 'logged-a', linkedDiveNumber: 12),
      dive('b'),
    ]);

    await tester.tap(find.text('Dived as #12'));
    await tester.pumpAndSettle();

    expect(find.text('DIVE logged-a'), findsOneWidget);
  });

  testWidgets('a dive not in the log has nothing to open', (tester) async {
    await pump(tester, [dive('a'), dive('b')]);

    expect(find.byTooltip('Open in dive log'), findsNothing);
  });

  testWidgets('a series row counts the dives dived once any are', (
    tester,
  ) async {
    late String none;
    late String some;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            const units = UnitFormatter(AppSettings());
            none = savedPlanRowSubtitle(
              context,
              SavedPlanRow(plan: dive('a'), dives: [dive('a'), dive('b')]),
              units,
            );
            some = savedPlanRowSubtitle(
              context,
              SavedPlanRow(
                plan: dive('a'),
                dives: [
                  dive('a', linkedDiveId: 'd1', linkedDiveNumber: 7),
                  dive('b', linkedDiveId: 'd2', linkedDiveIsPlanned: true),
                  dive('c'),
                ],
              ),
              units,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(none, startsWith('2 dives'));
    expect(some, startsWith('1 of 3 dived'));
  });
}
