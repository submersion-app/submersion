import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/import_target_choice.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Says whose dive computer this is and which profile the download goes to,
/// with a picker to send this one download elsewhere (issue #2050).
///
/// Shown on the review step under the source card only when the computer
/// belongs to a profile other than the active one. Renders nothing while the
/// profiles load, or when the owner is no longer a profile.
class ComputerOwnerNotice extends ConsumerWidget {
  const ComputerOwnerNotice({
    super.key,
    required this.choice,
    required this.onChanged,
    this.busy = false,
  });

  final ImportTargetChoice choice;

  /// Called with the id of the profile picked for this download.
  final ValueChanged<String> onChanged;

  /// The download is being re-checked for a newly picked profile: the picker
  /// is held and shows progress until the new choice lands.
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(allDiversProvider).value ?? const [];
    final names = {for (final p in profiles) p.id: p.name};
    final owner = names[choice.ownerDiverId];
    if (owner == null) return const SizedBox.shrink();
    final chosen = names[choice.chosenDiverId];
    if (chosen == null && profiles.isNotEmpty && !busy) {
      // The chosen profile is gone (deleted elsewhere): send the download
      // back to the owner so what the notice says is where the dives go.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onChanged(choice.ownerDiverId),
      );
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.person_pin_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.universalImport_computerOwner_notice(
                    owner,
                    chosen ?? owner,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: _picker(context, profiles),
                ),
              ),
              if (busy) ...[
                const SizedBox(width: 12),
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _picker(BuildContext context, List<Diver> profiles) {
    final l10n = context.l10n;
    final ids = {for (final p in profiles) p.id};
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.universalImport_computerOwner_profileLabel,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('computer_owner_profile'),
          value: ids.contains(choice.chosenDiverId)
              ? choice.chosenDiverId
              : choice.ownerDiverId,
          isExpanded: true,
          isDense: true,
          items: [
            for (final profile in profiles)
              DropdownMenuItem(
                value: profile.id,
                child: Text(profile.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: busy
              ? null
              : (id) {
                  if (id != null && id != choice.chosenDiverId) {
                    onChanged(id);
                  }
                },
        ),
      ),
    );
  }
}
