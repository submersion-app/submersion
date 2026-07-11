import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';

/// Result wrapper distinguishing "cancelled" (showDiveRoleSelector returns
/// null) from "explicitly chose no role" (DiveRoleSelection(null)).
class DiveRoleSelection {
  final DiveRole? role;
  const DiveRoleSelection(this.role);
}

/// Bottom sheet listing [roles] (credential-backed ones first), with an
/// optional "No role" entry and an optional "Add custom role..." row that
/// creates a role via [onCreateCustomRole] and returns it selected.
Future<DiveRoleSelection?> showDiveRoleSelector(
  BuildContext context, {
  required String title,
  required List<DiveRole> roles,
  Set<String> credentialRoleIds = const {},
  bool allowNone = false,
  String? selectedRoleId,
  Future<DiveRole?> Function(String name)? onCreateCustomRole,
}) {
  final orderedRoles = [
    ...roles.where((r) => credentialRoleIds.contains(r.id)),
    ...roles.where((r) => !credentialRoleIds.contains(r.id)),
  ];
  return showModalBottomSheet<DiveRoleSelection>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const Divider(),
            if (allowNone)
              ListTile(
                leading: Icon(
                  selectedRoleId == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selectedRoleId == null
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                title: Text(ctx.l10n.buddies_picker_noRole),
                onTap: () => Navigator.pop(ctx, const DiveRoleSelection(null)),
              ),
            ...orderedRoles.map(
              (role) => ListTile(
                leading: Icon(
                  credentialRoleIds.contains(role.id)
                      ? Icons.workspace_premium
                      : role.id == selectedRoleId
                      ? Icons.radio_button_checked
                      : Icons.person,
                  color: role.id == selectedRoleId
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                title: Text(role.localizedName(ctx.l10n)),
                onTap: () => Navigator.pop(ctx, DiveRoleSelection(role)),
              ),
            ),
            if (onCreateCustomRole != null)
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(ctx.l10n.buddies_picker_addCustomRole),
                onTap: () async {
                  final created = await _showAddCustomRoleDialog(
                    ctx,
                    onCreateCustomRole,
                  );
                  if (created != null && ctx.mounted) {
                    Navigator.pop(ctx, DiveRoleSelection(created));
                  }
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

Future<DiveRole?> _showAddCustomRoleDialog(
  BuildContext context,
  Future<DiveRole?> Function(String name) onCreate,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => const _AddCustomRoleDialog(),
  );
  if (name == null || name.isEmpty) return null;
  return onCreate(name);
}

class _AddCustomRoleDialog extends StatefulWidget {
  const _AddCustomRoleDialog();

  @override
  State<_AddCustomRoleDialog> createState() => _AddCustomRoleDialogState();
}

class _AddCustomRoleDialogState extends State<_AddCustomRoleDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.diveRoles_addDialog_title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: context.l10n.diveRoles_addDialog_nameLabel,
          hintText: context.l10n.diveRoles_addDialog_nameHint,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_action_cancel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(context.l10n.diveRoles_addDialog_addButton),
        ),
      ],
    );
  }
}
