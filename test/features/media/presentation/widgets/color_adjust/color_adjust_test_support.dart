import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/services/color_analysis_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Records what the panel saves instead of touching a database.
class FakeColorRepository implements MediaColorAdjustmentRepository {
  final saves = <(String, ColorAdjustment?)>[];
  final applies = <(String, String, ColorAdjustment)>[];
  final restores = <Map<String, ColorAdjustment?>>[];
  int siblings = 3;
  Map<String, ColorAdjustment?> prior = {
    'a': null,
    'b': const ColorAdjustment(tint: 0.2),
    'c': null,
  };
  bool failSave = false;

  @override
  Future<void> setColorAdjustment(
    String mediaId,
    ColorAdjustment? adjustment,
  ) async {
    if (failSave) throw StateError('gone');
    saves.add((mediaId, adjustment));
  }

  @override
  Future<int> countOtherMediaOnDive(
    String diveId,
    String excludeMediaId,
  ) async => siblings;

  @override
  Future<Map<String, ColorAdjustment?>> applySlidersToDive({
    required String diveId,
    required String sourceMediaId,
    required ColorAdjustment source,
  }) async {
    applies.add((diveId, sourceMediaId, source));
    return prior;
  }

  @override
  Future<MediaEnrichment?> enrichmentFor(String mediaId) async => null;

  @override
  Stream<void> watchEnrichmentChanges() => const Stream.empty();

  @override
  Future<void> restoreColorAdjustments(
    Map<String, ColorAdjustment?> prior,
  ) async => restores.add(prior);
}

MediaItem colorItem({
  String? diveId = 'd1',
  double? depth = 18,
  ColorAdjustment? adjustment,
  MediaType type = MediaType.photo,
}) => MediaItem(
  id: 'm1',
  diveId: diveId,
  mediaType: type,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  colorAdjustment: adjustment,
  enrichment: depth == null
      ? null
      : MediaEnrichment(
          id: 'e1',
          mediaId: 'm1',
          diveId: 'd1',
          depthMeters: depth,
          elapsedSeconds: 600,
          matchConfidence: MatchConfidence.interpolated,
          createdAt: DateTime.utc(2026),
        ),
);

/// A container with the fake repository, the diver switch and [settings].
ProviderContainer colorContainer(
  FakeColorRepository repo, {
  bool diverAuto = false,
  AppSettings settings = const AppSettings(),
  ColorAnalysisService? analysis,
}) => ProviderContainer(
  overrides: [
    mediaColorAdjustmentRepositoryProvider.overrideWithValue(repo),
    diverAutoColorCorrectionProvider.overrideWithValue(diverAuto),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
    if (analysis != null)
      colorAnalysisServiceProvider.overrideWithValue(analysis),
  ],
);

Widget colorHost(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
