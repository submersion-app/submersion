import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/pages/replace_join_page.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_library_probe.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_library_choice.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_scaffold.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_sync_actions.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/typed_word_confirm_dialog.dart';

/// Step 2, "Dives on every device" (issue #3482, spec 6.4): points sync at
/// the account chosen in step 1, reads what the account holds, and offers
/// what fits it: start the library, download it, combine with it, or
/// replace this device's dives by it (replace and join).
class SetUpSyncStep extends ConsumerStatefulWidget {
  const SetUpSyncStep({
    super.key,
    required this.navigation,
    this.actions = const SetUpSyncActions(),
  });

  final SetUpStepNavigation navigation;
  final SetUpSyncActions actions;

  @override
  ConsumerState<SetUpSyncStep> createState() => _SetUpSyncStepState();
}

class _SetUpSyncStepState extends ConsumerState<SetUpSyncStep> {
  final _secret = TextEditingController();
  bool _connected = false;

  /// Sync could not be pointed at the account; Check again tries again.
  bool _connectFailed = false;
  bool _busy = false;
  bool _keepInStep = true;
  SetUpLibraryChoice _choice = SetUpLibraryChoice.combine;

  /// A refusal or failure, said above the buttons.
  String? _line;
  String? _secretError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  Future<AccountGroup?> _account() async =>
      ref.read(setUpFlowProvider) ??
      currentSyncGroup(await ref.read(accountGroupsProvider.future));

  Future<void> _connect() async {
    bool connected;
    try {
      final account = await _account();
      if (!mounted || account == null) return;
      connected = await widget.actions.connect(context, ref, account);
    } on Object {
      connected = false;
    }
    if (!mounted) return;
    setState(() {
      _connected = connected;
      _connectFailed = !connected;
    });
    if (connected) refreshSetUpLibrary(ref.invalidate);
  }

  /// Check again: connects first when that is what failed, once at a time.
  void _checkAgain() {
    if (_connected) {
      refreshSetUpLibrary(ref.invalidate);
    } else if (!_busy) {
      _run(_connect);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _line = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _firstSync({required bool realignDiver}) => _run(() async {
    final result = await widget.actions.firstSync(
      ref,
      keepInStep: _keepInStep,
      realignDiver: realignDiver,
    );
    if (!mounted) return;
    switch (result) {
      case SetUpFirstSync.synced:
        widget.navigation.onNext();
      case SetUpFirstSync.blocked:
        refreshSetUpLibrary(ref.invalidate);
      case SetUpFirstSync.failed:
        setState(() => _line = ref.read(syncStateProvider).message);
    }
  });

  Future<void> _replace(AccountGroup account, int dives) async {
    final l10n = context.l10n;
    final confirmed = await TypedWordConfirmDialog.show(
      context,
      title: l10n.settings_setUpDevice_replace_title,
      paragraphs: [
        l10n.settings_setUpDevice_replace_body(dives, account.label),
      ],
      word: l10n.settings_cloudSync_replaceLibrary_confirmWord,
      hint: l10n.settings_cloudSync_replaceLibrary_confirmHint,
      confirmLabel: l10n.settings_cloudSync_replaceLibrary_confirm,
    );
    if (!confirmed || !mounted) return;
    final note = l10n.settings_setUpDevice_replace_backupNote(
      UnitFormatter(ref.read(settingsProvider)).formatDate(DateTime.now()),
    );
    await _run(() async {
      final end = await widget.actions.replace(
        context,
        ref,
        diveCount: dives,
        backupNote: note,
        keepInStep: _keepInStep,
      );
      if (!mounted) return;
      if (end case ReplaceJoinRefused(
        result: ReplaceJoinResult(outcome: ReplaceJoinOutcome.needsPassphrase),
      )) {
        // The library turned out locked: the step reads it again and asks.
        refreshSetUpLibrary(ref.invalidate);
      }
      final line = switch (end) {
        null => null,
        ReplaceJoinFailed() => l10n.settings_setUpDevice_replace_failed,
        ReplaceJoinRefused(:final result) => _refusal(l10n, account, result),
      };
      setState(() => _line = line);
    });
  }

  String? _refusal(
    AppLocalizations l10n,
    AccountGroup account,
    ReplaceJoinResult result,
  ) => switch (result.outcome) {
    ReplaceJoinOutcome.noLibrary => l10n.settings_setUpDevice_replace_noLibrary(
      account.label,
    ),
    ReplaceJoinOutcome.stillUploading =>
      l10n.settings_setUpDevice_replace_stillUploading,
    ReplaceJoinOutcome.newerSchema =>
      l10n.settings_setUpDevice_replace_newerSchema(
        result.newerSchemaPeerNames.values.join(', '),
      ),
    ReplaceJoinOutcome.photosBusy =>
      l10n.settings_setUpDevice_replace_photosBusy,
    ReplaceJoinOutcome.needsPassphrase || ReplaceJoinOutcome.replaced => null,
  };

  Future<void> _unlock(AccountGroup account) async {
    final secret = _secret.text;
    if (secret.isEmpty) return;
    await _run(() async {
      try {
        await widget.actions.unlock(ref, secret);
        if (!mounted) return;
        setState(() => _secretError = null);
        refreshSetUpLibrary(ref.invalidate);
      } on WrongPassphraseException {
        if (mounted) {
          setState(
            () => _secretError =
                context.l10n.settings_cloudSync_encryption_wrongPassphrase,
          );
        }
      } on Object {
        // The key could not be read at all: the account, not the secret.
        if (mounted) {
          setState(() {
            _secretError = null;
            _line = context.l10n.settings_setUpDevice_sync_unreachable(
              account.label,
            );
          });
        }
      }
    });
  }

  Future<void> _adopt(LibraryAwaitingAdoption awaiting) => _run(() async {
    final adopted = await widget.actions.adopt(context, ref, awaiting.marker);
    if (!mounted) return;
    if (adopted) {
      widget.navigation.onNext();
    } else {
      refreshSetUpLibrary(ref.invalidate);
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Watched so the account lookups this page makes stay loaded.
    final groups = ref.watch(accountGroupsProvider).value ?? const [];
    final account = ref.watch(setUpFlowProvider) ?? currentSyncGroup(groups);
    if (account == null) {
      return SetUpStepScaffold(
        title: l10n.settings_setUpDevice_sync_title,
        intro: l10n.settings_setUpDevice_sync_noAccount,
        backLabel: l10n.common_action_back,
        onBack: widget.navigation.onBack,
        primaryLabel: l10n.settings_setUpDevice_next,
        onPrimary: null,
        children: const [],
      );
    }
    final library = _connectFailed
        ? const LibraryUnreachable()
        : _connected
        ? ref.watch(setUpLibraryProvider).value
        : null;
    final (children, primaryLabel, onPrimary) = _forLibrary(
      l10n,
      account,
      library,
    );
    final message = ref.watch(syncStateProvider.select((s) => s.message));
    return SetUpStepScaffold(
      title: l10n.settings_setUpDevice_sync_title,
      intro: l10n.settings_setUpDevice_sync_signedIn(account.label),
      backLabel: l10n.common_action_back,
      onBack: widget.navigation.onBack,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      busy: _busy,
      secondary: TextButton(
        onPressed: _busy ? null : widget.navigation.onNotNow,
        child: Text(l10n.settings_setUpDevice_notNow),
      ),
      children: [
        ...children,
        if (_busy && message != null) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(message),
        ],
        if (_line != null) ...[
          const SizedBox(height: 16),
          Text(
            _line!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  /// The step's body for what the account holds, its primary button's label
  /// and what that button does.
  (List<Widget>, String, VoidCallback?) _forLibrary(
    AppLocalizations l10n,
    AccountGroup account,
    SetUpLibrary? library,
  ) => switch (library) {
    null => (
      const [Center(child: CircularProgressIndicator())],
      l10n.settings_setUpDevice_next,
      null,
    ),
    NoLibrary() => (
      [
        Text(l10n.settings_setUpDevice_sync_noLibrary(account.label)),
        _keepInStepSwitch(l10n),
      ],
      l10n.settings_setUpDevice_sync_turnOn,
      () => _firstSync(realignDiver: false),
    ),
    LibraryFound(:final localDives) => (
      [
        Text(setUpFoundSentence(l10n, account.label, library)),
        if (localDives == 0)
          Text(l10n.settings_setUpDevice_sync_foundEmpty)
        else
          SetUpLibraryChoices(
            choice: _choice,
            onChanged: (choice) => setState(() => _choice = choice),
          ),
        _keepInStepSwitch(l10n),
      ],
      localDives == 0
          ? l10n.settings_setUpDevice_sync_download
          : _choice == SetUpLibraryChoice.combine
          ? l10n.settings_setUpDevice_sync_combineAndDownload
          : l10n.settings_setUpDevice_sync_replaceAndDownload,
      localDives == 0
          ? () => _firstSync(realignDiver: true)
          : _choice == SetUpLibraryChoice.combine
          ? () => _firstSync(realignDiver: false)
          : () => _replace(account, localDives),
    ),
    LibraryLocked() => (
      [
        Text(
          l10n.setup_syncPull_locked_title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(l10n.setup_syncPull_locked_message),
        const SizedBox(height: 12),
        TextField(
          controller: _secret,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.settings_cloudSync_encryption_unlockHint,
            errorText: _secretError,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _unlock(account),
        ),
      ],
      l10n.settings_cloudSync_encryption_unlock,
      () => _unlock(account),
    ),
    LibraryIncomplete() => (
      [
        Text(
          l10n.setup_syncPull_incomplete_title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(l10n.setup_syncPull_incomplete_message),
      ],
      l10n.setup_syncPull_incomplete_retry,
      _checkAgain,
    ),
    LibraryAwaitingAdoption(:final marker) => (
      [
        Text(
          l10n.settings_cloudSync_adopt_dialogTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          l10n.settings_cloudSync_adopt_dialogContent(
            marker.displayName,
            marker.replacedAt > 0
                ? UnitFormatter(ref.read(settingsProvider)).formatDateTime(
                    DateTime.fromMillisecondsSinceEpoch(marker.replacedAt),
                    l10n: l10n,
                  )
                : '?',
          ),
        ),
      ],
      l10n.settings_cloudSync_adopt_confirm,
      () => _adopt(library),
    ),
    LibraryUnreachable() => (
      [Text(l10n.settings_setUpDevice_sync_unreachable(account.label))],
      l10n.setup_syncPull_incomplete_retry,
      _checkAgain,
    ),
  };

  Widget _keepInStepSwitch(AppLocalizations l10n) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    value: _keepInStep,
    onChanged: _busy ? null : (on) => setState(() => _keepInStep = on),
    title: Text(l10n.settings_sync_keepInStep),
    subtitle: Text(l10n.settings_setUpDevice_sync_keepInStepDetail),
  );
}
