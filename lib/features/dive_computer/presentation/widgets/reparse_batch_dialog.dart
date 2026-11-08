import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_batch_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Re-parses [diveIds] behind a modal progress dialog that ends in a results
/// summary (issue #224). With [computerId], only that computer's sources are
/// re-parsed. Returns once the diver closes the dialog; a failed dive the
/// diver tapped is opened after it closes.
Future<void> runReparseBatch(
  BuildContext context,
  WidgetRef ref,
  List<String> diveIds, {
  String? computerId,
}) async {
  final notifier = ref.read(reparseBatchProvider.notifier);
  // A run already going (its dialog lost to a crash of the route, say) is
  // shown again rather than started twice.
  if (ref.read(reparseBatchProvider) is! ReparseBatchRunning) {
    unawaited(notifier.start(diveIds, computerId: computerId));
  }
  final router = GoRouter.maybeOf(context);
  final openDiveId = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ReparseBatchDialog(),
  );
  notifier.reset();
  if (openDiveId != null) router?.push('/dives/$openDiveId');
}

/// [error] from a re-parse as the diver reads it: the engine's own English
/// errors translated, a parser's message as it came.
String reparseErrorLabel(AppLocalizations l10n, String error) =>
    error == missingDescriptorsError
    ? l10n.reparseBatch_missingDescriptors
    : error;

/// Asks before a batch re-parse of [count] dives. [skipped] counts chosen
/// dives that have no raw data and will be left out. True when confirmed.
Future<bool> confirmBatchReparse(
  BuildContext context, {
  required int count,
  int skipped = 0,
}) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.reparseBatch_confirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.reparseBatch_confirmMessage(count)),
          if (skipped > 0) ...[
            const SizedBox(height: 12),
            Text(l10n.reparseBatch_confirmSkipped(skipped)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.common_action_reparse),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Progress while [reparseBatchProvider] runs, then the results. Cannot be
/// dismissed until the run has finished.
class ReparseBatchDialog extends ConsumerWidget {
  const ReparseBatchDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reparseBatchProvider);
    return PopScope(
      canPop: state is ReparseBatchFinished,
      child: switch (state) {
        ReparseBatchFinished() => _ResultsDialog(state: state),
        ReparseBatchRunning() => _ProgressDialog(state: state),
        ReparseBatchIdle() => const _ProgressDialog(
          state: ReparseBatchRunning(done: 0, total: 0),
        ),
      },
    );
  }
}

class _ProgressDialog extends ConsumerWidget {
  const _ProgressDialog({required this.state});

  final ReparseBatchRunning state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final total = state.total;
    return AlertDialog(
      title: Text(l10n.reparseBatch_progressTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: total == 0 ? null : state.done / total,
          ),
          const SizedBox(height: 12),
          Text(l10n.reparseBatch_progressCount(state.done, total)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: state.cancelling
              ? null
              : () => ref.read(reparseBatchProvider.notifier).cancel(),
          child: Text(
            state.cancelling
                ? l10n.reparseBatch_cancelling
                : l10n.common_action_cancel,
          ),
        ),
      ],
    );
  }
}

class _ResultsDialog extends ConsumerWidget {
  const _ResultsDialog({required this.state});

  final ReparseBatchFinished state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final result = state.result;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);

    // A run that stopped on an error was neither finished nor cancelled. It
    // cannot say how many of the dives before the error succeeded, so it
    // reports only the error and what it never reached.
    final runError = state.runError;
    final lines = [
      if (runError == null)
        l10n.reparseBatch_resultSummary(result.succeeded, result.total)
      else
        l10n.diveLog_detail_reparseFailed(runError),
      if (result.failed > 0) l10n.reparseBatch_resultFailed(result.failed),
      if (result.notProcessed > 0)
        runError == null
            ? l10n.reparseBatch_resultNotProcessed(result.notProcessed)
            : l10n.reparseBatch_resultNotReached(result.notProcessed),
      if (result.skipped > 0) l10n.reparseBatch_resultSkipped(result.skipped),
      if (result.profilesPreserved > 0)
        l10n.reparseBatch_resultProfilesPreserved(result.profilesPreserved),
    ];

    return AlertDialog(
      title: Text(switch ((runError, result.cancelled)) {
        (String(), _) => l10n.reparseBatch_resultErrorTitle,
        (null, true) => l10n.reparseBatch_resultCancelledTitle,
        (null, false) => l10n.reparseBatch_resultTitle,
      }),
      // A fixed width lets the failed list scroll; AlertDialog sizes its
      // content intrinsically, which a ListView cannot report.
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line),
              ),
            if (state.failedDives.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.reparseBatch_failedListHeader,
                style: theme.textTheme.titleSmall,
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: state.failedDives.length,
                  itemBuilder: (context, index) => _FailedDiveTile(
                    dive: state.failedDives[index],
                    units: units,
                    l10n: l10n,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_done),
        ),
      ],
    );
  }
}

class _FailedDiveTile extends StatelessWidget {
  const _FailedDiveTile({
    required this.dive,
    required this.units,
    required this.l10n,
  });

  final ReparseFailedDive dive;
  final UnitFormatter units;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final number = dive.diveNumber;
    final when = units.formatDateTime(dive.date, l10n: l10n);
    final site = dive.siteName;
    final error = reparseErrorLabel(l10n, dive.error);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.error_outline, color: colorScheme.error),
      title: Text(
        number == null
            ? l10n.reparseBatch_failedDiveUnnumbered
            : l10n.reparseBatch_failedDiveTitle(number),
      ),
      subtitle: Text(
        '${site == null || site.isEmpty ? when : '$when · $site'}\n$error',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pop(dive.diveId),
    );
  }
}
