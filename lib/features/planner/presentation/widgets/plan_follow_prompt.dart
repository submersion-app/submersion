import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/services/logged_dive_chain.dart';
import 'package:submersion/features/planner/domain/utils/hours_minutes.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Offers to follow the most recent logged dive with one tap, when it ended
/// less than 48 hours ago (issue #3565). Hidden once the plan follows a
/// dive, for a replan of a logged dive, and once dismissed.
class PlanFollowPrompt extends ConsumerStatefulWidget {
  const PlanFollowPrompt({super.key});

  @override
  ConsumerState<PlanFollowPrompt> createState() => _PlanFollowPromptState();
}

class _PlanFollowPromptState extends ConsumerState<PlanFollowPrompt> {
  bool _following = false;

  Future<void> _follow(Dive dive) async {
    setState(() => _following = true);
    final messenger = ScaffoldMessenger.of(context);
    final noTissues = context.l10n.plannerCanvas_follow_noTissues;
    try {
      final follow = await followLoggedDive(ref, dive.id);
      if (!mounted) return;
      if (follow != null && follow.endTissues == null) {
        messenger.showSnackBar(SnackBar(content: Text(noTissues)));
      }
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final follows = ref.watch(
      planSeriesNotifierProvider.select((s) => s.follow != null),
    );
    final allowed = ref.watch(followAllowedProvider);
    final dive = ref.watch(followSuggestionProvider).valueOrNull;
    final dismissed = ref.watch(dismissedFollowSuggestionsProvider);
    if (follows || !allowed || dive == null || dismissed.contains(dive.id)) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    // Its name, else its number, as in the series bar.
    final number = dive.diveNumber;
    final label = (dive.name?.isNotEmpty ?? false)
        ? dive.name!
        : number != null
        ? l10n.plannerSeries_loggedDiveNumber(number)
        : units.formatDate(dive.effectiveEntryTime);
    final ago = formatHoursMinutes(
      clock.now().difference(diveEndInstant(dive)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.history,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.plannerSeries_followPrompt(label, ago),
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _following
                ? null
                : () => logFailure(
                    _follow(dive),
                    _PlanFollowPromptState,
                    'follow a logged dive',
                  ),
            child: Text(l10n.plannerSeries_follow),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.common_action_dismiss,
            onPressed: () => ref
                .read(dismissedFollowSuggestionsProvider.notifier)
                .update((ids) => {...ids, dive.id}),
          ),
        ],
      ),
    );
  }
}
