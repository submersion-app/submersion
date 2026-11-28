import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';

import '../../../../helpers/test_database.dart';

/// Counts the reads of the gear used on a dive.
class _CountingGear extends MediaGearRepository {
  int reads = 0;

  @override
  Future<Set<String>> gearOnDive(String diveId) async {
    reads++;
    return const {};
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
}
