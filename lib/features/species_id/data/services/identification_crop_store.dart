import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// The cropped image of each animal the marine life model found, kept on
/// this device so the diver can check the app's call (issue #4668).
///
/// Durable application support storage, not a cache the operating system
/// may empty. A deliberate, narrow exception to "media is links only":
/// small crops of detected animals, never the originals. Crops are deleted
/// only with their identification, by the app's own code; there is no
/// sweep of files without a row, because this folder is shared by every
/// logbook opened on the device.
class IdentificationCropStore {
  IdentificationCropStore({required Future<String> Function() supportPath})
    : _supportPath = supportPath;

  final Future<String> Function() _supportPath;

  Future<Directory> root() async =>
      Directory(p.join(await _supportPath(), 'species_id', 'crops'));

  Future<File> fileFor(String mediaId, String identificationId) async {
    _checkId(mediaId);
    _checkId(identificationId);
    return File(p.join((await root()).path, mediaId, '$identificationId.jpg'));
  }

  Future<void> write(
    String mediaId,
    String identificationId,
    Uint8List jpeg,
  ) async {
    final file = await fileFor(mediaId, identificationId);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(jpeg, flush: true);
    await temporary.rename(file.path);
  }

  Future<bool> allPresent(
    String mediaId,
    List<String> identificationIds,
  ) async {
    for (final id in identificationIds) {
      if (!await (await fileFor(mediaId, id)).exists()) return false;
    }
    return true;
  }

  Future<void> deleteMedia(List<String> mediaIds) async {
    final base = await root();
    for (final mediaId in mediaIds) {
      _checkId(mediaId);
      final dir = Directory(p.join(base.path, mediaId));
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }

  Future<void> delete(String mediaId, List<String> identificationIds) async {
    for (final id in identificationIds) {
      final file = await fileFor(mediaId, id);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> deleteAll() async {
    final base = await root();
    if (await base.exists()) await base.delete(recursive: true);
  }

  Future<int> sizeBytes() async {
    final base = await root();
    if (!await base.exists()) return 0;
    var total = 0;
    await for (final entity in base.list(recursive: true, followLinks: false)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Ids are file and folder names here, so one that could reach outside the
  /// crops folder is refused.
  static void _checkId(String id) {
    if (id.isEmpty ||
        id == '.' ||
        id == '..' ||
        id.contains('/') ||
        id.contains(r'\') ||
        id.contains(p.separator)) {
      throw ArgumentError.value(id, 'id', 'not a safe file name');
    }
  }
}
