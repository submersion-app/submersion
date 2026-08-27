import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';

void main() {
  test('kindFrom maps connectivity results', () {
    expect(
      NetworkStatusService.kindFrom([ConnectivityResult.wifi]),
      NetworkKind.unmetered,
    );
    expect(
      NetworkStatusService.kindFrom([ConnectivityResult.ethernet]),
      NetworkKind.unmetered,
    );
    expect(
      NetworkStatusService.kindFrom([
        ConnectivityResult.vpn,
        ConnectivityResult.mobile,
      ]),
      NetworkKind.unmetered,
    );
    expect(
      NetworkStatusService.kindFrom([ConnectivityResult.mobile]),
      NetworkKind.cellular,
    );
    expect(
      NetworkStatusService.kindFrom([ConnectivityResult.none]),
      NetworkKind.offline,
    );
    expect(NetworkStatusService.kindFrom(const []), NetworkKind.offline);
  });

  test('kindFrom treats satellite as metered, not offline', () {
    // connectivity_plus 7 added ConnectivityResult.satellite. The old
    // "anything unrecognised is offline" fallback would have reported a
    // working satellite link as no link at all, blocking transfers outright.
    expect(
      NetworkStatusService.kindFrom([ConnectivityResult.satellite]),
      NetworkKind.cellular,
    );
    expect(
      NetworkStatusService.kindFrom([
        ConnectivityResult.satellite,
        ConnectivityResult.wifi,
      ]),
      NetworkKind.unmetered,
      reason: 'an unmetered transport still wins when both are present',
    );
  });
}
