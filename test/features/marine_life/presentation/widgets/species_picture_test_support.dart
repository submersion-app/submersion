import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../media/presentation/support/media_widget_harness.dart';

SpeciesCrop testCrop(
  String id, {
  bool video = false,
  int? bestMs,
  String? mediaId,
}) => SpeciesCrop(
  identificationId: id,
  mediaId: mediaId ?? 'm_$id',
  box: const IdentificationBox(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
  shorterSide: 200,
  bestMs: bestMs,
  isVideo: video,
  confirmed: true,
);

MediaItem testPhoto(String id, {bool video = false}) => MediaItem(
  id: id,
  mediaType: video ? MediaType.video : MediaType.photo,
  sourceType: MediaSourceType.localFile,
  localPath: p.join(Directory.systemTemp.path, '$id.jpg'),
  width: 4000,
  height: 3000,
  takenAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Pumps [child] with crops served as one-pixel bytes and media resolved to
/// [resolverData] (a one-pixel image by default).
Future<void> pumpPictures(
  WidgetTester tester,
  Widget child, {
  MediaSourceData? resolverData,
  List<Override> extra = const [],
}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...base,
        mediaResolverOverride(resolverData: resolverData),
        identificationCropProvider.overrideWith(
          (ref, key) async => CropBytes(onePixelPng()),
        ),
        ...extra,
      ],
      child: child,
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a whole [app] (a router app, say) with crops served as one-pixel
/// bytes and media resolved to a one-pixel image.
Future<void> pumpPicturesApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaResolverOverride(),
        identificationCropProvider.overrideWith(
          (ref, key) async => CropBytes(onePixelPng()),
        ),
      ],
      child: app,
    ),
  );
  await tester.pumpAndSettle();
}
