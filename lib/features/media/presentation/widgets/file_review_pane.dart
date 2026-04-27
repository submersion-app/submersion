import 'package:flutter/material.dart';

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
/// Stateless because all mutation flows through
/// [filesTabNotifierProvider]; the pane just renders the current
/// [FilesTabState] passed in by the parent.
class FileReviewPane extends StatelessWidget {
  final FilesTabState state;
  const FileReviewPane({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      FileReviewCard(file: f, targetDiveId: entry.key),
                  ],
                ),
              if (state.match.unmatched.isNotEmpty)
                ExpansionTile(
                  title: const Text('Unmatched'),
                  subtitle: Text('${state.match.unmatched.length} photos'),
                  initiallyExpanded: true,
                  children: [
                    for (final f in state.match.unmatched)
                      FileReviewCard(file: f, targetDiveId: null),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
