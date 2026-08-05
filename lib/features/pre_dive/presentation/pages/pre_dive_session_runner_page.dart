import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/session_item_tile.dart';
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
  }) {
    return ref
        .read(preDiveSessionRepositoryProvider)
        .updateItemState(
          sessionId: sessionId,
          itemId: item.id,
          state: state,
          valueNumber: valueNumber,
          note: note,
        );
  }

  Future<void> _editValue(
    BuildContext context,
    WidgetRef ref,
    PreDiveSessionItem item,
  ) async {
    final result = await showDialog<({double? value, String? note})>(
      context: context,
      builder: (context) => _ValueEntryDialog(item: item),
    );
    if (result == null) return;
    await _setState(
      ref,
      item,
      PreDiveItemState.done,
      valueNumber: result.value,
      note: result.note,
    );
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
    // Preserve the current state; only the note changes.
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
    await _setState(ref, item, PreDiveItemState.flagged, note: note);
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
                '${session.completedAt == null ? '' : ' - ${MaterialLocalizations.of(context).formatMediumDate(session.completedAt!)}'}',
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
                      onDone: () => _setState(ref, item, PreDiveItemState.done),
                      onSkip: () =>
                          _setState(ref, item, PreDiveItemState.skipped),
                      onFlag: () => _flag(context, ref, item),
                      onEditValue: () => _editValue(context, ref, item),
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

/// Value entry for a `value` item. Owns its controllers and disposes them in
/// its own [State.dispose] (see the checklist item dialog for why).
class _ValueEntryDialog extends StatefulWidget {
  final PreDiveSessionItem item;

  const _ValueEntryDialog({required this.item});

  @override
  State<_ValueEntryDialog> createState() => _ValueEntryDialogState();
}

class _ValueEntryDialogState extends State<_ValueEntryDialog> {
  late final TextEditingController _valueController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(
      text: widget.item.valueNumber?.toString() ?? '',
    );
    _noteController = TextEditingController(text: widget.item.note);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.item.valueLabel ?? widget.item.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _valueController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.preDive_runner_enterValue,
              suffixText: widget.item.valueUnit,
            ),
          ),
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
            value: double.tryParse(_valueController.text.trim()),
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
