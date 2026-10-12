import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The localised name of a role (issue #2567).
String libraryRoleLabel(BuildContext context, SharedLibraryRole role) =>
    switch (role) {
      SharedLibraryRole.reader => context.l10n.sharedLibrary_role_reader,
      SharedLibraryRole.editor => context.l10n.sharedLibrary_role_editor,
      SharedLibraryRole.owner => context.l10n.sharedLibrary_role_owner,
    };

/// A small chip naming a member's role.
class LibraryRoleChip extends StatelessWidget {
  const LibraryRoleChip({super.key, required this.role});

  final SharedLibraryRole role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(libraryRoleLabel(context, role)),
      visualDensity: VisualDensity.compact,
      backgroundColor: role == SharedLibraryRole.owner
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
    );
  }
}

/// A date for attribution lines and sync status, in the diver's date format.
String libraryDateLabel(WidgetRef ref, DateTime when) =>
    UnitFormatter(ref.watch(settingsProvider)).formatDate(when.toLocal());
