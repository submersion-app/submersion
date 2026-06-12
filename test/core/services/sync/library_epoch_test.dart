import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

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

  test('displayName never renders blank', () {
    const named = LibraryEpochMarker(
      epochId: 'e',
      replacedAt: 1,
      deviceId: 'd1',
      deviceName: 'Eric Mac',
    );
    expect(named.displayName, 'Eric Mac');

    const idOnly = LibraryEpochMarker(
      epochId: 'e',
      replacedAt: 1,
      deviceId: 'd1',
    );
    expect(idOnly.displayName, 'd1');

    const blankName = LibraryEpochMarker(
      epochId: 'e',
      replacedAt: 1,
      deviceId: 'd1',
      deviceName: '   ',
    );
    expect(blankName.displayName, 'd1');

    const allBlank = LibraryEpochMarker(
      epochId: 'e',
      replacedAt: 1,
      deviceId: '',
      deviceName: '',
    );
    expect(allBlank.displayName, '?');
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

  group('SyncPayload epoch stamp', () {
    test('serializes and parses epochId', () {
      const payload = SyncPayload(
        version: 1,
        exportedAt: 1,
        deviceId: 'd1',
        checksum: 'c',
        data: SyncData(),
        deletions: {},
        epochId: 'e1',
      );
      final parsed = SyncPayload.fromJson(
        jsonDecode(jsonEncode(payload.toJson())) as Map<String, dynamic>,
      );
      expect(parsed.epochId, 'e1');
    });

    test('legacy payload without epochId parses as null', () {
      const payload = SyncPayload(
        version: 1,
        exportedAt: 1,
        deviceId: 'd1',
        checksum: 'c',
        data: SyncData(),
        deletions: {},
      );
      final json = payload.toJson()..remove('epochId');
      final parsed = SyncPayload.fromJson(json);
      expect(parsed.epochId, isNull);
    });
  });
}
