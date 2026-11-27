import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/widgets/nest_parts_switch.dart';
import 'package:submersion/features/settings/domain/list_arrangements.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';
import '../../../../support/recording_arrangement_settings.dart';

/// The Equipment page's "Show parts under their assembly" switch (issue
/// #5071).
void main() {
  RecordingArrangementSettings settings({bool failWrite = false}) {
    final s = RecordingArrangementSettings()..failWrite = failWrite;
    // The diver has an arrangement of their own, so a change never reads
    // the app-wide value older builds saved.
    s.state = s.state.copyWith(
      listArrangements: ListArrangements(
        equipmentArrangement: encodeEquipmentArrangement(
          EquipmentArrangement.defaults,
        ),
      ),
    );
    return s;
  }

  Future<void> pump(WidgetTester tester, RecordingArrangementSettings s) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [settingsProvider.overrideWith((ref) => s)],
        child: const NestPartsSwitch(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the switch is on by default', (tester) async {
    await pump(tester, settings());
    expect(find.text('Show parts under their assembly'), findsOneWidget);
    expect(find.text("Fold each assembly's parts under it"), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('turning it off saves the arrangement for the diver', (
    tester,
  ) async {
    final s = settings();
    await pump(tester, s);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(s.stored?.nestParts, isFalse);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('a failed save says so', (tester) async {
    await pump(tester, settings(failWrite: true));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Could not save the arrangement'), findsOneWidget);
  });
}
