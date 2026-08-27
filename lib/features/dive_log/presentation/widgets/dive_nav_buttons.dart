import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// Previous / next controls for stepping to the dive adjacent to [diveId] in
/// the current list (filter + sort) order. Each button is disabled when there
/// is no neighbor in that direction (list ends, or dive not in the filter).
class DiveNavButtons extends ConsumerWidget {
  const DiveNavButtons({
    super.key,
    required this.diveId,
    required this.onNavigate,
  });

  final String diveId;
  final void Function(String neighborId) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neighbors = ref.watch(diveNeighborsProvider(diveId));
    final previousId = neighbors.previousId;
    final nextId = neighbors.nextId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: context.l10n.diveLog_detail_tooltip_previousDive,
          onPressed: previousId == null ? null : () => onNavigate(previousId),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: context.l10n.diveLog_detail_tooltip_nextDive,
          onPressed: nextId == null ? null : () => onNavigate(nextId),
        ),
      ],
    );
  }
}
