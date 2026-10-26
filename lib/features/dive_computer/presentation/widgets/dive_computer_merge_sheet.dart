import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart';
import 'package:submersion/features/dive_computer/presentation/utils/connection_presentation.dart';
import 'package:submersion/features/dive_computer/domain/services/dive_computer_merge_rules.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet that folds two or more dive computer records into one.
///
/// The user picks which record to keep; every dive, profile and download
/// cursor moves to it and the others are deleted. The sheet is the review
/// step issue #645 asks for before any duplicate is removed, so it shows each
/// record's identity, how many dives will move, and a warning when the
/// records report different serial numbers.
class DiveComputerMergeSheet extends ConsumerStatefulWidget {
  const DiveComputerMergeSheet({super.key, required this.computers});

  /// The records to merge, at least two.
  final List<DiveComputer> computers;

  /// Opens the sheet. Resolves to the merge result, or null when dismissed.
  static Future<DiveComputerMergeResult?> show(
    BuildContext context,
    List<DiveComputer> computers,
  ) {
    return showModalBottomSheet<DiveComputerMergeResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DiveComputerMergeSheet(computers: computers),
    );
  }

  @override
  ConsumerState<DiveComputerMergeSheet> createState() =>
      _DiveComputerMergeSheetState();
}

class _DiveComputerMergeSheetState
    extends ConsumerState<DiveComputerMergeSheet> {
  late String _survivorId;
  int? _affectedDives;
  bool _isMerging = false;

  List<String> get _duplicateIds => [
    for (final computer in widget.computers)
      if (computer.id != _survivorId) computer.id,
  ];

  @override
  void initState() {
    super.initState();
    _survivorId = defaultSurvivor(widget.computers).id;
    _reloadAffectedDives();
  }

  void _reloadAffectedDives() {
    _affectedDives = null;
    logFailure(
      _loadAffectedDives(_survivorId, _duplicateIds),
      _DiveComputerMergeSheetState,
      'count affected dives',
    );
  }

  Future<void> _loadAffectedDives(
    String survivorId,
    List<String> duplicateIds,
  ) async {
    final count = await ref
        .read(diveComputerMergeRepositoryProvider)
        .countAffectedDives(survivorId: survivorId, duplicateIds: duplicateIds);
    // The survivor may have changed while the count was in flight.
    if (mounted && survivorId == _survivorId) {
      setState(() => _affectedDives = count);
    }
  }

  Future<void> _performMerge() async {
    setState(() => _isMerging = true);
    try {
      final result = await ref
          .read(diveComputerNotifierProvider.notifier)
          .merge(survivorId: _survivorId, duplicateIds: _duplicateIds);
      // Dive attribution changed under the dive list; the computer notifier
      // cannot reach these providers without an import cycle.
      ref.invalidate(divesProvider);
      ref.invalidate(diveListNotifierProvider);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMerging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.diveComputer_merge_failed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final conflict = serialNumbersConflict(widget.computers);
    // Which way each record came in (issue #3106), so the diver can tell a
    // Bluetooth record from a file import before choosing the one to keep.
    final connections =
        ref.watch(allDiveComputerConnectionsProvider).valueOrNull ??
        const <String, List<DiveComputerConnection>>{};

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.diveComputer_merge_title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.diveComputer_merge_intro(widget.computers.length),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            // The duplicates' gear items are folded into the survivor's
            // (#3676), so the sheet says where their history goes.
            Text(
              l10n.diveComputer_merge_gearNote,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (conflict) ...[
              const SizedBox(height: 12),
              const _SerialMismatchWarning(
                key: ValueKey('merge_serial_warning'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.diveComputer_merge_keepLabel,
              style: theme.textTheme.titleSmall,
            ),
            RadioGroup<String>(
              groupValue: _survivorId,
              onChanged: (value) {
                if (value == null || value == _survivorId) return;
                setState(() {
                  _survivorId = value;
                  _reloadAffectedDives();
                });
              },
              child: Column(
                children: [
                  for (final computer in widget.computers)
                    RadioListTile<String>(
                      key: ValueKey('merge_keep_${computer.id}'),
                      value: computer.id,
                      title: Text(computer.displayName),
                      subtitle: Text(
                        _subtitleFor(
                          context,
                          computer,
                          connections[computer.id] ?? const [],
                        ),
                      ),
                      secondary: computer.isFavorite
                          ? Icon(Icons.star, color: theme.colorScheme.primary)
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_affectedDives != null)
              Text(
                l10n.diveComputer_merge_affectedDives(_affectedDives!),
                key: const ValueKey('merge_affected_dives'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isMerging
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('merge_confirm'),
                  onPressed: _isMerging ? null : _performMerge,
                  child: _isMerging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.diveComputer_merge_action),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(
    BuildContext context,
    DiveComputer computer,
    List<DiveComputerConnection> connections,
  ) {
    final l10n = context.l10n;
    final serial = computer.serialNumber?.trim();
    final parts = <String>[
      if (computer.fullName != computer.displayName) computer.fullName,
      serial != null && serial.isNotEmpty
          ? l10n.diveComputer_merge_serialLabel(serial)
          : l10n.diveComputer_merge_noSerial,
      l10n.diveComputer_list_diveCount(computer.diveCount),
      if (connections.isNotEmpty)
        connections.map((c) => connectionLabel(l10n, c)).join(', '),
    ];
    return parts.join(' · ');
  }
}

class _SerialMismatchWarning extends StatelessWidget {
  const _SerialMismatchWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.diveComputer_merge_serialMismatchWarning,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
