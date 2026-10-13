import 'package:submersion/core/database/database.dart';

/// The database file's size and how much of it is free pages, which SQLite
/// reuses but only a VACUUM gives back to the disk (issue #3333).
class DatabaseSpace {
  /// A rewrite makes a launch slower, so only a saving that is large both
  /// on its own and against the whole file earns one.
  static const int minimumReclaimBytes = 50 * 1024 * 1024;

  final int pageSize;
  final int pageCount;
  final int freePages;

  const DatabaseSpace({
    required this.pageSize,
    required this.pageCount,
    required this.freePages,
  });

  int get fileBytes => pageSize * pageCount;
  int get reclaimableBytes => pageSize * freePages;

  /// At least [minimumReclaimBytes] and at least a quarter of the file.
  bool get worthCompacting =>
      reclaimableBytes >= minimumReclaimBytes &&
      reclaimableBytes * 4 >= fileBytes;
}

Future<DatabaseSpace> readDatabaseSpace(AppDatabase db) async {
  Future<int> pragma(String name) async =>
      (await db.customSelect('PRAGMA $name').getSingle()).data.values.first
          as int;
  return DatabaseSpace(
    pageSize: await pragma('page_size'),
    pageCount: await pragma('page_count'),
    freePages: await pragma('freelist_count'),
  );
}
