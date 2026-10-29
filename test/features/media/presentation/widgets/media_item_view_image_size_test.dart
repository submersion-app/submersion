import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

class _BytesResolver implements MediaSourceResolver {
  _BytesResolver(this.bytes);
  final Uint8List bytes;
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      BytesData(bytes: bytes);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// The viewer places face boxes by the photo's aspect (issue #1745); a row
/// with no stored width and height learns it from the decoded image.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('onImageSize reports the decoded image size once', (
    tester,
  ) async {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 120, height: 80)),
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sizes = <Size>[];
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.platformGallery: _BytesResolver(png),
              }),
            ),
          ],
          child: MaterialApp(
            home: MediaItemView(
              item: MediaItem(
                id: 'm1',
                mediaType: MediaType.photo,
                sourceType: MediaSourceType.platformGallery,
                takenAt: DateTime(2024),
                createdAt: DateTime(2024),
                updatedAt: DateTime(2024),
              ),
              fit: BoxFit.contain,
              onImageSize: sizes.add,
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });

    expect(sizes, hasLength(1));
    expect(sizes.single.aspectRatio, closeTo(120 / 80, 0.01));
  });
}
