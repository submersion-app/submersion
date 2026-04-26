import 'dart:io';
import 'dart:ui' show Size;

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolves [MediaSourceType.signature] items.
///
/// Signatures are stored either inline as a BLOB on the media row
/// ([MediaItem.imageData]) or as a file at [MediaItem.filePath]. The BLOB
/// path takes precedence when both are present.
class SignatureResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.signature;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    if (item.imageData != null && item.imageData!.isNotEmpty) {
      return BytesData(bytes: item.imageData!);
    }
    final path = item.filePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        return FileData(file: file);
      }
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
