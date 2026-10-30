import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Present the follow-a-dive picker as a modal bottom sheet.
Future<void> showFollowDiveSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const FollowDiveSheet(),
  );
}

/// Picks any logged dive for the plan to follow (issue #3565): the series
/// starts from it, with its end tissues, CNS, OTU and tank pressures, and
/// shows it and the dives before it in the series bar.
class FollowDiveSheet extends ConsumerStatefulWidget {
  const FollowDiveSheet({super.key});

  @override
  ConsumerState<FollowDiveSheet> createState() => _FollowDiveSheetState();
}

class _FollowDiveSheetState extends ConsumerState<FollowDiveSheet> {
  String? _loadingDiveId;

  @override
  Widget build(BuildContext context) {
    final divesAsync = ref.watch(divesProvider);
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));

    // Render stale data during a reload rather than flashing a spinner.
    // Any logged dive can be followed; judging whether the plan is
    // realistic is left to the diver.
    final dives = divesAsync.valueOrNull
        ?.where((dive) => !dive.isPlanned)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.plannerCanvas_follow_title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (dives == null && divesAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (dives == null || dives.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  context.l10n.plannerCanvas_follow_empty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: dives.length,
                  itemBuilder: (context, i) => _diveTile(dives[i], units),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _diveTile(Dive dive, UnitFormatter units) {
    final date = units.formatDate(dive.entryTime ?? dive.dateTime);
    final subtitleParts = <String>[
      date,
      if (dive.maxDepth != null) units.formatDepth(dive.maxDepth!),
      if (dive.effectiveRuntime != null) '${dive.effectiveRuntime!.inMinutes}′',
    ];
    final title = (dive.name?.isNotEmpty ?? false)
        ? dive.name!
        : (dive.diveNumber != null ? '#${dive.diveNumber}' : date);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: _loadingDiveId == dive.id
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      enabled: _loadingDiveId == null,
      onTap: () =>
          logFailure(_follow(dive), _FollowDiveSheetState, 'follow a dive'),
    );
  }

  Future<void> _follow(Dive dive) async {
    setState(() => _loadingDiveId = dive.id);
    try {
      final follow = await followLoggedDive(ref, dive.id);
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      if (follow != null && follow.endTissues == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.plannerCanvas_follow_noTissues)),
        );
      }
      Navigator.of(context).pop();
    } finally {
      // The sheet is still open only when the load failed.
      if (mounted) setState(() => _loadingDiveId = null);
    }
  }
}
