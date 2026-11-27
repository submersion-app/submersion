import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/dense_equipment_list_tile.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_status_providers.dart';

import '../../../../helpers/test_app.dart';

/// The equipment list flags gear with a newer firmware release (issue
/// #5104), below a service clock or a finding, which ask for more.
void main() {
  const item = EquipmentItem(
    id: 'perdix',
    name: 'Perdix 2',
    type: EquipmentType.computer,
  );
  const model = FirmwareModel(
    id: 'm',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    equipmentTypes: {EquipmentType.computer},
    releases: [
      FirmwareRelease(version: 'V95'),
      FirmwareRelease(version: 'V94'),
    ],
  );
  const update = FirmwareUpdateAvailable(model, [
    FirmwareRelease(version: 'V95'),
  ]);

  RollupClock overdue() {
    final t0 = DateTime(2026, 1, 1);
    return (
      ownerId: item.id,
      ownerName: item.name,
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's',
          equipmentId: item.id,
          serviceKindId: 'annual',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: ServiceKind(
          id: 'annual',
          name: 'Annual service',
          createdAt: t0,
          updatedAt: t0,
        ),
        anchor: t0,
        dueDate: DateTime.now().subtract(const Duration(days: 5)),
        severity: ServiceClockSeverity.overdue,
        now: DateTime.now(),
      ),
    );
  }

  List<Object> overrides(
    FirmwareStatus status, {
    Map<String, RollupClock> rollup = const {},
  }) => [
    equipmentRollupClockProvider.overrideWith((ref) async => rollup),
    equipmentComponentsIndexProvider.overrideWith(
      (ref) async => ComponentsIndex.empty,
    ),
    firmwareStatusesProvider.overrideWith((ref) async => {item.id: status}),
  ];

  for (final (name, tile) in [
    ('list tile', const EquipmentListTile(item: item) as Widget),
    ('dense tile', DenseEquipmentListTile(item: item, onTap: () {})),
  ]) {
    testWidgets('the $name flags an available update', (tester) async {
      await tester.pumpWidget(
        testApp(overrides: overrides(update), child: tile),
      );
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
    });

    testWidgets('the $name keeps an overdue clock above it', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: overrides(update, rollup: {item.id: overdue()}),
          child: tile,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Annual service'), findsOneWidget);
      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('the $name says nothing when up to date', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: overrides(const FirmwareUpToDate(model)),
          child: tile,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
    });
  }
}
