import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_settings_section.dart';
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

enum _PullPhase { connect, pulling, done, empty, locked, incomplete }

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
      final library = await ref
          .read(syncInitializerProvider)
          .peerLibraryState(instance);
      if (library != PeerLibraryState.pullable) {
        // "Nothing here" and "a publish died partway" both leave no manifest
        // to pull, but only the first one means Start Fresh is the right
        // advice: an unfinished publish is the user's data, mid-upload.
        if (mounted) {
          setState(
            () => _phase = library == PeerLibraryState.incomplete
                ? _PullPhase.incomplete
                : _PullPhase.empty,
          );
        }
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
      if (syncState.needsPassphrase) {
        // An end-to-end-encrypted library halts the pull with
        // awaitingPassphrase, which is NOT an error: the manifest is there,
        // this device just has no key yet, so nothing was written. Falling
        // through would count zero divers and claim the account holds no
        // library at all, stranding the user one passphrase short of their
        // data (issue #792). Offer the unlock instead.
        if (mounted) setState(() => _phase = _PullPhase.locked);
        return;
      }
      await realignActiveDiverAfterDataReplace(
        ref.read(sharedPreferencesProvider),
      );
      // The step can be disposed mid-pull (user backs out during the spinner);
      // touching ref after that throws, so bail before invalidating/reading.
      if (!mounted) return;
      // The pull wrote divers straight into the DB. Consult the repository
      // directly for the "did a library arrive?" decision: the cached diver
      // providers can still report empty here because their pause-aware
      // self-invalidation (Ref.invalidateSelfWhen) does not fire while nothing
      // is listening to them in the wizard, so ref.read(hasAnyDiversProvider
      // .future) would return the stale startup value and wrongly show
      // "no library".
      // Invalidate the cache too, so the dashboard redirect's later
      // hasAnyDiversProvider read reflects the freshly pulled rows.
      ref.invalidate(allDiversProvider);
      final hasDivers =
          (await ref.read(diverRepositoryProvider).getDiverCount()) > 0;
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

  /// Prompt for the library passphrase, then pull again with the session in
  /// place. The shared flow's own follow-up sync is suppressed: this step has
  /// to observe the pull's outcome to pick the next screen.
  Future<void> _unlock() async {
    final unlocked = await runEncryptionUnlockFlow(context, ref, resync: false);
    if (!mounted || !unlocked) return;
    await _startPull();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final syncState = ref.watch(syncStateProvider);
    // Hold the wizard draft alive for the whole step. It is an autoDispose
    // family whose only other listener is the connect phase's gate; every
    // later phase replaces that subtree, so without this watch the draft is
    // discarded and connectedProvider reads back null -- which would bounce
    // the post-unlock retry straight back to the connect screen.
    ref.watch(setupWizardProvider(widget.mode));

    switch (_phase) {
      case _PullPhase.connect:
        // Reuse the provider cards; connecting enables the continue gate.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: BackupSyncStep(mode: widget.mode)),
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
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: syncState.progress),
              const SizedBox(height: 12),
              Text(syncState.message ?? l10n.setup_syncPull_syncing),
            ],
          ),
        );
      case _PullPhase.done:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
      case _PullPhase.locked:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.setup_syncPull_locked_title,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.setup_syncPull_locked_message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _unlock,
                child: Text(l10n.settings_cloudSync_encryption_enterPassphrase),
              ),
            ],
          ),
        );
      case _PullPhase.incomplete:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_sync_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.setup_syncPull_incomplete_title,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.setup_syncPull_incomplete_message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _startPull,
                child: Text(l10n.setup_syncPull_incomplete_retry),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onNoLibrary,
                child: Text(l10n.setup_sync_libraryFound_keepFresh),
              ),
            ],
          ),
        );
      case _PullPhase.empty:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
