import 'dart:typed_data';

import 'package:submersion/core/database/database_image.dart';
import 'package:submersion/core/platform/file_saver.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

/// A browser's backups (issue #4121): a browser has no backup files, so its
/// copy is an image of the live library handed to a download.

/// `<prefix>-<yyyyMMdd>-<HHmm>.db`.
String browserBackupFileName(
  DateTime at, {
  String prefix = 'submersion-backup',
}) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '$prefix-${at.year}${two(at.month)}${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}.db';
}

/// The live library as the bytes of one SQLite file, read as a sync turn so
/// no merge runs across it.
Future<Uint8List> readLiveLibraryImage() => SyncCoordinator.join(
  () => readDatabaseImage(DatabaseService.instance.database),
);

/// Hands [bytes] to the browser's download under [fileName].
Future<void> saveBrowserBackup(Uint8List bytes, String fileName) =>
    FileSaver.saveBytes(
      bytes,
      fileName: fileName,
      mimeType: 'application/vnd.sqlite3',
    );

/// The browser's stand-in for the backup a file restore takes first: the
/// library downloads as a backup file, unless it holds no dives to lose.
Future<void> downloadLibraryBeforeRestore({
  DateTime Function() clock = DateTime.now,
  Future<Uint8List> Function() readImage = readLiveLibraryImage,
  Future<void> Function(Uint8List bytes, String fileName) save =
      saveBrowserBackup,
}) async {
  final row = await DatabaseService.instance.database
      .customSelect('SELECT EXISTS (SELECT 1 FROM dives) AS has_dives')
      .getSingle();
  if (row.read<int>('has_dives') != 1) return;
  await save(
    await readImage(),
    browserBackupFileName(clock(), prefix: 'submersion-backup-before-restore'),
  );
}
