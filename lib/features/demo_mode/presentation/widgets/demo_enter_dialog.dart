import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_service.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_question_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Enters demo mode in two steps. First a question names the size of
/// [package] (#3736); its Cancel downloads nothing. On Download, the progress
/// dialog downloads a package of exactly that size and opens it, asking
/// again if the size on offer has changed since. On success the app restarts
/// into demo mode and the dialog goes with the old screen; on failure it
/// explains and offers Retry; its Cancel stops the download in progress and
/// leaves everything as it was.
///
/// On the first-run welcome screen ([fromFirstRun]) there is no logbook of
/// the user's own yet, so the question does not mention setting one aside.
Future<void> askAndEnterDemo(
  BuildContext context, {
  required bool fromFirstRun,
  required DemoPackage package,
  DemoUnitSettings? units,
}) async {
  final l10n = context.l10n;
  final size = sizeInSentence(package.size);
  final confirmed = await askDemoQuestion(
    context,
    title: l10n.demo_enter_confirm_title,
    body: fromFirstRun
        ? l10n.demo_enter_confirm_body_firstRun(size)
        : l10n.demo_enter_confirm_body(size),
    action: l10n.demo_enter_confirm_action,
  );
  if (!confirmed || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DemoEnterDialog(
      fromFirstRun: fromFirstRun,
      package: package,
      units: units,
    ),
  );
}

/// [bytes] as a size to place inside a translated sentence. The isolate marks
/// keep it reading left to right in Arabic and Hebrew, where "12 MB" set in a
/// right-to-left sentence would otherwise show as "MB 12".
@visibleForTesting
String sizeInSentence(int bytes) => '\u2066${formatBytes(bytes)}\u2069';

class DemoEnterDialog extends ConsumerStatefulWidget {
  const DemoEnterDialog({
    super.key,
    required this.fromFirstRun,
    required this.package,
    this.units,
  });

  final bool fromFirstRun;

  /// The package whose size the user agreed to.
  final DemoPackage package;
  final DemoUnitSettings? units;

  @override
  ConsumerState<DemoEnterDialog> createState() => _DemoEnterDialogState();
}

class _DemoEnterDialogState extends ConsumerState<DemoEnterDialog> {
  /// The package whose size the user last agreed to: [DemoEnterDialog.package]
  /// until they accept a new size.
  late DemoPackage _package = widget.package;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() => ref
      .read(demoEnterControllerProvider.notifier)
      .start(
        fromFirstRun: widget.fromFirstRun,
        package: _package,
        units: widget.units,
      );

  void _acceptNewSize(DemoPackage package) {
    _package = package;
    _start();
  }

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
      DemoEnterPackageChanged(:final package) => AlertDialog(
        title: Text(l10n.demo_enter_confirm_title),
        content: Text(
          l10n.demo_enter_changed_body(sizeInSentence(package.size)),
        ),
        actions: [
          TextButton(onPressed: close, child: Text(l10n.common_action_cancel)),
          FilledButton(
            onPressed: () => _acceptNewSize(package),
            child: Text(l10n.demo_enter_confirm_action),
          ),
        ],
      ),
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
