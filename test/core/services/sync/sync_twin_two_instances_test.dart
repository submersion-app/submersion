import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Two app instances on one phone (issue #4843): Android started a second
/// activity, and with it a second Flutter engine, for a share sent while the
/// app was running. Both isolates share the database and the platform
/// preferences, but each `SharedPreferences.getInstance()` caches the values
/// it loaded at start, so writes from the other isolate stay invisible until
/// a reload.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;
  late SyncRepository repository;
  late Map<String, Object> platformStore;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    repository = SyncRepository();
    platformStore = <String, Object>{};
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  SyncService buildInstance() => SyncService(
    syncRepository: repository,
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
    syncInitializer: SyncInitializer(
      syncRepository: repository,
      prefs: _IsolateCachedPrefs(platformStore),
    ),
  );

  test(
    'a second instance uploading as this device is not read as a twin',
    () async {
      final first = buildInstance();
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd-first'),
      );
      expect((await first.performSync()).isSuccess, isTrue);
      final deviceId = await repository.getDeviceId();

      // The share opens a second engine; it loads the preferences as they are
      // now, then publishes its own upload under the same device id.
      final second = buildInstance();
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd-second'),
      );
      final secondResult = await second.performSync();
      expect(secondResult.isSuccess, isTrue);
      expect(secondResult.adoptedFreshIdentity, isFalse);

      final result = await first.performSync();

      expect(
        result.adoptedFreshIdentity,
        isFalse,
        reason:
            'the nonce in our manifest was minted on this phone by the other '
            'instance; a stale cache must not split the phone into two devices',
      );
      expect(await repository.getDeviceId(), deviceId);
    },
  );

  test('recording a nonce keeps the one the other instance recorded', () async {
    final initA = SyncInitializer(
      syncRepository: repository,
      prefs: _IsolateCachedPrefs(platformStore),
    );
    final initB = SyncInitializer(
      syncRepository: repository,
      prefs: _IsolateCachedPrefs(platformStore),
    );

    await initA.recordUploadNonce('nonce-a', 'fake');
    await initB.recordUploadNonce('nonce-b', 'fake');
    await initA.recordUploadNonce('nonce-a2', 'fake');

    expect(platformStore['sync_upload_nonces_fake'], [
      'nonce-a2',
      'nonce-b',
      'nonce-a',
    ]);
    expect(await initA.isForeignUploadNonce('nonce-b', 'fake'), isFalse);
    expect(await initB.isForeignUploadNonce('nonce-a2', 'fake'), isFalse);
  });

  test('overlapping records in one isolate keep both nonces', () async {
    final initializer = SyncInitializer(
      syncRepository: repository,
      prefs: _IsolateCachedPrefs(platformStore),
    );

    // Unawaited between them: the second reload is fetched before the first
    // write lands, and would otherwise put the stale ring back in the cache.
    await Future.wait([
      initializer.recordUploadNonce('nonce-a', 'fake'),
      initializer.recordUploadNonce('nonce-b', 'fake'),
    ]);

    expect(platformStore['sync_upload_nonces_fake'], ['nonce-b', 'nonce-a']);
  });

  test('a failed reload reads the cached ring instead of failing', () async {
    final prefs = _IsolateCachedPrefs(platformStore);
    final initializer = SyncInitializer(
      syncRepository: repository,
      prefs: prefs,
    );
    await initializer.recordUploadNonce('nonce-a', 'fake');
    prefs.failReload = true;

    expect(await initializer.isForeignUploadNonce('nonce-a', 'fake'), isFalse);
    expect(await initializer.isForeignUploadNonce('nonce-x', 'fake'), isTrue);
    await initializer.recordUploadNonce('nonce-b', 'fake');
    expect(platformStore['sync_upload_nonces_fake'], ['nonce-b', 'nonce-a']);
  });
}

/// One isolate's view of the platform preferences: it snapshots
/// [_platform] when created and serves reads from that snapshot until
/// [reload], while writes go through to [_platform], as the plugin's
/// `SharedPreferences` does. A reload replaces the cache with what it fetched
/// a round trip earlier, so it can undo a write made in between.
class _IsolateCachedPrefs extends Fake implements SharedPreferences {
  _IsolateCachedPrefs(this._platform) : _cache = Map.of(_platform);

  final Map<String, Object> _platform;
  Map<String, Object> _cache;

  Future<bool> _write(String key, Object value) async {
    _cache[key] = value;
    _platform[key] = value;
    return true;
  }

  /// Makes [reload] throw, as a platform storage error would.
  bool failReload = false;

  @override
  Future<void> reload() async {
    if (failReload) throw StateError('storage unavailable');
    // Fetched now, applied after a platform round trip, as the plugin does.
    final fetched = Map.of(_platform);
    await Future<void>.delayed(Duration.zero);
    _cache = fetched;
  }

  @override
  Set<String> getKeys() => _cache.keys.toSet();

  @override
  Object? get(String key) => _cache[key];

  @override
  bool containsKey(String key) => _cache.containsKey(key);

  @override
  String? getString(String key) => _cache[key] as String?;

  @override
  bool? getBool(String key) => _cache[key] as bool?;

  @override
  int? getInt(String key) => _cache[key] as int?;

  @override
  double? getDouble(String key) => _cache[key] as double?;

  @override
  List<String>? getStringList(String key) =>
      (_cache[key] as List<String>?)?.toList();

  @override
  Future<bool> setString(String key, String value) => _write(key, value);

  @override
  Future<bool> setBool(String key, bool value) => _write(key, value);

  @override
  Future<bool> setInt(String key, int value) => _write(key, value);

  @override
  Future<bool> setDouble(String key, double value) => _write(key, value);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _write(key, List<String>.of(value));

  @override
  Future<bool> remove(String key) async {
    _cache.remove(key);
    _platform.remove(key);
    return true;
  }
}
