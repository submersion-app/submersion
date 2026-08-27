import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

class _Fake implements MediaSourceResolver {
  _Fake(this.sourceType);
  @override
  final MediaSourceType sourceType;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.notFound;
}

void main() {
  test('lookup returns registered resolver', () {
    final reg = MediaSourceResolverRegistry({
      MediaSourceType.platformGallery: _Fake(MediaSourceType.platformGallery),
    });
    expect(reg.resolverFor(MediaSourceType.platformGallery), isA<_Fake>());
  });

  test('lookup throws on missing resolver', () {
    final reg = MediaSourceResolverRegistry(const {});
    expect(
      () => reg.resolverFor(MediaSourceType.localFile),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
