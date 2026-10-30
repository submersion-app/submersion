import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_file_gate.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Reads a media item's full content; null when this device cannot.
typedef MediaBytesReader = Future<Uint8List?> Function(MediaItem item);

class EquipmentFileConversionResult {
  final int converted;

  /// Gear files still linked: not readable here yet, or never convertible.
  final int remaining;

  const EquipmentFileConversionResult(this.converted, this.remaining);
}

/// Moves files linked to gear by the older attachment card (#1517) into the
/// Documents library (issue #3333), so they show in Documents and can be
/// refiled.
///
/// Runs at launch and after each sync, and is safe to repeat: a converted
/// file's media row is gone, a document a peer already converted is kept as
/// it is, a file this device cannot read yet is tried again next run, and
/// one the library can never hold (a kind it does not accept, or over the
/// page cap) stays on the gear's "Linked files" card. The media table holds
/// no size for a linked file, so an oversize one is only found by reading
/// it; its id is remembered on this device to spare a re-read of a large
/// file every launch.
class EquipmentFileConverter {
  EquipmentFileConverter({
    required MediaBytesReader readBytes,
    required SharedPreferences prefs,
    DocumentRepository? documents,
    MediaRepository? media,
    Future<void> Function(String mediaId)? unlink,
  }) : _readBytes = readBytes,
       _prefs = prefs,
       _documents = documents ?? DocumentRepository(),
       _media = media ?? MediaRepository(),
       _unlinkOverride = unlink;

  /// Per device, never synced: whether a file fits is the same everywhere,
  /// but only a device that read it knows.
  static const skippedKey = 'equipmentFileConversionSkipped';

  final MediaBytesReader _readBytes;
  final SharedPreferences _prefs;
  final DocumentRepository _documents;
  final MediaRepository _media;

  /// Drops a converted file's gear link the way the gear card's Remove
  /// does: a row a dive or site still uses keeps it with the gear link
  /// cleared, the rest leave the library. The app wires the deletion
  /// coordinator, which also queues the removal of an uploaded copy from
  /// the media store; without it, the rows are deleted directly.
  final Future<void> Function(String mediaId)? _unlinkOverride;

  Future<void> _unlink(String mediaId) =>
      (_unlinkOverride ??
      (id) => MediaUnlinkService(
        repository: _media,
        deleteMedia: _media.deleteMultipleMedia,
      ).unlinkFromEquipment([id]))(mediaId);
  final _log = LoggerService.forClass(EquipmentFileConverter);

  AppDatabase get _db => DatabaseService.instance.database;

  Future<EquipmentFileConversionResult> run() async {
    final previouslyTooLarge = {...?_prefs.getStringList(skippedKey)};
    // Runs unawaited after a sync, so a restore, a storage move or demo mode
    // can open another database part way through (issue #3798).
    final startedOn = _db;
    final rows = await _db
        .customSelect(
          'SELECT m.id, e.diver_id FROM media m '
          'JOIN equipment e ON e.id = m.equipment_id',
          readsFrom: {_db.media, _db.equipment},
        )
        .get();
    var converted = 0;
    var remaining = 0;
    // Rebuilt from the rows still linked, so a deleted file's id drops out.
    final tooLarge = <String>[];
    for (final r in rows) {
      final mediaId = r.read<String>('id');
      final diverId = r.readNullable<String>('diver_id');
      if (previouslyTooLarge.contains(mediaId)) {
        tooLarge.add(mediaId);
        remaining++;
        continue;
      }
      try {
        final item = await _media.getMediaById(mediaId);
        if (item == null) continue;
        final outcome = diverId != null && _acceptedKind(_fileName(item))
            ? await _convert(item, diverId, startedOn)
            : _Outcome.left;
        switch (outcome) {
          case _Outcome.swapped:
            // The rows read belong to a database no longer open. Its links
            // and skip list stay as they were for the next run there.
            return EquipmentFileConversionResult(
              converted,
              rows.length - converted,
            );
          case _Outcome.converted:
            converted++;
          case _Outcome.tooLarge:
            tooLarge.add(mediaId);
            remaining++;
          case _Outcome.left:
            remaining++;
        }
      } catch (e, stackTrace) {
        remaining++;
        _log.warning(
          'Could not convert gear file $mediaId',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    // The skip list is shared by every database, so it is replaced only
    // while the one these rows came from is still open.
    final kept = await _onDatabase(startedOn, () async {
      await _prefs.setStringList(skippedKey, tooLarge..sort());
      return true;
    });
    if (kept == null) {
      return EquipmentFileConversionResult(converted, rows.length - converted);
    }
    if (converted > 0) SyncEventBus.notifyLocalChange();
    return EquipmentFileConversionResult(converted, remaining);
  }

  static String _fileName(MediaItem item) =>
      item.originalFilename ?? p.basename(item.filePath ?? '');

  /// A kind the library holds as it is. An image would need the re-encode
  /// the document editor does; the old card never offered one, so any that
  /// exists stays linked rather than stored un-encoded.
  static bool _acceptedKind(String fileName) =>
      switch (checkDocumentFile(fileName: fileName, sizeBytes: 0)) {
        DocumentFileAccepted(:final needsImageReencode) => !needsImageReencode,
        _ => false,
      };

  /// The size of [item] when it is known without reading it: the store's
  /// record of an uploaded file, or a local file's length on disk. Null for
  /// anything else (an Android content URI, a file not on this device).
  static int? _knownSize(MediaItem item) {
    if (item.contentSizeBytes case final size?) return size;
    final path = item.filePath;
    if (path == null || path.contains('://')) return null;
    try {
      final file = File(path);
      return file.existsSync() ? file.lengthSync() : null;
    } on FileSystemException {
      return null;
    }
  }

  /// Runs [write] as a [SyncCoordinator] turn while [startedOn] is still
  /// the open database, or returns null once it is not. Every database swap
  /// is a coordinator turn too, so the database cannot change mid-write.
  Future<T?> _onDatabase<T>(
    AppDatabase startedOn,
    Future<T> Function() write,
  ) => SyncCoordinator.run(
    () async => identical(DatabaseService.instance.databaseOrNull, startedOn)
        ? await write()
        : null,
  );

  Future<_Outcome> _convert(
    MediaItem item,
    String diverId,
    AppDatabase startedOn,
  ) async {
    final docId = documentEquipmentFileId(item.id);
    final peerConverted = await _onDatabase(startedOn, () async {
      if (await _documents.getById(docId) == null) return false;
      await _unlink(item.id);
      return true;
    });
    if (peerConverted == null) return _Outcome.swapped;
    if (peerConverted) return _Outcome.converted;
    // Checked before reading: an old link can be a PDF of hundreds of MB,
    // and reading it whole only to refuse it could exhaust a phone's memory.
    if ((_knownSize(item) ?? 0) > kMaxDocumentPageBytes) {
      return _Outcome.tooLarge;
    }
    final bytes = await _readBytes(item);
    if (bytes == null) return _Outcome.left;
    final name = _fileName(item);
    final verdict = checkDocumentFile(fileName: name, sizeBytes: bytes.length);
    if (verdict is DocumentFileTooLarge) return _Outcome.tooLarge;
    if (verdict is! DocumentFileAccepted) return _Outcome.left;
    final now = DateTime.now();
    final saved = await _onDatabase(
      startedOn,
      () => _db.transaction(() async {
        await _documents.save(
          Document(
            id: docId,
            diverId: diverId,
            owner: DocumentOwner(
              DocumentOwnerKind.equipment,
              item.equipmentId!,
            ),
            type: DocumentType.receipt,
            title: p.basenameWithoutExtension(name),
            notes: item.caption?.trim() ?? '',
            createdAt: item.createdAt,
            updatedAt: now,
          ),
          [
            DocumentPage(
              id: documentEquipmentFilePageId(docId),
              documentId: docId,
              pageIndex: 0,
              fileName: name,
              mimeType: verdict.mimeType,
              sizeBytes: bytes.length,
              bytes: bytes,
              createdAt: now,
              updatedAt: now,
            ),
          ],
          notify: false,
        );
        await _unlink(item.id);
        return true;
      }),
    );
    return saved == null ? _Outcome.swapped : _Outcome.converted;
  }
}

/// What one gear file's conversion attempt came to.
enum _Outcome {
  /// Now a library document (or a peer's conversion already was).
  converted,

  /// Over the library's page cap: remembered, never read again.
  tooLarge,

  /// Not convertible here, or not yet: left linked, tried again next run.
  left,

  /// Another database was opened during the run: nothing was written.
  swapped,
}
