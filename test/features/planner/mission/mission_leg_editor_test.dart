import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/presentation/mission/mission_leg_editor.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

const _leg = MissionLeg(
  id: 'L1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
);

/// What the dialog returned the last time it closed.
MissionLeg? lastResult;

Finder _box(String label) => find.descendant(
  of: find.widgetWithText(PlanNumberField, label),
  matching: find.byType(TextField),
);

Future<void> _open(
  WidgetTester tester, {
  bool openWater = false,
  AppSettings settings = const AppSettings(),
}) async {
  lastResult = null;
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async => lastResult = await showMissionLegEditor(
            context,
            leg: _leg,
            openWater: openWater,
            units: MissionUnits(UnitFormatter(settings)),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saving an edited distance returns the leg in metres', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.widgetWithText(TextField, '300'), '450');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Waypoint name'), findsNothing);
    expect(lastResult!.distanceM, 450);
    expect(lastResult!.label, 'T');
  });

  testWidgets('a leg in feet is shown in feet', (tester) async {
    await _open(tester, settings: const AppSettings(depthUnit: DepthUnit.feet));
    // 300 m is 984 ft.
    expect(find.widgetWithText(TextField, '984'), findsOneWidget);
  });

  testWidgets('the shore exit rows appear only in open water', (tester) async {
    await _open(tester);
    expect(find.text('Shore exit from here'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await _open(tester, openWater: true);
    expect(find.text('Shore exit from here'), findsOneWidget);
  });

  testWidgets('a distance emptied on the way to retyping is not saved as 0', (
    tester,
  ) async {
    await _open(tester);
    final box = find.descendant(
      of: find.widgetWithText(PlanNumberField, 'Distance'),
      matching: find.byType(TextField),
    );
    await tester.enterText(box, '');
    await tester.pump();
    // The box is not refilled with 0 under the diver's cursor.
    expect(tester.widget<TextField>(box).controller!.text, isEmpty);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.distanceM, 300);
  });

  testWidgets('a current of its own is saved; switching back clears it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _open(tester);
    await tester.enterText(_box('Heading'), '45');
    await tester.enterText(_box('Depth'), '25');
    await tester.tap(find.text("Use the mission's current"));
    await tester.pumpAndSettle();
    await tester.enterText(_box('Current speed'), '30');
    await tester.enterText(_box('Sets toward'), '200');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.headingDeg, 45);
    expect(lastResult!.depthM, 25);
    expect(lastResult!.current!.speedMps, closeTo(0.5, 1e-9));
    expect(lastResult!.current!.setsTowardDeg, 200);

    await _open(tester);
    await tester.tap(find.text("Use the mission's current"));
    await tester.pumpAndSettle();
    expect(find.text('Current speed'), findsOneWidget);
    await tester.tap(find.text("Use the mission's current"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.current, isNull);
  });

  testWidgets('a shore exit typed in feet is saved in metres', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _open(
      tester,
      openWater: true,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
    await tester.tap(find.text('Shore exit from here'));
    await tester.pumpAndSettle();
    await tester.enterText(_box('Surface swim to shore'), '328');
    await tester.enterText(_box('Walk to the entry'), '164');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.shoreExit!.surfaceSwimM, closeTo(99.97, 0.01));
    expect(lastResult!.shoreExit!.walkM, closeTo(49.99, 0.01));

    await _open(tester, openWater: true);
    await tester.tap(find.text('Shore exit from here'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shore exit from here'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.shoreExit, isNull);
  });

  testWidgets('Save keeps an out-of-range heading the diver just typed', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(_box('Heading'), '400');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.headingDeg, 359);
  });

  testWidgets('the leg editor fits a 320 pt phone with every row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _open(tester, openWater: true);
    await tester.tap(find.text("Use the mission's current"));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Shore exit from here'));
    await tester.tap(find.text('Shore exit from here'));
    await tester.pumpAndSettle();
    expect(find.text('Walk to the entry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
