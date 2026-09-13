import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// An in-memory database that writes every statement it runs through
/// `print`, installed as the one [DatabaseService] hands out.
Future<AppDatabase> setUpStatementLoggingDatabase() async {
  final db = AppDatabase(NativeDatabase.memory(logStatements: true));
  DatabaseService.instance.setTestDatabase(db);
  return db;
}

/// Runs [body] and returns what it returned with the statements it ran on
/// a [setUpStatementLoggingDatabase] database.
///
/// drift's `logStatements` writes each statement through `print`, one
/// `Drift: Sent ...` line per statement. Custom SQL keeps its line breaks,
/// so a multi-line query prints several lines; only the `Drift: Sent` line
/// starts a statement, and the continuation lines are not counted.
Future<(T, List<String>)> captureStatements<T>(
  Future<T> Function() body,
) async {
  final logged = <String>[];
  final result = await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => logged.add(line),
    ),
  );
  return (
    result,
    [
      for (final line in logged)
        if (line.startsWith('Drift: Sent')) line,
    ],
  );
}

/// Runs [body] with its printed output discarded: seeding a logging
/// database would otherwise flood the test log.
Future<T> silently<T>(Future<T> Function() body) async =>
    (await captureStatements(body)).$1;

/// Seeds [diveCount] dives, each carrying every per-dive relation a full
/// UDDF export reads (buddies with roles and a certification, tags, a
/// weight, gas switches, profile events and per-tank pressures) and a
/// signature from each kind of signer, plus one bare dive with none of
/// them. Returns the seeded equipment, [itemCount] items each with service
/// records.
///
/// Two of each dive's events share a timestamp, so a batched read has to
/// keep their order to produce the same document the per-dive read did.
Future<List<EquipmentItem>> seedExportLogbook({
  required int diveCount,
  int itemCount = 2,
}) async {
  final now = DateTime(2026, 1, 1);
  final buddies = BuddyRepository();
  final guide = await buddies.createBuddy(
    Buddy(id: 'buddy-guide', name: 'Ana Reyes', createdAt: now, updatedAt: now),
  );
  final plain = await buddies.createBuddy(
    Buddy(
      id: 'buddy-plain',
      name: 'Joe Bloggs',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await CertificationRepository().createCertification(
    Certification(
      id: '',
      buddyId: guide.id,
      name: 'Divemaster',
      level: CertificationLevel.diveMaster,
      agency: CertificationAgency.padi,
      createdAt: now,
      updatedAt: now,
    ),
  );

  final tags = TagRepository();
  final reef = await tags.createTag(
    Tag(id: 'tag-reef', name: 'Reef', createdAt: now, updatedAt: now),
  );
  final night = await tags.createTag(
    Tag(id: 'tag-night', name: 'Night', createdAt: now, updatedAt: now),
  );

  final dives = DiveRepository();
  final computers = DiveComputerRepository();
  final pressures = TankPressureRepository();
  final signatures = SignatureStorageService();
  final signature = Uint8List.fromList(const [1, 2, 3]);

  for (var i = 0; i < diveCount; i++) {
    final diveId = 'dive-$i';
    final back = '$diveId-back';
    final deco = '$diveId-deco';
    await dives.createDive(
      Dive(
        id: diveId,
        dateTime: DateTime(2026, 1, 1 + i, 9),
        tanks: [
          DiveTank(id: back),
          DiveTank(
            id: deco,
            gasMix: const GasMix(o2: 50),
            role: TankRole.deco,
            order: 1,
          ),
        ],
        weights: [
          DiveWeight(
            id: '$diveId-weight',
            diveId: diveId,
            weightType: WeightType.belt,
            amountKg: 4,
          ),
        ],
        profile: const [
          DiveProfilePoint(timestamp: 60, depth: 12),
          DiveProfilePoint(timestamp: 600, depth: 30),
          DiveProfilePoint(timestamp: 1500, depth: 21),
        ],
      ),
    );
    await buddies.addBuddyToDive(diveId, guide.id, DiveRole.diveGuideId);
    await buddies.addBuddyToDive(diveId, plain.id, DiveRole.buddyId);
    await tags.addTagToDive(diveId, reef.id);
    await tags.addTagToDive(diveId, night.id);
    await dives.createGasSwitch(
      GasSwitch(
        id: '',
        diveId: diveId,
        timestamp: 0,
        tankId: back,
        depth: 0,
        createdAt: now,
      ),
    );
    await dives.createGasSwitch(
      GasSwitch(
        id: '',
        diveId: diveId,
        timestamp: 1500,
        tankId: deco,
        depth: 21,
        createdAt: now,
      ),
    );
    await computers.addProfileEvent(
      diveId: diveId,
      timestamp: 600,
      eventType: ProfileEventType.maxDepth.name,
      depth: 30,
    );
    await computers.addProfileEvent(
      diveId: diveId,
      timestamp: 600,
      eventType: ProfileEventType.ascentStart.name,
      depth: 30,
    );
    await computers.addProfileEvent(
      diveId: diveId,
      timestamp: 1500,
      eventType: ProfileEventType.gasSwitch.name,
      depth: 21,
      tankId: deco,
    );
    await pressures.insertTankPressures(diveId, {
      back: [(timestamp: 0, pressure: 200), (timestamp: 60, pressure: 190)],
      deco: [(timestamp: 1500, pressure: 180)],
    });
    await signatures.saveSignature(
      diveId: diveId,
      imageBytes: signature,
      signerName: 'Instructor $i',
    );
    await signatures.saveBuddySignature(
      diveId: diveId,
      imageBytes: signature,
      buddyId: plain.id,
      buddyName: plain.name,
      role: 'buddy',
    );
  }

  // Nothing hangs off this one, so every loader must leave it out.
  await dives.createDive(
    Dive(id: 'dive-bare', dateTime: DateTime(2025, 12, 31, 9)),
  );

  final equipment = EquipmentRepository();
  final records = ServiceRecordRepository();
  final items = <EquipmentItem>[];
  for (var i = 0; i < itemCount; i++) {
    final item = await equipment.createEquipment(
      EquipmentItem(
        id: 'item-$i',
        name: 'Regulator $i',
        type: EquipmentType.regulator,
      ),
    );
    for (final (month, category) in [
      (3, ServiceCategory.annual),
      (9, ServiceCategory.inspection),
    ]) {
      await records.createRecord(
        ServiceRecord(
          id: '',
          equipmentId: item.id,
          serviceCategory: category,
          serviceDate: DateTime(2025, month, 1 + i),
          provider: 'Shop $i',
          cost: 80,
          notes: 'Service $month',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    items.add(item);
  }
  // No records at all: it must contribute nothing.
  items.add(
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'item-unserviced',
        name: 'Mask',
        type: EquipmentType.mask,
      ),
    ),
  );
  return items;
}
