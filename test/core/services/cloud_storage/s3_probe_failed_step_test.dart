import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';

class _NoStore implements S3CredentialsStore {
  @override
  Future<S3Config?> load() async => null;

  @override
  Future<void> save(S3Config config) async {}

  @override
  Future<void> clear() async {}
}

/// Fails one named step of the probe; the others succeed.
class _StepClient extends Fake implements S3ApiClient {
  _StepClient(this.failOn);

  final String? failOn;

  @override
  void Function(String region)? onRegionCorrected;

  void _maybeFail(String step) {
    if (failOn == step) throw CloudStorageException('$step failed');
  }

  @override
  Future<List<S3ObjectInfo>> listObjects({
    String prefix = '',
    int? maxKeys,
  }) async {
    _maybeFail('list');
    return const [];
  }

  @override
  Future<void> putObject(
    String key,
    Uint8List bytes, {
    String? contentType,
  }) async => _maybeFail('put');

  @override
  Future<Uint8List> getObject(String key) async {
    _maybeFail('get');
    return Uint8List.fromList('probe'.codeUnits);
  }

  @override
  Future<void> deleteObject(String key) async => _maybeFail('delete');

  @override
  void close() {}
}

/// A browser's connection test needs to know whether the store refused a
/// read or a write, which the probe records (issue #4121).
void main() {
  final config = S3Config(
    endpoint: 'http://nas.local:9000',
    bucket: 'dives',
    accessKeyId: 'ak',
    secretAccessKey: 'sk',
  );

  S3StorageProvider failing(String? step) => S3StorageProvider(
    store: _NoStore(),
    apiClientFactory: (_, {onRegionCorrected}) => _StepClient(step),
  );

  test('a failure while listing is a read failure', () async {
    final provider = failing('list');
    await expectLater(
      provider.testConnection(config),
      throwsA(isA<CloudStorageException>()),
    );
    expect(provider.lastProbeFailedOnWrite, isFalse);
  });

  test('a failure on the probe write is a write failure', () async {
    final provider = failing('put');
    await expectLater(
      provider.testConnection(config),
      throwsA(isA<CloudStorageException>()),
    );
    expect(provider.lastProbeFailedOnWrite, isTrue);
  });

  test('a failure reading the probe back is a read failure', () async {
    final provider = failing('get');
    await expectLater(
      provider.testConnection(config),
      throwsA(isA<CloudStorageException>()),
    );
    expect(provider.lastProbeFailedOnWrite, isFalse);
  });

  test('a failure deleting the probe is a write failure', () async {
    final provider = failing('delete');
    await expectLater(
      provider.testConnection(config),
      throwsA(isA<CloudStorageException>()),
    );
    expect(provider.lastProbeFailedOnWrite, isTrue);
  });

  test('a passing probe leaves it false', () async {
    final provider = failing(null);
    await provider.testConnection(config);
    expect(provider.lastProbeFailedOnWrite, isFalse);
  });
}
