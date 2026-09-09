import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

import '../../../../helpers/test_database.dart';

/// Exposes a Ref for the loader under test.
final _probe = Provider<Ref>((ref) => ref);

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('loadTransmitterMatcher indexes the active diver entries', () async {
    final repo = TransmitterRepository();
    await repo.create(
      Transmitter(
        id: 'e1',
        diverId: null,
        transmitterSerial: '180777',
        label: 'O2',
        role: TankRole.oxygenSupply,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    final matcher = await loadTransmitterMatcher(container.read(_probe));

    expect(
      matcher.match(serial: '180777', computerId: null, index: 0)?.id,
      'e1',
    );
  });
}
