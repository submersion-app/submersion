import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/insights/presentation/providers/dive_deco_status_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A loading state that says how far the dive analysis has got while a
/// `deco` filter waits for it (#4461), and a plain spinner otherwise. A
/// library nothing has analyzed takes minutes on a phone (#3807), which a
/// bare spinner makes look hung.
class DecoAnalysisProgress extends ConsumerWidget {
  const DecoAnalysisProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only a list whose filter reads the verdicts waits for the analysis:
    // a pass run for another reader (an Insights deco filter) is not what
    // this list is loading.
    final waits = ref.watch(
      diveFilterProvider.select(
        (f) => diveFilterTablesTouched(f).contains(kDiveDecoStatusTable),
      ),
    );
    final progress = waits ? ref.watch(diveDecoStatusProgressProvider) : null;
    if (progress == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoAnalysisProgressBar(
            analyzed: progress.analyzed,
            total: progress.total,
          ),
        ),
      ),
    );
  }
}

/// How far a deco analysis pass has got: a bar and "[analyzed] of [total]",
/// shared by the dive list's wait and the Insights deco card's.
class DecoAnalysisProgressBar extends StatelessWidget {
  const DecoAnalysisProgressBar({
    super.key,
    required this.analyzed,
    required this.total,
  });

  final int analyzed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: total == 0 ? null : analyzed / total),
        const SizedBox(height: 8),
        Text(
          context.l10n.insights_profile_deco_analyzing(analyzed, total),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
