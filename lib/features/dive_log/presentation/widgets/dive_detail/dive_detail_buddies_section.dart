import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_text_section.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/logged_with_tiles.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_list_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/dive_owner_display.dart';
import 'package:submersion/features/divers/presentation/widgets/dive_owner_avatar.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// The Buddies card.
class DiveBuddiesSection extends ConsumerWidget {
  const DiveBuddiesSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddiesAsync = ref.watch(buddiesForDiveProvider(dive.id));
    // Only the own-role row needs the dive's owner; it draws a placeholder
    // while the owner loads rather than holding back the whole card.
    final ownerAsync = dive.diverRoleIds.isEmpty
        ? null
        : ref.watch(diveOwnerProvider(dive.diverId));

    return buddiesAsync.when(
      data: (buddies) {
        // The dive_buddies junction is authoritative once it holds anyone.
        // The legacy free-text dives.buddy and dives.dive_master columns are
        // only a fallback for a dive whose people were never linked, such as
        // a CSV import, so such a dive is not called solo, and the section
        // offers to link the text to buddy records (#1831). A text holding
        // only a placeholder like "None" does not count.
        final showLegacyText =
            buddies.isEmpty && LegacyBuddyTextSection.hasContent(dive);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.diveLog_detail_section_buddies,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (buddies.isNotEmpty)
                      Text(
                        context.l10n.diveLog_detail_buddyCount(buddies.length),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const Divider(),
                if (ownerAsync != null)
                  _buildMyRoleTile(context, ref, ownerAsync),
                if (showLegacyText)
                  LegacyBuddyTextSection(dive: dive)
                else if (buddies.isEmpty && dive.diverRoleIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      context.l10n.diveLog_detail_soloDive,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...buddies.map((bwr) => _buildBuddyTile(context, bwr)),
                // Other profiles' logs of this outing (issue #2002).
                LoggedWithTiles(diveId: dive.id),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBuddyTile(BuildContext context, BuddyWithRole bwr) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ProfileAvatar(
        photo: bwr.buddy.photo,
        initials: bwr.buddy.initials,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      title: Text(bwr.buddy.name),
      subtitle: Text(bwr.roles.joinedLocalizedNames(context.l10n)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push('/buddies/${bwr.buddy.id}'),
    );
  }

  /// The diver's own roles on this dive (#547, #1221), shown above buddies,
  /// with the dive owner's photo and name like the edit view's Me chip
  /// (#4458).
  Widget _buildMyRoleTile(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Diver?> ownerAsync,
  ) {
    final rolesById =
        ref.watch(diveRoleMapProvider).value ?? const <String, DiveRole>{};
    final label = rolesForIds(
      dive.diverRoleIds,
      rolesById,
    ).joinedLocalizedNames(context.l10n);
    final owner = ownerAsync.value;
    final pending = isDiveOwnerPending(ownerAsync);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: DiveOwnerAvatar(diver: owner, pending: pending),
      title: Text(pending ? '' : diveOwnerLabel(owner, context.l10n)),
      subtitle: Text(label),
    );
  }
}
