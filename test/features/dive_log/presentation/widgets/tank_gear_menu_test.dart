import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_gear_menu.dart';
import 'package:submersion/features/equipment/data/services/cylinder_from_tank_service.dart';
import 'package:submersion/features/equipment/presentation/providers/cylinder_proposal_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _FakeService extends CylinderFromTankService {
  final unlinked = <String>[];
  bool unlinkResult = true;

  @override
  Future<bool> unlinkTank({
    required String tankId,
    required String equipmentId,
  }) async {
    unlinked.add('$tankId:$equipmentId');
    return unlinkResult;
  }
}

void main() {
  late _FakeService service;

  /// What each run of the menu as a page operation answered.
  final ran = <bool>[];

  Future<void> pumpMenu(
    WidgetTester tester,
    DiveTank tank, {
    bool asOperation = false,
  }) async {
    ran.clear();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = _FakeService();
    await tester.pumpWidget(
      testApp(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          cylinderFromTankServiceProvider.overrideWithValue(service),
        ],
        child: TankGearMenu(
          operationReason: null,
          dive: Dive(id: 'd', dateTime: DateTime(2026), tanks: [tank]),
          tank: tank,
          // Off the page's lock the action simply runs.
          runAsOperation: asOperation
              ? (operation) async => ran.add(await operation())
              : (operation) async => operation(),
        ),
      ),
    );
    await tester.tap(find.byKey(Key('tank-gear-menu-${tank.id}')));
    await tester.pumpAndSettle();
  }

  testWidgets('an unlinked tank offers add and link', (tester) async {
    await pumpMenu(tester, const DiveTank(id: 't', volume: 11.1));
    expect(find.text('Add to my gear'), findsOneWidget);
    expect(find.text('Link to a cylinder I own'), findsOneWidget);
    expect(find.text('Unlink cylinder'), findsNothing);
  });

  testWidgets('add opens the review sheet for that tank', (tester) async {
    await pumpMenu(tester, const DiveTank(id: 't', volume: 11.1));
    await tester.tap(find.text('Add to my gear'));
    await tester.pumpAndSettle();
    expect(find.text('Add cylinders to your gear'), findsOneWidget);
    expect(find.text('Add 1 cylinder'), findsOneWidget);
  });

  testWidgets('a linked tank offers only unlink, which clears the link', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      const DiveTank(id: 't', volume: 11.1, equipmentId: 'mine'),
    );
    expect(find.text('Add to my gear'), findsNothing);
    expect(find.text('Link to a cylinder I own'), findsNothing);
    await tester.tap(find.text('Unlink cylinder'));
    await tester.pumpAndSettle();
    expect(service.unlinked, ['t:mine']);
    expect(find.text("Couldn't change the cylinder link"), findsNothing);
  });

  testWidgets('a stale unlink says the link did not change', (tester) async {
    await pumpMenu(
      tester,
      const DiveTank(id: 't', volume: 11.1, equipmentId: 'mine'),
    );
    service.unlinkResult = false;
    await tester.tap(find.text('Unlink cylinder'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't change the cylinder link"), findsOneWidget);
  });

  // As a page operation (issue #4527) the menu answers whether it wrote, so
  // a sheet closed without a change does not start the sitting again.
  testWidgets('add closed without adding answers that nothing was written', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      const DiveTank(id: 't', volume: 11.1),
      asOperation: true,
    );
    await tester.tap(find.text('Add to my gear'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Add 1 cylinder'))).pop();
    await tester.pumpAndSettle();

    expect(ran, [false]);
  });

  testWidgets('an unlink answers that it wrote', (tester) async {
    await pumpMenu(
      tester,
      const DiveTank(id: 't', volume: 11.1, equipmentId: 'cyl'),
      asOperation: true,
    );
    await tester.tap(find.text('Unlink cylinder'));
    await tester.pumpAndSettle();

    expect(ran, [true]);
  });

  testWidgets('a stale unlink answers that nothing was written', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      const DiveTank(id: 't', volume: 11.1, equipmentId: 'mine'),
      asOperation: true,
    );
    service.unlinkResult = false;
    await tester.tap(find.text('Unlink cylinder'));
    await tester.pumpAndSettle();

    expect(ran, [false]);
  });
}
