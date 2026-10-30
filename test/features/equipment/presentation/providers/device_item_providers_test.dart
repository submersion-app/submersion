import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/device_item_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

/// The Dive Computers and Transmitters lists read Equipment items (issue
/// #3676), each with the device records behind it.
void main() {
  EquipmentItem item(
    String id,
    EquipmentType type, {
    EquipmentStatus status = EquipmentStatus.active,
  }) => EquipmentItem(id: id, name: id, type: type, status: status);

  DiveComputer computer(String id, String? itemId, {DateTime? last}) =>
      DiveComputer(
        id: id,
        name: id,
        equipmentId: itemId,
        lastDownload: last,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  Transmitter key(String id, String? itemId) => Transmitter(
    id: id,
    transmitterSerial: id,
    label: id,
    transmitterEquipmentId: itemId,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        allEquipmentProvider.overrideWith(
          (ref) async => [
            item('teric', EquipmentType.computer),
            item('backup', EquipmentType.computer),
            item(
              'wish',
              EquipmentType.computer,
              status: EquipmentStatus.wanted,
            ),
            item('tx', EquipmentType.transmitter),
            item(
              'parked',
              EquipmentType.computer,
              status: EquipmentStatus.wanted,
            ),
            item(
              'parked-tx',
              EquipmentType.transmitter,
              status: EquipmentStatus.wanted,
            ),
            item('mask', EquipmentType.mask),
          ],
        ),
        allDiveComputersProvider.overrideWith(
          (ref) async => [
            computer('old', 'teric', last: DateTime(2025)),
            computer('new', 'teric', last: DateTime(2026, 5)),
            computer('stray', null),
            // A device whose item the diver set to Wanted is still a device.
            computer('kept', 'parked'),
          ],
        ),
        transmittersProvider.overrideWith(
          (ref) async => [
            key('4A21F', 'tx'),
            key('7C0B19', 'tx'),
            key('9Z9', 'parked-tx'),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the Dive Computers list shows every computer item, hand-added ones '
      'too, and no wanted one without a device (review)', () async {
    final rows = await container().read(computerItemsProvider.future);

    expect(rows.map((r) => r.item.id), ['teric', 'backup', 'parked']);
    expect(rows.first.computers.map((c) => c.id), ['new', 'old']);
    expect(rows[1].computers, isEmpty);
  });

  test(
    'the Transmitters list shows each transmitter item with its keys',
    () async {
      final rows = await container().read(transmitterItemsProvider.future);

      expect(rows.map((r) => r.item.id), ['tx', 'parked-tx']);
      expect(rows.first.keys.map((k) => k.id), ['4A21F', '7C0B19']);
    },
  );
}
