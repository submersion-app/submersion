import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_service.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Downloads and opens the sample logbook, showing progress. On success the
/// app restarts into demo mode and this dialog goes with the old screen; on
/// failure it explains and offers Retry; Cancel stops the download and leaves
/// everything as it was.
Future<void> showDemoEnterDialog(
  BuildContext context, {
  required bool fromFirstRun,
  DemoUnitSettings? units,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => DemoEnterDialog(fromFirstRun: fromFirstRun, units: units),
);

class DemoEnterDialog extends ConsumerStatefulWidget {
  const DemoEnterDialog({super.key, required this.fromFirstRun, this.units});

  final bool fromFirstRun;
  final DemoUnitSettings? units;

  @override
  ConsumerState<DemoEnterDialog> createState() => _DemoEnterDialogState();
}

class _DemoEnterDialogState extends ConsumerState<DemoEnterDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() => ref
      .read(demoEnterControllerProvider.notifier)
      .start(fromFirstRun: widget.fromFirstRun, units: widget.units);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(demoEnterControllerProvider);
    final controller = ref.read(demoEnterControllerProvider.notifier);

    void close() {
      controller
        ..cancel()
        ..reset();
      Navigator.of(context).pop();
    }

    return switch (state) {
      DemoEnterFailed() => AlertDialog(
        title: Text(l10n.demo_welcome_title),
        content: Text(l10n.demo_enter_failed),
        actions: [
          TextButton(onPressed: close, child: Text(l10n.common_action_close)),
          FilledButton(
            onPressed: _start,
            child: Text(l10n.common_action_retry),
          ),
        ],
      ),
      DemoEnterRunning(:final progress) => _progressDialog(
        context,
        progress,
        close,
      ),
      DemoEnterIdle() => _progressDialog(
        context,
        const DemoEnterProgress(DemoEnterStage.downloading),
        close,
      ),
    };
  }

  Widget _progressDialog(
    BuildContext context,
    DemoEnterProgress progress,
    VoidCallback cancel,
  ) {
    final l10n = context.l10n;
    final label = switch (progress.stage) {
      DemoEnterStage.downloading => l10n.demo_enter_downloading,
      DemoEnterStage.preparing => l10n.demo_enter_preparing,
      DemoEnterStage.opening => l10n.demo_enter_opening,
    };
    final fraction =
        progress.stage == DemoEnterStage.downloading && progress.total > 0
        ? progress.received / progress.total
        : null;
    return AlertDialog(
      title: Text(l10n.demo_welcome_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: fraction),
        ],
      ),
      actions: [
        if (progress.stage == DemoEnterStage.downloading)
          TextButton(onPressed: cancel, child: Text(l10n.common_action_cancel)),
      ],
    );
  }
}
