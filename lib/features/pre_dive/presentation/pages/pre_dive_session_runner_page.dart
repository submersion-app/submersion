import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/overdue_service_entry.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/cell_linearity.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/session_item_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Runs (or, once locked, displays) a pre-dive checklist session. Every tap
/// writes through to the database immediately: crash-safe resume for free,
/// and per-item completedAt stamped at tap time is honest audit evidence.
class PreDiveSessionRunnerPage extends ConsumerWidget {
  final String sessionId;

  const PreDiveSessionRunnerPage({super.key, required this.sessionId});

  Future<void> _setState(
    WidgetRef ref,
    PreDiveSessionItem item,
    PreDiveItemState state, {
    double? valueNumber,
    String? note,
    List<OverdueServiceEntry>? overdueServices,
    bool freezeOverdueServices = false,
    double? sourceValueNumber,
  }) {
    return ref
        .read(preDiveSessionRepositoryProvider)
        .updateItemState(
          sessionId: sessionId,
          itemId: item.id,
          state: state,
          valueNumber: valueNumber,
          note: note,
          // Only a resolving call overwrites the snapshot, and it may
          // legitimately write null (an item with no linked equipment has
          // nothing to freeze). A plain `??` fallback could not express that,
          // so the intent is carried by the flag rather than by the value.
          // Every other call passes the item's existing snapshot straight
          // through: a transition to pending clears it repository-side
          // regardless, and a note or value edit that leaves the item
          // resolved must leave the snapshot untouched.
          overdueServices: freezeOverdueServices
              ? overdueServices
              : item.overdueServices,
          // Same rule as overdueServices: a call that supplies no fresh
          // reading (a note edit, say) must leave the frozen one alone.
          sourceValueNumber: sourceValueNumber ?? item.sourceValueNumber,
        );
  }

  /// Resolves [item] to [state], freezing its live overdue-service list at
  /// this exact moment -- the informative red warning becomes a snapshot the
  /// instant the diver makes a decision, rather than staying tied to
  /// whatever the equipment's service clocks say later.
  Future<void> _resolve(
    WidgetRef ref,
    PreDiveSessionItem item,
    PreDiveItemState state, {
    double? valueNumber,
    String? note,
    double? sourceValueNumber,
  }) async {
    final overdueServices = await _overdueEntriesFor(ref, item);
    await _setState(
      ref,
      item,
      state,
      valueNumber: valueNumber,
      note: note,
      overdueServices: overdueServices,
      freezeOverdueServices: true,
      sourceValueNumber: sourceValueNumber,
    );
  }

  /// The item's currently overdue service clocks, or null when the item has
  /// no linked equipment. Null and empty are deliberately different: null
  /// means there was nothing to check, while an empty list means the linked
  /// equipment was checked and nothing was overdue. Collapsing the two would
  /// store a snapshot for every unlinked item and lose that distinction.
  Future<List<OverdueServiceEntry>?> _overdueEntriesFor(
    WidgetRef ref,
    PreDiveSessionItem item,
  ) async {
    final equipmentId = item.equipmentId;
    if (equipmentId == null) return null;
    final statuses = await ref.read(
      serviceClockStatusesProvider(equipmentId).future,
    );
    return [
      for (final status in statuses)
        if (status.severity == ServiceClockSeverity.overdue)
          OverdueServiceEntry.fromStatus(status),
    ];
  }

  Future<void> _editValue(
    BuildContext context,
    WidgetRef ref,
    List<PreDiveSessionItem> items,
    PreDiveSessionItem item,
  ) async {
    // Read the source at the moment the dialog opens and freeze whatever it
    // said when the diver confirms. A linearity item that is unlinked, or
    // whose source is still unanswered, records its own reading regardless.
    final sourceValue = item.isCellLinearity
        ? _currentSourceValue(items, item)
        : null;
    final result = await showDialog<({double? value, String? note})>(
      context: context,
      builder: (context) =>
          _ValueEntryDialog(item: item, sourceValue: sourceValue),
    );
    if (result == null) return;
    await _resolve(
      ref,
      item,
      PreDiveItemState.done,
      valueNumber: result.value,
      note: result.note,
      sourceValueNumber: sourceValue,
    );
  }

  /// The current value of [item]'s source row, or null when it is unlinked,
  /// missing, or not yet answered.
  static double? _currentSourceValue(
    List<PreDiveSessionItem> items,
    PreDiveSessionItem item,
  ) {
    final sourceId = item.sourceItemId;
    if (sourceId == null) return null;
    for (final candidate in items) {
      if (candidate.id == sourceId) return candidate.valueNumber;
    }
    return null;
  }

  /// The source item's current value when it no longer matches the reading
  /// frozen onto [item], or null when there is nothing to flag.
  ///
  /// Only a resolved item can be stale: a pending one has frozen nothing
  /// yet, so there is no discrepancy to report.
  static double? _staleSourceValue(
    List<PreDiveSessionItem> items,
    PreDiveSessionItem item,
  ) {
    if (!item.isCellLinearity) return null;
    final frozen = item.sourceValueNumber;
    if (frozen == null) return null;
    final current = _currentSourceValue(items, item);
    if (current == null || current == frozen) return null;
    return current;
  }

  Future<void> _addNote(
    BuildContext context,
    WidgetRef ref,
    PreDiveSessionItem item,
  ) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _NoteDialog(item: item),
    );
    if (note == null) return;
    // Preserve the current state; only the note changes. _setState keeps
    // item.overdueServices untouched since no fresh snapshot is passed.
    await _setState(ref, item, item.state, note: note);
  }

  Future<void> _flag(
    BuildContext context,
    WidgetRef ref,
    PreDiveSessionItem item,
  ) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _NoteDialog(item: item),
    );
    // Flagging without a note is allowed; dialog cancel aborts.
    if (note == null) return;
    await _resolve(ref, item, PreDiveItemState.flagged, note: note);
  }

  Future<void> _complete(
    BuildContext context,
    WidgetRef ref,
    List<PreDiveSessionItem> items,
  ) async {
    final l10n = context.l10n;
    final flagged = ChecklistSessionEngine.flaggedCount(items);
    if (flagged > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.preDive_runner_completeFlagged(flagged)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.preDive_runner_complete),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref.read(preDiveSessionRepositoryProvider).completeSession(sessionId);
  }

  Future<void> _abort(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.preDive_runner_abort),
        content: Text(l10n.preDive_runner_abortConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.preDive_runner_abort),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(preDiveSessionRepositoryProvider).abortSession(sessionId);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  String _statusLabel(BuildContext context, PreDiveSessionStatus status) {
    return switch (status) {
      PreDiveSessionStatus.inProgress =>
        context.l10n.preDive_sessions_statusInProgress,
      PreDiveSessionStatus.completed =>
        context.l10n.preDive_sessions_statusCompleted,
      PreDiveSessionStatus.aborted =>
        context.l10n.preDive_sessions_statusAborted,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sessionAsync = ref.watch(preDiveSessionProvider(sessionId));
    final itemsAsync = ref.watch(preDiveSessionItemsProvider(sessionId));
    final session = sessionAsync.value;
    final items = itemsAsync.value;

    if (session == null || items == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: sessionAsync.hasError || itemsAsync.hasError
              ? Text((sessionAsync.error ?? itemsAsync.error).toString())
              : const CircularProgressIndicator(),
        ),
      );
    }

    final resolved = ChecklistSessionEngine.resolvedCount(items);
    final flagged = ChecklistSessionEngine.flaggedCount(items);
    final canComplete = ChecklistSessionEngine.canComplete(items);

    // Group by section, null-section items first, preserving sort order.
    final sections = <String?, List<PreDiveSessionItem>>{};
    for (final item in items) {
      sections.putIfAbsent(item.section, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(session.templateName),
        actions: [
          if (flagged > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  avatar: Icon(
                    Icons.flag,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(l10n.preDive_runner_flaggedBadge(flagged)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          if (!session.isLocked)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.preDive_runner_abort,
              onPressed: () => _abort(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: items.isEmpty ? 0 : resolved / items.length,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.preDive_runner_progress(resolved, items.length),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          if (session.isLocked)
            Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${l10n.preDive_runner_locked} - '
                '${_statusLabel(context, session.status)}'
                // Time of day, not just the date: the gap between finishing
                // the checklist and splashing is what the run is evidence of,
                // and it is what auto-links this run to a dive. l10n is
                // threaded through so the date/time connector is translated
                // rather than falling back to a hardcoded English "at".
                '${session.completedAt == null ? '' : ' - ${UnitFormatter(ref.watch(settingsProvider)).formatDateTime(session.completedAt, l10n: l10n)}'}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                for (final entry in sections.entries) ...[
                  if (entry.key != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        entry.key!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  for (final item in entry.value)
                    SessionItemTile(
                      session: session,
                      sortedItems: items,
                      item: item,
                      onDone: () => _resolve(ref, item, PreDiveItemState.done),
                      onSkip: () =>
                          _resolve(ref, item, PreDiveItemState.skipped),
                      onFlag: () => _flag(context, ref, item),
                      onEditValue: () => _editValue(context, ref, items, item),
                      staleSourceValue: _staleSourceValue(items, item),
                      onAddNote: () => _addNote(context, ref, item),
                      onReset: () =>
                          _setState(ref, item, PreDiveItemState.pending),
                    ),
                ],
                const SizedBox(height: 88),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: session.isLocked
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: canComplete
                      ? () => _complete(context, ref, items)
                      : null,
                  child: Text(l10n.preDive_runner_complete),
                ),
              ),
            ),
    );
  }
}

/// Number entry for a `value` item or a `cellLinearity` one.
///
/// A linearity item additionally shows the cell's air reading above the
/// field and a live expected-mV and linearity readout below it, recomputed
/// on each keystroke so the diver sees the result before committing to it.
///
/// Owns its controllers and disposes them in its own [State.dispose] (see
/// the checklist item dialog for why).
class _ValueEntryDialog extends StatefulWidget {
  final PreDiveSessionItem item;

  /// The source item's air reading, for a cell linearity item. Null for a
  /// plain value item, and for a linearity item whose air reading has not
  /// been taken yet.
  final double? sourceValue;

  const _ValueEntryDialog({required this.item, this.sourceValue});

  @override
  State<_ValueEntryDialog> createState() => _ValueEntryDialogState();
}

class _ValueEntryDialogState extends State<_ValueEntryDialog> {
  late final TextEditingController _valueController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final value = widget.item.valueNumber;
    _valueController = TextEditingController(
      text: value == null ? '' : formatDecimalForInput(value),
    );
    _noteController = TextEditingController(text: widget.item.note);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The live readout, recomputed on every keystroke from the text in the
  /// field rather than from the stored value, so the diver sees the answer
  /// before committing to it. Null when there is nothing to compute.
  String? _readout(BuildContext context) {
    if (!widget.item.isCellLinearity) return null;
    final typed = parseUserDecimal(_valueController.text);
    final expected = CellLinearity.expectedO2Millivolts(widget.sourceValue);
    final percent = CellLinearity.percent(
      airMillivolts: widget.sourceValue,
      o2Millivolts: typed,
    );
    if (expected == null || percent == null) return null;
    return context.l10n.preDive_runner_linearityReadout(
      formatDecimalForDisplay(double.parse(expected.toStringAsFixed(1))),
      percent.round().toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isLinearity = widget.item.isCellLinearity;
    final readout = _readout(context);
    return AlertDialog(
      title: Text(widget.item.valueLabel ?? widget.item.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLinearity)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.sourceValue == null
                    ? '${l10n.preDive_runner_cellInAir}: '
                          '${l10n.preDive_runner_cellInAirMissing}'
                    : '${l10n.preDive_runner_cellInAir}: '
                              '${formatDecimalForDisplay(widget.sourceValue!)} '
                              '${widget.item.valueUnit ?? ''}'
                          .trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          TextField(
            controller: _valueController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: isLinearity ? (_) => setState(() {}) : null,
            decoration: InputDecoration(
              labelText: isLinearity
                  ? l10n.preDive_runner_enterO2Value
                  : l10n.preDive_runner_enterValue,
              suffixText: widget.item.valueUnit,
            ),
          ),
          if (readout != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(readout, style: theme.textTheme.bodyMedium),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(labelText: l10n.preDive_runner_addNote),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            value: parseUserDecimal(_valueController.text),
            note: _noteController.text.trim(),
          )),
          child: Text(l10n.common_action_ok),
        ),
      ],
    );
  }
}

/// Free-text note entry, used for Add note and for Flag.
class _NoteDialog extends StatefulWidget {
  final PreDiveSessionItem item;

  const _NoteDialog({required this.item});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.item.note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.item.title),
      content: TextField(
        controller: _noteController,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.preDive_runner_addNote),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_noteController.text.trim()),
          child: Text(l10n.common_action_ok),
        ),
      ],
    );
  }
}
