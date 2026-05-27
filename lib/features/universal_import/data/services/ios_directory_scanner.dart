import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/universal_import/data/services/directory_scanner.dart';
import 'package:submersion/features/universal_import/data/value_objects/scanned_file.dart';

/// iOS [DirectoryScanner] over the `enumerateScopedDirectory` channel
/// method. Each yielded [ScannedFile] carries a security-scoped bookmark
/// blob created natively while the directory scope was held.
class IosDirectoryScanner implements DirectoryScanner {
  IosDirectoryScanner(this._platform);
  final LocalMediaPlatform _platform;

  @override
  Stream<ScannedFile> scan(GrantedFolder folder) async* {
    final entries = await _platform.enumerateScopedDirectory(
      folder.iosFolderBookmark!,
    );
    for (final e in entries) {
      yield ScannedFile(
        basename: e.basename,
        handle: MediaHandle.bookmark(e.bookmarkBlob),
      );
    }
  }
}
