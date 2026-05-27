import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/universal_import/data/services/directory_scanner.dart';
import 'package:submersion/features/universal_import/data/value_objects/scanned_file.dart';

/// Desktop (Windows / Linux / macOS) [DirectoryScanner] backed by
/// `dart:io`. The recorded paths in the export came from a Mac, so the
/// handle is the absolute filesystem path; no bookmark is needed because
/// desktop file access does not expire.
class DesktopDirectoryScanner implements DirectoryScanner {
  final _log = LoggerService.forClass(DesktopDirectoryScanner);

  @override
  Stream<ScannedFile> scan(GrantedFolder folder) async* {
    final dir = Directory(folder.path);
    if (!await dir.exists()) return;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        yield ScannedFile(
          basename: p.basename(entity.path),
          handle: MediaHandle.localPath(entity.path),
        );
      }
    } catch (e, st) {
      // Permission / IO errors surface as stream error events here, not as
      // a synchronous throw from list(); catching around the await-for is
      // what actually handles them. Degrade to "no more files".
      _log.error(
        'Failed to list directory: ${folder.path}',
        error: e,
        stackTrace: st,
      );
    }
  }
}
