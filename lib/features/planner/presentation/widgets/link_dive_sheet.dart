import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How the dive pickers name [dive]: its name, else its number, else its date,
/// over the date, depth and runtime.
({String title, String subtitle}) diveRowLabels(
  Dive dive,
  UnitFormatter units,
) {
  final date = units.formatDate(dive.entryTime ?? dive.dateTime);
  return (
    title: (dive.name?.isNotEmpty ?? false)
        ? dive.name!
        : (dive.diveNumber != null ? '#${dive.diveNumber}' : date),
    subtitle: [
      date,
      if (dive.maxDepth != null) units.formatDepth(dive.maxDepth!),
      if (dive.effectiveRuntime != null) '${dive.effectiveRuntime!.inMinutes}′',
    ].join(' · '),
  );
}

/// Picks a logged dive for a saved plan, returning its id, or null if the
/// sheet was dismissed.
Future<String?> showLinkDiveSheet(
  BuildContext context, {
  DateTime? planDay,
  String? currentDiveId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) =>
        LinkDiveSheet(planDay: planDay, currentDiveId: currentDiveId),
  );
}

/// Logged dives, newest first, with the dives of [planDay] leading when the
/// plan has a date. Dives still waiting to happen are left out: a plan links
/// to a dive that was dived.
class LinkDiveSheet extends ConsumerWidget {
  const LinkDiveSheet({super.key, this.planDay, this.currentDiveId});

  /// The plan's own date, if it has one.
  final DateTime? planDay;

  /// The dive the plan is linked to now.
  final String? currentDiveId;

  DateTime _start(Dive dive) => dive.entryTime ?? dive.dateTime;

  bool _onPlanDay(Dive dive) {
    final day = planDay;
    if (day == null) return false;
    final start = _start(dive);
    return start.year == day.year &&
        start.month == day.month &&
        start.day == day.day;
  }

  List<Dive> _ordered(List<Dive> dives) {
    final logged = [
      for (final dive in dives)
        if (!dive.isPlanned) dive,
    ];
    logged.sort((a, b) {
      final aFirst = _onPlanDay(a);
      if (aFirst != _onPlanDay(b)) return aFirst ? -1 : 1;
      return _start(b).compareTo(_start(a));
    });
    return logged;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divesAsync = ref.watch(divesProvider);
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);

    // Render stale data during a reload rather than flashing a spinner.
    final loaded = divesAsync.valueOrNull;
    final dives = loaded == null ? null : _ordered(loaded);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.plannerCanvas_link_action,
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
              // Not shrink-wrapped: a logbook runs to thousands of dives, and
              // an old plan's dive has to stay reachable.
              Flexible(
                child: ListView.builder(
                  itemCount: dives.length,
                  itemBuilder: (context, i) =>
                      _diveTile(context, dives[i], units),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _diveTile(BuildContext context, Dive dive, UnitFormatter units) {
    final labels = diveRowLabels(dive, units);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(labels.title),
      subtitle: Text(labels.subtitle),
      trailing: dive.id == currentDiveId ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(dive.id),
    );
  }
}
