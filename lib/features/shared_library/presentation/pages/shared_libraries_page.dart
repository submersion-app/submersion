import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_role_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Club libraries: the libraries connected on this device that
/// the active profile belongs to (issue #2567).
class SharedLibrariesPage extends ConsumerWidget {
  const SharedLibrariesPage({super.key});

  static const connectRoute = '/settings/club-libraries/connect';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final libraries = ref.watch(sharedLibrariesProvider);
    final memberships = ref.watch(currentMembershipsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sharedLibrary_settings_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.sharedLibrary_connect_action,
            onPressed: () => context.push(connectRoute),
          ),
        ],
      ),
      body: switch ((libraries, memberships)) {
        (AsyncData(value: final libs), AsyncData(value: final mine)) => _body(
          context,
          libs,
          mine,
        ),
        (AsyncError(error: final e), _) ||
        (_, AsyncError(error: final e)) => Center(child: Text(e.toString())),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(
    BuildContext context,
    List<SharedLibrary> libraries,
    List<SharedLibraryMembership> memberships,
  ) {
    final l10n = context.l10n;
    final memberOf = {for (final m in memberships) m.libraryId};
    final visible = [
      for (final lib in libraries)
        if (memberOf.contains(lib.id)) lib,
    ];
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.groups_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(l10n.sharedLibrary_list_empty, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push(connectRoute),
                icon: const Icon(Icons.add),
                label: Text(l10n.sharedLibrary_connect_action),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _LibraryTile(library: visible[index]),
    );
  }
}

class _LibraryTile extends ConsumerWidget {
  const _LibraryTile({required this.library});

  final SharedLibrary library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final role = ref.watch(libraryRoleProvider(library.id)).valueOrNull;
    final names = ref.watch(libraryMemberNamesProvider(library.id)).valueOrNull;
    final parts = <String>[
      if (role != null) libraryRoleLabel(context, role),
      if (names != null) l10n.sharedLibrary_library_memberCount(names.length),
      if (library.lastSyncAt != null)
        l10n.sharedLibrary_library_lastSync(
          libraryDateLabel(ref, library.lastSyncAt!),
        )
      else
        l10n.sharedLibrary_library_neverSynced,
    ];
    return ListTile(
      leading: Icon(
        library.lastError != null ? Icons.error_outline : Icons.groups_outlined,
        color: library.lastError != null
            ? Theme.of(context).colorScheme.error
            : null,
      ),
      title: Text(library.name),
      subtitle: Text(parts.join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/settings/club-libraries/${library.id}'),
    );
  }
}
