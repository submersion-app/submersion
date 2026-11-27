import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/firmware/data/firmware_update_recorder.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../helpers/test_database.dart';

/// Writing firmware history (issue #5104): an update logged by hand, and a
/// version a dive computer download reports.
void main() {
  late EquipmentRepository equipment;
  late ServiceRecordRepository records;
  late FirmwareUpdateRecorder recorder;
  late FirmwareCatalogue catalogue;
  final at = DateTime(2026, 11, 20, 18, 30);

  setUpAll(() {
    catalogue = FirmwareCatalogue.parse(
      File(
        p.join('test', 'fixtures', 'firmware_catalogue', 'sample.json'),
      ).readAsStringSync(),
    )!;
  });

  setUp(() async {
    await setUpTestDatabase();
    equipment = EquipmentRepository();
    records = ServiceRecordRepository();
    recorder = FirmwareUpdateRecorder(
      equipment: equipment,
      serviceRecords: records,
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> addComputer({String? firmware}) => equipment.createEquipment(
    EquipmentItem(
      id: 'perdix',
      name: 'Perdix 2',
      type: EquipmentType.computer,
      brand: 'Shearwater',
      model: 'Perdix 2',
      attributes: [
        const EquipmentAttribute(
          id: 'custom1',
          equipmentId: 'perdix',
          key: 'Strap',
          isCustom: true,
          valueText: 'Bungee',
        ),
        if (firmware != null)
          EquipmentAttribute.curated(
            equipmentId: 'perdix',
            key: EquipmentAttrKeys.firmwareVersion,
            valueText: firmware,
          ),
      ],
    ),
  );

  Future<EquipmentItem> item() async =>
      (await equipment.getEquipmentById('perdix'))!;

  Future<List<ServiceRecord>> history() =>
      records.getRecordsForEquipment('perdix');

  test('logging an update writes the record and the version', () async {
    await addComputer(firmware: 'V92');

    await recorder.logUpdate(
      equipmentId: 'perdix',
      version: ' V95 ',
      date: DateTime(2026, 11, 2),
      notes: 'Updated on the boat',
    );

    final log = await history();
    expect(log, hasLength(1));
    expect(log.single.serviceCategory, ServiceCategory.firmwareUpdate);
    expect(log.single.firmwareVersion, 'V95');
    expect(log.single.serviceKindId, isNull);
    expect(log.single.serviceDate, DateTime(2026, 11, 2));
    expect(log.single.notes, 'Updated on the boat');

    final updated = await item();
    expect(updated.firmwareVersion, 'V95');
    // The diver's own fields survive the attribute write.
    expect(
      updated.attributes.where((a) => a.isCustom).map((a) => a.valueText),
      ['Bungee'],
    );
  });

  test('a first report records the version without history', () async {
    await addComputer();

    final outcome = await recorder.recordReported(
      equipmentId: 'perdix',
      reportedVersion: '95',
      at: at,
      catalogue: catalogue,
    );

    expect(outcome, FirmwareReportOutcome.recordedFirst);
    expect((await item()).firmwareVersion, '95');
    expect(await history(), isEmpty);
  });

  test('another spelling of the same release logs nothing and keeps the '
      "diver's spelling", () async {
    await addComputer(firmware: 'V95');

    final outcome = await recorder.recordReported(
      equipmentId: 'perdix',
      reportedVersion: '95',
      at: at,
      catalogue: catalogue,
    );

    expect(outcome, FirmwareReportOutcome.unchanged);
    expect((await item()).firmwareVersion, 'V95');
    expect(await history(), isEmpty);
  });

  test(
    'the same text in another case logs nothing, catalogue or not',
    () async {
      await addComputer(firmware: 'V95');

      final outcome = await recorder.recordReported(
        equipmentId: 'perdix',
        reportedVersion: 'v95',
        at: at,
      );

      expect(outcome, FirmwareReportOutcome.unchanged);
      expect(await history(), isEmpty);
    },
  );

  test('a gear twin with no maker of its own matches through the '
      'download', () async {
    await equipment.createEquipment(
      EquipmentItem(
        id: 'twin',
        name: 'Perdix 2',
        type: EquipmentType.computer,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'twin',
            key: EquipmentAttrKeys.firmwareVersion,
            valueText: 'V95',
          ),
        ],
      ),
    );

    final outcome = await recorder.recordReported(
      equipmentId: 'twin',
      reportedVersion: '95',
      at: at,
      catalogue: catalogue,
      fallbackBrand: 'Shearwater',
      fallbackModel: 'Perdix 2',
    );

    expect(outcome, FirmwareReportOutcome.unchanged);
    expect(await records.getRecordsForEquipment('twin'), isEmpty);
  });

  test(
    'a version only the registration held counts as the previous one',
    () async {
      await addComputer();

      final outcome = await recorder.recordReported(
        equipmentId: 'perdix',
        reportedVersion: '95',
        at: at,
        catalogue: catalogue,
        previousVersion: '92',
      );

      expect(outcome, FirmwareReportOutcome.logged);
      expect((await history()).single.firmwareVersion, '95');
    },
  );

  test('a new version logs one entry', () async {
    await addComputer(firmware: 'V92');

    final outcome = await recorder.recordReported(
      equipmentId: 'perdix',
      reportedVersion: '95',
      at: at,
      catalogue: catalogue,
    );

    expect(outcome, FirmwareReportOutcome.logged);
    expect((await item()).firmwareVersion, '95');
    final log = await history();
    expect(log, hasLength(1));
    expect(log.single.firmwareVersion, '95');
    expect(log.single.serviceDate, at);
    expect(log.single.serviceKindId, isNull);
  });

  test('an item that no longer exists is left alone', () async {
    final outcome = await recorder.recordReported(
      equipmentId: 'gone',
      reportedVersion: '95',
      at: at,
    );
    expect(outcome, FirmwareReportOutcome.unchanged);
  });

  group('firmwareHistoryLabel', () {
    final l10n = AppLocalizationsEn();
    FirmwareModel perdix() => catalogue.models.first;
    ServiceRecord rec(String version) => ServiceRecord(
      id: 'r',
      equipmentId: 'perdix',
      serviceCategory: ServiceCategory.firmwareUpdate,
      serviceDate: at,
      firmwareVersion: version,
      createdAt: at,
      updatedAt: at,
    );

    test('a newer or unrankable version reads as an update', () {
      expect(
        firmwareHistoryLabel(
          l10n,
          rec('V95'),
          model: perdix(),
          previous: 'V92',
        ),
        'Firmware updated to V95',
      );
      expect(firmwareHistoryLabel(l10n, rec('V95')), 'Firmware updated to V95');
      expect(
        firmwareHistoryLabel(
          l10n,
          rec('V97'),
          model: perdix(),
          previous: 'V95',
        ),
        'Firmware updated to V97',
      );
    });

    test(
      'a version the list ranks below the previous one reads as a change',
      () {
        expect(
          firmwareHistoryLabel(
            l10n,
            rec('V94'),
            model: perdix(),
            previous: 'V95',
          ),
          'Firmware changed to V94',
        );
      },
    );
  });
}
