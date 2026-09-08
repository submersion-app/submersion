import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_editor.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
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
  Widget harness() => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: const SingleChildScrollView(child: SegmentList()),
  );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SegmentList)));

  /// Appends a waypoint on the plan's primary tank unless [tank] is given.
  void addSegment(
    ProviderContainer container, {
    required String id,
    required double depth,
    required int minutes,
    DiveTank? tank,
  }) {
    final tankToUse =
        tank ?? container.read(divePlanNotifierProvider).tanks.first;
    container
        .read(divePlanNotifierProvider.notifier)
        .addSegment(
          PlanSegment(
            id: id,
            targetDepth: depth,
            durationSeconds: minutes * 60,
            tankId: tankToUse.id,
            gasMix: tankToUse.gasMix,
          ),
        );
  }

  ListTile tileAt(WidgetTester tester, int index) =>
      tester.widgetList<ListTile>(find.byType(ListTile)).elementAt(index);

  String subtitleAt(WidgetTester tester, int index) =>
      (tileAt(tester, index).subtitle! as Text).data!;

  group('edit dialog start depth', () {
    testWidgets('a later segment starts where the previous one ended', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      final container = containerOf(tester);
      // Quick plan: descent to 30 m, then 20 min on the bottom at 30 m.
      container
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit segment').at(1));
      await tester.pumpAndSettle();

      final editor = tester.widget<SegmentEditor>(find.byType(SegmentEditor));
      expect(editor.startDepth, 30.0);
      // The bottom leg starts and ends at 30 m, so the derived phase line can
      // only read as level if the start depth really came from the previous
      // segment (with the old 0 m start it read as a descent).
      expect(find.text('Level at 30m'), findsOneWidget);
    });

    testWidgets('the first segment starts at the surface', (tester) async {
      await tester.pumpWidget(harness());
      final container = containerOf(tester);
      container
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit segment').first);
      await tester.pumpAndSettle();

      final editor = tester.widget<SegmentEditor>(find.byType(SegmentEditor));
      expect(editor.startDepth, 0.0);
      expect(find.textContaining('Descent 0m → 30m'), findsOneWidget);
    });
  });

  group('subtitle', () {
    testWidgets(
      'a leg breathing a different tank is labelled as a gas switch',
      (tester) async {
        await tester.pumpWidget(harness());
        final container = containerOf(tester);
        const decoTank = DiveTank(
          id: 'deco',
          name: 'Deco',
          gasMix: GasMix(o2: 50),
        );
        container.read(divePlanNotifierProvider.notifier).addTank(decoTank);
        addSegment(container, id: 'bottom', depth: 30, minutes: 20);
        addSegment(container, id: 'stop', depth: 6, minutes: 3, tank: decoTank);
        await tester.pumpAndSettle();

        expect(subtitleAt(tester, 0), contains('Air'));
        expect(subtitleAt(tester, 0), isNot(contains('Gas switch')));
        expect(subtitleAt(tester, 1), contains('Gas switch to EAN50'));
      },
    );

    testWidgets('staying on the same tank is not a gas switch', (tester) async {
      await tester.pumpWidget(harness());
      final container = containerOf(tester);
      addSegment(container, id: 'down', depth: 30, minutes: 2);
      addSegment(container, id: 'bottom', depth: 30, minutes: 20);
      await tester.pumpAndSettle();

      expect(find.textContaining('Gas switch'), findsNothing);
      expect(subtitleAt(tester, 1), contains('Air'));
    });
  });

  group('phase description and icon', () {
    testWidgets('ascent and deco stop legs read as such', (tester) async {
      await tester.pumpWidget(harness());
      final container = containerOf(tester);
      // Descent, bottom, ascent to 5 m, a flat 5 m stop, ascent to the
      // surface. The flat leg at 5 m is a stop because it is shallower than
      // the deepest point and nothing deeper follows it.
      addSegment(container, id: 'down', depth: 30, minutes: 2);
      addSegment(container, id: 'bottom', depth: 30, minutes: 20);
      addSegment(container, id: 'up', depth: 5, minutes: 3);
      addSegment(container, id: 'stop', depth: 5, minutes: 3);
      addSegment(container, id: 'surface', depth: 0, minutes: 1);
      await tester.pumpAndSettle();

      expect(find.text('Descent 0.0m → 30.0m'), findsOneWidget);
      expect(find.text('Bottom 30.0m for 20 min'), findsOneWidget);
      expect(find.text('Ascent 30.0m → 5.0m'), findsOneWidget);
      expect(find.text('Deco 5.0m for 3 min'), findsOneWidget);
      expect(find.text('Ascent 5.0m → 0.0m'), findsOneWidget);

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.byIcon(Icons.horizontal_rule), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNWidgets(2));
      expect(find.byIcon(Icons.stop_circle), findsOneWidget);
    });

    testWidgets('a flat leg that the dive later goes deeper than is a bottom', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      final container = containerOf(tester);
      // Multi-level: 18 m, then down to 30 m. The 18 m flat leg is not a stop
      // because the profile has not begun its final ascent yet.
      addSegment(container, id: 'down1', depth: 18, minutes: 1);
      addSegment(container, id: 'level1', depth: 18, minutes: 10);
      addSegment(container, id: 'down2', depth: 30, minutes: 1);
      addSegment(container, id: 'level2', depth: 30, minutes: 10);
      await tester.pumpAndSettle();

      expect(find.text('Bottom 18.0m for 10 min'), findsOneWidget);
      expect(find.text('Bottom 30.0m for 10 min'), findsOneWidget);
      expect(find.textContaining('Deco'), findsNothing);
      expect(find.byIcon(Icons.stop_circle), findsNothing);
    });
  });
}
