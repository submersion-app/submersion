import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_check_ins_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A gear item's check-ins and their photos, held in its page's sitting
/// (issue #4527, phase 3, plan 6).
void main() {
  late EquipmentRepository items;
  late EquipmentObservationRepository observations;
  late ProviderContainer container;
  final changeLog = ChangeLogRepository();
  final at = DateTime(2026, 3, 1);

  setUp(() async {
    final db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    container = ProviderContainer();
    addTearDown(container.dispose);
    items = EquipmentRepository();
    observations = EquipmentObservationRepository();
    await items.createEquipment(
      const EquipmentItem(
        id: 'g1',
        name: 'Apex',
        type: EquipmentType.regulator,
      ),
    );
    await observations.create(
      id: 'o1',
      equipmentId: 'g1',
      observedAt: at,
      status: ObservationStatus.ok,
      note: 'Fine',
    );
    await db.customStatement(
      "INSERT INTO media (id, equipment_id, observation_id, file_path, "
      "created_at, updated_at) VALUES ('op1', 'g1', 'o1', '/op1.jpg', 0, 0)",
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  Future<bool> exists(String table, String id) async =>
      (await DatabaseService.instance.database
              .customSelect(
                'SELECT id FROM $table WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .get())
          .isNotEmpty;

  Future<EditSession<EquipmentItem>> sitting({
    SittingMediaWriters? writers,
  }) async {
    final session = EditSession((await items.getEquipmentById('g1'))!);
    addTearDown(session.dispose);
    holdCheckIns(
      session,
      writers ?? SittingMediaWriters.forEquipment(container.read),
    );
    await gearItemCheckInsList.load(session);
    return session;
  }

  Future<void> save(EditSession<EquipmentItem> session) =>
      GearItemEditSaveService(items, GearPhotoRepository()).save(
        equipmentId: 'g1',
        apply: (s) => gearItemToSave(s, session.applyTo(s)),
        changedCardIds: session.changedCardIds,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        alsoWriteIsAChange: session.hasHeldChanges,
      );

  EquipmentObservation fresh(String id) => EquipmentObservation(
    id: id,
    equipmentId: 'g1',
    observedAt: at,
    status: ObservationStatus.ok,
    note: 'New',
    createdAt: at,
    updatedAt: at,
  );

  HeldMediaAdd photo(String id, String observationId) => HeldMediaRow((
    item: MediaItem(
      id: id,
      equipmentId: 'g1',
      observationId: observationId,
      filePath: '/$id.jpg',
      localPath: '/$id.jpg',
      mediaType: MediaType.photo,
      takenAt: at,
      createdAt: at,
      updatedAt: at,
    ),
    enrichment: null,
  ));

  test('a new check-in\'s row is written before its photos', () async {
    final seen = <bool>[];
    final real = SittingMediaWriters.forEquipment(container.read);
    final writers = SittingMediaWriters(
      writeRows: (rows) async {
        seen.add(await exists('equipment_observations', 'o2'));
        return real.writeRows(rows);
      },
      insertNetwork: real.insertNetwork,
      unlink: real.unlink,
      replace: real.replace,
      drainDeletes: real.drainDeletes,
      enqueueUpload: (_) {},
    );
    final session = await sitting(writers: writers);
    holdCheckIn(
      session,
      HeldCheckIn(observation: fresh('o2'), added: [photo('np1', 'o2')]),
    );

    await save(session);

    expect(seen, [true]);
    expect(await exists('equipment_observations', 'o2'), isTrue);
    expect(await exists('media', 'np1'), isTrue);
    await changeLog.settleAll();
    final ops = await DatabaseService.instance.database
        .customSelect('SELECT label FROM change_log_operations')
        .get();
    expect(ops.single.data['label'], 'record_edit:equipment:g1:observations');
  });

  test('the same, then Cancel: no row and no media row', () async {
    final session = await sitting();
    holdCheckIn(
      session,
      HeldCheckIn(observation: fresh('o2'), added: [photo('np1', 'o2')]),
    );

    // Cancel: the sitting ends unsaved (disposed at tear-down).
    expect(session.changedCardIds, {'observations'});
    expect(await exists('equipment_observations', 'o2'), isFalse);
    expect(await exists('media', 'np1'), isFalse);
  });

  test('a removed check-in\'s photos are unlinked in the same write', () async {
    final session = await sitting();
    deleteHeldCheckIn(session, 'o1');

    expect(await exists('equipment_observations', 'o1'), isTrue);
    await save(session);

    expect(await exists('equipment_observations', 'o1'), isFalse);
    expect(await exists('media', 'op1'), isFalse);
  });

  test('a check-in added and deleted in one sitting writes nothing', () async {
    final session = await sitting();
    holdCheckIn(session, HeldCheckIn(observation: fresh('o2')));
    deleteHeldCheckIn(session, 'o2');

    expect(session.isDirty, isFalse);
  });

  test('an edited check-in and a brand change are one entry, and reverting '
      'restores the check-in', () async {
    final session = await sitting();
    final row = gearItemCheckInsList.current(session)!.single;
    holdCheckIn(
      session,
      row.copyWith(observation: row.observation.copyWith(note: 'Leaking')),
    );
    session.set(gearBrandField, 'Scubapro');

    await save(session);

    expect((await observations.getForEquipment('g1')).single.note, 'Leaking');
    await changeLog.settleAll();
    final ops = await DatabaseService.instance.database
        .customSelect('SELECT id FROM change_log_operations')
        .get();
    expect(ops, hasLength(1));

    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(
      await revert.planOperation(ops.single.data['id']! as String),
    );

    expect((await observations.getForEquipment('g1')).single.note, 'Fine');
    expect((await items.getEquipmentById('g1'))!.brand, isNull);
  });
}
