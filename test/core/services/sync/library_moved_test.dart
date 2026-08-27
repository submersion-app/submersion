import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/library_moved.dart';

/// The "library moved" marker: written to the OLD backend when a device
/// switches away from it, so a straggler device still pointed at that backend
/// learns the library has moved instead of syncing into an abandoned copy
/// forever (the invisible split-brain). Mirrors LibraryEpochMarker's shape.
void main() {
  group('LibraryMovedMarker', () {
    test('round-trips through JSON', () {
      const marker = LibraryMovedMarker(
        movedAt: 1234567,
        toProviderId: 'icloud',
        toProviderName: 'iCloud',
        deviceId: 'device-A',
        deviceName: "Eric's Mac",
        appVersion: '1.4.9.99',
      );

      final decoded = LibraryMovedMarker.fromJson(marker.toJson());

      expect(decoded.movedAt, 1234567);
      expect(decoded.toProviderId, 'icloud');
      expect(decoded.toProviderName, 'iCloud');
      expect(decoded.deviceId, 'device-A');
      expect(decoded.deviceName, "Eric's Mac");
      expect(decoded.appVersion, '1.4.9.99');
    });

    test('tolerates missing optional fields', () {
      final decoded = LibraryMovedMarker.fromJson({
        'toProviderId': 's3',
        'movedAt': 10,
      });

      expect(decoded.toProviderId, 's3');
      expect(decoded.movedAt, 10);
      expect(decoded.deviceName, isNull);
      expect(decoded.appVersion, isNull);
      expect(decoded.deviceId, '');
    });

    test('rejects a marker with no destination provider', () {
      // Without a destination the banner cannot tell the user where the
      // library went, which is the marker's entire purpose.
      expect(
        () => LibraryMovedMarker.fromJson({'movedAt': 1}),
        throwsFormatException,
      );
      expect(
        () => LibraryMovedMarker.fromJson({'toProviderId': '', 'movedAt': 1}),
        throwsFormatException,
      );
    });

    test('displayName prefers device name, falls back to id then ?', () {
      expect(
        const LibraryMovedMarker(
          movedAt: 0,
          toProviderId: 's3',
          deviceName: 'Phone',
          deviceId: 'id',
        ).displayName,
        'Phone',
      );
      expect(
        const LibraryMovedMarker(
          movedAt: 0,
          toProviderId: 's3',
          deviceId: 'id-only',
        ).displayName,
        'id-only',
      );
      expect(
        const LibraryMovedMarker(
          movedAt: 0,
          toProviderId: 's3',
          deviceId: '',
        ).displayName,
        '?',
      );
    });

    test('toProviderDisplay prefers name, falls back to id', () {
      expect(
        const LibraryMovedMarker(
          movedAt: 0,
          toProviderId: 'icloud',
          toProviderName: 'iCloud',
          deviceId: 'd',
        ).toProviderDisplay,
        'iCloud',
      );
      expect(
        const LibraryMovedMarker(
          movedAt: 0,
          toProviderId: 'icloud',
          deviceId: 'd',
        ).toProviderDisplay,
        'icloud',
      );
    });
  });
}
