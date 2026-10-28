import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/group_by_location_switch.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';
import '../../../../support/recording_arrangement_settings.dart';

void main() {
  testWidgets('the switch saves the choice for the diver', (tester) async {
    // Per diver since issue #3748.
    final settings = RecordingArrangementSettings();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => settings),
          equipmentGroupByLocationProvider.overrideWith((ref) async => false),
        ],
        child: const GroupByLocationSwitch(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(settings.state.listArrangements.equipmentGroupByLocation, isTrue);
  });

  testWidgets('a failed save says so instead of failing silently', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith(
            (ref) => RecordingArrangementSettings()..failWrite = true,
          ),
          equipmentGroupByLocationProvider.overrideWith((ref) async => false),
        ],
        child: const GroupByLocationSwitch(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}
