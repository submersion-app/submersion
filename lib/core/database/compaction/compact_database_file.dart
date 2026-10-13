import 'dart:isolate';

import 'package:submersion/core/services/database_service.dart';

/// Rewrites the database at [path] without its free pages, then truncates
/// the write-ahead log so the file itself shrinks (issue #3333).
///
/// On an isolate of its own with a connection of its own: a VACUUM rewrites
/// the whole file, and on the UI isolate the startup screen would freeze
/// until it finished. Call it before any other connection opens the file.
Future<void> compactDatabaseFile(String path, {String? keyHex}) =>
    Isolate.run(() {
      final db = DatabaseService.openRaw(path, keyHex: keyHex);
      try {
        db.execute('VACUUM');
        db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      } finally {
        db.close();
      }
    });
