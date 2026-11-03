import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/scratch_database.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../support/fake_keychain_storage.dart';

const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);
const _keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';
const _passphrase = 'correct horse battery staple';

class _NoFileAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath, {String? note}) =>
      throw UnsupportedError('a browser restore takes no file backup');

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) => throw UnsupportedError('a browser restore swaps no file');

  @override
  Future<String> get databasePath async => '/opfs/Submersion/submersion.db';

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  String? get databaseKeyHex => null;
}

class _SpySyncRepository extends SyncRepository {
  String? preservedDeviceId;

  @override
  Future<String> getDeviceId() async => 'browser-device';

  @override
  Future<String?> getLastAcceptedEpochId() async => null;

  @override
  Future<void> rebaselineAfterRestore({
    String? preserveDeviceId,
    String? preserveEpochId,
  }) async {
    preservedDeviceId = preserveDeviceId;
  }
}

/// A browser restores a backup it holds in memory (issue #4121): the checks
/// the file restore makes come first, then the safety copy, then the swap
/// and the same sync re-baseline.
void main() {
  late List<String> events;
  late List<Uint8List> swapped;
  late _SpySyncRepository repository;
  late LibraryEpochStore epochStore;
  late EncryptionKeyStore keyStore;
  late BackupService service;

  Future<Uint8List> image({bool submersion = true, int version = 300}) =>
      withScratchDatabase((db) async {
        db.execute(
          submersion
              ? 'CREATE TABLE dives (id TEXT)'
              : 'CREATE TABLE recipes (id TEXT)',
        );
        db.execute('PRAGMA user_version = $version');
      });

  Future<Uint8List> encrypted(Uint8List plain, SecretKey mlk) async {
    final dir = await Directory.systemTemp.createTemp('image_restore_');
    addTearDown(() => dir.delete(recursive: true));
    final inPath = p.join(dir.path, 'in.db');
    final outPath = p.join(dir.path, 'out.sbe');
    await File(inPath).writeAsBytes(plain);
    final keyslots = KeyslotFile(
      version: 1,
      libraryKeyId: _keyId,
      slots: [
        await Keyslots.createSlot(
          type: 'passphrase',
          secret: _passphrase,
          mlk: mlk,
          kdf: _fastKdf,
        ),
      ],
    );
    await BackupCrypto.encryptFile(
      inPath: inPath,
      outPath: outPath,
      mlk: mlk,
      libraryKeyId: _keyId,
      keyslotBytes: keyslots.toJsonBytes(),
    );
    return File(outPath).readAsBytes();
  }

  Future<void> safetyCopy() async => events.add('safety copy');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    events = [];
    swapped = [];
    repository = _SpySyncRepository();
    epochStore = LibraryEpochStore(prefs);
    keyStore = EncryptionKeyStore(storage: InMemoryKeychain());
    service = BackupService(
      dbAdapter: _NoFileAdapter(),
      preferences: BackupPreferences(prefs),
      syncRepository: repository,
      epochStore: epochStore,
      encryptionKeyStore: keyStore,
      restoreImage: (bytes, {onMigrationProgress}) async {
        events.add('swap');
        swapped.add(bytes);
        onMigrationProgress?.call(3, 7);
      },
    );
  });

  test('a backup is checked, the safety copy taken, then swapped in with '
      'the device kept', () async {
    final backup = await image();

    await service.restoreFromImage(backup, safetyCopy: safetyCopy);

    expect(events, ['safety copy', 'swap']);
    expect(swapped.single, backup);
    expect(repository.preservedDeviceId, 'browser-device');
    expect(epochStore.pendingReplace, isNull);
  });

  test('replace mode mints the pending replace', () async {
    await service.restoreFromImage(
      await image(),
      mode: RestoreMode.replace,
      safetyCopy: safetyCopy,
    );
    expect(epochStore.pendingReplace, isNotNull);
  });

  test('a backup from a newer app is refused before the safety copy', () async {
    await expectLater(
      service.restoreFromImage(
        await image(version: AppDatabase.currentSchemaVersion + 1),
        safetyCopy: safetyCopy,
      ),
      throwsA(isA<BackupNewerSchemaException>()),
    );
    expect(events, isEmpty);
  });

  test('a database that is not a Submersion backup is refused', () async {
    await expectLater(
      service.restoreFromImage(
        await image(submersion: false),
        safetyCopy: safetyCopy,
      ),
      throwsA(isA<BackupException>()),
    );
    expect(events, isEmpty);
  });

  test('bytes that are not a database are refused, naming a protected '
      'copy as the likely cause', () async {
    await expectLater(
      service.restoreFromImage(
        Uint8List.fromList(List.filled(4096, 3)),
        safetyCopy: safetyCopy,
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          BackupService.unreadableCopyNoKeyMessage,
        ),
      ),
    );
    expect(events, isEmpty);
  });

  test('an older backup\'s upgrade steps reach the caller', () async {
    final steps = <(int, int)>[];
    await service.restoreFromImage(
      await image(),
      safetyCopy: safetyCopy,
      onMigrationProgress: (step, total) => steps.add((step, total)),
    );
    expect(steps, [(3, 7)]);
  });

  group('an encrypted backup', () {
    final mlk = SecretKey(List<int>.generate(32, (i) => (i * 7 + 3) % 256));

    test('asks for a passphrase when no key here opens it', () async {
      await expectLater(
        service.restoreFromImage(
          await encrypted(await image(), mlk),
          safetyCopy: safetyCopy,
        ),
        throwsA(isA<BackupEncryptedException>()),
      );
      expect(events, isEmpty);
    });

    test('restores the plaintext with the passphrase', () async {
      final plain = await image();
      await service.restoreFromImage(
        await encrypted(plain, mlk),
        encryptionSecret: _passphrase,
        safetyCopy: safetyCopy,
      );
      expect(swapped.single, plain);
    });

    test('a wrong passphrase is refused before the safety copy', () async {
      await expectLater(
        service.restoreFromImage(
          await encrypted(await image(), mlk),
          encryptionSecret: 'not it',
          safetyCopy: safetyCopy,
        ),
        throwsA(isA<WrongPassphraseException>()),
      );
      expect(events, isEmpty);
    });

    test('opens silently with this browser\'s sync key', () async {
      await keyStore.saveKey(
        libraryKeyId: _keyId,
        mlkBytes: await mlk.extractBytes(),
      );
      final plain = await image();
      await service.restoreFromImage(
        await encrypted(plain, mlk),
        safetyCopy: safetyCopy,
      );
      expect(swapped.single, plain);
    });
  });

  test('is sealed in demo mode', () async {
    addTearDown(applyGlobalTestDefaults);
    DemoModeGate.instance.debugActive = true;
    await expectLater(
      service.restoreFromImage(await image(), safetyCopy: safetyCopy),
      throwsA(
        isA<DemoModeSealedException>().having(
          (e) => e.feature,
          'feature',
          DemoSealedFeature.restore,
        ),
      ),
    );
    expect(events, isEmpty);
  });
}
