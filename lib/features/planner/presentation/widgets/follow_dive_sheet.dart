import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
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

/// Picks a logged dive for the plan to follow: seeds the plan's start
/// tissues from the dive's end-of-dive compartment state (same analysis
/// the dive details page runs) and sets the surface interval.
class FollowDiveSheet extends ConsumerStatefulWidget {
  const FollowDiveSheet({super.key, this.maxDives = 30});

  /// How many recent dives to offer.
  final int maxDives;

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
    final dives = divesAsync.valueOrNull?.take(widget.maxDives).toList();

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
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(dive.entryTime ?? dive.dateTime);
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
      onTap: () => _follow(dive),
    );
  }

  Future<void> _follow(Dive dive) async {
    setState(() => _loadingDiveId = dive.id);
    final analysis = await ref.read(profileAnalysisProvider(dive.id).future);
    if (!mounted) return;

    final compartments = (analysis != null && analysis.decoStatuses.isNotEmpty)
        ? analysis.decoStatuses.last.compartments
        : null;

    final end = (dive.entryTime ?? dive.dateTime).add(
      dive.effectiveRuntime ?? Duration.zero,
    );
    var interval = DateTime.now().difference(end);
    if (interval < const Duration(minutes: 10)) {
      interval = const Duration(hours: 1);
    }

    ref
        .read(divePlanNotifierProvider.notifier)
        .setFollowedDive(
          diveId: dive.id,
          compartments: compartments,
          surfaceInterval: interval,
        );

    final messenger = ScaffoldMessenger.of(context);
    if (compartments == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.plannerCanvas_follow_noTissues)),
      );
    }
    Navigator.of(context).pop();
  }
}
