import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_catalogue_providers.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_status_providers.dart';

/// The firmware status of the active diver's gear (issue #5104).
void main() {
  late String sample;

  setUpAll(() {
    sample = File(
      p.join('test', 'fixtures', 'firmware_catalogue', 'sample.json'),
    ).readAsStringSync();
  });

  EquipmentItem item(
    String id,
    EquipmentType type, {
    String? brand = 'Shearwater',
    String? model = 'Perdix 2',
    String? firmware,
    String name = 'Item',
    EquipmentStatus status = EquipmentStatus.active,
  }) => EquipmentItem(
    id: id,
    name: name,
    type: type,
    brand: brand,
    model: model,
    status: status,
    attributes: [
      if (firmware != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: 'firmware_version',
          valueText: firmware,
        ),
    ],
  );

  DiveComputer registration(
    String equipmentId, {
    String? firmware,
    String? manufacturer = 'Shearwater',
    String? model = 'Perdix 2',
    DateTime? lastDownload,
  }) => DiveComputer(
    id: 'dc-$equipmentId-${lastDownload?.millisecondsSinceEpoch}',
    name: 'Perdix 2',
    manufacturer: manufacturer,
    model: model,
    firmwareVersion: firmware,
    lastDownload: lastDownload,
    equipmentId: equipmentId,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  ProviderContainer container(
    List<EquipmentItem> items, {
    List<DiveComputer> computers = const [],
    bool withCatalogue = true,
    String? catalogue,
  }) {
    final c = ProviderContainer(
      overrides: [
        allEquipmentProvider.overrideWith((ref) async => items),
        allDiveComputersProvider.overrideWith((ref) async => computers),
        firmwareCatalogueProvider.overrideWith(
          () => _FixedCatalogue(
            withCatalogue ? FirmwareCatalogue.parse(catalogue ?? sample) : null,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('installedFirmwareOf', () {
    test('the item version wins over its registrations', () {
      expect(
        installedFirmwareOf(
          item('a', EquipmentType.computer, firmware: 'V94'),
          [registration('a', firmware: '92')],
        ),
        'V94',
      );
    });

    test('without one, the newest download reads through', () {
      expect(
        installedFirmwareOf(item('a', EquipmentType.computer), [
          registration('a', firmware: '90', lastDownload: DateTime(2026, 1)),
          registration('a', firmware: '92', lastDownload: DateTime(2026, 6)),
        ]),
        '92',
      );
      expect(installedFirmwareOf(item('a', EquipmentType.light), []), isNull);
    });
  });

  test('a version stored only on the registration is compared', () async {
    final c = container(
      [item('a', EquipmentType.computer)],
      computers: [registration('a', firmware: '92')],
    );
    final statuses = await c.read(firmwareStatusesProvider.future);
    expect(statuses['a'], isA<FirmwareUpdateAvailable>());
  });

  test('retired gear and gear without firmware are left out', () async {
    final c = container([
      item(
        'old',
        EquipmentType.computer,
        firmware: '92',
        status: EquipmentStatus.retired,
      ),
      item('fins', EquipmentType.fins),
    ]);
    expect(await c.read(firmwareStatusesProvider.future), isEmpty);
  });

  test('a gear twin with no maker of its own matches through its '
      'registration', () async {
    final c = container(
      [item('a', EquipmentType.computer, brand: null, model: null)],
      computers: [registration('a', firmware: 'V95')],
    );
    expect(
      (await c.read(firmwareStatusesProvider.future))['a'],
      isA<FirmwareUpToDate>(),
    );
  });

  test('safety updates come first, then by name', () async {
    // The Perdix's V95 is a safety release; Seal 2's 2.4.0 is not.
    final c = container([
      item('a', EquipmentType.computer, firmware: 'V94', name: 'Zulu'),
      item(
        'dpv',
        EquipmentType.dpv,
        brand: 'Example Scooters',
        model: 'Seal 2',
        firmware: '2.3.0',
        name: 'Alpha',
      ),
      item('b', EquipmentType.computer, firmware: 'V92', name: 'Bravo'),
    ], catalogue: _withOlderSealRelease(sample));
    final updates = await c.read(firmwareUpdatesProvider.future);
    expect(updates.map((u) => u.item.id), ['b', 'a', 'dpv']);
    expect(updates.first.status.newer.map((r) => r.version), ['V95', 'V94']);
  });

  test('no catalogue, no updates', () async {
    final c = container([
      item('a', EquipmentType.computer, firmware: '92'),
    ], withCatalogue: false);
    expect(
      (await c.read(firmwareStatusesProvider.future))['a'],
      isA<FirmwareNotListed>(),
    );
    expect(await c.read(firmwareUpdatesProvider.future), isEmpty);
  });
}

/// The sample with an older Seal 2 release listed below 2.4.0.
String _withOlderSealRelease(String json) => json.replaceFirst(
  '"futureField": "ignored by the app"\n        }',
  '"futureField": "ignored by the app"\n        },\n        {\n          "version": "2.3.0",\n          "source": "https://example.com/seal-2/firmware"\n        }',
);

class _FixedCatalogue extends FirmwareCatalogueNotifier {
  _FixedCatalogue(this._catalogue);
  final FirmwareCatalogue? _catalogue;

  @override
  Future<FirmwareCatalogue?> build() async => _catalogue;
}
