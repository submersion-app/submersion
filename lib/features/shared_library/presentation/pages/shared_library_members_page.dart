import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_role_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The members of a club library with their roles; owners change roles
/// here (issue #2567).
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sharedLibrary_library_members)),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final m = list[index];
            final role = roles.roleOf(m.memberId);
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(m.displayName.isEmpty ? m.memberId : m.displayName),
              subtitle: Text(libraryDateLabel(ref, m.joinedAt)),
              trailing: canManageLibrary(myRole)
                  ? PopupMenuButton<SharedLibraryRole>(
                      tooltip: l10n.sharedLibrary_members_setRole,
                      icon: LibraryRoleChip(role: role),
                      onSelected: (r) => _setRole(context, ref, m.memberId, r),
                      itemBuilder: (ctx) => [
                        for (final r in SharedLibraryRole.values)
                          PopupMenuItem(
                            value: r,
                            child: Text(libraryRoleLabel(ctx, r)),
                          ),
                      ],
                    )
                  : LibraryRoleChip(role: role),
            );
          },
        ),
      ),
    );
  }

  Future<void> _setRole(
    BuildContext context,
    WidgetRef ref,
    String memberId,
    SharedLibraryRole role,
  ) async {
    final l10n = context.l10n;
    final me = await ref.read(currentMembershipProvider(libraryId).future);
    if (me == null) return;
    try {
      await ref
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
