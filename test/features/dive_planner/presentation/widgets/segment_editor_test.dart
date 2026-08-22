import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_editor.dart';
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

  Widget harness({PlanSegment? segment, double initialStartDepth = 0}) =>
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: SegmentEditor(
          segment: segment,
          initialStartDepth: initialStartDepth,
          availableTanks: const [tank],
          onSave: (_) {},
        ),
      );

  TextEditingController controllerAt(WidgetTester tester, int index) => tester
      .widgetList<TextField>(find.byType(TextField))
      .elementAt(index)
      .controller!;

  Future<void> selectType(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButton<SegmentType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a new segment seeds start and end depth from initialStartDepth',
    (tester) async {
      await tester.pumpWidget(harness(initialStartDepth: 12));
      await tester.pumpAndSettle();

      expect(controllerAt(tester, 0).text, '12');
      expect(controllerAt(tester, 1).text, '12');
    },
  );

  testWidgets('a new segment with no inherited depth defaults to 0', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(controllerAt(tester, 0).text, '0');
    expect(controllerAt(tester, 1).text, '0');
  });

  testWidgets(
    'switching a new segment to Descent keeps the inherited start depth',
    (tester) async {
      await tester.pumpWidget(harness(initialStartDepth: 12));
      await tester.pumpAndSettle();

      await selectType(tester, 'Descent');

      expect(controllerAt(tester, 0).text, '12');
    },
  );

  testWidgets(
    "switching an existing segment to Descent keeps the segment's own start "
    'depth instead of resetting to 0',
    (tester) async {
      const segment = PlanSegment(
        id: 's1',
        type: SegmentType.bottom,
        startDepth: 20,
        endDepth: 20,
        durationSeconds: 600,
        tankId: 't1',
        gasMix: GasMix(),
      );
      await tester.pumpWidget(harness(segment: segment));
      await tester.pumpAndSettle();

      await selectType(tester, 'Descent');

      expect(controllerAt(tester, 0).text, '20');
    },
  );
}
