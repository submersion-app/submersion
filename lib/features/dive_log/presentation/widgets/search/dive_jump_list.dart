import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The newest dives matching the typed query over the WHOLE log, ignoring
/// the list's other filters (#2773, the Search overlay's old job).
class DiveJumpList extends ConsumerStatefulWidget {
  const DiveJumpList({super.key, required this.query, required this.onOpen});

  final QueryNode query;
  final ValueChanged<DiveSummary> onOpen;

  @override
  ConsumerState<DiveJumpList> createState() => _DiveJumpListState();
}

class _DiveJumpListState extends ConsumerState<DiveJumpList> {
  /// The last rows a query answered, kept while the next one loads so the
  /// list does not collapse and reappear as the diver types.
  List<DiveSummary> _shown = const [];

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(diveJumpResultsProvider(widget.query));
    // A failed query hides the rows; only a load in progress keeps the
    // previous query's rows.
    if (result.hasError) {
      _shown = const [];
    } else if (result.value case final latest?) {
      _shown = latest;
    }
    final dives = _shown;
    if (dives.isEmpty) return const SizedBox.shrink();
    final units = UnitFormatter(ref.watch(settingsProvider));
    final theme = Theme.of(context);
    // Inside the field's tap region: on desktop a mouse press anywhere
    // else unfocuses the field, which would hide these rows before the
    // click on one of them landed.
    return TextFieldTapRegion(
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(
                context.l10n.diveLog_search_jumpTitle,
                style: theme.textTheme.labelMedium,
              ),
            ),
            for (final d in dives)
              ListTile(
                key: ValueKey('dive-jump-${d.id}'),
                dense: true,
                title: Text(
                  d.siteName ??
                      d.name ??
                      units.formatMonthDayWithYear(d.dateTime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${units.formatMonthDayWithYear(d.dateTime)} · '
                  '${units.formatDepth(d.maxDepth)}',
                ),
                onTap: () => widget.onOpen(d),
              ),
          ],
        ),
      ),
    );
  }
}
