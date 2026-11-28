import 'package:drift/drift.dart' show TableUpdate, UpdateKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';

import '../../../../helpers/test_database.dart';

/// Counts the reads of the gear used on a dive.
class _CountingGear extends MediaGearRepository {
  int reads = 0;

  int linkedReads = 0;

  @override
  Future<Set<String>> gearOnDive(String diveId) async {
    reads++;
    return const {};
  }

  @override
  Future<List<MediaItem>> linkedMediaFor(
    String equipmentId, {
    required String? diverId,
  }) async {
    linkedReads++;
    return const [];
  }
}

/// The photo gear sheet's On this dive list (issue #5046) follows every
/// table the gear-usage query reads.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test(
    'gear on a dive is read again when a transmitter mapping changes',
    () async {
      final gear = _CountingGear();
      final container = ProviderContainer(
        overrides: [mediaGearRepositoryProvider.overrideWithValue(gear)],
      );
      addTearDown(container.dispose);
      // A listener keeps the provider active, as a mounted sheet would.
      container.listen(gearOnDiveProvider('dive1'), (_, _) {});
      await container.read(gearOnDiveProvider('dive1').future);
      expect(gear.reads, 1);

      // A tank's transmitter serial resolves to an item through this table.
      db.markTablesUpdated({db.transmitters});
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await container.read(gearOnDiveProvider('dive1').future);

      expect(gear.reads, 2);
    },
  );

  test('linked photos are read again when a dive changes owner', () async {
    // Which linked photos a diver sees depends on whose dive each is on.
    final gear = _CountingGear();
    final container = ProviderContainer(
      overrides: [
        mediaGearRepositoryProvider.overrideWithValue(gear),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ],
    );
    addTearDown(container.dispose);
    container.listen(linkedMediaForEquipmentProvider('e1'), (_, _) {});
    await container.read(linkedMediaForEquipmentProvider('e1').future);
    expect(gear.linkedReads, 1);

    // An update, as a change of owner is: a delete would also reach the
    // media rows through their ON DELETE SET NULL.
    db.notifyUpdates({TableUpdate.onTable(db.dives, kind: UpdateKind.update)});
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await container.read(linkedMediaForEquipmentProvider('e1').future);

    expect(gear.linkedReads, 2);
  });
}
