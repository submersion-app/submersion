import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';

void main() {
  test('marker filename must not match the sync-file stem', () {
    // Sync-file discovery lists files by substring match on the stem; a
    // marker name containing it would be treated as a peer device's file.
    expect(
      libraryEpochFileName.contains(CloudStorageProviderMixin.syncFileStem),
      isFalse,
    );
  });

  test('round-trips through JSON', () {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1234,
      deviceId: 'd1',
      deviceName: 'Mac',
      appVersion: '1.5.0.1',
    );
    final restored = LibraryEpochMarker.fromJson(marker.toJson());
    expect(restored.epochId, 'e1');
    expect(restored.replacedAt, 1234);
    expect(restored.deviceId, 'd1');
    expect(restored.deviceName, 'Mac');
    expect(restored.appVersion, '1.5.0.1');
  });

  test('tolerates missing optional fields, rejects missing epochId', () {
    final restored = LibraryEpochMarker.fromJson({
      'epochId': 'e2',
      'replacedAt': 5,
      'deviceId': 'd2',
    });
    expect(restored.deviceName, isNull);
    expect(restored.appVersion, isNull);
    expect(
      () => LibraryEpochMarker.fromJson({'replacedAt': 5, 'deviceId': 'd'}),
      throwsFormatException,
    );
  });
}
