import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/capture_time_offset_bar.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Review pane shown in the Files tab once one or more files have been
/// staged via the picker.
///
/// Phase 2 / Task 11: renders a summary header
/// ("N photos -> M dives, K unmatched") followed by an [ExpansionTile] per
/// matched-dive group and an "Unmatched" group at the bottom (only when
/// non-empty). Each group's children are [FileReviewCard]s.
///
/// Holds no state of its own: the current [FilesTabState] is passed in by the
/// parent, and the pane's own actions -- the Unmatched group's bulk
/// "add all to this dive", plus each [FileReviewCard]'s assign and remove --
/// are dispatched to [filesTabNotifierProvider], which owns every mutation.
/// It is a [ConsumerWidget] rather than a [StatelessWidget] only to reach
/// that notifier.
class FileReviewPane extends ConsumerWidget {
  final FilesTabState state;

  /// The dive files may be manually assigned to, when the picker was opened
  /// from one. Drives the Unmatched group's bulk action and the per-card
  /// assign affordance; null hides both.
  final String? assignableDiveId;

  /// Renders one flat list of every staged file instead of the matched /
  /// unmatched dive grouping.
  ///
  /// Used when the session attaches to a dive site: matched-vs-unmatched is
  /// a statement about dives, so on a site it is both meaningless and
  /// alarming: the user sees "0 dives, N unmatched" and reasonably concludes
  /// the app rejected their photos (issue #1098).
  final bool flat;

  const FileReviewPane({
    super.key,
    required this.state,
    this.assignableDiveId,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (flat) return _buildFlat(context, theme);

    final summary = context.l10n.media_photoPicker_files_summary(
      state.files.length,
      state.match.diveCount,
      state.match.unmatched.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(summary, style: theme.textTheme.titleMedium),
        ),
        // Shown whenever files are staged and auto-match is on, including when
        // everything already matched: gating on unmatched.isNotEmpty would make
        // the control disappear the instant a shift worked, stranding the user
        // with a correction they could no longer see or undo.
        if (state.files.isNotEmpty && state.autoMatchByDate)
          CaptureTimeOffsetBar(state: state),
        Expanded(
          child: ListView(
            children: [
              for (final entry in state.match.matched.entries)
                ExpansionTile(
                  title: Text(
                    context.l10n.media_photoPicker_files_diveGroupTitle(
                      entry.key,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.media_photoPicker_files_groupCount(
                      entry.value.length,
                    ),
                  ),
                  initiallyExpanded: true,
                  children: [
                    for (final f in entry.value)
                      FileReviewCard(
                        file: f,
                        targetDiveId: entry.key,
                        assignableDiveId: assignableDiveId,
                        captureTimeOffset: state.captureTimeOffset,
                      ),
                  ],
                ),
              if (state.match.unmatched.isNotEmpty)
                ExpansionTile(
                  title: Text(
                    context.l10n.media_photoPicker_files_unmatchedGroupTitle,
                  ),
                  subtitle: Text(
                    context.l10n.media_photoPicker_files_groupCount(
                      state.match.unmatched.length,
                    ),
                  ),
                  initiallyExpanded: true,
                  // Without this the only thing a user could do with a photo
                  // the matcher rejected was remove it -- commit() never sees
                  // the unmatched bucket.
                  trailing: assignableDiveId == null
                      ? null
                      : TextButton(
                          onPressed: () => ref
                              .read(filesTabNotifierProvider.notifier)
                              .assignAllUnmatched(assignableDiveId!),
                          child: Text(
                            context.l10n.media_photoPicker_files_addAllToDive(
                              state.match.unmatched.length,
                            ),
                          ),
                        ),
                  children: [
                    for (final f in state.match.unmatched)
                      FileReviewCard(
                        file: f,
                        targetDiveId: null,
                        assignableDiveId: assignableDiveId,
                        diagnostic: state.match.diagnostics[f.sourcePath],
                        captureTimeOffset: state.captureTimeOffset,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Flat variant: a count and one card per staged file, with no dive
  /// grouping and no assign affordances (there is no dive to assign to).
  Widget _buildFlat(BuildContext context, ThemeData theme) {
    final count = state.files.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          // "item", not "photo": the Files tab picks with FileType.media and
          // the folder scan admits .mp4/.mov/.m4v, so a staged set can be all
          // video. Matches the commit button's wording.
          child: Text(
            context.l10n.media_photoPicker_files_itemCount(count),
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final f in state.files)
                FileReviewCard(
                  file: f,
                  targetDiveId: null,
                  captureTimeOffset: state.captureTimeOffset,
                  // A site owns every staged file, so there is no dive to
                  // route one to. Without this the card falls through to its
                  // "choose a dive" branch, contradicting this method's
                  // contract below.
                  allowDiveAssignment: false,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
