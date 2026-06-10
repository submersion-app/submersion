import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';

class _MemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  late _MemorySecureStorage storage;
  late S3CredentialsStore store;

  setUp(() {
    storage = _MemorySecureStorage();
    store = S3CredentialsStore(storage: storage);
  });

  S3Config config() => S3Config(
    endpoint: 'http://nas.local:9000',
    bucket: 'dive-sync',
    accessKeyId: 'ak',
    secretAccessKey: 'sk',
  );

  test('load returns null when nothing is stored', () async {
    expect(await store.load(), isNull);
  });

  test('save then load round-trips the config', () async {
    await store.save(config());
    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.endpoint, 'http://nas.local:9000');
    expect(loaded.bucket, 'dive-sync');
    expect(loaded.secretAccessKey, 'sk');
    expect(storage.values.keys, [S3CredentialsStore.storageKey]);
  });

  test('clear removes the blob', () async {
    await store.save(config());
    await store.clear();
    expect(await store.load(), isNull);
    expect(storage.values, isEmpty);
  });

  test('corrupted JSON loads as null instead of throwing', () async {
    storage.values[S3CredentialsStore.storageKey] = 'not-json{';
    expect(await store.load(), isNull);
  });
}
