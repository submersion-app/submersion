import 'dart:typed_data';

import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// What a photo library search for a file whose pointer stopped reading
/// comes to (media sync program spec 6.3):
///
/// * the photo's bytes, when the search found it and it reads;
/// * an inconclusive `accessDenied` (flagged when the view was a limited
///   selection), when the search could not look at all;
/// * null, when it looked and found nothing that reads.
///
/// Only null lets the caller fall back to its own verdict, which for a
/// failed read on the linking device is notFound, so a search that could
/// not look must never collapse into it.
Future<MediaSourceData?> librarySearchOutcome(
  ResolutionResult found,
  Future<Uint8List?> Function(String assetId) originBytes,
) async {
  if (found.status == ResolutionStatus.accessDenied) {
    return UnavailableData(
      kind: UnavailableKind.accessDenied,
      limitedAccess: found.limitedAccess,
    );
  }
  final id = found.localAssetId;
  if (id == null) return null;
  final bytes = await originBytes(id);
  return bytes == null
      ? null
      : BytesData(bytes: bytes, servedFrom: ServedFrom.platformGallery);
}
