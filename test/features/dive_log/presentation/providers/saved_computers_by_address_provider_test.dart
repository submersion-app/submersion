import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

DiveComputer _computer(String id, {String? bluetoothAddress}) => DiveComputer(
  id: id,
  name: id,
  bluetoothAddress: bluetoothAddress,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DiveComputerConnection _connection(
  String computerId,
  DiveComputerConnectionKind kind, {
  String? address,
}) => DiveComputerConnection(
  id: '$computerId-${kind.name}',
  computerId: computerId,
  kind: kind,
  firstUsedAt: DateTime(2026),
  lastUsedAt: DateTime(2026),
  address: address,
);

void main() {
  test('maps the legacy address and every local connection address '
      '(#3106)', () async {
    final legacy = _computer('legacy', bluetoothAddress: 'AA:BB');
    final usb = _computer('usb');
    final container = ProviderContainer(
      overrides: [
        allDiveComputersProvider.overrideWith((ref) async => [legacy, usb]),
        allDiveComputerConnectionsProvider.overrideWith(
          (ref) async => {
            'usb': [
              _connection('usb', DiveComputerConnectionKind.usb, address: 'P1'),
              _connection(
                'usb',
                DiveComputerConnectionKind.file,
                address: 'NOT-A-PORT',
              ),
            ],
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final map = await container.read(savedComputersByAddressProvider.future);

    expect(map['AA:BB']?.id, 'legacy');
    expect(map['P1']?.id, 'usb');
    expect(map.containsKey('NOT-A-PORT'), isFalse);
  });

  test('a failed connections read still maps the legacy addresses', () async {
    final legacy = _computer('legacy', bluetoothAddress: 'AA:BB');
    final container = ProviderContainer(
      overrides: [
        allDiveComputersProvider.overrideWith((ref) async => [legacy]),
        allDiveComputerConnectionsProvider.overrideWith(
          (ref) async => throw StateError('no database'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final map = await container.read(savedComputersByAddressProvider.future);

    expect(map['AA:BB']?.id, 'legacy');
  });
}
