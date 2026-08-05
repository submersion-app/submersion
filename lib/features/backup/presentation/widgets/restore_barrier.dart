import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';

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
            child: _RestoreOverlay(message: ref.watch(restoreMessageProvider)),
          ),
      ],
    );
  }
}

class _RestoreOverlay extends StatelessWidget {
  const _RestoreOverlay({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The provider already supplies an English progress string; fall back to a
    // plain one if it is ever absent.
    final label = message ?? 'Restoring backup...';

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(label, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
