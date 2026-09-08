import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_editor.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

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
  const tank = DiveTank(id: 't1');

  Widget harness({
    PlanSegment? segment,
    double startDepth = 0,
    ValueChanged<PlanSegment>? onSave,
  }) => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: SegmentEditor(
      segment: segment,
      startDepth: startDepth,
      availableTanks: const [tank],
      onSave: onSave ?? (_) {},
    ),
  );

  /// The editor as a real dialog, so tapping Save can pop a route.
  Widget dialogHarness({
    PlanSegment? segment,
    double startDepth = 0,
    required ValueChanged<PlanSegment> onSave,
  }) => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => SegmentEditor(
                segment: segment,
                startDepth: startDepth,
                availableTanks: const [tank],
                onSave: onSave,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  TextEditingController controllerAt(WidgetTester tester, int index) => tester
      .widgetList<TextField>(find.byType(TextField))
      .elementAt(index)
      .controller!;

  testWidgets('asks for a depth and a duration, and nothing else', (
    tester,
  ) async {
    await tester.pumpWidget(harness(startDepth: 12));
    await tester.pumpAndSettle();

    // No segment-type picker: the phase is derived, never declared. Two text
    // fields (depth, duration) where there used to be four.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Segment Type'), findsNothing);
    expect(find.text('Start Depth (m)'), findsNothing);
    expect(find.text('Depth (m)'), findsOneWidget);
  });

  testWidgets('a new segment seeds its depth from where it starts', (
    tester,
  ) async {
    await tester.pumpWidget(harness(startDepth: 12));
    await tester.pumpAndSettle();

    expect(controllerAt(tester, 0).text, '12');
    // Seeded at its own start depth, so it reads as a level leg until the
    // diver moves it.
    expect(find.text('Level at 12m'), findsOneWidget);
  });

  testWidgets('a new segment with no inherited depth defaults to 0', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(controllerAt(tester, 0).text, '0');
  });

  testWidgets('a deeper target reads as a descent with the implied rate', (
    tester,
  ) async {
    await tester.pumpWidget(harness(startDepth: 12));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '30');
    await tester.pumpAndSettle();

    // 18 m over the default 20 min duration.
    expect(find.text('Descent 12m → 30m at 0.9m/min'), findsOneWidget);
  });

  testWidgets('a shallower target reads as an ascent', (tester) async {
    await tester.pumpWidget(harness(startDepth: 30));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '6');
    await tester.pumpAndSettle();

    expect(find.textContaining('Ascent 30m → 6m'), findsOneWidget);
  });

  testWidgets('a zero duration reads as a direction without a rate', (
    tester,
  ) async {
    await tester.pumpWidget(harness(startDepth: 12));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '30');
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.pumpAndSettle();

    // No duration to divide by, so only the direction is known.
    expect(find.text('Descent 12m → 30m'), findsOneWidget);
  });

  testWidgets('a shallower target with zero duration reads as an ascent '
      'without a rate', (tester) async {
    await tester.pumpWidget(harness(startDepth: 30));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '6');
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.pumpAndSettle();

    expect(find.text('Ascent 30m → 6m'), findsOneWidget);
    expect(find.textContaining('/min'), findsNothing);
  });

  testWidgets('a shallower target with an empty duration reads as an ascent '
      'without a rate', (tester) async {
    await tester.pumpWidget(harness(startDepth: 30));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '6');
    await tester.enterText(find.byType(TextField).at(1), '');
    await tester.pumpAndSettle();

    // An unparseable duration counts as 0, so the leg has no rate.
    expect(find.text('Ascent 30m → 6m'), findsOneWidget);
  });

  testWidgets('saving writes the target depth and duration', (tester) async {
    PlanSegment? saved;
    await tester.pumpWidget(dialogHarness(onSave: (s) => saved = s));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '30');
    await tester.enterText(find.byType(TextField).at(1), '25');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.targetDepth, 30);
    expect(saved!.durationSeconds, 25 * 60);
    expect(saved!.tankId, 't1');
  });

  testWidgets('editing preserves the setpoint and dive-mode override', (
    tester,
  ) async {
    // Regression: the old editor rebuilt the segment from its fields alone,
    // so both were silently dropped on every edit round-trip.
    const segment = PlanSegment(
      id: 's1',
      targetDepth: 20,
      durationSeconds: 600,
      tankId: 't1',
      gasMix: GasMix(),
      setpointBar: 1.3,
      diveModeOverride: PlanMode.oc,
      order: 3,
    );
    PlanSegment? saved;
    await tester.pumpWidget(
      dialogHarness(segment: segment, onSave: (s) => saved = s),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '24');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.targetDepth, 24);
    expect(saved!.setpointBar, 1.3);
    expect(saved!.diveModeOverride, PlanMode.oc);
    expect(saved!.id, 's1');
    expect(saved!.order, 3);
  });
}
