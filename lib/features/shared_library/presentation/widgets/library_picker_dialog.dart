import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The connected libraries the active profile may push sites to.
Future<List<SharedLibrary>> pushableLibraries(WidgetRef ref) async {
  final libraries = await ref.read(sharedLibrariesProvider.future);
  final memberships = await ref.read(currentMembershipsProvider.future);
  final mine = {for (final m in memberships) m.libraryId};
  final result = <SharedLibrary>[];
  for (final l in libraries) {
    if (!mine.contains(l.id)) continue;
    final role = await ref.read(libraryRoleProvider(l.id).future);
    if (canEditLibrarySite(role)) result.add(l);
  }
  return result;
}

/// Picks one of the libraries the profile may push to: returns its id, or
/// null when cancelled. With exactly one library, returns it without
/// asking (issue #2567).
Future<String?> showLibraryPickerDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final libraries = await pushableLibraries(ref);
  if (libraries.isEmpty) return null;
  if (libraries.length == 1) return libraries.single.id;
  if (!context.mounted) return null;
  final l10n = context.l10n;
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.sharedLibrary_site_chooseLibrary),
      children: [
        for (final l in libraries)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(l.id),
            child: Row(
              children: [
                const Icon(Icons.groups_outlined),
                const SizedBox(width: 12),
                Expanded(child: Text(l.name)),
              ],
            ),
          ),
      ],
    ),
  );
}
