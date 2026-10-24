import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/shared_items/profile_checkbox_tile.dart';

/// Asks who a trip or site is shared with (issue #2151): Everyone, which
/// also reaches profiles added later, or a checkbox per profile in
/// [profiles]. The two exclude each other. Returns the choice, or null when
/// cancelled. With [allowEmpty] false the confirm button stays disabled
/// until something is chosen.
Future<ItemSharing?> showShareTargetDialog(
  BuildContext context, {
  required String title,
  required String body,
  required List<Diver> profiles,
  required ItemSharing initial,
  required String confirmLabel,
  bool allowEmpty = true,
}) => showDialog<ItemSharing>(
  context: context,
  builder: (_) => _ShareTargetDialog(
    title: title,
    body: body,
    profiles: profiles,
    initial: initial,
    confirmLabel: confirmLabel,
    allowEmpty: allowEmpty,
  ),
);

/// "Not shared", "Everyone", or the chosen profiles' names sorted and
/// joined with ", ". A profile with no name in [namesById] (not loaded yet,
/// or deleted meanwhile) is left out.
String sharingSummary(
  ItemSharing sharing,
  Map<String, String> namesById,
  AppLocalizations l10n,
) {
  if (sharing.everyone) return l10n.sharedItems_sharedWith_everyone;
  final names = [for (final id in sharing.profileIds) ?namesById[id]]
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names.isEmpty ? l10n.sharedItems_sharedWith_none : names.join(', ');
}

class _ShareTargetDialog extends StatefulWidget {
  const _ShareTargetDialog({
    required this.title,
    required this.body,
    required this.profiles,
    required this.initial,
    required this.confirmLabel,
    required this.allowEmpty,
  });

  final String title;
  final String body;
  final List<Diver> profiles;
  final ItemSharing initial;
  final String confirmLabel;
  final bool allowEmpty;

  @override
  State<_ShareTargetDialog> createState() => _ShareTargetDialogState();
}

class _ShareTargetDialogState extends State<_ShareTargetDialog> {
  late ItemSharing _sharing = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final canConfirm = widget.allowEmpty || _sharing.isShared;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _sharing.everyone,
              secondary: CircleAvatar(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                child: const Icon(Icons.groups_outlined),
              ),
              title: Text(l10n.sharedItems_sharedWith_everyone),
              subtitle: Text(l10n.sharedItems_shareDialog_everyoneSubtitle),
              onChanged: (checked) => setState(() {
                _sharing = checked == true ? ItemSharing.all : ItemSharing.none;
              }),
            ),
            const Divider(),
            for (final diver in widget.profiles)
              ProfileCheckboxTile(
                diver: diver,
                value: _sharing.profileIds.contains(diver.id),
                // Ticking a profile leaves Everyone: the two exclude each
                // other.
                onChanged: (checked) => setState(() {
                  final ids = _sharing.profileIds;
                  _sharing = ItemSharing(
                    profileIds: checked
                        ? {...ids, diver.id}
                        : ids.difference({diver.id}),
                  );
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: canConfirm ? () => Navigator.pop(context, _sharing) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
