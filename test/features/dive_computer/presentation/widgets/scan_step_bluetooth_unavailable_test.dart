import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';

import 'scan_step_test_support.dart';

/// Service whose BLE scan fails the way the Windows plugin reports a radio
/// that is off or missing.
class _BluetoothOffService extends FakeDiveComputerService {
  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {
    throw PlatformException(
      code: pigeon.bluetoothUnavailableErrorCode,
      message: 'Bluetooth is unavailable: The device is not ready for use.',
    );
  }
}

void main() {
  // Issue #2507: opening the scan step with Bluetooth off used to abort the
  // app on Windows. It now has to land on a readable banner that points at
  // the USB tab, rather than a raw PlatformException dump.
  testWidgets('says Bluetooth is off instead of dumping the exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScanStepTestWidget(
        discoveryNotifier: () =>
            DiscoveryNotifier(service: _BluetoothOffService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Bluetooth is off or unavailable. Turn it on and tap Retry, '
        'or connect with the USB Cable tab.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}
