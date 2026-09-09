import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/overdue_service_entry.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One checklist row in the session runner: large tap target, state icon,
/// secondary menu for Skip/Flag/note. Dimmed and inert when the engine says
/// the item is not actionable (strict order, locked session, resolved).
class SessionItemTile extends ConsumerWidget {
  final PreDiveSession session;
  final List<PreDiveSessionItem> sortedItems;
  final PreDiveSessionItem item;
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onFlag;
  final VoidCallback onEditValue;
  final VoidCallback onAddNote;
  final VoidCallback onReset;

  /// The source item's current value, when this is a cell linearity item
  /// whose frozen air reading no longer matches it. Null means there is no
  /// discrepancy to report.
  ///
  /// Supplied by the page, because a tile cannot see its siblings. The
  /// frozen figure is never recomputed from this; a resolved item is an
  /// audit record and only the diver may redo it.
  final double? staleSourceValue;

  const SessionItemTile({
    super.key,
    required this.session,
    required this.sortedItems,
    required this.item,
    required this.onDone,
    required this.onSkip,
    required this.onFlag,
    required this.onEditValue,
    required this.onAddNote,
    required this.onReset,
    this.staleSourceValue,
  });

  /// The item's overdue-service entries to display, paired with the instant
  /// they should be read against: live-computed from its linked equipment
  /// while pending (so the warning tracks the current service state up to the
  /// moment of decision), or the frozen snapshot once resolved (so a later
  /// service log entry cannot silently rewrite what the diver saw when they
  /// made the call).
  ///
  /// The instant matters because [formatServiceTriggerText] decides between
  /// "Due {date}" and "Overdue since {date}" by comparing it against the
  /// entry's dueDate. An entry frozen while overdue on its dives or hours
  /// trigger can still carry a dueDate in the future, so reading a resolved
  /// item against the wall clock would silently reword the snapshot once that
  /// date passes. Resolved items therefore read against completedAt, the same
  /// instant the repository stamped when it froze the snapshot.
  (List<OverdueServiceEntry>, DateTime) _overdueEntries(WidgetRef ref) {
    if (item.state != PreDiveItemState.pending) {
      return (
        item.overdueServices ?? const [],
        item.completedAt ?? DateTime.now(),
      );
    }
    final equipmentId = item.equipmentId;
    if (equipmentId == null) return (const [], DateTime.now());
    final statuses =
        ref.watch(serviceClockStatusesProvider(equipmentId)).value ?? const [];
    return (
      [
        for (final status in statuses)
          if (status.severity == ServiceClockSeverity.overdue)
            OverdueServiceEntry.fromStatus(status),
      ],
      DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final (overdueEntries, overdueAsOf) = _overdueEntries(ref);
    final actionable = ChecklistSessionEngine.isItemActionable(
      session,
      sortedItems,
      item,
    );
    // The overflow menu must respect strict-order gating too: a pending item
    // that is not yet actionable cannot be skipped/flagged/noted out of order.
    // Resolved items keep their menu so Reset/Note stay reachable.
    final showMenu = !session.isLocked && (actionable || item.isResolved);

    final (stateIcon, stateColor) = switch (item.state) {
      PreDiveItemState.pending => (
        Icons.radio_button_unchecked,
        theme.colorScheme.onSurfaceVariant,
      ),
      PreDiveItemState.done => (Icons.check_circle, theme.colorScheme.primary),
      PreDiveItemState.skipped => (
        Icons.remove_circle_outline,
        theme.colorScheme.onSurfaceVariant,
      ),
      PreDiveItemState.flagged => (Icons.flag, theme.colorScheme.error),
    };

    // A cell linearity item records a number just as a value item does, so
    // it renders the same primary line and takes the same tap route.
    final isValueLike =
        item.itemType == PreDiveItemType.value || item.isCellLinearity;

    final valueLine = isValueLike
        ? [
            if (item.valueLabel != null) item.valueLabel!,
            if (item.valueNumber != null)
              '${formatDecimalForDisplay(item.valueNumber!)}'
                  '${item.valueUnit == null ? '' : ' ${item.valueUnit}'}',
          ].join(': ')
        : null;

    // The full working, so the linearity result is readable from the list
    // without opening the item. Rounding is applied here and nowhere else:
    // the percentage itself is derived from the exact expected value.
    final percent = item.linearityPercent;
    final expected = item.expectedO2Millivolts;
    final air = item.sourceValueNumber;
    // Both numbers are localised so the diver reads their own decimal
    // separator (#1684 did the value line above; this is the same bug on the
    // same tile, tracked as #1682), but through different helpers, because
    // they pin their precision differently.
    //
    // The air reading keeps the precision the diver entered, because it is
    // their input and rounding it would show a figure they never typed, so it
    // takes formatDecimalForDisplay. The expected value is derived and shown
    // to a fixed 1 dp, which is formatFixedForDisplay's whole purpose.
    final linearityLine = (percent != null && expected != null && air != null)
        ? l10n.preDive_runner_linearityLine(
            formatDecimalForDisplay(air),
            formatFixedForDisplay(expected, 1),
            percent.round().toString(),
          )
        : null;

    // The advisory warning has to mark the number that actually breached its
    // threshold. On a value item that is the recorded number itself, but on a
    // linearity item the threshold is a percentage, so the amber belongs on
    // the working line rather than on the O2 millivolts, which no threshold
    // applies to.
    final primaryOutOfRange = item.valueOutOfRange && !item.isCellLinearity;

    final subtitleChildren = <Widget>[
      if (valueLine != null && valueLine.isNotEmpty)
        Text(
          valueLine,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: primaryOutOfRange
                ? Colors.amber.shade700
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: primaryOutOfRange ? FontWeight.bold : null,
          ),
        ),
      if (linearityLine != null)
        Text(
          linearityLine,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: item.valueOutOfRange
                ? Colors.amber.shade700
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: item.valueOutOfRange ? FontWeight.bold : null,
          ),
        ),
      if (staleSourceValue != null)
        Text(
          l10n.preDive_runner_sourceChanged,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      if (item.note.isNotEmpty)
        Text(
          item.note,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
      if (item.notes.isNotEmpty)
        Text(item.notes, style: theme.textTheme.bodySmall),
      if (overdueEntries.isNotEmpty) ...[
        Text(
          l10n.preDive_runner_serviceOverdue,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        for (final entry in overdueEntries)
          Text(
            '${entry.kindName}: '
            '${formatServiceTriggerText(context, units: UnitFormatter(ref.watch(settingsProvider)), now: overdueAsOf, dueDate: entry.dueDate, divesSinceAnchor: entry.divesSinceAnchor, divesRemaining: entry.divesRemaining, hoursSinceAnchor: entry.hoursSinceAnchor, hoursRemaining: entry.hoursRemaining)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
      // Completion time belongs in the subtitle, not in trailing: a ListTile
      // measures its trailing widget against the full tile width, so anything
      // text-bearing there eats into the item title (issue #935).
      if (item.completedAt != null)
        Text(
          UnitFormatter(
            ref.watch(settingsProvider),
          ).formatTime(item.completedAt),
          style: theme.textTheme.bodySmall,
        ),
    ];

    final dimmed = !actionable && item.state == PreDiveItemState.pending;

    final tile = ListTile(
      minVerticalPadding: 12,
      leading: Icon(stateIcon, color: stateColor, size: 28),
      title: Text(item.title, style: theme.textTheme.bodyLarge),
      subtitle: subtitleChildren.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: subtitleChildren,
            ),
      trailing: !showMenu
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'skip':
                    onSkip();
                  case 'flag':
                    onFlag();
                  case 'note':
                    onAddNote();
                  case 'reset':
                    onReset();
                }
              },
              itemBuilder: (context) => [
                if (!item.isRequired && !item.isResolved)
                  PopupMenuItem(
                    value: 'skip',
                    child: Text(l10n.preDive_runner_skip),
                  ),
                if (!item.isResolved)
                  PopupMenuItem(
                    value: 'flag',
                    child: Text(l10n.preDive_runner_flag),
                  ),
                PopupMenuItem(
                  value: 'note',
                  child: Text(l10n.preDive_runner_addNote),
                ),
                if (item.isResolved)
                  PopupMenuItem(
                    value: 'reset',
                    child: Text(l10n.preDive_runner_undo),
                  ),
              ],
            ),
      enabled: actionable,
      onTap: actionable ? (isValueLike ? onEditValue : onDone) : null,
    );

    return dimmed ? Opacity(opacity: 0.4, child: tile) : tile;
  }
}
