import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/universal_import/data/services/directory_scanner.dart';
import 'package:submersion/features/universal_import/data/value_objects/scanned_file.dart';

/// Android [DirectoryScanner] over the `enumerateTree` channel method.
/// Each yielded [ScannedFile] carries a per-file content URI usable as the
/// `bookmarkRef` on the persisted [MediaItem] row.
class AndroidDirectoryScanner implements DirectoryScanner {
  AndroidDirectoryScanner(this._platform);
  final LocalMediaPlatform _platform;

  @override
  Stream<ScannedFile> scan(GrantedFolder folder) async* {
    final entries = await _platform.enumerateTree(folder.path);
    for (final e in entries) {
      yield ScannedFile(
        basename: e.basename,
        handle: MediaHandle.contentUri(e.contentUri),
      );
    }
  }
}
