import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/data/services/dive_gallery_lookup.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/helpers/asset_import_candidate.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
/// resolves to a dive or a site before any row exists), prepared for the
/// species page's sitting, which writes the rows and then tags each at its
/// Save. The species is applied after the attach, never instead of it, so
/// the attached-or-absent rule is untouched.
class SpeciesPhotoImportHelper {
  const SpeciesPhotoImportHelper._();

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

  /// "Add photos" on a species page in a sitting: the photo picker and the
  /// import review, whose Confirm prepares the photos and returns them,
  /// writing nothing. Null when nothing was chosen.
  static Future<List<PreparedMedia>?> preparePhotosForSpecies(
    BuildContext context,
    WidgetRef ref, {
    required String speciesId,
    Future<List<AssetInfo>?> Function(BuildContext context)? pick,
  }) async {
    // The rows are written at Save, past the import service's own demo
    // check: a demo stops here, before any work.
    if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) return null;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final assets =
        await (pick?.call(context) ??
            showPhotoPicker(
              context: context,
              diveStartTime: MediaImportView.libraryWindowStart,
              diveEndTime: DateTime.now().add(const Duration(days: 1)),
              buffer: Duration.zero,
              // Only the Gallery's choice comes back here; Files and URL
              // would write rows past the species' sitting (issue #4527).
              galleryOnly: true,
            )) ??
        const <AssetInfo>[];
    if (assets.isEmpty || !context.mounted) return null;
    final service = ref.read(mediaImportServiceProvider);
    final dives = ref.read(diveRepositoryProvider);
    final picker = ref.read(photoPickerServiceProvider);
    List<PreparedMedia>? result;
    var failed = 0;
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
            failed = done.review.failures.length;
            return done.review;
          },
        ),
      ),
    );
    // The species page has gone while the review was open: nothing to hold
    // and nobody to tell.
    if (!context.mounted) return null;
    // The review says nothing while the photos wait for Save; photos that
    // could not be prepared are said here, as the import says them.
    if (speciesPrepareFailureMessage(l10n, failed) case final message?) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
    return result;
  }

  /// What to say about [failed] photos that could not be prepared, or null
  /// when there were none.
  static String? speciesPrepareFailureMessage(
    AppLocalizations l10n,
    int failed,
  ) => failed == 0 ? null : l10n.marineLife_speciesPhotos_importFailed(failed);
}
