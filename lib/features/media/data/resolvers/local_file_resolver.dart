import 'dart:io';
import 'dart:ui' show Size;

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Phase 1 resolver for [MediaSourceType.localFile].
///
/// Reads [MediaItem.localPath] (falling back to [MediaItem.filePath] for
/// pre-v72 rows that the migration backfilled) and returns the file as
/// [FileData] if it exists on this device's filesystem.
///
/// On desktop platforms (macOS / Linux / Windows) the backfilled paths are
/// generally still valid, so this resolver renders existing local-file
/// media without further work. On iOS / Android the path is not directly
/// readable due to sandboxing — this resolver returns
/// [UnavailableData] (`UnavailableKind.notFound`) for those rows; Phase 2
/// replaces this stub with a `LocalFilePathResolver` that resolves the
/// stored security-scoped bookmark / persistable URI before reading.
class LocalFileResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    final path = item.localPath ?? item.filePath;
    if (path == null || path.isEmpty) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        return FileData(file: file);
      }
    } on FileSystemException {
      // Fall through to UnavailableData. Honors the "Never throws" contract
      // on MediaSourceResolver.resolve.
    }
    return const UnavailableData(kind: UnavailableKind.notFound);
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final data = await resolve(item);
    return data is UnavailableData
        ? VerifyResult.notFound
        : VerifyResult.available;
  }
}
