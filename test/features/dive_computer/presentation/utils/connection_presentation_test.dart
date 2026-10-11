import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/presentation/utils/connection_presentation.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

DiveComputerConnection _c(
  DiveComputerConnectionKind kind, {
  String? detail,
  int lastUsedMs = 1000,
}) => DiveComputerConnection(
  id: '${kind.name}-$detail',
  computerId: 'dc',
  kind: kind,
  detail: detail,
  firstUsedAt: DateTime(2026),
  lastUsedAt: DateTime.fromMillisecondsSinceEpoch(lastUsedMs),
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('labels every kind (#3106)', () {
    expect(
      connectionLabel(l10n, _c(DiveComputerConnectionKind.ble)),
      'Bluetooth LE',
    );
    expect(
      connectionLabel(l10n, _c(DiveComputerConnectionKind.bluetoothClassic)),
      'Bluetooth',
    );
    expect(connectionLabel(l10n, _c(DiveComputerConnectionKind.usb)), 'USB');
    expect(
      connectionLabel(l10n, _c(DiveComputerConnectionKind.infrared)),
      'Infrared',
    );
    expect(
      connectionLabel(
        l10n,
        _c(DiveComputerConnectionKind.file, detail: 'shearwaterDb'),
      ),
      'Shearwater Cloud file',
    );
    expect(
      connectionLabel(l10n, _c(DiveComputerConnectionKind.file, detail: 'fit')),
      'Garmin FIT file',
    );
    expect(
      connectionLabel(
        l10n,
        _c(DiveComputerConnectionKind.file, detail: 'someNewFormat'),
      ),
      'someNewFormat file',
    );
    expect(
      connectionLabel(
        l10n,
        _c(DiveComputerConnectionKind.cloud, detail: 'garminConnect'),
      ),
      'Garmin Connect',
    );
    expect(
      connectionLabel(
        l10n,
        _c(DiveComputerConnectionKind.cloud, detail: 'suuntoCloud'),
      ),
      'Suunto app',
    );
    expect(
      connectionLabel(l10n, _c(DiveComputerConnectionKind.cloud)),
      'Cloud import',
    );
  });

  test('icons by kind', () {
    expect(connectionIcon(DiveComputerConnectionKind.ble), Icons.bluetooth);
    expect(connectionIcon(DiveComputerConnectionKind.usb), Icons.usb);
    expect(
      connectionIcon(DiveComputerConnectionKind.file),
      Icons.description_outlined,
    );
    expect(
      connectionIcon(DiveComputerConnectionKind.cloud),
      Icons.cloud_outlined,
    );
    expect(connectionIcon(null), Icons.watch);
  });

  test('a computer\'s icon follows its newest connection, else the legacy '
      'type', () {
    final computer = DiveComputer(
      id: 'dc',
      name: 'x',
      connectionType: 'bluetooth',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(computerConnectionIcon(computer, const []), Icons.bluetooth);
    expect(
      computerConnectionIcon(computer, [
        _c(DiveComputerConnectionKind.file, detail: 'fit', lastUsedMs: 1),
        _c(DiveComputerConnectionKind.cloud, lastUsedMs: 9),
      ]),
      Icons.cloud_outlined,
    );
  });
}
