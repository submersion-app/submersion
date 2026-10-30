import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/member_removal.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_role_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The members of a shared site library with their roles; owners change roles
/// here (issue #2567) and remove members or allow them back (issue #3481).
class SharedLibraryMembersPage extends ConsumerWidget {
  const SharedLibraryMembersPage({super.key, required this.libraryId});

  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(libraryMembersProvider(libraryId));
    final myRole =
        ref.watch(libraryRoleProvider(libraryId)).valueOrNull ??
        SharedLibraryRole.reader;
    final libraries = ref.watch(sharedLibrariesProvider).valueOrNull;
    var roles = SharedLibraryRoles.empty;
    for (final l in libraries ?? const <SharedLibrary>[]) {
      if (l.id == libraryId) roles = l.roles;
    }
    final owner = canManageLibrary(myRole);
    final me = ref.watch(currentMembershipProvider(libraryId)).value?.memberId;
    final removals =
        ref.watch(libraryRemovalsProvider(libraryId)).value ??
        const <MemberRemoval>[];
    final removed = {for (final r in removals) r.memberId};
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sharedLibrary_library_members)),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          // Approved: a genuine card whose key the owners approved. Only
          // those members' edits count, so only they are listed to all.
          // Someone removed is listed only under Removed, whatever card
          // or role is still about.
          final approved = [
            for (final m in list)
              if (isApprovedMember(m, roles) && !removed.contains(m.memberId))
                m,
          ];
          final pending = [
            for (final m in list)
              if (!isApprovedMember(m, roles) && !removed.contains(m.memberId))
                m,
          ];
          final cards = {for (final m in list) m.memberId};
          final departed = [
            for (final id in {...roles.owners, ...roles.editors})
              if (!cards.contains(id) && !removed.contains(id)) id,
          ]..sort();
          return ListView(
            children: [
              for (final m in approved) ...[
                _memberTile(
                  context,
                  ref,
                  m,
                  roles.roleOf(m.memberId),
                  owner,
                  removable: owner && me != null && m.memberId != me,
                ),
                const Divider(height: 1),
              ],
              if (owner && pending.isNotEmpty) ...[
                _Header(l10n.sharedLibrary_members_pending),
                for (final m in pending) _pendingTile(context, ref, m),
              ],
              if (owner && departed.isNotEmpty) ...[
                _Header(l10n.sharedLibrary_members_left),
                for (final id in departed)
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined),
                    title: Text(id),
                    trailing: LibraryRoleChip(role: roles.roleOf(id)),
                    subtitle: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () =>
                            _setRole(context, id, SharedLibraryRole.reader),
                        child: Text(l10n.sharedLibrary_members_removeRole),
                      ),
                    ),
                  ),
              ],
              if (owner && removals.isNotEmpty) ...[
                _Header(l10n.sharedLibrary_members_removedHeader),
                for (final r in removals) _removedTile(context, ref, r),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _memberTile(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMember m,
    SharedLibraryRole role,
    bool owner, {
    required bool removable,
  }) {
    final l10n = context.l10n;
    final name = m.displayName.isEmpty ? m.memberId : m.displayName;
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(name),
      subtitle: Text(libraryDateLabel(ref, m.joinedAt)),
      trailing: owner
          // A role, or [_removeChoice]: one menu for everything an owner
          // does to an approved member.
          ? PopupMenuButton<Object>(
              tooltip: l10n.sharedLibrary_members_setRole,
              icon: LibraryRoleChip(role: role),
              onSelected: (choice) => choice is SharedLibraryRole
                  ? _setRole(context, m.memberId, choice)
                  : _confirmRemove(context, m.memberId, name),
              itemBuilder: (ctx) => [
                for (final r in SharedLibraryRole.values)
                  PopupMenuItem<Object>(
                    value: r,
                    child: Text(libraryRoleLabel(ctx, r)),
                  ),
                if (removable) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem<Object>(
                    value: _removeChoice,
                    child: Text(l10n.sharedLibrary_members_remove),
                  ),
                ],
              ],
            )
          : LibraryRoleChip(role: role),
    );
  }

  /// The [_memberTile] menu's value for Remove.
  static const _removeChoice = #remove;

  /// Someone an owner removed: when, and Allow back, which lets their next
  /// sync bring them back to wait for approval.
  Widget _removedTile(BuildContext context, WidgetRef ref, MemberRemoval r) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.person_remove_outlined),
      title: Text(r.displayName.isEmpty ? r.memberId : r.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sharedLibrary_members_removedOn(
              libraryDateLabel(ref, r.removedAt),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => _act(
                context,
                (service, me) => service.allowBack(
                  libraryId: libraryId,
                  memberId: r.memberId,
                  actingMemberId: me,
                ),
              ),
              child: Text(l10n.sharedLibrary_members_allowBack),
            ),
          ),
        ],
      ),
    );
  }

  /// Asks first: what stays, and what a removal cannot stop.
  Future<void> _confirmRemove(
    BuildContext context,
    String memberId,
    String name,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sharedLibrary_members_removeTitle(name)),
        content: Text(l10n.sharedLibrary_members_removeBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.sharedLibrary_members_removeConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _act(
      context,
      (service, me) => service.removeMember(
        libraryId: libraryId,
        memberId: memberId,
        actingMemberId: me,
      ),
    );
  }

  /// A member whose key no owner approved yet: name, the key's
  /// fingerprint to compare in person, Approve and Reject.
  Widget _pendingTile(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMember m,
  ) {
    final l10n = context.l10n;
    final name = m.displayName.isEmpty ? m.memberId : m.displayName;
    final key = m.cardVerified ? m.publicKey : null;
    return ListTile(
      leading: const Icon(Icons.hourglass_empty),
      title: Text(name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key == null
                ? l10n.sharedLibrary_members_unsignedCard
                : l10n.sharedLibrary_members_fingerprint(
                    LibrarySigner.fingerprint(key),
                  ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _reject(context, ref, m.memberId, name),
                child: Text(l10n.sharedLibrary_members_reject),
              ),
              if (key != null)
                FilledButton.tonal(
                  onPressed: () => _act(
                    context,
                    (service, me) => service.approveMember(
                      libraryId: libraryId,
                      memberId: m.memberId,
                      actingMemberId: me,
                      publicKey: key,
                    ),
                  ),
                  child: Text(l10n.sharedLibrary_members_approve),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    String memberId,
    String name,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sharedLibrary_members_rejectTitle(name)),
        content: Text(l10n.sharedLibrary_members_rejectBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.sharedLibrary_members_reject),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _act(
      context,
      (service, me) => service.rejectMember(
        libraryId: libraryId,
        memberId: memberId,
        actingMemberId: me,
      ),
    );
  }

  /// Runs [action] as this profile's member id; a refusal or an offline
  /// storage is said in a snack bar.
  Future<void> _act(
    BuildContext context,
    Future<void> Function(SharedLibraryMembershipService service, String me)
    action,
  ) async {
    final l10n = context.l10n;
    // Kept from before the awaits: the page may close meanwhile, and its
    // ref is no use after that.
    final container = ProviderScope.containerOf(context, listen: false);
    final me = await container.read(
      currentMembershipProvider(libraryId).future,
    );
    if (me == null) return;
    try {
      await action(
        container.read(sharedLibraryMembershipServiceProvider),
        me.memberId,
      );
      container.invalidate(libraryMembersProvider(libraryId));
    } catch (e) {
      // A refusal may have refreshed the list (a member's new key to
      // compare): show it as it stands.
      container.invalidate(libraryMembersProvider(libraryId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(libraryErrorText(l10n, e))));
    }
  }

  Future<void> _setRole(
    BuildContext context,
    String memberId,
    SharedLibraryRole role,
  ) async {
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final me = await container.read(
      currentMembershipProvider(libraryId).future,
    );
    if (me == null) return;
    try {
      await container
          .read(sharedLibraryMembershipServiceProvider)
          .setRole(
            libraryId: libraryId,
            actingMemberId: me.memberId,
            memberId: memberId,
            role: role,
          );
    } catch (e) {
      // setRole reads and writes roles.json, so it fails offline too.
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(libraryErrorText(l10n, e))));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
