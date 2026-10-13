import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/shared_library/presentation/widgets/recovery_code_dialog.dart';
import 'package:submersion/features/weight_presets/presentation/widgets/name_prompt_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// An ownership reset waiting for this member's answer (issue #2567): who
/// made themselves owner, with their key's fingerprint, and Accept. Until
/// then the device only reads the library.
class PendingResetBanner extends ConsumerWidget {
  const PendingResetBanner({
    super.key,
    required this.library,
    required this.names,
  });

  final SharedLibrary library;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pending = library.pendingRoles;
    if (pending == null || pending.owners.isEmpty) {
      return const SizedBox.shrink();
    }
    // A reset counts only when its one owner signed it: they are who the
    // member is asked to check.
    final owner = pending.signedBy ?? (pending.owners.toList()..sort()).first;
    final key = pending.approvedKeys[owner];
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(12),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sharedLibrary_owner_resetPrompt(
                library.name,
                names[owner] ?? owner,
                key == null ? '?' : LibrarySigner.fingerprint(key),
              ),
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: () => ref
                    .read(sharedLibraryMembershipServiceProvider)
                    .acceptReset(library.id),
                child: Text(l10n.sharedLibrary_owner_resetAccept),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An encrypted library this device holds no key for, or an older one
/// (issue #2567): nothing syncs until the passphrase is entered.
class LockedLibraryBanner extends ConsumerWidget {
  const LockedLibraryBanner({
    super.key,
    required this.library,
    required this.membership,
  });

  final SharedLibrary library;
  final SharedLibraryMembership? membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = membership;
    if (!library.encrypted || me == null || me.libraryKeyId == library.keyId) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(12),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              me.libraryKeyId == null
                  ? l10n.sharedLibrary_encrypted_locked(library.name)
                  : l10n.sharedLibrary_encrypted_changed(library.name),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: () => _unlock(context, ref, me),
                child: Text(l10n.sharedLibrary_encrypted_unlock),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlock(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMembership me,
  ) async {
    final secret = await promptLibrarySecret(context);
    if (secret == null || secret.isEmpty || !context.mounted) return;
    final l10n = context.l10n;
    try {
      await ref
          .read(sharedLibraryMembershipServiceProvider)
          .unlockLibrary(
            libraryId: library.id,
            diverId: me.diverId,
            secret: secret,
          );
      if (!context.mounted) return;
      ref.invalidate(currentMembershipsProvider);
      // The library's sites come in now, not at the next sync.
      await ref.read(sharedLibrarySyncProvider.notifier).syncOne(library.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(libraryErrorText(l10n, e))));
    }
  }
}

/// Keeping a library owned (issue #2567): a warning while one owner is
/// left, a new recovery code for owners, and for everyone else recovery
/// with the code or, as a last resort, a reset the members must accept.
class LibraryOwnershipSection extends ConsumerWidget {
  const LibraryOwnershipSection({
    super.key,
    required this.library,
    required this.role,
    required this.membership,
  });

  final SharedLibrary library;
  final SharedLibraryRole role;
  final SharedLibraryMembership? membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final owner = canManageLibrary(role);
    final me = membership;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (owner && library.roles.owners.length == 1)
          ListTile(
            leading: Icon(
              Icons.warning_amber_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(l10n.sharedLibrary_owner_onlyOne),
            subtitle: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => context.push(
                  '/settings/shared-libraries/${library.id}/members',
                ),
                child: Text(l10n.sharedLibrary_owner_addOwner),
              ),
            ),
          ),
        if (owner && me != null)
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.sharedLibrary_owner_newCode),
            subtitle: Text(l10n.sharedLibrary_owner_newCodeHelp),
            onTap: () => _newCode(context, ref, me),
          ),
        if (!owner && me != null) ...[
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: Text(l10n.sharedLibrary_owner_recover),
            subtitle: Text(l10n.sharedLibrary_owner_recoverHelp),
            onTap: () => _recover(context, ref, me),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.sharedLibrary_owner_reset),
            subtitle: Text(l10n.sharedLibrary_owner_resetHelp),
            onTap: () => _reset(context, ref, me),
          ),
        ],
      ],
    );
  }

  Future<void> _newCode(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMembership me,
  ) {
    // The page may rebuild this section away meanwhile (the roles warning
    // goes once new roles are written): the code, already in force, is
    // shown over the whole app, never skipped.
    final shown = Navigator.of(context, rootNavigator: true).context;
    return _run(context, () async {
      final code = await ref
          .read(sharedLibraryMembershipServiceProvider)
          .reissueRecoveryCode(libraryId: library.id, diverId: me.diverId);
      if (shown.mounted) await showRecoveryCodeDialog(shown, code);
    });
  }

  Future<void> _recover(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMembership me,
  ) async {
    final l10n = context.l10n;
    final code = await NamePromptDialog.show(
      context,
      title: l10n.sharedLibrary_owner_recover,
      label: l10n.sharedLibrary_owner_recoverPrompt,
      confirmLabel: MaterialLocalizations.of(context).okButtonLabel,
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    await _run(context, () async {
      await ref
          .read(sharedLibraryMembershipServiceProvider)
          .recoverOwnership(
            libraryId: library.id,
            diverId: me.diverId,
            code: code,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sharedLibrary_owner_recovered)),
        );
      }
    });
  }

  Future<void> _reset(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMembership me,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sharedLibrary_owner_reset),
        content: Text(l10n.sharedLibrary_owner_resetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.sharedLibrary_owner_reset),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(sharedLibraryMembershipServiceProvider)
          .resetOwnership(libraryId: library.id, diverId: me.diverId),
    );
  }

  /// Runs [action]; a refusal or an unreachable storage is said in a
  /// snack bar.
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final l10n = context.l10n;
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(libraryErrorText(l10n, e))));
    }
  }
}
