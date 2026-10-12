import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show EquipmentCompanion;
import 'package:submersion/core/services/export/models/export_service_record.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

import '../../../../core/services/export/csv/csv_test_fixtures.dart';
import '../../../../helpers/test_database.dart';
import 'wizard_import_harness.dart';

const _diverId = 'diver-1';
final _now = DateTime(2026);

Diver _diver() =>
    Diver(id: _diverId, name: 'Test Diver', createdAt: _now, updatedAt: _now);

/// A full UDDF backup restored through the wizard into a clean library
/// (issue #2651): fills keep their ids and link through the restored
/// passport id, a second import adds nothing, a deleted fill stays
/// deleted, and the service records come along.
void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 2, 10),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 18.0,
    tanks: const [],
    profile: const [],
    gear: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );
  final tank = EquipmentItem(
    id: 'e-tank',
    name: 'AL80',
    type: EquipmentType.tank,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: 'e-tank',
        key: EquipmentAttrKeys.passportId,
        valueText: 'pp-al80',
      ),
    ],
  );
  final service = ServiceRecord(
    id: 's1',
    equipmentId: 'e-tank',
    serviceCategory: ServiceCategory.inspection,
    serviceKindId: 'k-burst',
    serviceDate: DateTime(2026, 5, 1),
    provider: 'Hydro shop',
  );
  // A custom service kind and two clocks on the tank (issue #2651): one of
  // the built-in hydro kind, which createEquipment also seeds, and one of
  // the custom kind.
  final burst = ServiceKind(
    id: 'k-burst',
    diverId: 'someone-else',
    name: 'Burst disc',
    applicableTypes: const [EquipmentType.tank],
    defaultIntervalDays: 730,
    createdAt: _now,
    updatedAt: _now,
  );
  final clocks = [
    ServiceSchedule(
      id: 'auto-hydro-e-tank',
      equipmentId: 'e-tank',
      serviceKindId: 'hydro',
      intervalDays: 1095,
      createdAt: _now,
      updatedAt: _now,
    ),
    ServiceSchedule(
      id: 'c-burst',
      equipmentId: 'e-tank',
      serviceKindId: 'k-burst',
      intervalDays: 365,
      createdAt: _now,
      updatedAt: _now,
    ),
  ];

  Future<Uint8List> backup() async => Uint8List.fromList(
    utf8.encode(
      await UddfFullExportService().generateAllDataXmlForTest(
        dives: [dive],
        equipment: [tank],
        serviceRecords: [service],
        fills: goldenFills(),
        serviceKinds: [burst],
        serviceSchedulesByItem: {'e-tank': clocks},
      ),
    ),
  );

  testWidgets('a full backup restores fills linked, once, with service '
      'records', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await tester.runAsync(() => DiverRepository().createDiver(_diver()));

    final payload = await tester.runAsync(
      () async => UddfImportParser().parse(await backup()),
    );
    ImportBundle? review;
    final result = await importThroughWizard(
      tester,
      payload: payload!,
      diver: _diver(),
      onReview: (bundle) => review = bundle,
    );
    expect(result.errorMessage, isNull);
    expect(review!.groups[ImportEntityType.fills]!.items, hasLength(2));
    expect(result.importedCounts[ImportEntityType.fills], 2);

    late String restoredTank;
    await tester.runAsync(() async {
      final items = await EquipmentRepository().getAllEquipment(
        diverId: _diverId,
      );
      restoredTank = items.single.id;
      expect(
        await CylinderPassportRepository().getPassportId(restoredTank),
        'pp-al80',
      );
      final fills = CylinderFillRepository();
      final linked = (await fills.getById(goldenFills().first.id))!;
      expect(linked.equipmentId, restoredTank);
      expect(linked.pressureBar, 206.843);
      expect(linked.temperatureC, 22);
      final unlinked = (await fills.getById(goldenFills()[1].id))!;
      expect(unlinked.equipmentId, isNull);
      final records = await ServiceRecordRepository().getRecordsForEquipment(
        restoredTank,
      );
      expect(records.map((r) => r.provider), ['Hydro shop']);

      // The custom kind is the diver's own now, and the record and a clock
      // point at it; the seeded hydro clock took the backup's interval.
      final mine = [
        for (final k in await ServiceKindRepository().getAllKinds(
          diverId: _diverId,
        ))
          if (!k.isBuiltIn) k,
      ];
      expect(mine.map((k) => k.name), ['Burst disc']);
      expect(mine.single.diverId, _diverId);
      expect(records.single.serviceKindId, mine.single.id);
      final restoredClocks = await ServiceScheduleRepository()
          .getSchedulesForEquipment(restoredTank);
      final hydro = restoredClocks.where((s) => s.serviceKindId == 'hydro');
      expect(hydro.map((s) => s.intervalDays), [1095]);
      // Exactly the backup's clocks: no default VIP clock it did not list.
      expect(
        {for (final s in restoredClocks) s.serviceKindId},
        {'hydro', mine.single.id},
      );
      expect(
        restoredClocks
            .where((s) => s.serviceKindId == mine.single.id)
            .map((s) => s.intervalDays),
        [365],
      );
    });

    // The same backup over the restored library: every fill is marked as
    // already here and nothing is added; the tag stays where it is.
    ImportBundle? again;
    final second = await importThroughWizard(
      tester,
      payload: payload,
      diver: _diver(),
      onReview: (bundle) => again = bundle,
    );
    expect(again!.groups[ImportEntityType.fills]!.duplicateIndices, {0, 1});
    expect(second.importedCounts[ImportEntityType.fills], isNull);
    await tester.runAsync(() async {
      expect(
        await CylinderFillRepository().getAllVisibleTo(_diverId),
        hasLength(2),
      );
      expect(
        await CylinderPassportRepository().getPassportId(restoredTank),
        'pp-al80',
      );
      // Nothing is duplicated: one custom kind, the same clocks.
      expect([
        for (final k in await ServiceKindRepository().getAllKinds(
          diverId: _diverId,
        ))
          if (!k.isBuiltIn) k,
      ], hasLength(1));
      expect(
        (await ServiceScheduleRepository().getSchedulesForEquipment(
          restoredTank,
        )).where((s) => s.serviceKindId == 'hydro'),
        hasLength(1),
      );
      // A matched item's history is not attached again.
      expect(
        await ServiceRecordRepository().getRecordsForEquipment(restoredTank),
        hasLength(1),
      );
      await CylinderFillRepository().delete(goldenFills().first.id);
    });

    // A fill deleted here does not come back.
    await importThroughWizard(tester, payload: payload, diver: _diver());
    await tester.runAsync(() async {
      expect(
        await CylinderFillRepository().getById(goldenFills().first.id),
        isNull,
      );
    });
  });

  testWidgets('an id another item already holds is not adopted, and the '
      'fills link to that holder', (tester) async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await tester.runAsync(() async {
      await DiverRepository().createDiver(_diver());
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'holder',
              name: 'Steel 15',
              type: 'tank',
              createdAt: t,
              updatedAt: t,
              diverId: const Value(_diverId),
            ),
          );
      await CylinderPassportRepository().assignPassportId(
        equipmentId: 'holder',
        passportId: 'pp-al80',
        diverId: _diverId,
      );
    });

    final payload = await tester.runAsync(
      () async => UddfImportParser().parse(await backup()),
    );
    await importThroughWizard(tester, payload: payload!, diver: _diver());

    await tester.runAsync(() async {
      final items = await EquipmentRepository().getAllEquipment(
        diverId: _diverId,
      );
      final restored = items.singleWhere((i) => i.id != 'holder');
      expect(
        await CylinderPassportRepository().getPassportId(restored.id),
        isNull,
      );
      expect(
        (await CylinderFillRepository().getById(
          goldenFills().first.id,
        ))!.equipmentId,
        'holder',
      );
    });
  });

  testWidgets('two backups imported as one batch resolve their tags, fills '
      'and clocks through the per-file ids', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await tester.runAsync(() => DiverRepository().createDiver(_diver()));

    EquipmentItem tagged(String id, String name, String passportId) =>
        EquipmentItem(
          id: id,
          name: name,
          type: EquipmentType.tank,
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: id,
              key: EquipmentAttrKeys.passportId,
              valueText: passportId,
            ),
          ],
        );
    CylinderFill fillOf(String id, String passportId) => CylinderFill(
      id: id,
      passportId: passportId,
      filledAt: DateTime(2026, 9, 1),
      o2Percent: 32,
      createdAt: _now,
      updatedAt: _now,
    );
    ServiceSchedule clock(String item, String kind, int days) =>
        ServiceSchedule(
          id: 'c-$item-$kind',
          equipmentId: item,
          serviceKindId: kind,
          intervalDays: days,
          createdAt: _now,
          updatedAt: _now,
        );
    Future<ImportPayload> parsed(
      String diveId,
      DateTime when,
      EquipmentItem tank,
      CylinderFill fill,
      List<ServiceSchedule> clocks,
    ) async => UddfImportParser().parse(
      Uint8List.fromList(
        utf8.encode(
          await UddfFullExportService().generateAllDataXmlForTest(
            dives: [dive.copyWith(id: diveId, dateTime: when)],
            equipment: [tank],
            fills: [fill],
            serviceKinds: [burst],
            serviceSchedulesByItem: {tank.id: clocks},
          ),
        ),
      ),
    );

    final batch = await tester.runAsync(() async {
      final a = await parsed(
        'dive-a',
        DateTime(2026, 6, 2, 10),
        tagged('e-a', 'AL80', 'pp-a'),
        fillOf('f-a', 'pp-a'),
        [clock('e-a', 'hydro', 1095), clock('e-a', 'k-burst', 365)],
      );
      final b = await parsed(
        'dive-b',
        DateTime(2026, 7, 9, 14),
        tagged('e-b', 'Steel 15', 'pp-b'),
        fillOf('f-b', 'pp-b'),
        [clock('e-b', 'k-burst', 200)],
      );
      return const PayloadMerger().merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);
    });
    final result = await importThroughWizard(
      tester,
      payload: batch!,
      diver: _diver(),
    );
    expect(result.errorMessage, isNull);

    await tester.runAsync(() async {
      final kinds = [
        for (final k in await ServiceKindRepository().getAllKinds(
          diverId: _diverId,
        ))
          if (!k.isBuiltIn) k,
      ];
      expect(kinds.map((k) => k.name), ['Burst disc']);
      final byName = {
        for (final e in await EquipmentRepository().getAllEquipment(
          diverId: _diverId,
        ))
          e.name: e.id,
      };
      final passports = CylinderPassportRepository();
      final fills = CylinderFillRepository();
      final schedules = ServiceScheduleRepository();
      Future<Map<String, int?>> clocksOf(String id) async => {
        for (final s in await schedules.getSchedulesForEquipment(id))
          s.serviceKindId: s.intervalDays,
      };

      expect(await passports.getPassportId(byName['AL80']!), 'pp-a');
      expect(await passports.getPassportId(byName['Steel 15']!), 'pp-b');
      expect((await fills.getById('f-a'))!.equipmentId, byName['AL80']);
      expect((await fills.getById('f-b'))!.equipmentId, byName['Steel 15']);
      expect(await clocksOf(byName['AL80']!), {
        'hydro': 1095,
        kinds.single.id: 365,
      });
      expect(await clocksOf(byName['Steel 15']!), {kinds.single.id: 200});
    });
  });
}
