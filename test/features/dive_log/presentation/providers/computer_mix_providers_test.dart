import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/services/computer_mix_reader.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/computer_mix_providers.dart';

import '../../../../helpers/test_database.dart';

/// A reader that always has a recording, to show whether it was asked.
class _NitroxReader implements ComputerMixReader {
  @override
  Future<GasMix?> recordedMix({
    required String diveId,
    required DiveTank tank,
  }) async => const GasMix(o2: 32);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  group('in a browser (#4121)', () {
    const tank = DiveTank(
      id: 'tank-1',
      computerId: 'dc1',
      sourceId: 'source-1',
      sourceTankIndex: 0,
    );

    test('natively the reader\'s recording comes through', () async {
      final container = ProviderContainer(
        overrides: [
          computerMixReaderProvider.overrideWithValue(_NitroxReader()),
        ],
      );
      addTearDown(container.dispose);
      final provider = recordedComputerMixProvider(
        computerMixKeyFor('dive-1', tank),
      );
      final hold = container.listen(provider, (_, _) {});
      addTearDown(hold.close);
      expect((await container.read(provider.future))?.o2, 32);
    });

    test('a browser never asks the native parser: no recording', () async {
      final container = ProviderContainer(
        overrides: [
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
          computerMixReaderProvider.overrideWithValue(_NitroxReader()),
        ],
      );
      addTearDown(container.dispose);
      final provider = recordedComputerMixProvider(
        computerMixKeyFor('dive-1', tank),
      );
      final hold = container.listen(provider, (_, _) {});
      addTearDown(hold.close);
      expect(await container.read(provider.future), isNull);
    });
  });
}
