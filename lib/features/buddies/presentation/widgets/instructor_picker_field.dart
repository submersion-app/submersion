import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';

/// Dropdown for picking a certification/course instructor from the buddy
/// list. Buddies holding an instructor credential are grouped first and
/// annotated with it; any buddy remains selectable (autofills name only).
class InstructorPickerField extends ConsumerWidget {
  final String? instructorId;
  final void Function(Buddy? buddy, BuddyRoleCredential? credential) onSelected;

  const InstructorPickerField({
    super.key,
    required this.instructorId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddiesAsync = ref.watch(allBuddiesProvider);
    final rolesAsync = ref.watch(allBuddyRolesProvider);
    final buddies = buddiesAsync.value ?? const <Buddy>[];
    final rolesByBuddy =
        rolesAsync.value ?? const <String, List<BuddyRoleCredential>>{};
    if (buddies.isEmpty) return const SizedBox.shrink();

    BuddyRoleCredential? instructorCredential(String buddyId) {
      final credentials = rolesByBuddy[buddyId];
      if (credentials == null) return null;
      for (final c in credentials) {
        if (c.role == BuddyRole.instructor) return c;
      }
      return null;
    }

    final credentialed = buddies
        .where((b) => instructorCredential(b.id) != null)
        .toList();
    final others = buddies
        .where((b) => instructorCredential(b.id) == null)
        .toList();
    final ordered = [...credentialed, ...others];
    // Guard against a stale instructorId (buddy deleted / not yet synced).
    final validValue = ordered.any((b) => b.id == instructorId)
        ? instructorId
        : null;

    return DropdownButtonFormField<String?>(
      key: ValueKey(validValue),
      initialValue: validValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.buddies_instructorPicker_label,
        prefixIcon: const Icon(Icons.people),
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(context.l10n.buddies_instructorPicker_none),
        ),
        ...ordered.map((buddy) {
          final credential = instructorCredential(buddy.id);
          final label = credential == null
              ? buddy.name
              : '${buddy.name} (${credential.displayLabel})';
          return DropdownMenuItem(
            value: buddy.id,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (value) {
        if (value == null) {
          onSelected(null, null);
          return;
        }
        final buddy = ordered.firstWhere((b) => b.id == value);
        onSelected(buddy, instructorCredential(buddy.id));
      },
    );
  }
}
