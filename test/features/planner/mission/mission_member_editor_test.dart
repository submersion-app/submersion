import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/presentation/mission/mission_member_editor.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/planner/presentation/mission/buddy_picker_sheet.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

import '../../../helpers/test_app.dart';

MissionMember? lastResult;

Finder _box(String label) => find.descendant(
  of: find.widgetWithText(PlanNumberField, label),
  matching: find.byType(TextField),
);

const _member = MissionMember(
  id: 'm1',
  order: 0,
  displayName: 'Diver 1',
  sacBottom: 15,
  scooter: ScooterSpec(name: '', ratedSpeedMps: 0, burnTimeSeconds: 0),
);

Future<void> _open(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
}) async {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  lastResult = null;
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        allBuddiesProvider.overrideWith(
          (ref) async => [
            Buddy(
              id: 'b1',
              name: 'Alex Rivers',
              createdAt: DateTime(2026, 9, 28),
              updatedAt: DateTime(2026, 9, 28),
            ),
          ],
        ),
        currentDiverProvider.overrideWith(
          (ref) async => Diver(
            id: 'd1',
            name: 'Sam Lee',
            createdAt: DateTime(2026, 9, 28),
            updatedAt: DateTime(2026, 9, 28),
          ),
        ),
        activeEquipmentProvider.overrideWith(
          (ref) async => [
            EquipmentItem(
              id: 'eq-1',
              name: 'Blacktip',
              type: EquipmentType.dpv,
              attributes: [
                EquipmentAttribute.curated(
                  equipmentId: 'eq-1',
                  key: 'speed_mps',
                  valueNum: 0.9,
                ),
                EquipmentAttribute.curated(
                  equipmentId: 'eq-1',
                  key: 'burn_time_h',
                  valueNum: 1.5,
                ),
              ],
            ),
            // Logged with a speed but no burn time yet.
            EquipmentItem(
              id: 'eq-2',
              name: 'Half-logged DPV',
              type: EquipmentType.dpv,
              attributes: [
                EquipmentAttribute.curated(
                  equipmentId: 'eq-2',
                  key: 'speed_mps',
                  valueNum: 0.8,
                ),
              ],
            ),
          ],
        ),
      ],
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async => lastResult = await showMissionMemberEditor(
            context,
            member: _member,
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
  testWidgets('picking a buddy fills the name and buddy id', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Choose a buddy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Rivers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.displayName, 'Alex Rivers');
    expect(lastResult!.buddyId, 'b1');
    expect(lastResult!.diverId, isNull);
  });

  testWidgets('picking Me fills the active diver', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Choose a buddy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.displayName, 'Sam Lee');
    expect(lastResult!.diverId, 'd1');
  });

  testWidgets('a scooter from equipment brings its numbers', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Choose from equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blacktip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final scooter = lastResult!.scooter;
    expect(scooter.equipmentId, 'eq-1');
    expect(scooter.ratedSpeedMps, 0.9);
    expect(scooter.burnTimeSeconds, 5400);
  });

  testWidgets('editing a picked scooter by hand makes it manual', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Choose from equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blacktip'));
    await tester.pumpAndSettle();
    // 0.9 m/s shows as 54 m/min; the diver types their own figure.
    await tester.enterText(find.widgetWithText(TextField, '54'), '60');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.scooter.equipmentId, isNull);
    expect(lastResult!.scooter.ratedSpeedMps, closeTo(1.0, 1e-9));
  });

  testWidgets('a linked buddy with no photo shows the diver profile photo', (
    tester,
  ) async {
    final photo = Uint8List.fromList([1, 2, 3]);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          allBuddiesProvider.overrideWith(
            (ref) async => [
              Buddy(
                id: 'b2',
                name: 'Linked Buddy',
                linkedDiverId: 'd2',
                createdAt: DateTime(2026, 9, 28),
                updatedAt: DateTime(2026, 9, 28),
              ),
            ],
          ),
          currentDiverProvider.overrideWith((ref) async => null),
          diverByIdProvider('d2').overrideWith(
            (ref) async => Diver(
              id: 'd2',
              name: 'Linked Diver',
              photo: photo,
              createdAt: DateTime(2026, 9, 28),
              updatedAt: DateTime(2026, 9, 28),
            ),
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBuddyPickerSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final avatar = tester.widget<ProfileAvatar>(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Linked Buddy'),
        matching: find.byType(ProfileAvatar),
      ),
    );
    expect(avatar.photo, same(photo));
  });

  testWidgets('the scooter buttons leave room for the name field label', (
    tester,
  ) async {
    await _open(tester);
    final buttons = tester.getRect(find.byType(Wrap));
    final field = tester.getRect(
      find.ancestor(
        of: find.text('Scooter name'),
        matching: find.byType(TextField),
      ),
    );
    expect(field.top - buttons.bottom, greaterThanOrEqualTo(8));
  });

  testWidgets('RMV in cubic feet keeps two decimals', (tester) async {
    await _open(
      tester,
      settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
    );
    // 15 L/min is 0.5297 cuft/min; one decimal would round it to 0.5.
    expect(find.text('0.53'), findsOneWidget);
  });

  testWidgets('a scooter with missing numbers still brings what it has', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Choose from equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Half-logged DPV'));
    await tester.pumpAndSettle();
    // The name lands in the field, so the diver sees the pick took.
    expect(find.text('Half-logged DPV'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final scooter = lastResult!.scooter;
    expect(scooter.equipmentId, 'eq-2');
    expect(scooter.name, 'Half-logged DPV');
    expect(scooter.ratedSpeedMps, 0.8);
    // Left for the diver to fill in; validation reports it until then.
    expect(scooter.burnTimeSeconds, 0);
  });

  testWidgets('an RMV emptied on the way to retyping is not saved as 0', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(PlanNumberField, 'Bottom RMV'),
        matching: find.byType(TextField),
      ),
      '',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.sacBottom, 15);
  });

  testWidgets('name, swim speed and a manual scooter are saved', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextField, 'Diver 1'),
      ),
      '  Robin  ',
    );
    await tester.enterText(_box('Swim speed'), '30');
    await tester.enterText(
      find.ancestor(
        of: find.text('Scooter name'),
        matching: find.byType(TextField),
      ),
      'My DPV',
    );
    await tester.enterText(_box('Rated speed'), '60');
    await tester.enterText(_box('Burn time'), '90');
    await tester.enterText(_box('Tow speed factor'), '0.5');
    await tester.enterText(_box('Tow burn factor'), '1.8');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final m = lastResult!;
    expect(m.displayName, 'Robin');
    expect(m.swimSpeedMps, closeTo(0.5, 1e-9));
    expect(m.scooter.name, 'My DPV');
    expect(m.scooter.ratedSpeedMps, closeTo(1.0, 1e-9));
    expect(m.scooter.burnTimeSeconds, 90 * 60);
    expect(m.scooter.towSpeedFactor, 0.5);
    expect(m.scooter.towBurnFactor, 1.8);
    expect(m.scooter.equipmentId, isNull);
  });

  testWidgets('Enter manually unlinks a picked scooter', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Choose from equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blacktip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter manually'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(lastResult!.scooter.equipmentId, isNull);
    expect(lastResult!.scooter.ratedSpeedMps, 0.9);
  });
}
