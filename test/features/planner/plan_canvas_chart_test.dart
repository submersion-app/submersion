import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_canvas_chart.dart';
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
  group('segmentIdAtTime', () {
    const gas = GasMix(o2: 21);
    final segments = [
      PlanSegment.descent(
        id: 'descent',
        targetDepth: 30,
        tankId: 't1',
        gasMix: gas,
        order: 0,
      ), // 30/18*60 = 100 s
      PlanSegment.bottom(
        id: 'bottom',
        depth: 30,
        durationMinutes: 20,
        tankId: 't1',
        gasMix: gas,
        order: 1,
      ), // 1200 s
    ];

    test('maps times to the covering segment', () {
      expect(segmentIdAtTime(segments, 50), 'descent');
      expect(segmentIdAtTime(segments, 600), 'bottom');
    });

    test('returns null past the last user segment (computed ascent)', () {
      expect(segmentIdAtTime(segments, 5000), isNull);
    });

    test('empty segments yield null', () {
      expect(segmentIdAtTime(const [], 10), isNull);
    });
  });

  group('PlanCanvasChart widget', () {
    Widget harness() => testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: const SizedBox(width: 400, height: 300, child: PlanCanvasChart()),
    );

    testWidgets('renders the empty state with a quick-plan action', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('renders a LineChart once a plan exists', (tester) async {
      await tester.pumpWidget(harness());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanCanvasChart)),
      );
      container
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('empty-state action opens the quick-plan dialog', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('gas-switch markers and the scrub readout render', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanCanvasChart)),
      );
      // Deep air with an O2 deco gas gives a gas switch during the ascent.
      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
      notifier.addTank(
        const DiveTank(
          id: 'o2',
          volume: 11.1,
          startPressure: 207,
          gasMix: GasMix(o2: 100),
          role: TankRole.deco,
        ),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        chart.data.extraLinesData.verticalLines,
        isNotEmpty,
        reason: 'a gas switch should draw a vertical marker line',
      );

      // Scrubbing renders the readout overlay.
      container.read(scrubTimeProvider.notifier).state = 300;
      await tester.pumpAndSettle();
      expect(find.textContaining('RT'), findsOneWidget);
    });
  });
}
