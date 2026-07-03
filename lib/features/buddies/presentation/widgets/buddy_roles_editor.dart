import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';

/// Editable list of professional credentials for the buddy edit form.
/// Controlled: the parent owns the list and receives every change via
/// [onChanged]; nothing is persisted here.
class BuddyRolesEditor extends StatelessWidget {
  final List<BuddyRoleCredential> roles;
  final ValueChanged<List<BuddyRoleCredential>> onChanged;

  const BuddyRolesEditor({
    super.key,
    required this.roles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final usedRoles = roles.map((r) => r.role).toSet();
    final availableRoles = kProfessionalBuddyRoles
        .where((r) => !usedRoles.contains(r))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (roles.isEmpty)
          Text(
            context.l10n.buddies_roles_emptyHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        for (final credential in roles) ...[
          _RoleEntry(
            key: ValueKey(credential.role),
            credential: credential,
            usedRoles: usedRoles,
            onChanged: (updated) => onChanged([
              for (final r in roles)
                if (r.role == credential.role) updated else r,
            ]),
            onRemoved: () => onChanged([
              for (final r in roles)
                if (r.role != credential.role) r,
            ]),
          ),
          const SizedBox(height: 16),
        ],
        if (availableRoles.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final now = DateTime.now();
                onChanged([
                  ...roles,
                  BuddyRoleCredential(
                    id: '',
                    buddyId: roles.isNotEmpty ? roles.first.buddyId : '',
                    role: availableRoles.first,
                    createdAt: now,
                    updatedAt: now,
                  ),
                ]);
              },
              icon: const Icon(Icons.add),
              label: Text(context.l10n.buddies_roles_addRole),
            ),
          ),
      ],
    );
  }
}

/// A single editable professional-credential row: role, agency, and
/// credential-number fields plus a remove action.
class _RoleEntry extends StatefulWidget {
  final BuddyRoleCredential credential;
  final Set<BuddyRole> usedRoles;
  final ValueChanged<BuddyRoleCredential> onChanged;
  final VoidCallback onRemoved;

  const _RoleEntry({
    super.key,
    required this.credential,
    required this.usedRoles,
    required this.onChanged,
    required this.onRemoved,
  });

  @override
  State<_RoleEntry> createState() => _RoleEntryState();
}

class _RoleEntryState extends State<_RoleEntry> {
  late TextEditingController _numberController;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(
      text: widget.credential.credentialNumber ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _RoleEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync on role change, and on an external credential-number change
    // (e.g. the merge-form seed replacing a same-role entry). A change that
    // originated from this field already matches the controller text, so
    // user typing is never clobbered.
    final incomingNumber = widget.credential.credentialNumber ?? '';
    if (oldWidget.credential.role != widget.credential.role ||
        (oldWidget.credential.credentialNumber !=
                widget.credential.credentialNumber &&
            _numberController.text != incomingNumber)) {
      _numberController.text = incomingNumber;
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credential = widget.credential;
    // Roles used by OTHER entries are excluded; the current entry's own
    // role must always remain selectable.
    final otherUsedRoles = widget.usedRoles.difference({credential.role});
    final roleOptions = kProfessionalBuddyRoles
        .where((r) => !otherUsedRoles.contains(r))
        .toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<BuddyRole>(
                    initialValue: credential.role,
                    decoration: InputDecoration(
                      labelText: context.l10n.buddies_roles_role,
                    ),
                    items: roleOptions
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      widget.onChanged(credential.copyWith(role: value));
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.buddies_roles_removeTooltip,
                  onPressed: widget.onRemoved,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CertificationAgency?>(
              initialValue: credential.agency,
              decoration: InputDecoration(
                labelText: context.l10n.buddies_roles_agency,
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(context.l10n.buddies_label_notSpecified),
                ),
                ...CertificationAgency.values.map(
                  (agency) => DropdownMenuItem(
                    value: agency,
                    child: Text(agency.displayName),
                  ),
                ),
              ],
              onChanged: (value) {
                widget.onChanged(
                  value == null
                      ? BuddyRoleCredential(
                          id: credential.id,
                          buddyId: credential.buddyId,
                          role: credential.role,
                          credentialNumber: credential.credentialNumber,
                          agency: null,
                          notes: credential.notes,
                          createdAt: credential.createdAt,
                          updatedAt: credential.updatedAt,
                        )
                      : credential.copyWith(agency: value),
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numberController,
              decoration: InputDecoration(
                labelText: context.l10n.buddies_roles_credentialNumber,
              ),
              onChanged: (value) {
                widget.onChanged(
                  value.isEmpty
                      ? BuddyRoleCredential(
                          id: credential.id,
                          buddyId: credential.buddyId,
                          role: credential.role,
                          credentialNumber: null,
                          agency: credential.agency,
                          notes: credential.notes,
                          createdAt: credential.createdAt,
                          updatedAt: credential.updatedAt,
                        )
                      : credential.copyWith(credentialNumber: value),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
