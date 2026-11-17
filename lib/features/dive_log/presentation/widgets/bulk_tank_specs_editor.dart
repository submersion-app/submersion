import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart' show TankRole;
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_tank_slot_roles_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bulk edit of the cylinders the selected dives already have (#797).
///
/// A [TankEditor] supplies the values and a chip per [TankSpecField] says which
/// of them to write; everything unchecked, and start/end pressure always, is
/// left as it is on each dive. This is the "Update" arm of the tanks collection
/// edit, alongside Add (append a tank) and Replace (discard and re-create).
///
/// The spec state lives in the parent, matching how the bulk form owns its
/// other collection editors. Only the name field's controller is local, since
/// [TankEditor] has no name input of its own.
class BulkTankSpecsEditor extends StatefulWidget {
  const BulkTankSpecsEditor({
    super.key,
    required this.specs,
    required this.fields,
    required this.slotRoles,
    required this.onSpecsChanged,
    required this.onFieldsChanged,
    required this.onSlotRolesChanged,
  });

  /// The template cylinder. Only the attributes named in [fields] are read.
  final DiveTank specs;

  /// Which attributes to overwrite. Empty means the edit does nothing.
  final Set<TankSpecField> fields;

  /// A role per tank position in place of the template's single role, or
  /// null for the same role on every tank (issue #4412). Read only while
  /// [fields] has [TankSpecField.role].
  final List<TankRole>? slotRoles;

  final ValueChanged<DiveTank> onSpecsChanged;
  final ValueChanged<Set<TankSpecField>> onFieldsChanged;
  final ValueChanged<List<TankRole>?> onSlotRolesChanged;

  /// Where "Role by tank position" starts: the sidemount pair that asked
  /// for it.
  static const defaultSlotRoles = [
    TankRole.sidemountLeft,
    TankRole.sidemountRight,
  ];

  @override
  State<BulkTankSpecsEditor> createState() => _BulkTankSpecsEditorState();
}

class _BulkTankSpecsEditorState extends State<BulkTankSpecsEditor> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.specs.name ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _label(TankSpecField f) => switch (f) {
    TankSpecField.preset => context.l10n.diveLog_bulkEdit_tankFieldPreset,
    TankSpecField.role => context.l10n.diveLog_bulkEdit_tankFieldRole,
    TankSpecField.volume => context.l10n.diveLog_bulkEdit_tankFieldVolume,
    TankSpecField.workingPressure =>
      context.l10n.diveLog_bulkEdit_tankFieldWorkingPressure,
    TankSpecField.material => context.l10n.diveLog_bulkEdit_tankFieldMaterial,
    TankSpecField.gasMix => context.l10n.diveLog_bulkEdit_tankFieldGasMix,
    TankSpecField.name => context.l10n.diveLog_bulkEdit_tankFieldName,
  };

  void _toggle(TankSpecField f, bool selected) {
    final next = Set<TankSpecField>.from(widget.fields);
    if (selected) {
      next.add(f);
    } else {
      next.remove(f);
    }
    widget.onFieldsChanged(next);
  }

  void _onNameChanged(String value) {
    final trimmed = value.trim();
    widget.onSpecsChanged(
      trimmed.isEmpty
          ? widget.specs.copyWith(clearName: true)
          : widget.specs.copyWith(name: trimmed),
    );
  }

  Widget _roleLayout() {
    final l10n = context.l10n;
    final byPosition = widget.slotRoles != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(l10n.diveLog_bulkEdit_tankRoleSameForAll),
              ),
              ButtonSegment(
                value: true,
                label: Text(l10n.diveLog_bulkEdit_tankRoleByPosition),
              ),
            ],
            selected: {byPosition},
            onSelectionChanged: (s) => widget.onSlotRolesChanged(
              s.first ? BulkTankSpecsEditor.defaultSlotRoles : null,
            ),
          ),
          if (byPosition) ...[
            const SizedBox(height: 12),
            BulkTankSlotRolesEditor(
              roles: widget.slotRoles!,
              onChanged: widget.onSlotRolesChanged,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rolesByPosition =
        widget.fields.contains(TankSpecField.role) && widget.slotRoles != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Text(
            context.l10n.diveLog_bulkEdit_tankSpecsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in TankSpecField.values)
                FilterChip(
                  label: Text(_label(f)),
                  selected: widget.fields.contains(f),
                  onSelected: (selected) => _toggle(f, selected),
                ),
            ],
          ),
        ),
        if (widget.fields.contains(TankSpecField.role)) _roleLayout(),
        // TankEditor carries every spec except the tank name, which it passes
        // through untouched, so the name input has to live here.
        if (widget.fields.contains(TankSpecField.name))
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: TextFormField(
              key: const ValueKey('bulk-tank-spec-name'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.diveLog_bulkEdit_tankFieldName,
                isDense: true,
              ),
              onChanged: _onNameChanged,
            ),
          ),
        // Picking a preset here fills volume, working pressure, and material in
        // one go, which is the common case: a whole import missing its
        // cylinder identity.
        TankEditor(
          tank: widget.specs,
          tankNumber: 1,
          // The values go to every tank on every selected dive, so the card
          // must not read as the dives' first tank (#3367).
          headerTitle: context.l10n.diveLog_bulkEdit_tankSpecsTemplateTitle,
          onChanged: widget.onSpecsChanged,
          canRemove: false,
          showPressures: false,
          // Per-position roles replace the template's one role (#4412).
          showRole: !rolesByPosition,
        ),
      ],
    );
  }
}
