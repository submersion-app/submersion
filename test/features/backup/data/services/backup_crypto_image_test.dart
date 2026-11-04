import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';
import 'package:submersion/features/backup/data/services/backup_crypto_image.dart';

const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);
const _keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';
const _passphrase = 'correct horse battery staple';

/// A browser holds a backup in memory, not in a file (issue #4121): the
/// in-memory reader opens exactly what the file writer wrote, frame rules
/// and all.
void main() {
  late Directory tempDir;
  late SecretKey mlk;
  late Uint8List plain;
  late Uint8List artifact;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_crypto_image_');
    mlk = SecretKey(List<int>.generate(32, (i) => (i * 13 + 5) % 256));
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
    // Past one frame, so the frame order and the final flag are exercised.
    plain = Uint8List.fromList(
      List<int>.generate(BackupCrypto.frameSize + 4096, (i) => (i * 31) % 251),
    );
    final inPath = p.join(tempDir.path, 'in.db');
    final outPath = p.join(tempDir.path, 'out.sbe');
    await File(inPath).writeAsBytes(plain);
    await BackupCrypto.encryptFile(
      inPath: inPath,
      outPath: outPath,
      mlk: mlk,
      libraryKeyId: _keyId,
      keyslotBytes: keyslots.toJsonBytes(),
    );
    artifact = await File(outPath).readAsBytes();
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  test('recognises an encrypted backup and reads its key id', () {
    expect(BackupCryptoImage.isEncrypted(artifact), isTrue);
    expect(BackupCryptoImage.isEncrypted(plain), isFalse);
    expect(BackupCryptoImage.libraryKeyIdOf(artifact), _keyId);
  });

  test('decrypts with the passphrase', () async {
    expect(
      await BackupCryptoImage.decrypt(artifact, secret: _passphrase),
      plain,
    );
  });

  test('decrypts with the library key', () async {
    expect(
      await BackupCryptoImage.decryptWithKey(
        artifact,
        mlk: mlk,
        expectedLibraryKeyId: _keyId,
      ),
      plain,
    );
  });

  test('a wrong passphrase is refused', () async {
    await expectLater(
      BackupCryptoImage.decrypt(artifact, secret: 'not it'),
      throwsA(isA<WrongPassphraseException>()),
    );
  });

  test('a key for another library is refused', () async {
    await expectLater(
      BackupCryptoImage.decryptWithKey(
        artifact,
        mlk: mlk,
        expectedLibraryKeyId: '00000000-0000-4000-8000-000000000000',
      ),
      throwsA(isA<SyncEncryptionRequired>()),
    );
  });

  test('a truncated backup is refused', () async {
    await expectLater(
      BackupCryptoImage.decryptWithKey(
        Uint8List.sublistView(artifact, 0, artifact.length - 20),
        mlk: mlk,
        expectedLibraryKeyId: _keyId,
      ),
      throwsA(isA<EnvelopeCorruptException>()),
    );
  });
}
