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

  @override
  Future<void> unlinkTank(String tankId) async => unlinked.add(tankId);
}

void main() {
  late _FakeService service;

  Future<void> pumpMenu(WidgetTester tester, DiveTank tank) async {
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
          dive: Dive(id: 'd', dateTime: DateTime(2026), tanks: [tank]),
          tank: tank,
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
    expect(service.unlinked, ['t']);
  });
}
