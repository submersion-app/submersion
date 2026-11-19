import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/editing/dive_computer_settings_sitting.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A dive computer's own settings, held in its gear item's sitting (issue
/// #4527, phase 3, plan 6).
void main() {
  const item = EquipmentItem(
    id: 'g1',
    name: 'Perdix',
    type: EquipmentType.computer,
  );

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'D', 0, 0)",
    );
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO dive_computers (id, diver_id, name, is_favorite, "
      "created_at, updated_at) VALUES "
      "('c1', 'd1', 'Perdix', 0, 0, 0), ('c2', 'd1', 'Teric', 1, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<DiveComputer> computer(String id) async =>
      (await DiveComputerRepository().getComputerById(id))!;

  DiveComputerSettings stored(DiveComputer c) =>
      storedDiveComputerSettings(c, ClockSyncOverride.inherit);

  test('a favourite set back to stored releases the change', () async {
    final c1 = await computer('c1');
    final session = EditSession(item);
    addTearDown(session.dispose);

    holdDiveComputerSettings(
      session,
      computer: c1,
      stored: stored(c1),
      next: (
        favourite: true,
        autoDownloadDisabled: false,
        clockSync: ClockSyncOverride.inherit,
      ),
    );
    expect(session.changedCardIds, {'diveComputer'});
    holdDiveComputerSettings(
      session,
      computer: c1,
      stored: stored(c1),
      next: stored(c1),
    );

    expect(session.isDirty, isFalse);
    expect(heldDiveComputerSettings(session), isNull);
  });

  test('the write sets favourite and auto-download only where they differ, '
      'and the clock sync choice waits for the commit', () async {
    final c1 = await computer('c1');
    final session = EditSession(item);
    addTearDown(session.dispose);

    holdDiveComputerSettings(
      session,
      computer: c1,
      stored: stored(c1),
      next: (
        favourite: true,
        autoDownloadDisabled: true,
        clockSync: ClockSyncOverride.never,
      ),
      diverId: 'd1',
    );
    expect((await computer('c1')).isFavorite, isFalse);
    await session.runHeldWrites();

    expect((await computer('c1')).isFavorite, isTrue);
    expect((await computer('c1')).autoDownloadDisabled, isTrue);
    // Making it the favourite takes the star from the diver's other one.
    expect((await computer('c2')).isFavorite, isFalse);
    expect(heldClockSync(session), (
      computerId: 'c1',
      value: ClockSyncOverride.never,
    ));
  });

  test('a clock sync choice alone writes nothing to the database', () async {
    final c2 = await computer('c2');
    final session = EditSession(item);
    addTearDown(session.dispose);

    holdDiveComputerSettings(
      session,
      computer: c2,
      stored: stored(c2),
      next: (
        favourite: true,
        autoDownloadDisabled: false,
        clockSync: ClockSyncOverride.always,
      ),
    );
    await session.runHeldWrites();

    expect((await computer('c2')).isFavorite, isTrue);
    expect((await computer('c1')).isFavorite, isFalse);
    expect(session.changedCardIds, {'diveComputer'});
    expect(heldClockSync(session)?.value, ClockSyncOverride.always);
  });
}
