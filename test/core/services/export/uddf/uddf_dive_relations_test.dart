import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/export/models/export_service_record.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_relations.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/export_logbook_fixture.dart';

/// Issue #1867: the full UDDF export read each relation one dive (and one
/// gear item) at a time, so its statement count grew with the logbook.
void main() {
  /// Statements [load] issues against a fresh logbook of [diveCount] dives
  /// and [itemCount] gear items. Seeding and the dive list (the caller's
  /// read, not the loader's) run outside the capture: they hit the same
  /// tables and would be counted too.
  Future<int> statementsFor({
    required int diveCount,
    required int itemCount,
    required Future<Object?> Function(
      List<Dive> dives,
      List<EquipmentItem> items,
    )
    load,
  }) async {
    await setUpStatementLoggingDatabase();
    try {
      final items = await silently(
        () => seedExportLogbook(diveCount: diveCount, itemCount: itemCount),
      );
      final dives = await silently(() => DiveRepository().getAllDives());
      final (_, statements) = await captureStatements(() => load(dives, items));
      return statements.length;
    } finally {
      await tearDownTestDatabase();
    }
  }

  Future<UddfDiveRelations> loadRelations(List<Dive> dives) =>
      loadUddfDiveRelations(
        buddyRepository: BuddyRepository(),
        tagRepository: TagRepository(),
        diveRepository: DiveRepository(),
        diveComputerRepository: DiveComputerRepository(),
        tankPressureRepository: TankPressureRepository(),
        dives: dives,
      );

  group('statement count', () {
    test('the per-dive relations cost the same for any logbook size', () async {
      Future<int> count(int diveCount) => statementsFor(
        diveCount: diveCount,
        itemCount: 1,
        load: (dives, _) => loadRelations(dives),
      );

      final small = await count(2);
      final large = await count(12);
      expect(large, small, reason: '2 dives: $small, 12 dives: $large');
    });

    test('service records cost the same for any gear count', () async {
      Future<int> count(int itemCount) => statementsFor(
        diveCount: 1,
        itemCount: itemCount,
        load: (_, items) =>
            loadUddfServiceRecords(ServiceRecordRepository(), items),
      );

      final small = await count(2);
      final large = await count(12);
      expect(large, small, reason: '2 items: $small, 12 items: $large');
    });
  });

  group('exported document', () {
    setUp(setUpTestDatabase);
    tearDown(tearDownTestDatabase);

    Future<String> render(
      List<Dive> dives,
      List<EquipmentItem> items,
      UddfDiveRelations relations,
      List<ServiceRecord> serviceRecords,
    ) async {
      final xml = await UddfFullExportService().generateAllDataXmlForTest(
        dives: dives,
        buddies: await BuddyRepository().getAllBuddies(),
        tags: await TagRepository().getAllTags(),
        equipment: items,
        serviceRecords: serviceRecords,
        diveBuddies: relations.diveBuddies,
        diveTags: relations.diveTags,
        diveWeights: relations.diveWeights,
        diveGasSwitches: relations.diveGasSwitches,
        diveProfileEvents: relations.diveProfileEvents,
        diveTankPressures: relations.diveTankPressures,
      );
      // The generator stamps the wall clock; nothing else differs by time.
      return xml.replaceFirst(RegExp('<datetime>[^<]*</datetime>'), '');
    }

    test('is identical to the one built from per-dive reads', () async {
      final items = await seedExportLogbook(diveCount: 4, itemCount: 3);
      final repository = DiveRepository();
      // The builder writes tank pressures only on profile waypoints, and
      // getAllDives leaves profiles out, so they are attached here for the
      // pressures to reach the document at all.
      final dives = [
        for (final dive in await repository.getAllDives())
          dive.copyWith(
            profile: (await repository.getDiveById(dive.id))!.profile,
          ),
      ];

      final expected = await render(
        dives,
        items,
        await _loadRelationsPerDive(dives),
        await _loadServiceRecordsPerItem(items),
      );
      final actual = await render(
        dives,
        items,
        await loadRelations(dives),
        await loadUddfServiceRecords(ServiceRecordRepository(), items),
      );

      // Every relation has to reach the document, or two empty documents
      // would compare equal and prove nothing.
      for (final marker in [
        '<tagref>tag_tag-reef</tagref>',
        '<eventtype>ascentStart</eventtype>',
        '<tankref>dive-0-deco</tankref>',
        '<tankpressure ref="tank_dive-0-back">',
        'buddy-guide',
        'Service 9',
      ]) {
        expect(expected, contains(marker), reason: marker);
      }
      expect(actual, expected);
    });
  });
}

/// The per-dive reads both full UDDF exports made before issue #1867,
/// kept as the oracle the batched loader has to reproduce.
Future<UddfDiveRelations> _loadRelationsPerDive(List<Dive> dives) async {
  final buddies = BuddyRepository();
  final tags = TagRepository();
  final diveRepository = DiveRepository();
  final computers = DiveComputerRepository();
  final pressures = TankPressureRepository();
  final diveBuddies = <String, List<BuddyWithRole>>{};
  final diveTags = <String, List<Tag>>{};
  final diveWeights = <String, List<DiveWeight>>{};
  final diveGasSwitches = <String, List<GasSwitchWithTank>>{};
  final diveProfileEvents = <String, List<ProfileEvent>>{};
  final diveTankPressures = <String, Map<String, List<TankPressurePoint>>>{};
  for (final dive in dives) {
    final buddiesForDive = await buddies.getBuddiesForDive(dive.id);
    if (buddiesForDive.isNotEmpty) diveBuddies[dive.id] = buddiesForDive;
    final tagsForDive = await tags.getTagsForDive(dive.id);
    if (tagsForDive.isNotEmpty) diveTags[dive.id] = tagsForDive;
    if (dive.weights.isNotEmpty) diveWeights[dive.id] = dive.weights;
    final switches = await diveRepository.getGasSwitchesForDive(dive.id);
    if (switches.isNotEmpty) diveGasSwitches[dive.id] = switches;
    final eventRows = await computers.getEventsForDive(dive.id);
    if (eventRows.isNotEmpty) {
      diveProfileEvents[dive.id] = eventRows
          .map(mapDiveProfileEventToProfileEvent)
          .toList();
    }
    final tankPressures = await pressures.getTankPressuresForDive(dive.id);
    if (tankPressures.isNotEmpty) diveTankPressures[dive.id] = tankPressures;
  }
  return UddfDiveRelations(
    diveBuddies: diveBuddies,
    diveTags: diveTags,
    diveWeights: diveWeights,
    diveGasSwitches: diveGasSwitches,
    diveProfileEvents: diveProfileEvents,
    diveTankPressures: diveTankPressures,
  );
}

/// The per-item service record read the full UDDF exports made before
/// issue #1867.
Future<List<ServiceRecord>> _loadServiceRecordsPerItem(
  List<EquipmentItem> items,
) async => [
  for (final item in items)
    for (final r in await ServiceRecordRepository().getRecordsForEquipment(
      item.id,
    ))
      ServiceRecord(
        id: r.id,
        equipmentId: r.equipmentId,
        serviceCategory: r.serviceCategory,
        serviceDate: r.serviceDate,
        provider: r.provider,
        cost: r.cost,
        currency: r.currency,
        nextServiceDue: r.nextServiceDue,
        notes: r.notes,
      ),
];
