import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';

void main() {
  late LibrarySigningKey key;

  setUpAll(() async => key = await LibrarySigner.generate());

  Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

  final files = {
    'submersion-shared-library.json': b('{"id":"L"}'),
    'roles.json': b('{"owners":["m"]}'),
    'sites/site-s1.json': b('{"id":"s1"}'),
    'members/member-m.json': b('{"displayName":"Ann"}'),
  };

  LibraryBackupHeader header() => LibraryBackupHeader(
    backupId: 'b1',
    libraryId: 'L',
    name: 'Reef Survey',
    createdAt: DateTime.utc(2026, 10, 12, 9),
    createdBy: 'm',
    createdByKey: key.publicKey,
    appVersion: '1.8.3',
    automatic: false,
    note: 'before the trip',
    siteCount: 1,
    memberCount: 1,
  );

  test('a backup round trips its files and header', () async {
    final zip = await LibraryBackupArchive.build(
      files: files,
      header: header(),
      key: key,
    );
    final read = await LibraryBackupArchive.read(zip);
    expect(read.header.note, 'before the trip');
    expect(read.header.siteCount, 1);
    expect(read.files.keys.toSet(), files.keys.toSet());
    expect(utf8.decode(read.files['sites/site-s1.json']!), '{"id":"s1"}');
  });

  Uint8List rewritten(
    Uint8List zip,
    Uint8List Function(String name, Uint8List bytes) change,
  ) {
    final archive = ZipDecoder().decodeBytes(zip);
    final out = Archive();
    for (final f in archive.files) {
      out.addFile(ArchiveFile.bytes(f.name, change(f.name, f.content)));
    }
    return ZipEncoder().encodeBytes(out);
  }

  test('a changed file is refused', () async {
    final zip = await LibraryBackupArchive.build(
      files: files,
      header: header(),
      key: key,
    );
    final tampered = rewritten(
      zip,
      (name, bytes) => name == 'sites/site-s1.json' ? b('{"id":"sX"}') : bytes,
    );
    await expectLater(
      LibraryBackupArchive.read(tampered),
      throwsA(
        isA<BackupRefusedError>().having((e) => e.reason, 'reason', 'hash'),
      ),
    );
  });

  test('an edited header is refused', () async {
    final zip = await LibraryBackupArchive.build(
      files: files,
      header: header(),
      key: key,
    );
    final tampered = rewritten(zip, (name, bytes) {
      if (name != LibraryBackupArchive.headerFile) return bytes;
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return b(jsonEncode({...json, 'note': 'changed'}));
    });
    await expectLater(
      LibraryBackupArchive.read(tampered),
      throwsA(
        isA<BackupRefusedError>().having(
          (e) => e.reason,
          'reason',
          'signature',
        ),
      ),
    );
  });

  test('a zip that is no backup is refused', () async {
    final other = Archive()..addFile(ArchiveFile.bytes('x.txt', b('hi')));
    await expectLater(
      LibraryBackupArchive.read(ZipEncoder().encodeBytes(other)),
      throwsA(
        isA<BackupRefusedError>().having(
          (e) => e.reason,
          'reason',
          'notABackup',
        ),
      ),
    );
    await expectLater(
      LibraryBackupArchive.read(b('not a zip')),
      throwsA(isA<BackupRefusedError>()),
    );
  });

  test('the content hash does not depend on entry order', () {
    final reversed = Map.fromEntries(files.entries.toList().reversed);
    expect(
      LibraryBackupArchive.contentHash(files),
      LibraryBackupArchive.contentHash(reversed),
    );
  });
}
