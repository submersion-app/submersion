import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_gas_section.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/follow_dive_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final stubDive = Dive(
    id: 'dive-9',
    diveNumber: 42,
    name: 'Reef drift',
    dateTime: DateTime(2026, 7, 1, 9),
    runtime: const Duration(minutes: 45),
    maxDepth: 30.0,
  );

  List<dynamic> overrides() => [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    diveProvider.overrideWith((ref, id) async => stubDive),
  ];

  testWidgets('FollowingChip appears when following and clears on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(overrides: overrides(), child: const FollowingChip()),
    );
    // Hidden with no followed dive.
    expect(find.byType(PlanChip), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FollowingChip)),
    );
    container
        .read(planSeriesNotifierProvider.notifier)
        .followDive(
          SeriesFollow(
            loggedDives: [
              SeriesLoggedDive(
                id: 'dive-9',
                diveNumber: 42,
                name: 'Reef drift',
                start: DateTime(2026, 7, 1, 9),
                end: DateTime(2026, 7, 1, 9, 45),
              ),
            ],
          ),
          surfaceInterval: const Duration(hours: 1),
        );
    await tester.pumpAndSettle();

    // A logged dive goes by its number, as in the series bar.
    expect(find.textContaining('#42'), findsOneWidget);

    await tester.tap(find.byType(PlanChip));
    await tester.pumpAndSettle();

    expect(container.read(planSeriesNotifierProvider).follow, isNull);
    expect(find.byType(PlanChip), findsNothing);
  });

  testWidgets('logged-average SAC button fills the plan SAC rate', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides(),
          loggedAverageSacProvider.overrideWith((ref) async => 17.6),
        ],
        child: const SingleChildScrollView(child: PlanGasSection()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.textContaining('17.6');
    expect(button, findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanGasSection)),
    );
    expect(
      container.read(divePlanNotifierProvider).sacRate,
      closeTo(17.6, 0.01),
    );
    // Button hides once the plan matches the logged average. The readout
    // beside the slider now shows the plan's 17.6 L/min itself, so look for
    // the button's icon rather than the number.
    expect(find.byIcon(Icons.history), findsNothing);
  });

  testWidgets('FollowDiveSheet lists dives and follows the tapped one', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          divesProvider.overrideWith((ref) async => [stubDive]),
          diveProvider.overrideWith((ref, id) async => stubDive),
          // No profile analysis -> follows with a surface interval but no
          // tissue seed (the null-compartments branch).
          profileAnalysisProvider.overrideWith((ref, id) async => null),
        ],
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showFollowDiveSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.text('open')),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(FollowDiveSheet), findsOneWidget);
    expect(find.text('Reef drift'), findsOneWidget);

    await tester.tap(find.text('Reef drift'));
    await tester.pumpAndSettle();

    // The series follows the dive; the plan's own source dive is left for
    // replans. The dive is months old, so the interval is the default hour.
    final follow = container.read(planSeriesNotifierProvider).follow;
    expect(follow?.followed.id, 'dive-9');
    final state = container.read(divePlanNotifierProvider);
    expect(state.sourceDiveId, isNull);
    expect(state.surfaceInterval, const Duration(hours: 1));
    // The sheet closed after following.
    expect(find.byType(FollowDiveSheet), findsNothing);
  });

  testWidgets('FollowDiveSheet shows an empty state with no logged dives', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          divesProvider.overrideWith((ref) async => <Dive>[]),
        ],
        child: const FollowDiveSheet(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No logged dives yet'), findsOneWidget);
  });
}
