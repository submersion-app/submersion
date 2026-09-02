import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/value_objects/import_preview.dart';
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

    final candidates = [
      for (final a in assets)
        ImportCandidate(
          key: a.id,
          title: a.filename ?? a.id,
          takenAt: TripMediaScanner.toWallClockUtc(a.createDateTime),
          preview: AssetImportPreview(a.id),
        ),
    ];

    SpeciesImportOutcome? outcome;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaImportReviewPage(
          candidates: candidates,
          onConfirm: (targets) async {
            final review = await MediaImportView.importResolved(
              service: ref.read(mediaImportServiceProvider),
              diveRepository: ref.read(diveRepositoryProvider),
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
}
