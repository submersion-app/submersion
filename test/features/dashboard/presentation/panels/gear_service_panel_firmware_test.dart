import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dashboard/presentation/panels/gear_service_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_status_providers.dart';

import 'panel_harness.dart';

/// The gear service panel lists firmware updates after the service bars
/// (issue #5104), within the panel's row cap.
void main() {
  ServiceClockStatus clock([
    ServiceClockSeverity severity = ServiceClockSeverity.ok,
  ]) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's',
      equipmentId: 'e',
      serviceKindId: 'k',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    kind: ServiceKind(
      id: 'k',
      name: 'Annual',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    anchor: DateTime(2026),
    dueDate: DateTime.now().add(const Duration(days: 40, hours: 1)),
    severity: severity,
    now: DateTime.now(),
  );

  GearServiceBar bar(
    String id, [
    ServiceClockSeverity severity = ServiceClockSeverity.ok,
  ]) => GearServiceBar(
    itemId: id,
    itemName: 'Reg $id',
    status: clock(severity),
    fraction: 0.3,
  );

  FirmwareUpdateEntry update(String id, String name, String version) {
    final model = FirmwareModel(
      id: 'm-$id',
      manufacturer: 'Maker',
      model: name,
      equipmentTypes: const {EquipmentType.computer},
      releases: [
        FirmwareRelease(version: version),
        const FirmwareRelease(version: 'old'),
      ],
    );
    return (
      item: EquipmentItem(id: id, name: name, type: EquipmentType.computer),
      status: FirmwareUpdateAvailable(model, [model.releases.first]),
    );
  }

  List<Object> overrides(
    List<GearServiceBar> bars,
    List<FirmwareUpdateEntry> updates,
  ) => [
    homeGearServiceProvider.overrideWith((ref) async => bars),
    homeHasGearProvider.overrideWith((ref) async => true),
    firmwareUpdatesProvider.overrideWith((ref) async => updates),
  ];

  testWidgets('updates fill the rows the bars leave, the rest counted', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const GearServicePanel(),
      height: 320,
      overrides: overrides(
        [
          bar('1', ServiceClockSeverity.dueSoon),
          bar('2', ServiceClockSeverity.dueSoon),
        ],
        [
          update('a', 'Perdix 2', 'V95'),
          update('b', 'Teric', 'V40'),
          update('c', 'Tern TX', 'V36'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reg 1'), findsOneWidget);
    expect(find.text('Reg 2'), findsOneWidget);
    expect(find.text('Perdix 2'), findsOneWidget);
    expect(find.text('Firmware V95'), findsOneWidget);
    expect(find.text('Teric'), findsNothing);
    expect(find.text('2 more firmware updates'), findsOneWidget);
  });

  testWidgets('with no bars an update shows instead of the empty text', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const GearServicePanel(),
      overrides: overrides([], [update('a', 'Perdix 2', 'V95')]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Perdix 2'), findsOneWidget);
    expect(find.text('No service clocks'), findsNothing);
  });

  testWidgets('a firmware row opens its item', (tester) async {
    final nav = await pumpPanel(
      tester,
      const GearServicePanel(),
      overrides: overrides([], [update('a', 'Perdix 2', 'V95')]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perdix 2'));
    await tester.pumpAndSettle();
    expect(nav.location, '/equipment/a');
  });

  testWidgets('no updates leave the panel as it was', (tester) async {
    await pumpPanel(
      tester,
      const GearServicePanel(),
      overrides: overrides([bar('1')], []),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reg 1'), findsOneWidget);
    expect(find.textContaining('firmware'), findsNothing);
    expect(find.textContaining('Firmware'), findsNothing);
  });
  testWidgets('a due bar comes first, then updates, then healthy bars', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const GearServicePanel(),
      height: 320,
      overrides: overrides(
        [bar('1', ServiceClockSeverity.overdue), bar('2'), bar('3')],
        [update('a', 'Perdix 2', 'V95')],
      ),
    );
    await tester.pumpAndSettle();
    final y = {
      for (final t in ['Reg 1', 'Perdix 2', 'Reg 2'])
        t: tester.getTopLeft(find.text(t)).dy,
    };
    expect(y['Reg 1']! < y['Perdix 2']!, isTrue);
    expect(y['Perdix 2']! < y['Reg 2']!, isTrue);
    expect(find.text('Reg 3'), findsNothing);
  });
}
