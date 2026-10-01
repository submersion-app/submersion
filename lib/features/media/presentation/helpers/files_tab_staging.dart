import 'dart:io';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// Reads each file's capture metadata and stages the readable ones in the
/// picker's Files tab for review, the way picking them there does.
///
/// Files whose metadata cannot be read are left out. Every staged file is
/// then placed according to [target]:
///
/// - A [SiteAttachTarget] owns every file, so nothing is matched or grouped.
///   Dive matching against a site is not merely useless but wrong: a site has
///   no time window, so the matcher would route photos to dives the user
///   never mentioned (issue #1098).
/// - With auto-match turned off, a [DiveAttachTarget] takes every file: the
///   user asked for exactly these files on exactly this dive. With no target
///   they wait unmatched for a manual assignment.
/// - Otherwise [DivePhotoMatcher] assigns each file to the dive whose window
///   holds its capture time.
///
/// Takes the [ProviderContainer] rather than a widget's ref because the
/// metadata reads outlive a frame: the picker that started them may close
/// first, and the container outlives it.
Future<void> stageFilesForReview(
  ProviderContainer container,
  List<String> paths, {
  MediaAttachTarget? target,
}) async {
  final notifier = container.read(filesTabNotifierProvider.notifier);
  final extractor = container.read(exifExtractorProvider);

  notifier.setExtractionProgress(done: 0, total: paths.length);

  final extracted = <ExtractedFile>[];
  for (var i = 0; i < paths.length; i++) {
    final file = File(paths[i]);
    final meta = await extractor.extract(file);
    if (meta != null) {
      extracted.add(
        ExtractedFile(sourcePath: paths[i], file: file, metadata: meta),
      );
    }
    // Advance progress unconditionally so isExtracting flips false even when
    // files are skipped. `done` means "files processed", not "files read".
    notifier.setExtractionProgress(done: i + 1, total: paths.length);
  }

  if (target is SiteAttachTarget) {
    // The empty selection also keeps any dive grouping from an earlier
    // session on this (non-autoDispose) notifier out of the review pane.
    notifier.setFiles(extracted, match: MatchedSelection.empty());
    return;
  }

  final state = container.read(filesTabNotifierProvider);
  if (!state.autoMatchByDate) {
    notifier.setFiles(
      extracted,
      match: switch (target) {
        DiveAttachTarget(:final diveId) => MatchedSelection(
          matched: {diveId: extracted},
          unmatched: const [],
        ),
        _ => MatchedSelection(matched: const {}, unmatched: extracted),
      },
    );
    return;
  }

  final bounds = await container.read(diveBoundsProvider.future);
  final result = const DivePhotoMatcher().match(
    files: extracted,
    dives: bounds,
    offset: state.captureTimeOffset,
  );
  notifier.setFiles(extracted, match: result);
}
