import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/group_by_location_switch.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';
import '../../../../support/fake_app_settings_repository.dart';

class _FailingSettings extends FakeAppSettingsRepository {
  @override
  Future<void> setEquipmentGroupByLocation(bool value) async =>
      throw StateError('disk full');
}

void main() {
  testWidgets('a failed save says so instead of failing silently', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(_FailingSettings()),
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
