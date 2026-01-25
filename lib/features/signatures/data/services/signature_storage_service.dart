import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

/// Service for capturing, storing, and retrieving instructor signatures
class SignatureStorageService {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SignatureStorageService);

  static const String _signatureFileType = 'instructor_signature';
  static const String _signatureDir = 'signatures';

  /// Save a signature image and create media record
  ///
  /// [diveId] - The dive this signature belongs to
  /// [imageBytes] - PNG bytes of the signature
  /// [signerName] - Name of the instructor signing
  /// [signerId] - Optional buddy ID if instructor is in system
  Future<Signature> saveSignature({
    required String diveId,
    required Uint8List imageBytes,
    required String signerName,
    String? signerId,
  }) async {
    try {
      _log.info('Saving signature for dive: $diveId');

      // Create signatures directory if needed
      final directory = await getApplicationDocumentsDirectory();
      final sigDir = Directory('${directory.path}/$_signatureDir');
      if (!await sigDir.exists()) {
        await sigDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${diveId}_$timestamp.png';
      final filePath = '${sigDir.path}/$fileName';

      // Save image file
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      // Create media record
      final id = _uuid.v4();
      final now = DateTime.now();

      await _db
          .into(_db.media)
          .insert(
            MediaCompanion(
              id: Value(id),
              diveId: Value(diveId),
              filePath: Value(filePath),
              fileType: const Value(_signatureFileType),
              takenAt: Value(now.millisecondsSinceEpoch),
              signerId: Value(signerId),
              signerName: Value(signerName),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Saved signature with id: $id');

      return Signature(
        id: id,
        diveId: diveId,
        filePath: filePath,
        signerId: signerId,
        signerName: signerName,
        signedAt: now,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to save signature for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get signature for a specific dive
  Future<Signature?> getSignatureForDive(String diveId) async {
    try {
      final query = _db.select(_db.media)
        ..where(
          (t) =>
              t.diveId.equals(diveId) & t.fileType.equals(_signatureFileType),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.takenAt)])
        ..limit(1);

      final row = await query.getSingleOrNull();

      if (row == null) return null;

      return _mapRowToSignature(row);
    } catch (e, stackTrace) {
      _log.error('Failed to get signature for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get all signatures for a course (via linked dives)
  Future<List<Signature>> getSignaturesForCourse(String courseId) async {
    try {
      final results = await _db
          .customSelect(
            '''
        SELECT m.* FROM media m
        INNER JOIN dives d ON m.dive_id = d.id
        WHERE d.course_id = ? AND m.file_type = ?
        ORDER BY m.taken_at DESC
      ''',
            variables: [
              Variable.withString(courseId),
              Variable.withString(_signatureFileType),
            ],
          )
          .get();

      return results.map(_mapQueryRowToSignature).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get signatures for course: $courseId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a signature and its file
  Future<void> deleteSignature(String signatureId) async {
    try {
      _log.info('Deleting signature: $signatureId');

      // Get the file path first
      final query = _db.select(_db.media)
        ..where((t) => t.id.equals(signatureId));
      final row = await query.getSingleOrNull();

      if (row != null) {
        // Delete the file
        final file = File(row.filePath);
        if (await file.exists()) {
          await file.delete();
        }

        // Delete the media record
        await (_db.delete(
          _db.media,
        )..where((t) => t.id.equals(signatureId))).go();

        await _syncRepository.logDeletion(
          entityType: 'media',
          recordId: signatureId,
        );
        SyncEventBus.notifyLocalChange();
      }

      _log.info('Deleted signature: $signatureId');
    } catch (e, stackTrace) {
      _log.error('Failed to delete signature: $signatureId', e, stackTrace);
      rethrow;
    }
  }

  /// Check if a dive has a signature
  Future<bool> hasSignature(String diveId) async {
    try {
      final query = _db.select(_db.media)
        ..where(
          (t) =>
              t.diveId.equals(diveId) & t.fileType.equals(_signatureFileType),
        )
        ..limit(1);

      final row = await query.getSingleOrNull();
      return row != null;
    } catch (e, stackTrace) {
      _log.error('Failed to check signature for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Convert stroke data to PNG bytes using a Picture recorder
  ///
  /// [strokes] - List of strokes, each stroke is a list of offsets
  /// [width] - Canvas width
  /// [height] - Canvas height
  /// [strokeColor] - Color of the signature stroke
  /// [strokeWidth] - Width of the signature stroke
  /// [backgroundColor] - Optional background color (null for transparent)
  static Future<Uint8List> strokesToPng({
    required List<List<ui.Offset>> strokes,
    required double width,
    required double height,
    required Color strokeColor,
    required double strokeWidth,
    Color? backgroundColor,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw background if specified
    if (backgroundColor != null) {
      final bgPaint = Paint()..color = backgroundColor;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);
    }

    // Draw strokes
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;

      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);

      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }

      canvas.drawPath(path, paint);
    }

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  // Private mapping methods

  Signature _mapRowToSignature(MediaData row) {
    return Signature(
      id: row.id,
      diveId: row.diveId!,
      filePath: row.filePath,
      signerId: row.signerId,
      signerName: row.signerName ?? 'Unknown',
      signedAt: DateTime.fromMillisecondsSinceEpoch(row.takenAt ?? 0),
    );
  }

  Signature _mapQueryRowToSignature(QueryRow row) {
    return Signature(
      id: row.data['id'] as String,
      diveId: row.data['dive_id'] as String,
      filePath: row.data['file_path'] as String,
      signerId: row.data['signer_id'] as String?,
      signerName: (row.data['signer_name'] as String?) ?? 'Unknown',
      signedAt: DateTime.fromMillisecondsSinceEpoch(
        (row.data['taken_at'] as int?) ?? 0,
      ),
    );
  }
}
