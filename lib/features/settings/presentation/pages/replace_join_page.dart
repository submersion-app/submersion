import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/providers/replace_and_join_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/main.dart' show restartApp;

final _log = LoggerService.forClass(ReplaceJoinPage);

/// How a replace that did not finish ended, for the step that started it.
sealed class ReplaceJoinEnd {
  const ReplaceJoinEnd();
}

/// The service refused before anything changed ([ReplaceJoinResult]).
final class ReplaceJoinRefused extends ReplaceJoinEnd {
  const ReplaceJoinRefused(this.result);
  final ReplaceJoinResult result;
}

/// It failed before its commit; the device is as it was.
final class ReplaceJoinFailed extends ReplaceJoinEnd {
  const ReplaceJoinFailed();
}

/// Replace and join behind a full-screen page (issue #3482, spec 6.4.1):
/// it runs the service, and once the library has replaced this device's
/// dives it says so and reloads the app, as Reset Database and Restore do.
/// A refusal or a failure goes back to the step with its [ReplaceJoinEnd].
class ReplaceJoinPage extends ConsumerStatefulWidget {
  const ReplaceJoinPage({
    super.key,
    required this.diveCount,
    required this.backupNote,
    this.restart = restartApp,
    this.onReplaced,
  });

  final int diveCount;
  final String backupNote;

  /// Runs once the library has replaced this device's dives, before the
  /// reload (the step's own choices, such as keeping devices in step).
  final Future<void> Function()? onReplaced;

  /// Reloads the app; tests pass their own.
  final VoidCallback restart;

  /// Null only when the page closed some other way.
  static Future<ReplaceJoinEnd?> show(
    BuildContext context, {
    required int diveCount,
    required String backupNote,
    VoidCallback restart = restartApp,
    Future<void> Function()? onReplaced,
  }) => Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ReplaceJoinPage(
        diveCount: diveCount,
        backupNote: backupNote,
        restart: restart,
        onReplaced: onReplaced,
      ),
    ),
  );

  @override
  ConsumerState<ReplaceJoinPage> createState() => _ReplaceJoinPageState();
}

class _ReplaceJoinPageState extends ConsumerState<ReplaceJoinPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final ReplaceJoinResult result;
    try {
      result = await ref
          .read(replaceAndJoinServiceProvider)
          .run(backupNote: widget.backupNote);
    } catch (e, stackTrace) {
      _log.error('Replace and join failed', error: e, stackTrace: stackTrace);
      if (mounted) Navigator.of(context).pop(const ReplaceJoinFailed());
      return;
    }
    if (!mounted) return;
    if (result.outcome != ReplaceJoinOutcome.replaced) {
      Navigator.of(context).pop(ReplaceJoinRefused(result));
      return;
    }
    // The replace has committed; a failure here must not hide that.
    try {
      await widget.onReplaced?.call();
    } catch (e, stackTrace) {
      _log.error('After replace and join', error: e, stackTrace: stackTrace);
    }
    if (!mounted) return;
    // The pages behind would show the replaced library's old state; only
    // the reload remains.
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => _ReplaceJoinDone(
          diveCount: widget.diveCount,
          restart: widget.restart,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  context.l10n.settings_setUpDevice_replace_working,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ReplaceJoinDone extends StatelessWidget {
  const _ReplaceJoinDone({required this.diveCount, required this.restart});

  final int diveCount;
  final VoidCallback restart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.settings_setUpDevice_replace_doneTitle,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.settings_setUpDevice_replace_doneBody(diveCount),
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    FilledButton.icon(
                      onPressed: restart,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.backup_restoreComplete_continue),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
