import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_role_chip.dart';
import 'package:submersion/features/weight_presets/presentation/widgets/name_prompt_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';

/// One connected club library (issue #2567): status, display name, role,
/// members, suggestions, adding personal sites, leaving.
class SharedLibraryPage extends ConsumerWidget {
  const SharedLibraryPage({super.key, required this.libraryId});

  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final libraries = ref.watch(sharedLibrariesProvider).valueOrNull;
    SharedLibrary? library;
    for (final l in libraries ?? const <SharedLibrary>[]) {
      if (l.id == libraryId) library = l;
    }
    if (library == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.sharedLibrary_settings_title)),
        body: libraries == null
            ? const Center(child: CircularProgressIndicator())
            : Center(child: Text(l10n.sharedLibrary_list_empty)),
      );
    }
    final role =
        ref.watch(libraryRoleProvider(libraryId)).valueOrNull ??
        SharedLibraryRole.reader;
    final membership = ref
        .watch(currentMembershipProvider(libraryId))
        .valueOrNull;
    final names = ref.watch(libraryMemberNamesProvider(libraryId)).valueOrNull;
    final pending =
        ref
            .watch(pendingIncomingSuggestionCountProvider(libraryId))
            .valueOrNull ??
        0;
    final syncState = ref.watch(sharedLibrarySyncProvider);
    final syncing =
        syncState.syncing && syncState.syncingLibraryId == libraryId;

    return Scaffold(
      appBar: AppBar(title: Text(library.name)),
      body: ListView(
        children: [
          if (library.readOnlyDetected)
            _Banner(
              icon: Icons.lock_outline,
              text: l10n.sharedLibrary_library_readOnlyBanner,
            ),
          if (library.lastError != null)
            _Banner(
              icon: Icons.error_outline,
              text: l10n.sharedLibrary_library_errorBanner(library.lastError!),
              isError: true,
            ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(
              library.lastSyncAt == null
                  ? l10n.sharedLibrary_library_neverSynced
                  : l10n.sharedLibrary_library_lastSync(
                      libraryDateLabel(ref, library.lastSyncAt!),
                    ),
            ),
            subtitle: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonal(
                onPressed: syncing
                    ? null
                    : () => ref
                          .read(sharedLibrarySyncProvider.notifier)
                          .syncOne(libraryId),
                child: syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.sharedLibrary_library_syncNow),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(l10n.sharedLibrary_library_rename_label),
            subtitle: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(membership?.displayName ?? ''),
                LibraryRoleChip(role: role),
              ],
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: membership == null
                ? null
                : () => _rename(context, ref, membership),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(l10n.sharedLibrary_library_members),
            subtitle: names == null
                ? null
                : Text(l10n.sharedLibrary_library_memberCount(names.length)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('/settings/club-libraries/$libraryId/members'),
          ),
          if (canManageLibrary(role))
            ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: Text(l10n.sharedLibrary_library_suggestions),
              trailing: pending > 0
                  ? Badge.count(count: pending)
                  : const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/settings/club-libraries/$libraryId/suggestions',
              ),
            ),
          if (canEditLibrarySite(role))
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(l10n.sharedLibrary_library_addMySites),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _addMySites(context, ref, library!),
            ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.sharedLibrary_library_leave,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _leave(context, ref, library!),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMembership membership,
  ) async {
    final l10n = context.l10n;
    final name = await NamePromptDialog.show(
      context,
      title: l10n.sharedLibrary_library_rename_label,
      label: l10n.sharedLibrary_library_rename_label,
      confirmLabel: MaterialLocalizations.of(context).okButtonLabel,
      initialValue: membership.displayName,
    );
    if (name == null || name == membership.displayName) return;
    try {
      await ref
          .read(sharedLibraryMembershipServiceProvider)
          .rename(
            libraryId: libraryId,
            diverId: membership.diverId,
            displayName: name,
          );
    } catch (e) {
      // The member card lives in the library folder: offline, it fails.
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(libraryErrorText(l10n, e))));
      }
    }
    ref.invalidate(currentMembershipsProvider);
  }

  Future<void> _addMySites(
    BuildContext context,
    WidgetRef ref,
    SharedLibrary library,
  ) async {
    final l10n = context.l10n;
    final sites = await ref.read(sitesProvider.future);
    final activeDiver = ref.read(validatedCurrentDiverIdProvider);
    // The profile's own sites: another profile's shared site would be taken
    // from its owner by the push.
    final personal = [
      for (final s in sites)
        if (!s.isLibrarySite &&
            canDestroySharedItemOnceKnown(activeDiver, ownerId: s.diverId) ==
                true)
          s,
    ];
    if (!context.mounted) return;
    final chosen = <String>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(l10n.sharedLibrary_library_addMySites)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton(
                    onPressed: chosen.isEmpty
                        ? null
                        : () => Navigator.of(ctx).pop(true),
                    child: Text(l10n.sharedLibrary_site_addToLibrary),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in personal)
                      CheckboxListTile(
                        value: chosen.contains(s.id),
                        title: Text(s.name),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            chosen.add(s.id);
                          } else {
                            chosen.remove(s.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || chosen.isEmpty) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;
    final publisher = ref.read(sharedSitePublisherProvider);
    try {
      for (final id in chosen) {
        await publisher.push(
          siteId: id,
          libraryId: library.id,
          diverId: diverId,
        );
      }
    } catch (e) {
      // A role lowered since the page loaded, or a site no longer this
      // profile's: the service refuses, and says so here.
      ref.invalidate(sitesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(libraryErrorText(l10n, e))));
      }
      return;
    }
    ref.invalidate(sitesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.sharedLibrary_site_added(library.name))),
    );
  }

  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    SharedLibrary library,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.sharedLibrary_library_leaveConfirm_title(library.name),
        ),
        content: Text(l10n.sharedLibrary_library_leaveConfirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.sharedLibrary_library_leave),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;
    try {
      await ref
          .read(sharedLibraryMembershipServiceProvider)
          .leave(libraryId: library.id, diverId: diverId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(libraryErrorText(l10n, e))));
      return;
    }
    ref.invalidate(currentMembershipsProvider);
    ref.invalidate(sitesProvider);
    if (context.mounted) context.pop();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.isError = false});

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: isError ? scheme.errorContainer : scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: isError ? scheme.onErrorContainer : null),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
