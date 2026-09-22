import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// The "Linked profile" row on the buddy page: shows the linked local
/// profile (or "Not linked") and opens [showLinkedProfilePicker] on tap.
class LinkedProfileField extends ConsumerWidget {
  final String? ownerDiverId;
  final String? linkedDiverId;
  final ValueChanged<String?> onChanged;

  const LinkedProfileField({
    super.key,
    required this.ownerDiverId,
    required this.linkedDiverId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divers = ref.watch(allDiversProvider).value ?? const <Diver>[];
    Diver? linked;
    for (final d in divers) {
      if (d.id == linkedDiverId) linked = d;
    }
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: const Key('buddy_edit_linked_profile'),
      contentPadding: EdgeInsets.zero,
      leading: linked == null
          ? const Icon(Icons.person_outline)
          : ProfileAvatar(
              photo: linked.photo,
              initials: linked.initials,
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
            ),
      title: Text(context.l10n.buddies_field_linkedProfile),
      subtitle: Text(
        linked?.name ?? context.l10n.buddies_field_linkedProfileNone,
      ),
      trailing: linked == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              icon: const Icon(Icons.clear),
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final picked = await showLinkedProfilePicker(
          context,
          ownerDiverId: ownerDiverId,
          selectedDiverId: linkedDiverId,
        );
        if (picked == null) return;
        onChanged(picked.isEmpty ? null : picked);
      },
    );
  }
}

/// Bottom sheet listing every local profile except the owner. Returns the
/// chosen id, an empty string for "no link", or null when dismissed.
Future<String?> showLinkedProfilePicker(
  BuildContext context, {
  required String? ownerDiverId,
  String? selectedDiverId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final diversAsync = ref.watch(allDiversProvider);
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: diversAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (divers) {
              final choices = [
                for (final d in divers)
                  if (d.id != ownerDiverId) d,
              ];
              return ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.l10n.buddies_linkedProfile_pickerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.link_off),
                    title: Text(context.l10n.buddies_field_linkedProfileNone),
                    trailing: selectedDiverId == null
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, ''),
                  ),
                  for (final d in choices)
                    ListTile(
                      leading: ProfileAvatar(
                        photo: d.photo,
                        initials: d.initials,
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                      ),
                      title: Text(d.name),
                      subtitle: d.email == null ? null : Text(d.email!),
                      trailing: d.id == selectedDiverId
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, d.id),
                    ),
                ],
              );
            },
          ),
        );
      },
    ),
  );
}
