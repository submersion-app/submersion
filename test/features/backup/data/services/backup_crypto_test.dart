import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';

const _fastKdf = KdfParams(m: 1024, t: 3, p: 1);
const _keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';
const _passphrase = 'correct horse battery staple';
const _recoveryCode = 'acid-acorn-acre-act-add-age-aid-aim';

void main() {
  late Directory tempDir;
  late SecretKey mlk;
  late Uint8List keyslotBytes;

  setUpAll(() async {
    mlk = SecretKey(List<int>.generate(32, (i) => (i * 13 + 5) % 256));
    final file = KeyslotFile(
      version: 1,
      libraryKeyId: _keyId,
      slots: [
        await Keyslots.createSlot(
          type: 'passphrase',
          secret: _passphrase,
          mlk: mlk,
          kdf: _fastKdf,
        ),
        await Keyslots.createSlot(
          type: 'recovery',
          secret: _recoveryCode,
          mlk: mlk,
          kdf: _fastKdf,
        ),
      ],
    );
    keyslotBytes = file.toJsonBytes();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_crypto_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Deterministic pseudo-random content, written in bounded chunks.
  Future<String> writeInput(int size, {String name = 'in.db'}) async {
    final path = '${tempDir.path}/$name';
    final raf = File(path).openSync(mode: FileMode.write);
    const chunkSize = 1 << 20;
    var written = 0;
    while (written < size) {
      final n = (size - written).clamp(0, chunkSize);
      raf.writeFromSync(
        Uint8List.fromList(
          List<int>.generate(n, (i) => ((written + i) * 31 + 7) % 256),
        ),
      );
      written += n;
    }
    raf.closeSync();
    return path;
  }

  Future<String> encrypt(String inPath, {String name = 'out.sbe'}) async {
    final outPath = '${tempDir.path}/$name';
    await BackupCrypto.encryptFile(
      inPath: inPath,
      outPath: outPath,
      mlk: mlk,
      libraryKeyId: _keyId,
      keyslotBytes: keyslotBytes,
    );
    return outPath;
  }

  Future<bool> filesIdentical(String a, String b) async {
    final ba = await File(a).readAsBytes();
    final bb = await File(b).readAsBytes();
    if (ba.length != bb.length) return false;
    for (var i = 0; i < ba.length; i++) {
      if (ba[i] != bb[i]) return false;
    }
    return true;
  }

  test('20 MiB round-trip with the passphrase (3 frames)', () async {
    final input = await writeInput(20 * 1024 * 1024);
    final sbe = await encrypt(input);
    final out = '${tempDir.path}/out.db';
    await BackupCrypto.decryptFile(
      inPath: sbe,
      outPath: out,
      secret: _passphrase,
    );
    expect(await filesIdentical(input, out), isTrue);
  });

  test(
    'decryptFileWithKey: silent with matching key, throws on mismatch',
    () async {
      final input = await writeInput(1024 * 1024);
      final sbe = await encrypt(input);
      final out = '${tempDir.path}/out.db';
      await BackupCrypto.decryptFileWithKey(
        inPath: sbe,
        outPath: out,
        mlk: mlk,
        expectedLibraryKeyId: _keyId,
      );
      expect(await filesIdentical(input, out), isTrue);

      await expectLater(
        BackupCrypto.decryptFileWithKey(
          inPath: sbe,
          outPath: '${tempDir.path}/out2.db',
          mlk: mlk,
          expectedLibraryKeyId: '00000000-0000-0000-0000-000000000000',
        ),
        throwsA(isA<SyncEncryptionRequired>()),
      );
    },
  );

  test('wrong secret throws WrongPassphraseException', () async {
    final input = await writeInput(1024);
    final sbe = await encrypt(input);
    await expectLater(
      BackupCrypto.decryptFile(
        inPath: sbe,
        outPath: '${tempDir.path}/out.db',
        secret: 'totally wrong',
      ),
      throwsA(isA<WrongPassphraseException>()),
    );
  });

  test('recovery code decrypts, tolerant of spacing and case', () async {
    final input = await writeInput(1024);
    final sbe = await encrypt(input);
    final out = '${tempDir.path}/out.db';
    await BackupCrypto.decryptFile(
      inPath: sbe,
      outPath: out,
      secret: '  ACID acorn Acre act ADD age aid aim ',
    );
    expect(await filesIdentical(input, out), isTrue);
  });

  test('bit flip inside a frame fails authentication', () async {
    final input = await writeInput(1024 * 1024);
    final sbe = await encrypt(input);
    final bytes = await File(sbe).readAsBytes();
    bytes[bytes.length - 20] ^= 0x01; // inside the final frame's tail
    await File(sbe).writeAsBytes(bytes);
    await expectLater(
      BackupCrypto.decryptFile(
        inPath: sbe,
        outPath: '${tempDir.path}/out.db',
        secret: _passphrase,
      ),
      throwsA(isA<EnvelopeCorruptException>()),
    );
  });

  test('truncation before the final frame is detected', () async {
    final input = await writeInput(9 * 1024 * 1024); // 2 frames: 8 MiB + 1 MiB
    final sbe = await encrypt(input);
    final bytes = await File(sbe).readAsBytes();
    // Parse to the end of frame 0 and cut there (drops the final frame).
    final slotLen = ByteData.sublistView(bytes, 21, 25).getUint32(0);
    final frame0Start = 25 + slotLen;
    final frame0Len = ByteData.sublistView(
      bytes,
      frame0Start,
      frame0Start + 4,
    ).getUint32(0);
    final cut = frame0Start + 4 + frame0Len;
    await File(sbe).writeAsBytes(bytes.sublist(0, cut));
    await expectLater(
      BackupCrypto.decryptFile(
        inPath: sbe,
        outPath: '${tempDir.path}/out.db',
        secret: _passphrase,
      ),
      throwsA(isA<EnvelopeCorruptException>()),
    );
  });

  test('frame reorder is detected (frame index in AAD)', () async {
    final input = await writeInput(17 * 1024 * 1024); // 3 frames
    final sbe = await encrypt(input);
    final bytes = await File(sbe).readAsBytes();
    final slotLen = ByteData.sublistView(bytes, 21, 25).getUint32(0);
    final f0 = 25 + slotLen;
    final f0Len = ByteData.sublistView(bytes, f0, f0 + 4).getUint32(0);
    final f1 = f0 + 4 + f0Len;
    final f1Len = ByteData.sublistView(bytes, f1, f1 + 4).getUint32(0);
    final f2 = f1 + 4 + f1Len;
    // Swap frame 0 and frame 1 (both are full 8 MiB frames, equal length).
    final swapped = BytesBuilder(copy: false)
      ..add(bytes.sublist(0, f0))
      ..add(bytes.sublist(f1, f2))
      ..add(bytes.sublist(f0, f1))
      ..add(bytes.sublist(f2));
    await File(sbe).writeAsBytes(swapped.takeBytes());
    await expectLater(
      BackupCrypto.decryptFile(
        inPath: sbe,
        outPath: '${tempDir.path}/out.db',
        secret: _passphrase,
      ),
      throwsA(isA<EnvelopeCorruptException>()),
    );
  });

  test('empty input round-trips', () async {
    final input = await writeInput(0);
    final sbe = await encrypt(input);
    final out = '${tempDir.path}/out.db';
    await BackupCrypto.decryptFile(
      inPath: sbe,
      outPath: out,
      secret: _passphrase,
    );
    expect(await File(out).length(), 0);
  });

  test('isEncryptedBackup and libraryKeyIdOf', () async {
    final input = await writeInput(1024);
    final sbe = await encrypt(input);
    expect(await BackupCrypto.isEncryptedBackup(sbe), isTrue);
    expect(await BackupCrypto.isEncryptedBackup(input), isFalse);
    expect(await BackupCrypto.libraryKeyIdOf(sbe), _keyId);
  });
}
