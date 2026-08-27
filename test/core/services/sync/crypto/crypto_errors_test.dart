import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';

void main() {
  group('SyncEncryptionRequired', () {
    test('defaults and toString', () {
      const e = SyncEncryptionRequired();
      expect(e.libraryKeyId, isNull);
      expect(e.message, 'The cloud library is encrypted');
      expect(
        e.toString(),
        'SyncEncryptionRequired(null): The cloud library is encrypted',
      );
    });

    test('carries the keyId and a custom message', () {
      const e = SyncEncryptionRequired(libraryKeyId: 'abc', message: 'nope');
      expect(e.toString(), 'SyncEncryptionRequired(abc): nope');
    });
  });

  group('EnvelopeCorruptException', () {
    test('toString includes the message', () {
      const e = EnvelopeCorruptException('bad tag');
      expect(e.message, 'bad tag');
      expect(e.toString(), 'EnvelopeCorruptException: bad tag');
    });
  });

  test('BackupEncryptedException toString', () {
    expect(
      const BackupEncryptedException().toString(),
      'BackupEncryptedException: backup requires a passphrase',
    );
  });
}
