import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// The encrypted-library gate: what happens when sync meets SBE1 envelopes
/// without a key. Also pins the legacy fail-closed property (spec section 6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;
  late LibraryEpochStore epochStore;

  final dataKey = SecretKey(List<int>.generate(32, (i) => i));
  const keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    epochStore = LibraryEpochStore(await SharedPreferences.getInstance());
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
    epochStore: epochStore,
  );

  Future<Uint8List> sealedMarker() => SyncEnvelope.seal(
    plaintext: Uint8List.fromList(
      utf8.encode('{"epochId":"e1","replacedAt":1,"deviceId":"d1"}'),
    ),
    dataKey: dataKey,
    libraryKeyId: keyId,
    filename: libraryEpochFileName,
  );

  test('SBE1 bytes can never satisfy the legacy epoch-marker parse', () async {
    final envelope = await sealedMarker();
    // This IS the legacy client's exact parse sequence (fail-closed path):
    expect(
      () => LibraryEpochMarker.fromJson(
        jsonDecode(utf8.decode(envelope)) as Map<String, dynamic>,
      ),
      throwsA(anything), // utf8/json/FormatException; any throw = fail closed
    );
  });

  test('performSync halts awaitingPassphrase on an encrypted marker', () async {
    await cloud.uploadFile(await sealedMarker(), libraryEpochFileName);
    final service = buildService();
    final result = await service.performSync();
    expect(result.status, SyncResultStatus.awaitingPassphrase);
  });

  test('readLibraryEpochMarker throws SyncEncryptionRequired on SBE1 '
      'with the keyId attached', () async {
    await cloud.uploadFile(await sealedMarker(), libraryEpochFileName);
    final service = buildService();
    await expectLater(
      service.readLibraryEpochMarker(cloud),
      throwsA(
        isA<SyncEncryptionRequired>().having(
          (e) => e.libraryKeyId,
          'libraryKeyId',
          keyId,
        ),
      ),
    );
  });

  test(
    'SyncManifest.fromBytes throws SyncEncryptionRequired on SBE1',
    () async {
      final envelope = await SyncEnvelope.seal(
        plaintext: Uint8List.fromList(utf8.encode('{}')),
        dataKey: dataKey,
        libraryKeyId: keyId,
        filename: 'ssv1.devA.manifest.json',
      );
      expect(
        () => SyncManifest.fromBytes(envelope),
        throwsA(isA<SyncEncryptionRequired>()),
      );
    },
  );
}
