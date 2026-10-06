import 'package:flutter/material.dart';

import 'package:submersion/core/built_ins/visible_built_ins.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/domain/services/dive_role_set.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';

/// Bottom sheet for picking the roles a person holds on a dive (issue
/// #1221). Every row is a checkbox; Done returns the ticked roles in
/// DiveRoleSet order, and dismissing returns null so the caller changes
/// nothing. Ticking Solo clears the rest and ticking anything else clears
/// Solo ([DiveRoleSet.toggle]). Credential-backed roles come first.
/// [allowEmpty] adds a "No role" row that clears every tick (the diver's own
/// role); a buddy's caller maps an empty result to Buddy. "Add custom
/// role..." creates a role via [onCreateCustomRole] and ticks it.
Future<List<DiveRole>?> showDiveRoleSelector(
  BuildContext context, {
  required String title,
  required List<DiveRole> roles,
  Set<String> credentialRoleIds = const {},
  bool allowEmpty = false,
  List<String> selectedRoleIds = const [],
  Future<DiveRole?> Function(String name)? onCreateCustomRole,

  /// Built-in roles the diver hid from the pickers (issue #401). A ticked
  /// role stays even when hidden.
  Set<String> hiddenRoleIds = const {},

  /// Roles to offer even when hidden: the ones the record had when its
  /// editor opened, so a change can be undone in place.
  Iterable<String?> keepRoleIds = const [],
}) {
  final shownRoles = visibleBuiltIns(
    roles,
    hiddenRoleIds,
    isBuiltIn: (r) => r.isBuiltIn,
    idOf: (r) => r.id,
    keep: [...selectedRoleIds, ...keepRoleIds],
  );
  return showModalBottomSheet<List<DiveRole>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _DiveRoleSelectorSheet(
      title: title,
      roles: shownRoles,
      credentialRoleIds: credentialRoleIds,
      allowEmpty: allowEmpty,
      selectedRoleIds: selectedRoleIds,
      onCreateCustomRole: onCreateCustomRole,
    ),
  );
}

class _DiveRoleSelectorSheet extends StatefulWidget {
  const _DiveRoleSelectorSheet({
    required this.title,
    required this.roles,
    required this.credentialRoleIds,
    required this.allowEmpty,
    required this.selectedRoleIds,
    required this.onCreateCustomRole,
  });

  final String title;
  final List<DiveRole> roles;
  final Set<String> credentialRoleIds;
  final bool allowEmpty;
  final List<String> selectedRoleIds;
  final Future<DiveRole?> Function(String name)? onCreateCustomRole;

  @override
  State<_DiveRoleSelectorSheet> createState() => _DiveRoleSelectorSheetState();
}

class _DiveRoleSelectorSheetState extends State<_DiveRoleSelectorSheet> {
  late List<String> _ticked = DiveRoleSet.normalize(widget.selectedRoleIds);
  late final List<DiveRole> _roles = [...widget.roles];

  List<DiveRole> get _ordered => [
    ..._roles.where((r) => widget.credentialRoleIds.contains(r.id)),
    ..._roles.where((r) => !widget.credentialRoleIds.contains(r.id)),
  ];

  void _done() {
    final byId = {for (final r in _roles) r.id: r};
    Navigator.pop(context, [
      for (final id in _ticked) byId[id] ?? DiveRole.synthetic(id),
    ]);
  }

  Future<void> _addCustomRole() async {
    final created = await _showAddCustomRoleDialog(
      context,
      widget.onCreateCustomRole!,
    );
    if (created == null || !mounted) return;
    setState(() {
      if (!_roles.any((r) => r.id == created.id)) _roles.add(created);
      if (!_ticked.contains(created.id)) {
        _ticked = DiveRoleSet.toggle(_ticked, created.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _done,
                    child: Text(l10n.common_action_done),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (widget.allowEmpty)
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(l10n.buddies_picker_noRole),
                selected: _ticked.isEmpty,
                onTap: () => setState(() => _ticked = const []),
              ),
            for (final role in _ordered)
              CheckboxListTile(
                value: _ticked.contains(role.id),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: widget.credentialRoleIds.contains(role.id)
                    ? const Icon(Icons.workspace_premium)
                    : null,
                title: Text(role.localizedName(l10n)),
                onChanged: (_) => setState(
                  () => _ticked = DiveRoleSet.toggle(_ticked, role.id),
                ),
              ),
            if (widget.onCreateCustomRole != null)
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.buddies_picker_addCustomRole),
                onTap: _addCustomRole,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
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
