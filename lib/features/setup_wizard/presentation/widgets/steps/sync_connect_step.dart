import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Existing-data path: connect a provider, pull the library, land on the
/// dashboard once data (and its divers) have arrived.
class SyncConnectStep extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  /// Called when the connected account has no library (pivot to fresh).
  final VoidCallback onNoLibrary;

  const SyncConnectStep({
    super.key,
    required this.mode,
    required this.onNoLibrary,
  });

  @override
  ConsumerState<SyncConnectStep> createState() => _SyncConnectStepState();
}

enum _PullPhase { connect, pulling, done, empty }

class _SyncConnectStepState extends ConsumerState<SyncConnectStep> {
  _PullPhase _phase = _PullPhase.connect;

  Future<void> _startPull() async {
    setState(() => _phase = _PullPhase.pulling);
    final connected = ref
        .read(setupWizardProvider(widget.mode))
        .connectedProvider;
    if (connected == null) {
      setState(() => _phase = _PullPhase.connect);
      return;
    }
    try {
      final instance = cloudProviderInstanceFor(connected);
      final peers = await ref
          .read(syncInitializerProvider)
          .peerSyncFiles(instance);
      if (peers.isEmpty) {
        if (mounted) setState(() => _phase = _PullPhase.empty);
        return;
      }
      await ref.read(syncStateProvider.notifier).performSync();
      final syncState = ref.read(syncStateProvider);
      if (syncState.status == SyncStatus.error) {
        // A failed sync must not fall through to the "No library found" UI.
        if (mounted) {
          setState(() => _phase = _PullPhase.connect);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.setup_sync_error(syncState.message ?? ''),
              ),
            ),
          );
        }
        return;
      }
      await realignActiveDiverAfterDataReplace(
        ref.read(sharedPreferencesProvider),
      );
      final hasDivers = await ref.read(hasAnyDiversProvider.future);
      if (mounted) {
        setState(() => _phase = hasDivers ? _PullPhase.done : _PullPhase.empty);
      }
    } catch (e) {
      // Listing peers or syncing can fail (network/auth). Return to the
      // connect UI with an error rather than crashing or hanging on the
      // spinner.
      if (mounted) {
        setState(() => _phase = _PullPhase.connect);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.setup_sync_error(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final syncState = ref.watch(syncStateProvider);

    switch (_phase) {
      case _PullPhase.connect:
        // Reuse the provider cards; connecting enables the continue gate.
        return Column(
          children: [
            Expanded(child: BackupSyncStep(mode: widget.mode)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _ConnectedGate(
                  mode: widget.mode,
                  onContinue: _startPull,
                ),
              ),
            ),
          ],
        );
      case _PullPhase.pulling:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(value: syncState.progress),
              const SizedBox(height: 12),
              Text(syncState.message ?? l10n.setup_syncPull_syncing),
            ],
          ),
        );
      case _PullPhase.done:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.setup_syncPull_success,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/dashboard'),
                child: Text(l10n.setup_syncPull_continue),
              ),
            ],
          ),
        );
      case _PullPhase.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.setup_syncPull_noLibrary_title,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.setup_syncPull_noLibrary_message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.onNoLibrary,
                  child: Text(l10n.setup_sync_libraryFound_keepFresh),
                ),
              ],
            ),
          ),
        );
    }
  }
}

/// Continue button enabled once a provider is connected in the draft.
class _ConnectedGate extends ConsumerWidget {
  final SetupWizardMode mode;
  final VoidCallback onContinue;

  const _ConnectedGate({required this.mode, required this.onContinue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(
      setupWizardProvider(mode).select((d) => d.connectedProvider != null),
    );
    return FilledButton(
      onPressed: connected ? onContinue : null,
      child: Text(context.l10n.setup_syncPull_continue),
    );
  }
}
