import 'dart:io';

import 'package:submersion/core/database/database.dart';

/// The quiet facts line on Settings > Data (#3390): how much the database
/// holds. Counts cover the whole database, not the active diver: this is
/// about the data, not a diver's statistics.
class DataFacts {
  const DataFacts({
    required this.dives,
    required this.sites,
    required this.media,
    required this.databaseBytes,
  });

  static const empty = DataFacts(
    dives: 0,
    sites: 0,
    media: 0,
    databaseBytes: 0,
  );

  final int dives;

  /// Personal sites only; shared library rows belong to the club.
  final int sites;

  /// Photos and videos; signatures and documents also live in media.
  final int media;

  /// The main database file plus its WAL.
  final int databaseBytes;
}

class DataFactsRepository {
  const DataFactsRepository();

  Future<DataFacts> load(AppDatabase db, String? databasePath) async {
    final row = await db.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM dives) AS dives,
        (SELECT COUNT(*) FROM dive_sites WHERE shared_library_id IS NULL)
          AS sites,
        (SELECT COUNT(*) FROM media WHERE file_type IN ('photo', 'video'))
          AS media
    ''').getSingle();
    return DataFacts(
      dives: row.read<int>('dives'),
      sites: row.read<int>('sites'),
      media: row.read<int>('media'),
      databaseBytes: databasePath == null
          ? 0
          : await _fileSize(databasePath) +
                await _fileSize('$databasePath-wal'),
    );
  }

  Future<int> _fileSize(String path) async {
    try {
      final file = File(path);
      return await file.exists() ? await file.length() : 0;
    } on FileSystemException {
      return 0;
    }
  }
}
