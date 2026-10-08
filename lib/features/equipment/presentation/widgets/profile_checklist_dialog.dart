import 'package:flutter/material.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Asks which of [profiles] to pick (issue #2046). Returns the checked ids,
/// or null when cancelled. With [allowEmpty] false the confirm button stays
/// disabled until at least one profile is checked.
Future<Set<String>?> showProfileChecklistDialog(
  BuildContext context, {
  required String title,
  required String body,
  required List<Diver> profiles,
  required Set<String> initiallySelected,
  required String confirmLabel,
  bool allowEmpty = true,
}) => showDialog<Set<String>>(
  context: context,
  builder: (_) => _ProfileChecklistDialog(
    title: title,
    body: body,
    profiles: profiles,
    initiallySelected: initiallySelected,
    confirmLabel: confirmLabel,
    allowEmpty: allowEmpty,
  ),
);

class _ProfileChecklistDialog extends StatefulWidget {
  final String title;
  final String body;
  final List<Diver> profiles;
  final Set<String> initiallySelected;
  final String confirmLabel;
  final bool allowEmpty;

  const _ProfileChecklistDialog({
    required this.title,
    required this.body,
    required this.profiles,
    required this.initiallySelected,
    required this.confirmLabel,
    required this.allowEmpty,
  });

  @override
  State<_ProfileChecklistDialog> createState() =>
      _ProfileChecklistDialogState();
}

class _ProfileChecklistDialogState extends State<_ProfileChecklistDialog> {
  late Set<String> _selected = {...widget.initiallySelected};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canConfirm = widget.allowEmpty || _selected.isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body),
            const SizedBox(height: 12),
            for (final diver in widget.profiles)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(diver.id),
                secondary: ProfileAvatar(
                  photo: diver.photo,
                  initials: diver.initials,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                ),
                title: Text(diver.name),
                onChanged: (checked) => setState(() {
                  _selected = checked == true
                      ? {..._selected, diver.id}
                      : _selected.difference({diver.id});
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () => Navigator.pop(context, {..._selected})
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
