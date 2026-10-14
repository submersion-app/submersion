import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/add_to_library_confirmation.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The connected libraries the active profile may push sites to. Read from
/// the store, not the providers: a one-shot read of a stream provider no
/// widget listens to waits forever, as Riverpod pauses it.
Future<List<SharedLibrary>> pushableLibraries(WidgetRef ref) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return const [];
  final store = ref.read(sharedLibraryStoreProvider);
  final result = <SharedLibrary>[];
  for (final library in await store.getLibraries()) {
    final membership = await store.membership(
      diverId: diverId,
      libraryId: library.id,
    );
    if (membership == null) continue;
    final role = effectiveRole(
      listed: library.roles.roleOf(membership.memberId),
      readOnlyDetected: library.writesHeld,
    );
    if (canEditLibrarySite(role)) result.add(library);
  }
  return result;
}

/// Picks one of the libraries the profile may push to: returns its id, or
/// null when cancelled or when there is none, which it says itself. With
/// exactly one library, returns it without asking (issue #2567).
Future<String?> showLibraryPickerDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final libraries = await pushableLibraries(ref);
  if (libraries.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sharedLibrary_picker_none)),
      );
    }
    return null;
  }
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

/// Picks the library [siteCount] sites go to, then confirms what will be
/// shared (issue #2567). Null when there is none, or either step is
/// cancelled.
Future<SharedLibrary?> pickLibraryToAddTo(
  BuildContext context,
  WidgetRef ref, {
  required int siteCount,
  String? siteName,
}) async {
  final libraryId = await showLibraryPickerDialog(context, ref);
  if (libraryId == null || !context.mounted) return null;
  final library = await ref
      .read(sharedLibraryStoreProvider)
      .getLibrary(libraryId);
  if (library == null || !context.mounted) return null;
  final ok = await confirmAddToLibrary(
    context,
    libraryName: library.name,
    siteCount: siteCount,
    siteName: siteName,
  );
  return ok ? library : null;
}
