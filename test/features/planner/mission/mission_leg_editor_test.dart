import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
