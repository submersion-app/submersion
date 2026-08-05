import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';

void main() {
  test('round-trips through bytes', () {
    const marker = RetirementMarker(deviceId: 'dev-1', retiredAt: 12345);
    final decoded = RetirementMarker.fromBytes(marker.toBytes());
    expect(decoded.deviceId, 'dev-1');
    expect(decoded.retiredAt, 12345);
    expect(decoded.formatVersion, 1);
  });
}
