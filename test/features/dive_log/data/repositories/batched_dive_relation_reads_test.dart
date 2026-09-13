import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';

import '../../../../helpers/batched_read_expectations.dart';
import '../../../../helpers/export_logbook_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1867: the batched reads the full UDDF export uses in place of a
/// per-dive loop.
void main() {
  tearDown(tearDownTestDatabase);

  Future<List<String>> seedDives() async {
    await seedExportLogbook(diveCount: 3);
    return ['dive-0', 'dive-1', 'dive-2', 'dive-bare'];
  }

  group('DiveRepository.getGasSwitchesForDives', () {
    batchedReadTests(
      seed: seedDives,
      batched: (ids) => DiveRepository().getGasSwitchesForDives(ids),
      single: (id) => DiveRepository().getGasSwitchesForDive(id),
      holdsNothing: (switches) => switches.isEmpty,
    );
  });

  group('DiveComputerRepository.getEventsForDives', () {
    batchedReadTests(
      seed: seedDives,
      batched: (ids) => DiveComputerRepository().getEventsForDives(ids),
      single: (id) => DiveComputerRepository().getEventsForDive(id),
      holdsNothing: (events) => events.isEmpty,
    );
  });

  group('TankPressureRepository.getTankPressuresForDives', () {
    batchedReadTests(
      seed: seedDives,
      batched: (ids) => TankPressureRepository().getTankPressuresForDives(ids),
      single: (id) => TankPressureRepository().getTankPressuresForDive(id),
      holdsNothing: (byTank) => byTank.isEmpty,
    );
  });
}
