import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/cylinder_from_tank_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/tank_cylinder_matching.dart';
import 'package:submersion/features/equipment/presentation/providers/cylinder_proposal_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/cylinders_from_tanks_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _FakeService extends CylinderFromTankService {
  final drafts = <CylinderDraft>[];
  bool fail = false;

  @override
  Future<List<EquipmentItem>> create(
    List<CylinderDraft> drafts, {
    required String? diverId,
  }) async {
    if (fail) throw StateError('database locked');
    this.drafts.addAll(drafts);
    return [
      for (final d in drafts)
        for (var i = 0; i < d.proposal.cylinderCount; i++)
          EquipmentItem(id: '$i', name: d.name, type: EquipmentType.tank),
    ];
  }
}

void main() {
  late _FakeService service;

  final proposals = proposeCylinders(
    [
      for (var i = 0; i < 40; i++)
        TankRef(
          diveId: 'd$i',
          tank: DiveTank(
            id: 't$i',
            volume: 11.1,
            workingPressure: 206.843,
            material: TankMaterial.aluminum,
          ),
        ),
      const TankRef(
        diveId: 'd0',
        tank: DiveTank(id: 'stage', volume: 5.7, order: 1),
      ),
    ],
    owned: const [],
    ownedPairs: const [],
  );

  Future<void> pumpSheet(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = _FakeService();
    await tester.pumpWidget(
      testApp(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          cylinderFromTankServiceProvider.overrideWithValue(service),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCylindersFromTanksSheet(context, proposals),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists one row per spec with its dive count', (tester) async {
    await pumpSheet(tester);
    expect(find.text('Add cylinders to your gear'), findsOneWidget);
    expect(find.text('AL80'), findsWidgets);
    expect(find.text('on 40 dives'), findsOneWidget);
    expect(find.text('on 1 dive'), findsOneWidget);
    expect(find.text('Add 2 cylinders'), findsOneWidget);
  });

  testWidgets('unticking a row adds only the rest, with the edited name', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    expect(find.text('Add 1 cylinder'), findsOneWidget);

    final nameField = find.descendant(
      of: find.byKey(const Key('cylinders-from-tanks-row-0')),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField.first, 'Blue AL80');
    await tester.tap(find.byKey(const Key('cylinders-from-tanks-add')));
    await tester.pumpAndSettle();

    expect(service.drafts, hasLength(1));
    final draft = service.drafts.single;
    expect(draft.name, 'Blue AL80');
    expect(draft.volumeL, 11.1);
    expect(draft.workingPressureBar, 206.843);
    expect(draft.specChanged, isFalse);
    expect(find.text('Added 1 cylinder to your gear'), findsOneWidget);
  });

  testWidgets('a blank volume blocks adding', (tester) async {
    await pumpSheet(tester);
    final volumeField = find.descendant(
      of: find.byKey(const Key('cylinders-from-tanks-row-0')),
      matching: find.byType(TextField),
    );
    // Name, volume, working pressure: the volume is the second field.
    await tester.enterText(volumeField.at(1), '');
    await tester.pump();
    final add = tester.widget<FilledButton>(
      find.byKey(const Key('cylinders-from-tanks-add')),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('an unreadable pressure blocks adding', (tester) async {
    await pumpSheet(tester);
    final fields = find.descendant(
      of: find.byKey(const Key('cylinders-from-tanks-row-0')),
      matching: find.byType(TextField),
    );
    // Name, volume, working pressure: the pressure is the third field.
    await tester.enterText(fields.at(2), '2.0.7');
    await tester.pump();
    final add = tester.widget<FilledButton>(
      find.byKey(const Key('cylinders-from-tanks-add')),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('a failed save says so inside the sheet', (tester) async {
    await pumpSheet(tester);
    service.fail = true;
    await tester.tap(find.byKey(const Key('cylinders-from-tanks-add')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('cylinders-from-tanks-failed')),
      findsOneWidget,
    );
    expect(find.text('Add cylinders to your gear'), findsOneWidget);
  });
}
