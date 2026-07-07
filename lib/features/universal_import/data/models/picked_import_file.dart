import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/detection_result.dart';

/// Lifecycle of one file within a bulk import batch.
enum ImportFileStatus {
  /// Detected as a supported, batchable format; awaiting parse.
  pending,

  /// Parsed successfully into the merged payload.
  parsed,

  /// Detection succeeded but parsing threw; the batch continues without it.
  failed,

  /// CSV: requires the single-file mapping wizard, excluded from batches.
  excludedCsv,

  /// Format not supported by any parser.
  unsupported,
}

/// One file selected for import (via picker, folder scan, or drop).
///
/// For picker/drop files [path] is set and [bytes] is null: bytes were read
/// once for format detection and discarded, then re-read lazily at parse
/// time so a large folder pick never holds every raw buffer at once.
class PickedImportFile {
  final String name;
  final String? path;
  final Uint8List? bytes;
  final DetectionResult detection;
  final ImportFileStatus status;
  final String? error;
  final int diveCount;

  const PickedImportFile({
    required this.name,
    required this.detection,
    required this.status,
    this.path,
    this.bytes,
    this.error,
    this.diveCount = 0,
  });

  PickedImportFile copyWith({
    ImportFileStatus? status,
    String? error,
    int? diveCount,
  }) {
    return PickedImportFile(
      name: name,
      path: path,
      bytes: bytes,
      detection: detection,
      status: status ?? this.status,
      error: error ?? this.error,
      diveCount: diveCount ?? this.diveCount,
    );
  }
}
