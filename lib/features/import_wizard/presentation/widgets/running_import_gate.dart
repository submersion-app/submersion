import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/back_navigation.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_job_provider.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_progress_step.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Holds back an import wizard opened while another import still runs.
///
/// The wizard resets the shared import state when it opens, which would pull
/// the files and extracted photos out from under an import that runs on
/// after its own wizard closed (#3554). Opened during such an import, this
/// shows that import's progress, with a way to cancel it, and builds [child]
/// only once it has ended. A wizard opened with no import running gets
/// [child] straight away and is never held back later, so its own import
/// does not hide it.
class RunningImportGate extends ConsumerStatefulWidget {
  const RunningImportGate({
    super.key,
    required this.title,
    required this.child,
  });

  /// The wizard's title, for the app bar while it waits.
  final String title;

  final Widget child;

  @override
  ConsumerState<RunningImportGate> createState() => _RunningImportGateState();
}

class _RunningImportGateState extends ConsumerState<RunningImportGate> {
  late bool _waiting = ref.read(importJobProvider).isRunning;

  @override
  Widget build(BuildContext context) {
    if (_waiting) {
      final job = ref.watch(importJobProvider);
      if (job.isRunning) return _RunningImportView(title: widget.title);
      _waiting = false;
    }
    return widget.child;
  }
}

class _RunningImportView extends ConsumerWidget {
  const _RunningImportView({required this.title});

  final String title;

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(kRootLocation);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final job = ref.watch(importJobProvider);
    final fraction = job.total > 0 ? job.current / job.total : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => _close(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.universalImport_running_title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.universalImport_running_body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  job.isCancellationRequested
                      ? l10n.settings_import_cancelling
                      : importPhaseLabel(l10n, job.phase),
                  key: const Key('running_import_phase_text'),
                ),
                if (job.total > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.universalImport_label_xOfY(job.current, job.total),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                LinearProgressIndicator(value: fraction),
                const SizedBox(height: 24),
                TextButton.icon(
                  key: const Key('running_import_cancel_button'),
                  onPressed: job.isCancellationRequested
                      ? null
                      : () => ref.read(importJobProvider.notifier).cancel(),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(l10n.universalImport_cancel_confirmAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
