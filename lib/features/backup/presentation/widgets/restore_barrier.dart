import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// True while a database restore is running. Derived (not the whole operation
/// state) so widgets rebuild only when this specific flag flips, and so tests
/// can override it with a plain value.
final restoreInProgressProvider = Provider<bool>(
  (ref) => ref.watch(backupOperationProvider.select((s) => s.isRestoring)),
);

/// The current restore progress message (e.g. "Restoring backup...").
final restoreMessageProvider = Provider<String?>(
  (ref) => ref.watch(backupOperationProvider.select((s) => s.message)),
);

/// Non-null only while the post-restore safety review sweep is running.
final restoreSweepProgressProvider = Provider<SafetyReviewSweepProgress?>(
  (ref) => ref.watch(backupOperationProvider.select((s) => s.sweepProgress)),
);

/// Wraps the whole app and, while a database restore is running, covers it with
/// an interaction-blocking overlay.
///
/// A restore briefly closes and reopens the database. Without this barrier the
/// user could navigate to a data page mid-restore, whose providers would build
/// against the transient null database and cache a fatal "Database not
/// initialized" error that survives until a full app restart (the DiveCenters
/// red-screen bug). Blocking all interaction until the restore finishes — and
/// hands off to RestoreCompletePage — closes that gap.
class RestoreBarrier extends ConsumerWidget {
  const RestoreBarrier({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRestoring = ref.watch(restoreInProgressProvider);

    return Stack(
      children: [
        child,
        if (isRestoring)
          Positioned.fill(
            child: _RestoreOverlay(
              message: ref.watch(restoreMessageProvider),
              sweepProgress: ref.watch(restoreSweepProgressProvider),
              onSkipSweep: () => ref
                  .read(backupOperationProvider.notifier)
                  .skipSafetyReviewSweep(),
            ),
          ),
      ],
    );
  }
}

class _RestoreOverlay extends StatelessWidget {
  const _RestoreOverlay({
    this.message,
    this.sweepProgress,
    required this.onSkipSweep,
  });

  final String? message;
  final SafetyReviewSweepProgress? sweepProgress;
  final VoidCallback onSkipSweep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sweep = sweepProgress;

    // The provider supplies a localized progress string for the swap phases;
    // fall back to the plain restoring line if it is ever absent. Once the
    // safety sweep starts, its own label takes over.
    final label = sweep != null
        ? context.l10n.backup_restore_safetyReview_progress(
            sweep.done,
            sweep.total,
          )
        : (message ?? context.l10n.backup_operation_restoring);

    // Announce the busy/restoring state to screen readers as a live region, and
    // exclude the inner widgets' own semantics so the state is announced once
    // (not duplicated by the progress indicator and the label Text).
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Stack(
          children: [
            // Absorbs every pointer event and paints the scrim, so nothing
            // beneath can be tapped or scrolled during the restore.
            const ModalBarrier(dismissible: false, color: Colors.black54),
            Center(
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: sweep == null
                          ? _spinnerChildren(theme, label)
                          : _sweepChildren(context, theme, sweep, label),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _spinnerChildren(ThemeData theme, String label) {
    return [
      const CircularProgressIndicator(),
      const SizedBox(height: 16),
      Text(label, style: theme.textTheme.bodyMedium),
    ];
  }

  List<Widget> _sweepChildren(
    BuildContext context,
    ThemeData theme,
    SafetyReviewSweepProgress sweep,
    String label,
  ) {
    return [
      Text(
        context.l10n.backup_restore_safetyReview_title,
        style: theme.textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      LinearProgressIndicator(
        value: sweep.total == 0 ? null : sweep.done / sweep.total,
      ),
      const SizedBox(height: 12),
      Text(label, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 8),
      // Skipping is lossless: unswept dives still compute lazily when opened,
      // and Settings > Safety > "Analyze all dives" remains available.
      TextButton(
        onPressed: onSkipSweep,
        child: Text(context.l10n.backup_restore_safetyReview_skip),
      ),
    ];
  }
}
