import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/data/services/dive_gallery_lookup.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/presentation/helpers/asset_import_candidate.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What an import into a species did, for its snackbar.
class SpeciesImportOutcome {
  final int added;
  final int skipped;
  final int failed;

  const SpeciesImportOutcome({
    required this.added,
    required this.skipped,
    required this.failed,
  });
}

/// Prepares the reviewed photos for a species page in a sitting and hands
/// them back, writing nothing ([SpeciesPhotoImportHelper
/// .preparePhotosForSpecies]); a seam, so a page test can answer for it.
typedef SpeciesPhotoPrepareLauncher =
    Future<List<PreparedMedia>?> Function(
      BuildContext context,
      WidgetRef ref,
      String speciesId,
    );

final speciesPhotoPrepareLauncherProvider =
    Provider<SpeciesPhotoPrepareLauncher>(
      (ref) =>
          (context, ref, speciesId) =>
              SpeciesPhotoImportHelper.preparePhotosForSpecies(
                context,
                ref,
                speciesId: speciesId,
              ),
    );

/// "Add photos" on a species: the library's reviewed import (every photo
/// resolves to a dive or a site before any row exists), followed by a tag
/// on each row it created. The species is applied after the attach, never
/// instead of it, so the attached-or-absent rule is untouched.
class SpeciesPhotoImportHelper {
  const SpeciesPhotoImportHelper._();

  /// Tags the rows a review created and folds both failure maps together.
  static Future<SpeciesImportOutcome> tagImported({
    required ImportReviewResult review,
    required SpeciesTaggingService service,
    required String speciesId,
  }) async {
    final tagged = await service.tagPhotos(
      mediaIds: review.importedIds,
      speciesId: speciesId,
    );
    return SpeciesImportOutcome(
      added: tagged.tagged,
      skipped: review.skipped,
      failed: review.failures.length + tagged.failures.length,
    );
  }

  /// Runs the picker, the review page and the tagging, then reports.
  ///
  /// [pick] is a test seam that replaces the platform photo picker.
  static Future<void> importPhotosForSpecies(
    BuildContext context,
    WidgetRef ref, {
    required String speciesId,
    Future<List<AssetInfo>?> Function(BuildContext context)? pick,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final assets =
        await (pick?.call(context) ??
            showPhotoPicker(
              context: context,
              diveStartTime: MediaImportView.libraryWindowStart,
              diveEndTime: DateTime.now().add(const Duration(days: 1)),
              buffer: Duration.zero,
            )) ??
        const <AssetInfo>[];
    if (assets.isEmpty || !context.mounted) return;

    final candidates = [for (final a in assets) importCandidateForAsset(a)];

    SpeciesImportOutcome? outcome;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaImportReviewPage(
          candidates: candidates,
          onConfirm: (targets) async {
            final review = await MediaImportView.importResolved(
              service: ref.read(mediaImportServiceProvider),
              diveRepository: ref.read(diveRepositoryProvider),
              photoPickerService: ref.read(photoPickerServiceProvider),
              assets: assets,
              targets: targets,
            );
            outcome = await tagImported(
              review: review,
              service: ref.read(speciesTaggingServiceProvider),
              speciesId: speciesId,
            );
            return review;
          },
        ),
      ),
    );

    final done = outcome;
    if (done == null) return;
    final parts = [
      l10n.marineLife_speciesPhotos_importAdded(done.added),
      if (done.skipped > 0)
        l10n.marineLife_speciesPhotos_importSkipped(done.skipped),
      if (done.failed > 0)
        l10n.marineLife_speciesPhotos_importFailed(done.failed),
    ];
    messenger.showSnackBar(SnackBar(content: Text(parts.join(' · '))));
  }

  /// Prepares each reviewed photo for the dive or site it resolved to, as
  /// [MediaImportView.importResolved] imports it, and writes nothing: the
  /// rows are written at a species page's Save (issue #4527, phase 3). A
  /// group that cannot be prepared (its dive gone) is reported and left
  /// out; a photo already linked there is counted as skipped.
  static Future<({List<PreparedMedia> prepared, ImportReviewResult review})>
  prepareResolved({
    required List<AssetInfo> assets,
    required Map<String, MediaAttachTarget> targets,
    required Future<List<PreparedMedia>> Function(
      String diveId,
      List<AssetInfo> assets,
    )
    prepareForDive,
    required Future<List<PreparedMedia>> Function(
      String siteId,
      List<AssetInfo> assets,
    )
    prepareForSite,
  }) async {
    final byId = {for (final a in assets) a.id: a};
    final byDive = <String, List<AssetInfo>>{};
    final bySite = <String, List<AssetInfo>>{};
    final failures = <String, String>{};
    for (final MapEntry(:key, :value) in targets.entries) {
      final asset = byId[key];
      if (asset == null) continue;
      switch (value) {
        case DiveAttachTarget(:final diveId):
          byDive.putIfAbsent(diveId, () => []).add(asset);
        case SiteAttachTarget(:final siteId):
          bySite.putIfAbsent(siteId, () => []).add(asset);
        case EquipmentAttachTarget():
          // A species' photos go to a dive or a site, never to gear.
          failures[key] = 'not a dive or a site';
      }
    }
    final prepared = <PreparedMedia>[];
    var skipped = 0;
    Future<void> group(
      List<AssetInfo> group,
      Future<List<PreparedMedia>> Function() prepare,
    ) async {
      try {
        final ready = await prepare();
        prepared.addAll(ready);
        skipped += group.length - ready.length;
      } catch (e) {
        for (final a in group) {
          failures[a.id] = e.toString();
        }
      }
    }

    for (final MapEntry(:key, :value) in byDive.entries) {
      await group(value, () => prepareForDive(key, value));
    }
    for (final MapEntry(:key, :value) in bySite.entries) {
      await group(value, () => prepareForSite(key, value));
    }
    return (
      prepared: prepared,
      review: ImportReviewResult(
        linked: prepared.length,
        skipped: skipped,
        failures: failures,
      ),
    );
  }

  /// "Add photos" on a species page in a sitting: the same picker and
  /// review as [importPhotosForSpecies], but Confirm prepares the photos and
  /// returns them, writing nothing. Null when nothing was chosen.
  static Future<List<PreparedMedia>?> preparePhotosForSpecies(
    BuildContext context,
    WidgetRef ref, {
    required String speciesId,
    Future<List<AssetInfo>?> Function(BuildContext context)? pick,
  }) async {
    final assets =
        await (pick?.call(context) ??
            showPhotoPicker(
              context: context,
              diveStartTime: MediaImportView.libraryWindowStart,
              diveEndTime: DateTime.now().add(const Duration(days: 1)),
              buffer: Duration.zero,
            )) ??
        const <AssetInfo>[];
    if (assets.isEmpty || !context.mounted) return null;
    final service = ref.read(mediaImportServiceProvider);
    final dives = ref.read(diveRepositoryProvider);
    final picker = ref.read(photoPickerServiceProvider);
    List<PreparedMedia>? result;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaImportReviewPage(
          candidates: [for (final a in assets) importCandidateForAsset(a)],
          reportResult: false,
          onConfirm: (targets) async {
            final done = await prepareResolved(
              assets: assets,
              targets: targets,
              prepareForDive: (diveId, group) async {
                final dive = await dives.getDiveById(diveId);
                if (dive == null) {
                  throw StateError('dive $diveId no longer exists');
                }
                final (entryTime, exitTime) = TripMediaScanner.diveBounds(dive);
                return service.prepareForDive(
                  selectedAssets: await DiveGalleryLookup.correctedForDive(
                    assets: group,
                    windowStart: entryTime.subtract(DivePhotoMatcher.preBuffer),
                    windowEnd: exitTime.add(DivePhotoMatcher.postBuffer),
                    photoPickerService: picker,
                  ),
                  dive: dive,
                );
              },
              prepareForSite: (siteId, group) =>
                  service.prepareForSite(selectedAssets: group, siteId: siteId),
            );
            result = done.prepared;
            return done.review;
          },
        ),
      ),
    );
    return result;
  }
}
