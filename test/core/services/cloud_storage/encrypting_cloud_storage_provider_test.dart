import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/encrypting_cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';

import '../../../support/fake_cloud_storage_provider.dart';

const _keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';

void main() {
  late FakeCloudStorageProvider inner;
  late EncryptingCloudStorageProvider provider;
  final dataKey = SecretKey(List<int>.generate(32, (i) => i + 1));

  setUp(() {
    inner = FakeCloudStorageProvider();
    provider = EncryptingCloudStorageProvider(
      inner,
      dataKey: dataKey,
      libraryKeyId: _keyId,
    );
  });

  Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

  test('uploads are SBE1 at rest, downloads round-trip plaintext', () async {
    final up = await provider.uploadFile(
      bytesOf('{"cs":1}'),
      'ssv1.devA.cs.00001.json',
    );
    // At rest (inner fake) the bytes must be an envelope:
    final atRest = await inner.downloadFile(up.fileId);
    expect(SyncEnvelope.hasMagic(atRest), isTrue);
    // Through the decorator they come back as plaintext:
    final roundTrip = await provider.downloadFile(up.fileId);
    expect(utf8.decode(roundTrip), '{"cs":1}');
  });

  test('keyslot file and backup artifacts are exempt', () async {
    expect(
      EncryptingCloudStorageProvider.isExempt(KeyslotFile.cloudFileName),
      isTrue,
    );
    expect(
      EncryptingCloudStorageProvider.isExempt(
        'submersion_backup_2026-07-10.sbe',
      ),
      isTrue,
    );
    expect(
      EncryptingCloudStorageProvider.isExempt('ssv1.devA.manifest.json'),
      isFalse,
    );

    final up = await provider.uploadFile(
      bytesOf('{"slots":[]}'),
      KeyslotFile.cloudFileName,
    );
    final atRest = await inner.downloadFile(up.fileId);
    expect(SyncEnvelope.hasMagic(atRest), isFalse);
    expect(utf8.decode(atRest), '{"slots":[]}');
  });

  test('plaintext files pass through downloads unchanged', () async {
    final up = await inner.uploadFile(
      bytesOf('{"legacy":true}'),
      'submersion_library_epoch.json',
    );
    final viaDecorator = await provider.downloadFile(up.fileId);
    expect(utf8.decode(viaDecorator), '{"legacy":true}');
  });

  test('download resolves filename via listFiles for AAD', () async {
    await provider.uploadFile(bytesOf('{"m":1}'), 'ssv1.devB.manifest.json');
    // fresh decorator instance = empty name cache; it must list or getFileInfo
    final fresh = EncryptingCloudStorageProvider(
      inner,
      dataKey: dataKey,
      libraryKeyId: _keyId,
    );
    final files = await fresh.listFiles(namePattern: 'ssv1.');
    final m = files.singleWhere((f) => f.name == 'ssv1.devB.manifest.json');
    final bytes = await fresh.downloadFile(m.id);
    expect(utf8.decode(bytes), '{"m":1}');
  });

  test('download with cold cache falls back to getFileInfo', () async {
    final up = await provider.uploadFile(
      bytesOf('{"cold":true}'),
      'ssv1.devC.cs.00001.json',
    );
    final fresh = EncryptingCloudStorageProvider(
      inner,
      dataKey: dataKey,
      libraryKeyId: _keyId,
    );
    // No listFiles call first: must resolve the name via getFileInfo.
    final bytes = await fresh.downloadFile(up.fileId);
    expect(utf8.decode(bytes), '{"cold":true}');
  });

  test('delegates providerName/providerId and deleteFile', () async {
    expect(provider.providerId, inner.providerId);
    expect(provider.providerName, inner.providerName);
    final up = await provider.uploadFile(bytesOf('x'), 'ssv1.devA.cs.1.json');
    await provider.deleteFile(up.fileId);
    expect(await inner.fileExists(up.fileId), isFalse);
  });

  test('delegates the remaining provider surface untouched', () async {
    expect(await provider.isAvailable(), isTrue);
    expect(await provider.isAuthenticated(), isTrue);
    expect(await provider.getUserEmail(), 'test@example.com');
    // authenticate / signOut are no-ops on the fake; assert they pass through
    // without throwing.
    await provider.authenticate();
    await provider.signOut();
    expect(await provider.getOrCreateSyncFolder(), 'sync');
    final folder = await provider.createFolder('Sub', parentFolderId: 'root');
    expect(folder, 'root/Sub');
    final up = await provider.uploadFile(bytesOf('y'), 'ssv1.devA.cs.2.json');
    expect(await provider.fileExists(up.fileId), isTrue);
    final info = await provider.getFileInfo(up.fileId);
    expect(info?.name, 'ssv1.devA.cs.2.json');
  });

  test(
    'framed backup artifacts pass through download untouched (exempt)',
    () async {
      // A backup artifact is self-framed: it carries the SBE1 magic but must
      // NOT be opened as a single-shot envelope. Upload it via the RAW inner
      // provider (the backup service owns its encryption) with the SBE1 magic,
      // then download through the decorator and expect the bytes verbatim.
      final framed = Uint8List.fromList([
        ...SyncEnvelope.magic,
        ...List<int>.filled(64, 7), // opaque framed body; never opened
      ]);
      final up = await inner.uploadFile(
        framed,
        'submersion_backup_2026-07-10.sbe',
      );
      // Populate the decorator's name cache the way production does (listFiles).
      await provider.listFiles(namePattern: 'submersion_backup_');
      final out = await provider.downloadFile(up.fileId);
      expect(out, framed, reason: 'exempt artifact must not be decrypted');
    },
  );

  test('exemption rules: keyslots and .sbe backups only', () {
    expect(
      EncryptingCloudStorageProvider.isExempt('submersion_keyslots.json'),
      isTrue,
    );
    expect(
      EncryptingCloudStorageProvider.isExempt('submersion_backup_x.sbe'),
      isTrue,
    );
    // A plaintext .db backup is NOT exempt by the framed rule (it has no
    // magic on download, so it never needs the exemption anyway).
    expect(
      EncryptingCloudStorageProvider.isExempt('submersion_backup_x.db'),
      isFalse,
    );
    expect(
      EncryptingCloudStorageProvider.isExempt('ssv1.devA.manifest.json'),
      isFalse,
    );
  });

  test(
    'download throws when an encrypted file has no resolvable name',
    () async {
      // A (pathological) provider that returns SBE1 bytes on download but no
      // file info and no listing -- the decorator cannot resolve the AAD name
      // and must fail closed rather than guess.
      final sealed = await SyncEnvelope.seal(
        plaintext: bytesOf('{"x":1}'),
        dataKey: dataKey,
        libraryKeyId: _keyId,
        filename: 'ssv1.devA.cs.9.json',
      );
      final nameless = _NamelessProvider(sealed);
      final wrapped = EncryptingCloudStorageProvider(
        nameless,
        dataKey: dataKey,
        libraryKeyId: _keyId,
      );
      await expectLater(
        wrapped.downloadFile('whatever'),
        throwsA(isA<EnvelopeCorruptException>()),
      );
    },
  );
}

/// Returns SBE1 bytes on download but null file info and no listing, so the
/// decorator has no name to authenticate with.
class _NamelessProvider extends Fake implements CloudStorageProvider {
  _NamelessProvider(this._bytes);
  final Uint8List _bytes;

  @override
  Future<Uint8List> downloadFile(String fileId) async => _bytes;

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async => null;
}
