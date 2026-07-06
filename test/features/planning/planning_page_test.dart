import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/deco_calculator/presentation/providers/deco_calculator_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planning/presentation/pages/planning_page.dart';
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
  testWidgets('hub leads with New plan and recent saved plans', (tester) async {
    final summaries = [
      DivePlanSummary(
        id: 'p1',
        name: 'Reef 30m',
        updatedAt: DateTime(2026, 7, 4),
        maxDepth: 30.0,
        runtimeSeconds: 45 * 60,
        ttsSeconds: 300,
        mode: PlanMode.oc,
      ),
      DivePlanSummary(
        id: 'p2',
        name: 'Wreck 50m',
        updatedAt: DateTime(2026, 7, 3),
        maxDepth: 50.0,
        runtimeSeconds: 80 * 60,
        ttsSeconds: 2400,
        mode: PlanMode.ccr,
      ),
    ];

    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          divePlanSummariesProvider.overrideWith((ref) async => summaries),
        ],
        child: const PlanningPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New plan'), findsOneWidget);
    expect(find.text('Reef 30m'), findsOneWidget);
    expect(find.text('Wreck 50m'), findsOneWidget);
    expect(find.text('TOOLS'), findsOneWidget);
    // The calculators remain as tools.
    expect(find.text('Deco Calculator'), findsOneWidget);
  });

  test('deco calculator environment defaults to legacy standard water', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);

    final ndlAtSea = container.read(calcDecoStatusProvider).ndlSeconds;

    // Altitude shortens the NDL at the same depth/time/gas.
    container.read(calcAltitudeProvider.notifier).state = 2500.0;
    final ndlAtAltitude = container.read(calcDecoStatusProvider).ndlSeconds;
    expect(ndlAtAltitude, lessThan(ndlAtSea));
  });
}
