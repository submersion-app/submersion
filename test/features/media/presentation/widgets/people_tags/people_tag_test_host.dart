import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../data/repositories/species_photo_fixtures.dart';

/// Shared fixtures for the people-tag widget tests (issue #1745): diver A
/// with buddies Alex and Bea, dive d1 that Bea is logged on, and photo p1
/// (1200 x 900) on it.
Future<void> seedPeopleTagFixtures() async {
  await insertTestDiver('A');
  await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), diverId: 'A');
  await insertTestBuddy(id: 'alex', name: 'Alex', diverId: 'A');
  await insertTestBuddy(id: 'bea', name: 'Bea', diverId: 'A');
  await insertTestMedia(id: 'p1', diveId: 'd1', takenAt: DateTime(2024, 1, 10));
}

MediaItem photoItem({
  int? width = 1200,
  int? height = 900,
  String? diveId = 'd1',
}) => MediaItem(
  id: 'p1',
  diveId: diveId,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  width: width,
  height: height,
  takenAt: DateTime(2024, 1, 10),
  createdAt: DateTime(2024, 1, 10),
  updatedAt: DateTime(2024, 1, 10),
);

class _BytesResolver implements MediaSourceResolver {
  _BytesResolver(this.bytes);
  final Uint8List? bytes;
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async => bytes == null
      ? const UnavailableData(kind: UnavailableKind.notFound)
      : BytesData(bytes: bytes!);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// [home] in a provider scope with diver A active and a resolver that
/// serves a 1200 x 900 image, or nothing when [withImage] is false.
Future<Widget> peopleTagHost(Widget home, {bool withImage = true}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final diver = MockCurrentDiverIdNotifier();
  await diver.setCurrentDiver('A');
  final png = withImage
      ? Uint8List.fromList(img.encodePng(img.Image(width: 120, height: 90)))
      : null;
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentDiverIdProvider.overrideWith((ref) => diver),
      mediaSourceResolverRegistryProvider.overrideWithValue(
        MediaSourceResolverRegistry({
          MediaSourceType.platformGallery: _BytesResolver(png),
        }),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}
