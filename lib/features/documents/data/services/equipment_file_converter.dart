import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_file_gate.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
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
  }) : _readBytes = readBytes,
       _prefs = prefs,
       _documents = documents ?? DocumentRepository(),
       _media = media ?? MediaRepository();

  /// Per device, never synced: whether a file fits is the same everywhere,
  /// but only a device that read it knows.
  static const skippedKey = 'equipmentFileConversionSkipped';

  final MediaBytesReader _readBytes;
  final SharedPreferences _prefs;
  final DocumentRepository _documents;
  final MediaRepository _media;
  final _log = LoggerService.forClass(EquipmentFileConverter);

  AppDatabase get _db => DatabaseService.instance.database;

  Future<EquipmentFileConversionResult> run() async {
    final skipped = {...?_prefs.getStringList(skippedKey)};
    final rows = await _db
        .customSelect(
          'SELECT m.id, e.diver_id FROM media m '
          'JOIN equipment e ON e.id = m.equipment_id',
          readsFrom: {_db.media, _db.equipment},
        )
        .get();
    var converted = 0;
    var remaining = 0;
    for (final r in rows) {
      final mediaId = r.read<String>('id');
      final diverId = r.readNullable<String>('diver_id');
      try {
        final item = await _media.getMediaById(mediaId);
        if (item == null) continue;
        final convertible =
            diverId != null &&
            !skipped.contains(mediaId) &&
            _acceptedKind(_fileName(item));
        if (convertible && await _convert(item, diverId, skipped)) {
          converted++;
        } else {
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
    await _prefs.setStringList(skippedKey, skipped.toList()..sort());
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

  /// True when [item] is now a library document (or already was one).
  Future<bool> _convert(
    MediaItem item,
    String diverId,
    Set<String> skipped,
  ) async {
    final docId = documentEquipmentFileId(item.id);
    if (await _documents.getById(docId) != null) {
      await _media.deleteMedia(item.id);
      return true;
    }
    final bytes = await _readBytes(item);
    if (bytes == null) return false;
    final name = _fileName(item);
    final verdict = checkDocumentFile(fileName: name, sizeBytes: bytes.length);
    if (verdict is DocumentFileTooLarge) {
      skipped.add(item.id);
      return false;
    }
    if (verdict is! DocumentFileAccepted) return false;
    final now = DateTime.now();
    await _db.transaction(() async {
      await _documents.save(
        Document(
          id: docId,
          diverId: diverId,
          owner: DocumentOwner(DocumentOwnerKind.equipment, item.equipmentId!),
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
      await _media.deleteMedia(item.id);
    });
    return true;
  }
}
