import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_card.dart';

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

  const FileReviewPane({super.key, required this.state, this.assignableDiveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // TODO(media): l10n
    final summary =
        '${state.files.length} photos → '
        '${state.match.diveCount} dive${state.match.diveCount == 1 ? '' : 's'}, '
        '${state.match.unmatched.length} unmatched';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(summary, style: theme.textTheme.titleMedium),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final entry in state.match.matched.entries)
                ExpansionTile(
                  title: Text('Dive ${entry.key}'),
                  subtitle: Text('${entry.value.length} photos'),
                  initiallyExpanded: true,
                  children: [
                    for (final f in entry.value)
                      FileReviewCard(
                        file: f,
                        targetDiveId: entry.key,
                        assignableDiveId: assignableDiveId,
                      ),
                  ],
                ),
              if (state.match.unmatched.isNotEmpty)
                ExpansionTile(
                  title: const Text('Unmatched'),
                  subtitle: Text('${state.match.unmatched.length} photos'),
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
                            'Add all ${state.match.unmatched.length} '
                            'to this dive',
                          ),
                        ),
                  children: [
                    for (final f in state.match.unmatched)
                      FileReviewCard(
                        file: f,
                        targetDiveId: null,
                        assignableDiveId: assignableDiveId,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
