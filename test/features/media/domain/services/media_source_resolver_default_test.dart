// Covers the default `resolveThumbnail` body on the abstract
// `MediaSourceResolver` interface — it's `=> resolve(item)`, which
// no concrete in-tree resolver hits because they all override.

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

class _MinimalResolver extends MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.networkUrl;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);

  // Intentionally NOT overriding resolveThumbnail — this exercises the
  // abstract class' `=> resolve(item)` default.

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;

  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.notFound;
}

void main() {
  test(
    'default resolveThumbnail delegates to resolve when not overridden',
    () async {
      final r = _MinimalResolver();
      final item = MediaItem(
        id: 'x',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.networkUrl,
        takenAt: DateTime.utc(2024, 1, 1),
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      final d = await r.resolveThumbnail(item, target: const Size(64, 64));
      expect(d, isA<UnavailableData>());
    },
  );
}
