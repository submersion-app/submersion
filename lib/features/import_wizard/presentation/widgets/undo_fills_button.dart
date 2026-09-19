import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_computer/data/services/planned_dive_fill_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Undo for the planned dives this import filled (issue #2002): restores
/// each from its snapshot and refreshes the dive lists. Disables itself
/// once used, since the snapshots are then stale.
class UndoFillsButton extends ConsumerStatefulWidget {
  final List<PlannedDiveFillOutcome> outcomes;

  /// Injected by tests; the real service is built on demand otherwise.
  final PlannedDiveFillService? service;

  const UndoFillsButton({super.key, required this.outcomes, this.service});

  @override
  ConsumerState<UndoFillsButton> createState() => _UndoFillsButtonState();
}

class _UndoFillsButtonState extends ConsumerState<UndoFillsButton> {
  bool _busy = false;

  /// Fills still to undo. Each undo is its own transaction, so a failure
  /// part-way leaves the earlier ones restored; only the rest are retried.
  late List<PlannedDiveFillOutcome> _remaining = [...widget.outcomes];

  bool get _done => _remaining.isEmpty;

  void _refreshLists() {
    ref.invalidate(paginatedDiveListProvider);
    ref.invalidate(diveListNotifierProvider);
    ref.invalidate(divesProvider);
    ref.invalidate(diveStatisticsProvider);
    ref.invalidate(diveNumberingInfoProvider);
  }

  Future<void> _undo() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final service = widget.service ?? PlannedDiveFillService();
    var failed = false;
    try {
      for (final outcome in [..._remaining]) {
        await service.undo(outcome);
        _remaining = [
          for (final o in _remaining)
            if (!identical(o, outcome)) o,
        ];
      }
    } catch (_) {
      failed = true;
    } finally {
      // Refresh even after a failure: some fills may have been restored.
      _refreshLists();
      if (mounted) setState(() => _busy = false);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed
              ? l10n.universalImport_fillPlanned_undoFailed
              : l10n.universalImport_fillPlanned_undone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('import_summary_undo_fills'),
          onPressed: _done || _busy ? null : _undo,
          icon: const Icon(Icons.undo),
          label: Text(context.l10n.universalImport_fillPlanned_undo),
        ),
      ),
    );
  }
}
