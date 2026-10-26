import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/raw_dive_data_discard.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Download, view, re-import and re-parse, on a dive computer's Equipment
/// page (issue #3676).
class DiveComputerActionsCard extends ConsumerWidget {
  const DiveComputerActionsCard({super.key, required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () =>
                  context.push('/dive-computers/${computer.id}/download'),
              icon: const Icon(Icons.download),
              label: Text(context.l10n.diveComputer_detail_downloadDivesButton),
            ),
            const SizedBox(height: 12),
            // Filters on the computer id, not its serial number: keying it on
            // the serial dead-ended on every computer whose firmware never
            // reported one (issue #1064).
            OutlinedButton.icon(
              onPressed: () => openDiveList(
                context,
                ref,
                DiveFilterState(computerId: computer.id),
              ),
              icon: const Icon(Icons.list),
              label: Text(context.l10n.diveComputer_detail_viewDivesButton),
            ),
            if (computer.lastDiveFingerprint != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmReimportAll(context),
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.diveComputer_detail_reimportAllButton),
              ),
            ],
            _RawDataActions(computer: computer),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReimportAll(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.diveComputer_detail_reimportDialogTitle),
        content: Text(
          l10n.diveComputer_detail_reimportDialogBody(computer.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.common_action_continue),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.push('/dive-computers/${computer.id}/download?forceFull=true');
    }
  }
}

/// Re-parse all and discard raw data, shown only while the computer has
/// stored raw dive data.
class _RawDataActions extends ConsumerWidget {
  const _RawDataActions({required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(rawDataCountProvider(computer.id));
    return counts.when(
      data: (c) {
        if (c.withRawData == 0) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _confirmReparseAll(context, ref, c),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.diveComputer_detail_reparseAllButton),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                c.withoutRawData > 0
                    ? context.l10n
                          .diveComputer_detail_reparseRawDataCountWithout(
                            c.withRawData,
                            c.withoutRawData,
                          )
                    : context.l10n.diveComputer_detail_reparseRawDataCount(
                        c.withRawData,
                      ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('discard_raw_data_button'),
                onPressed: () => confirmAndDiscardComputerRawDiveData(
                  context,
                  ref,
                  computer,
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.diveComputer_rawData_discardButton),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Future<void> _confirmReparseAll(
    BuildContext context,
    WidgetRef ref,
    ({int withRawData, int withoutRawData}) counts,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.diveComputer_detail_reparseAllTitle),
        content: Text(
          l10n.diveComputer_detail_reparseAllMessage(counts.withRawData),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.common_action_reparse),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _executeReparseAll(context, ref);
    }
  }

  Future<void> _executeReparseAll(BuildContext context, WidgetRef ref) async {
    final service = ref.read(reparseServiceProvider);
    final l10n = context.l10n;

    final counts = await service.getRawDataCounts(computer.id);
    if (counts.withRawData == 0) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.diveComputer_detail_reparseAllProgress(counts.withRawData),
          ),
        ),
      );
    }

    final result = await service.reparseAllForComputer(
      computer.id,
      parseFn: pigeon.DiveComputerHostApi().parseRawDiveData,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failed == 0
                ? l10n.diveComputer_detail_reparseAllSuccess(result.succeeded)
                : l10n.diveComputer_detail_reparseAllPartial(
                    result.succeeded,
                    result.succeeded + result.failed,
                    result.failed,
                  ),
          ),
        ),
      );
    }
  }
}
