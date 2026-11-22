import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';

/// The cropped image of each animal the marine life model found, kept on
/// this device so the diver can check the app's call (issue #4668).
///
/// Durable application support storage, not a cache the operating system
/// may empty. A deliberate, narrow exception to "media is links only":
/// small crops of detected animals, never the originals. Crops are deleted
/// only with their identification, by the app's own code: when this device
/// deletes it, when sync applies a peer's delete of it, or by the launch
/// sweep for a photo of the open logbook whose identification it holds a
/// tombstone for (issue #4890). There is no sweep of files without a row,
/// because this folder is shared by every logbook opened on the device.
///
/// Since issue #4876 the crops of named identifications live in the
/// logbook instead ([IdentificationCropRepository]), so they sync; this
/// store fronts both, a file first.
class IdentificationCropStore {
  IdentificationCropStore({
    required Future<String> Function() supportPath,
    IdentificationCropRepository? table,
    bool files = !kIsWeb,
  }) : _supportPath = supportPath,
       _table = table,
       _files = files;

  final Future<String> Function() _supportPath;

  /// Whether crops are kept as files here. Not in a browser, which has no
  /// files and never analyses: there only the synced crops show (issue
  /// #4876).
  final bool _files;

  /// The synced crops, or null where only files are kept (a test).
  final IdentificationCropRepository? _table;
  final _changes = StreamController<String>.broadcast();
  static final _log = LoggerService.forClass(IdentificationCropStore);

  /// Marks a photo's folder once the photo has been analysed on this
  /// device. A dot name, so it can never be an identification's crop.
  static const _analysedMarker = '.analysed';

  /// The media id whose crops were written or deleted.
  Stream<String> watchChanges() => _changes.stream;

  Future<void> dispose() => _changes.close();

  Future<Directory> root() async =>
      Directory(p.join(await _supportPath(), 'species_id', 'crops'));

  Future<File> fileFor(String mediaId, String identificationId) async {
    _checkId(mediaId);
    _checkId(identificationId);
    return File(p.join((await root()).path, mediaId, '$identificationId.jpg'));
  }

  /// The crop of [identificationId] on [mediaId] here: its file, else the
  /// synced one, else null.
  Future<IdentificationCropImage?> read(
    String mediaId,
    String identificationId,
  ) async {
    if (_files) {
      final file = await fileFor(mediaId, identificationId);
      if (await file.exists()) return CropFile(file);
    }
    final bytes = await _table?.bytesFor(identificationId);
    return bytes == null ? null : CropBytes(bytes);
  }

  /// Stores [jpeg] as the crop of [identificationId]: in the logbook, so it
  /// syncs, when the identification is [named]; else a file here.
  Future<void> write(
    String mediaId,
    String identificationId,
    Uint8List jpeg, {
    bool named = false,
  }) async {
    final table = _table;
    if (named && table != null) {
      await table.put(identificationId, mediaId, jpeg);
      if (_files) {
        final file = await fileFor(mediaId, identificationId);
        if (await file.exists()) await file.delete();
      }
      _changed(mediaId);
      return;
    }
    if (!_files) return;
    final file = await fileFor(mediaId, identificationId);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(jpeg, flush: true);
    await temporary.rename(file.path);
    _changed(mediaId);
  }

  /// Records that [mediaId] was analysed on this device. A decided
  /// identification whose crop did not come back from that analysis then
  /// stays without one, instead of the photo being analysed at every
  /// opening.
  Future<void> markAnalysed(String mediaId) async {
    if (!_files) return;
    final marker = await _markerFor(mediaId);
    await marker.parent.create(recursive: true);
    await marker.writeAsBytes(const [], flush: true);
  }

  Future<bool> wasAnalysedHere(String mediaId) async =>
      _files && await (await _markerFor(mediaId)).exists();

  Future<File> _markerFor(String mediaId) async {
    _checkId(mediaId);
    return File(p.join((await root()).path, mediaId, _analysedMarker));
  }

  /// Moves the file crops of [identificationIds], identifications that are
  /// named now, into the logbook so they sync (issue #4876). A crop already
  /// there, or with no file, is left as it is. Never throws. Returns how
  /// many it moved.
  Future<int> promote(String mediaId, List<String> identificationIds) async {
    final table = _table;
    if (!_files || table == null || identificationIds.isEmpty) return 0;
    var moved = 0;
    try {
      final synced = await table.presentAmong(identificationIds);
      for (final id in identificationIds) {
        if (synced.contains(id)) continue;
        final file = await fileFor(mediaId, id);
        if (!await file.exists()) continue;
        // Not for an identification a sync deleted since it was read.
        if (!await table.putIfIdentified(
          id,
          mediaId,
          await file.readAsBytes(),
        )) {
          continue;
        }
        await file.delete();
        moved++;
      }
    } on Object catch (e) {
      // Left as files: the backfill at the next launch tries again.
      _log.debug('Could not move named crops of $mediaId to sync', error: e);
    }
    if (moved > 0) _changed(mediaId);
    return moved;
  }

  /// Publishes the synced crops whose mark was lost (issue #4876). Returns
  /// how many.
  Future<int> republishUnstamped() async =>
      await _table?.republishUnstamped() ?? 0;

  /// Whether every one of [identificationIds] has a crop here, a file or a
  /// synced one.
  Future<bool> allPresent(
    String mediaId,
    List<String> identificationIds,
  ) async {
    final missing = <String>[];
    for (final id in identificationIds) {
      if (!_files || !await (await fileFor(mediaId, id)).exists()) {
        missing.add(id);
      }
    }
    if (missing.isEmpty) return true;
    final synced = await _table?.presentAmong(missing) ?? const <String>{};
    return synced.length == missing.length;
  }

  /// The media that have a crops folder here: the only ones whose crops
  /// can still be files to move into the logbook.
  Future<List<String>> mediaWithFiles() => _mediaFolders();

  /// The media with a crops folder here, for the backfill and the sweep
  /// alike.
  Future<List<String>> _mediaFolders() async {
    if (!_files) return const [];
    final base = await root();
    if (!await base.exists()) return const [];
    return [
      await for (final entity in base.list(followLinks: false))
        if (entity is Directory) p.basename(entity.path),
    ];
  }

  /// Removes every crop of [mediaIds]: the files, and the synced ones,
  /// tombstoned unless not [publish] (issue #4876).
  Future<void> deleteMedia(List<String> mediaIds, {bool publish = true}) async {
    await _table?.deleteForMedia(mediaIds, publish: publish);
    if (!_files) {
      mediaIds.forEach(_changed);
      return;
    }
    final base = await root();
    for (final mediaId in mediaIds) {
      _checkId(mediaId);
      final dir = Directory(p.join(base.path, mediaId));
      if (await dir.exists()) await dir.delete(recursive: true);
      _changed(mediaId);
    }
  }

  Future<void> delete(String mediaId, List<String> identificationIds) async {
    await _table?.deleteIds(identificationIds);
    await _deleteFiles(mediaId, identificationIds);
    if (identificationIds.isNotEmpty) _changed(mediaId);
  }

  /// Removes the crop files of [identificationIds] only, never the synced
  /// crops: for identifications a peer deleted, whose synced crops its own
  /// tombstones remove (issue #4890).
  Future<void> deleteFiles(
    String mediaId,
    List<String> identificationIds,
  ) async {
    if (await _deleteFiles(mediaId, identificationIds)) _changed(mediaId);
  }

  /// Whether any file was there to remove.
  Future<bool> _deleteFiles(
    String mediaId,
    List<String> identificationIds,
  ) async {
    if (!_files) return false;
    var removed = false;
    for (final id in identificationIds) {
      final file = await fileFor(mediaId, id);
      if (!await file.exists()) continue;
      try {
        await file.delete();
        removed = true;
      } on PathNotFoundException {
        // Removed in between by another cleanup (the sync hook and the
        // launch sweep can run together): the rest still go.
      }
    }
    return removed;
  }

  /// The identifications with a crop file here, by media (issue #4890).
  /// A folder removed while it is read (a final delete) is left out.
  Future<Map<String, List<String>>> fileIds() async {
    final mediaIds = await _mediaFolders();
    if (mediaIds.isEmpty) return const {};
    final base = (await root()).path;
    final found = <String, List<String>>{};
    for (final mediaId in mediaIds) {
      final ids = await cropIdsIn(Directory(p.join(base, mediaId)));
      if (ids.isNotEmpty) found[mediaId] = ids;
    }
    return found;
  }

  /// The identifications with a crop file in [dir]; none when it cannot
  /// be read.
  @visibleForTesting
  static Future<List<String>> cropIdsIn(Directory dir) async {
    try {
      return [
        await for (final entity in dir.list(followLinks: false))
          if (entity is File && p.extension(entity.path) == '.jpg')
            p.basenameWithoutExtension(entity.path),
      ];
    } on FileSystemException {
      return const [];
    }
  }

  void _changed(String mediaId) {
    if (!_changes.isClosed) _changes.add(mediaId);
  }

  Future<int> sizeBytes() async {
    if (!_files) return 0;
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

/// An identification's crop as this device holds it (issue #4876).
sealed class IdentificationCropImage {
  const IdentificationCropImage();
}

/// A crop kept as a file: an unnamed identification's, analysed here.
class CropFile extends IdentificationCropImage {
  const CropFile(this.file);

  final File file;
}

/// A crop kept in the logbook: a named identification's, from any device.
class CropBytes extends IdentificationCropImage {
  const CropBytes(this.bytes);

  final Uint8List bytes;
}
