import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final summaries = [
    DivePlanSummary(
      id: 'p1',
      name: 'Reef 30m',
      updatedAt: DateTime(2026, 7, 4),
      maxDepth: 30.0,
      mode: PlanMode.oc,
    ),
    DivePlanSummary(
      id: 'p2',
      name: 'Wreck 50m',
      updatedAt: DateTime(2026, 7, 3),
      maxDepth: 50.0,
      mode: PlanMode.ccr,
    ),
  ];

  Future<void> pump(WidgetTester tester, {List<DivePlanSummary>? plans}) =>
      tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            divePlanSummariesProvider.overrideWith(
              (ref) async => plans ?? summaries,
            ),
          ],
          locale: const Locale('en'),
          child: const SavedPlansList(),
        ),
      );

  testWidgets('groups plans by mode under an uppercase header, without a '
      'per-row mode suffix', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('OC'), findsOneWidget);
    expect(find.text('CCR'), findsOneWidget);
    expect(find.text('Reef 30m'), findsOneWidget);
    expect(find.text('Wreck 50m'), findsOneWidget);
  });

  testWidgets('shows a tappable empty state linking to the planner', (
    tester,
  ) async {
    await pump(tester, plans: const []);
    await tester.pumpAndSettle();

    expect(find.text('No saved plans yet'), findsOneWidget);
  });

  testWidgets("a single plan's link badge opens its dive in the log", (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/plans',
      routes: [
        GoRoute(
          path: '/plans',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: SavedPlansList()),
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
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          divePlanSummariesProvider.overrideWith(
            (ref) async => [
              DivePlanSummary(
                id: 'p1',
                name: 'Reef 30m',
                updatedAt: DateTime(2026, 7, 4),
                linkedDiveId: 'logged-1',
                linkedDiveNumber: 12,
              ),
            ],
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open in dive log'));
    await tester.pumpAndSettle();

    expect(find.text('DIVE logged-1'), findsOneWidget);
  });
}
