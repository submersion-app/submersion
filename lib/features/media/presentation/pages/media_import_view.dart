import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/value_objects/import_preview.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/pages/media_import_review_page.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Import console section: launches the three-tab picker with no dive
/// context, then hands the picked assets to [MediaImportReviewPage]. Nothing
/// is written until the user confirms, and only assets resolved to a dive or
/// a site are imported.
class MediaImportView extends ConsumerWidget {
  const MediaImportView({super.key, this.launchOverride});

  /// Test seam: returns the picked assets instead of driving the platform
  /// picker (which flutter_test cannot).
  @visibleForTesting
  final Future<List<AssetInfo>> Function(BuildContext context)? launchOverride;

  /// Lower bound of the gallery tab's date window for a dive-less import.
  ///
  /// The mobile picker turns this into a hard photo_manager
  /// `DateTimeCond(min:)`, so a "recent enough" sentinel would quietly hide
  /// everything older -- scanned film and slide libraries being exactly the
  /// media a diver back-fills. Epoch is photo_manager's own no-lower-bound
  /// value (`DateTimeCond.def()`), so it reads as unbounded to the native
  /// query rather than as an arbitrary cutoff.
  static final DateTime libraryWindowStart =
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<List<AssetInfo>> _pick(BuildContext context) async {
    // No dive context: there is no meaningful date window, so the gallery
    // tab gets an unbounded one (desktop file dialogs ignore it entirely).
    final selected = await showPhotoPicker(
      context: context,
      diveStartTime: libraryWindowStart,
      diveEndTime: DateTime.now().add(const Duration(days: 1)),
      buffer: Duration.zero,
    );
    return selected ?? const [];
  }

  /// Imports the resolved assets, one service call per dive and per site.
  /// A failing group never blocks another: a throw inside one group is
  /// recorded against that group's assets and the loop moves on.
  @visibleForTesting
  static Future<ImportReviewResult> importResolved({
    required MediaImportService service,
    required DiveRepository diveRepository,
    required List<AssetInfo> assets,
    required Map<String, MediaAttachTarget> targets,
  }) async {
    final byId = {for (final a in assets) a.id: a};
    final byDive = <String, List<AssetInfo>>{};
    final bySite = <String, List<AssetInfo>>{};
    for (final MapEntry(:key, :value) in targets.entries) {
      final asset = byId[key];
      if (asset == null) continue;
      switch (value) {
        case DiveAttachTarget(:final diveId):
          byDive.putIfAbsent(diveId, () => []).add(asset);
        case SiteAttachTarget(:final siteId):
          bySite.putIfAbsent(siteId, () => []).add(asset);
      }
    }

    var linked = 0;
    final failures = <String, String>{};

    void failGroup(List<AssetInfo> group, Object reason) {
      for (final a in group) {
        failures[a.id] = reason.toString();
      }
    }

    for (final MapEntry(:key, :value) in byDive.entries) {
      try {
        final dive = await diveRepository.getDiveById(key);
        if (dive == null) {
          failGroup(value, 'dive $key no longer exists');
          continue;
        }
        final result = await service.importPhotosForDive(
          selectedAssets: value,
          dive: dive,
        );
        linked += result.imported.length;
        failures.addAll(result.failures);
      } catch (e) {
        failGroup(value, e);
      }
    }
    for (final MapEntry(:key, :value) in bySite.entries) {
      try {
        final result = await service.importPhotosForSite(
          selectedAssets: value,
          siteId: key,
        );
        linked += result.imported.length;
        failures.addAll(result.failures);
      } catch (e) {
        failGroup(value, e);
      }
    }
    return ImportReviewResult(
      linked: linked,
      skipped: assets.length - targets.length,
      failures: failures,
    );
  }

  Future<void> _launch(BuildContext context, WidgetRef ref) async {
    final assets = await (launchOverride?.call(context) ?? _pick(context));
    if (assets.isEmpty || !context.mounted) return;
    final candidates = [
      for (final a in assets)
        ImportCandidate(
          key: a.id,
          title: a.filename ?? a.id,
          // The same value the import persists as takenAt, so the match
          // shown here is the match the row would get.
          takenAt: TripMediaScanner.toWallClockUtc(a.createDateTime),
          preview: AssetImportPreview(a.id),
        ),
    ];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaImportReviewPage(
          candidates: candidates,
          onConfirm: (targets) => importResolved(
            service: ref.read(mediaImportServiceProvider),
            diveRepository: ref.read(diveRepositoryProvider),
            assets: assets,
            targets: targets,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 48),
            const SizedBox(height: 12),
            Text(context.l10n.media_import_intro, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(context.l10n.media_import_launch),
              onPressed: () => _launch(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
