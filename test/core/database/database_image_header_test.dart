import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database_image_header.dart';

/// A 100-byte SQLite header: the magic string, the write and read versions
/// at 18 and 19, and the user version at 60.
Uint8List header({int journal = 1, int userVersion = 0}) {
  final bytes = Uint8List(100);
  bytes.setAll(0, ascii.encode('SQLite format 3\u0000'));
  bytes[18] = journal;
  bytes[19] = journal;
  ByteData.sublistView(bytes).setUint32(60, userVersion);
  return bytes;
}

void main() {
  group('isSqliteImage', () {
    test('reads the magic string', () {
      expect(isSqliteImage(header()), isTrue);
    });

    test('refuses anything else', () {
      expect(isSqliteImage(Uint8List(100)), isFalse);
      expect(isSqliteImage(ascii.encode('SBE1')), isFalse);
      expect(isSqliteImage(Uint8List(0)), isFalse);
    });

    test('refuses a file too short to hold a header', () {
      expect(isSqliteImage(Uint8List.sublistView(header(), 0, 50)), isFalse);
    });
  });

  test('sqliteImageUserVersion reads the schema version', () {
    expect(sqliteImageUserVersion(header(userVersion: 327)), 327);
    expect(sqliteImageUserVersion(header()), 0);
  });

  group('withRollbackJournal', () {
    test('turns a WAL header into a rollback one, in a copy', () {
      final wal = header(journal: 2);
      final plain = withRollbackJournal(wal);
      expect(plain[18], 1);
      expect(plain[19], 1);
      expect(wal[18], 2, reason: 'the caller keeps its bytes');
      expect(plain.sublist(20), wal.sublist(20));
    });

    test('leaves a rollback header as it is', () {
      final plain = header();
      expect(withRollbackJournal(plain), plain);
    });
  });
}
