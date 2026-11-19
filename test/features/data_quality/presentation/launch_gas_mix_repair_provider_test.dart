import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/data_quality/data/services/hundredfold_gas_mix_repair.dart';
import 'package:submersion/features/data_quality/presentation/providers/launch_gas_mix_repair_provider.dart';

class _CountingRepair extends HundredfoldGasMixRepair {
  int runs = 0;
  Object? failWith;

  @override
  Future<Set<String>> rescaleAll() async {
    runs++;
    if (failWith case final error?) throw error;
    return const {};
  }
}

/// Issue #4714: the launch repair of mixes stored 100 times too high.
void main() {
  late _CountingRepair fake;
  late ProviderContainer container;

  setUp(() {
    fake = _CountingRepair();
    container = ProviderContainer(
      overrides: [hundredfoldGasMixRepairProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  test('runs the repair over the whole logbook', () async {
    await container.read(launchGasMixRepairProvider)();
    expect(fake.runs, 1);
  });

  test('a failure is contained, for the next launch to try again', () async {
    fake.failWith = StateError('database closed');
    await expectLater(container.read(launchGasMixRepairProvider)(), completes);
    expect(fake.runs, 1);
  });
}
