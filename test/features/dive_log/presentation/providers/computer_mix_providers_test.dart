import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/services/computer_mix_reader.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/computer_mix_providers.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3021: the real reader wiring, which the widget tests override.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('builds the reader on the app database', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(computerMixReaderProvider), isA<ComputerMixReader>());
  });

  test(
    'a computer tank on a dive with no downloads has no recorded mix',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const tank = DiveTank(
        id: 'tank-1',
        computerId: 'dc1',
        sourceId: 'source-1',
        sourceTankIndex: 0,
      );
      final provider = recordedComputerMixProvider(
        computerMixKeyFor('dive-1', tank),
      );
      // Held so the auto-disposed provider survives the read.
      final hold = container.listen(provider, (_, _) {});
      addTearDown(hold.close);

      expect(await container.read(provider.future), isNull);
    },
  );
}
