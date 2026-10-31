import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_surface_interval_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What sets the selected dive apart from the others in its series (issue
/// #3565): its name and the surface interval before it.
///
/// On a first dive that follows no logged dive there is no interval to set,
/// so the interval is greyed out rather than hidden: the card keeps its
/// height and nothing below it moves when the diver changes dives.
class PlanDiveDetailsCard extends ConsumerStatefulWidget {
  const PlanDiveDetailsCard({super.key});

  /// Longest dive name, so a chip in the navigator stays a chip.
  static const maxNameLength = 40;

  @override
  ConsumerState<PlanDiveDetailsCard> createState() =>
      _PlanDiveDetailsCardState();
}

class _PlanDiveDetailsCardState extends ConsumerState<PlanDiveDetailsCard> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text =
        ref.read(planSeriesNotifierProvider).selected.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show the selected dive's own name, whatever changed it. Compared
    // trimmed, so the space at the end of a name being typed stays put.
    ref.listen(
      planSeriesNotifierProvider.select(
        (s) => (s.selected.state.id, s.selected.name),
      ),
      (_, _) {
        final name = ref.read(planSeriesNotifierProvider).selected.name ?? '';
        if (_nameController.text.trim() != name) _nameController.text = name;
      },
    );

    final index = ref.watch(
      planSeriesNotifierProvider.select((s) => s.selectedIndex),
    );
    final followsDive = ref.watch(
      divePlanNotifierProvider.select((s) => s.sourceDiveId != null),
    );
    final hasInterval = index > 0 || followsDive;

    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.plannerSeries_diveDetails,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('diveNameField'),
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  PlanDiveDetailsCard.maxNameLength,
                ),
              ],
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                labelText: l10n.plannerSeries_diveName,
                // What the dive's chip shows while it has no name.
                hintText: seriesDiveLetter(index),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              onChanged: ref
                  .read(planSeriesNotifierProvider.notifier)
                  .renameSelected,
            ),
            const SizedBox(height: 16),
            PlanSurfaceIntervalField(enabled: hasInterval),
          ],
        ),
      ),
    );
  }
}
