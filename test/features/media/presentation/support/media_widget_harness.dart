import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../media_store/support/fake_local_file_resolver.dart';

/// Valid 1x1 transparent PNG, so [Image.memory] decodes instead of taking
/// the errorBuilder path.
const onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpe'
    'qz8AAAAASUVORK5CYII=';

Uint8List onePixelPng() => base64Decode(onePixelPngBase64);

/// Shared scaffolding for media widget tests.
///
/// Every one of them needs the same three things: the app-wide base
/// overrides (settings, prefs, stubbed streams), a resolver registry that
/// serves bytes without touching photo_manager or the filesystem, and a
/// locale-pinned [MaterialApp] so English assertions survive a non-English
/// host machine (flutter_test forwards the host's locale list).
///
/// [resolverData] is what every media item resolves to; the default is a
/// decodable 1x1 PNG. Pass [UnavailableData] to exercise placeholder paths.
Future<Widget> mediaTestApp({
  required Widget home,
  List<Override> overrides = const [],
  MediaSourceData? resolverData,
}) async {
  final base = await getBaseOverrides();
  final resolver = FakeLocalFileResolver(
    resolverData ?? BytesData(bytes: onePixelPng()),
  );
  return ProviderScope(
    overrides: [
      ...base,
      mediaSourceResolverRegistryProvider.overrideWithValue(
        MediaSourceResolverRegistry({
          MediaSourceType.localFile: resolver,
          MediaSourceType.platformGallery: resolver,
        }),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// Media item factory for widget tests. Defaults to a local-file photo,
/// which the harness registry can always resolve.
MediaItem testMediaItem({
  String id = 'm1',
  String? diveId,
  String? siteId,
  MediaType mediaType = MediaType.photo,
  String? originalFilename = 'reef.png',
  MediaSourceType sourceType = MediaSourceType.localFile,
  bool isOrphaned = false,
  String? caption,
  String? originDeviceId,
  MediaEnrichment? enrichment,
  DateTime? takenAt,
}) => MediaItem(
  id: id,
  diveId: diveId,
  siteId: siteId,
  mediaType: mediaType,
  sourceType: sourceType,
  originalFilename: originalFilename,
  localPath: '/tmp/$originalFilename',
  isOrphaned: isOrphaned,
  caption: caption,
  originDeviceId: originDeviceId,
  enrichment: enrichment,
  takenAt: takenAt ?? DateTime(2026, 3, 1, 10, 30),
  createdAt: DateTime(2026, 3, 1),
  updatedAt: DateTime(2026, 3, 1),
);
