import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_members_editor.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_bundle_sections.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_geofences_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The equipment set page's card editors (issue #4527, phase 3). Each sets
/// only its own card's values, with the old edit form's widgets and rules.

/// A text binding of [field], whose text is its value.
FieldTextBinding<EquipmentSet, String> _bindText(
  EditSession<EquipmentSet> session,
  EditField<EquipmentSet, String> field,
) => FieldTextBinding.plain(session: session, field: field, format: (v) => v);

/// The header block: the set's name (required), description, default and
/// auto-apply on computer import; the count of what it applies, read only.
class EquipmentSetHeaderEditor extends ConsumerStatefulWidget {
  const EquipmentSetHeaderEditor({super.key, required this.session});

  final EditSession<EquipmentSet> session;

  @override
  ConsumerState<EquipmentSetHeaderEditor> createState() =>
      _EquipmentSetHeaderEditorState();
}

class _EquipmentSetHeaderEditorState
    extends ConsumerState<EquipmentSetHeaderEditor> {
  EditSession<EquipmentSet> get _session => widget.session;

  late final _name = _bindText(_session, setNameField);
  late final _description = _bindText(_session, setDescriptionField);

  // The editor rebuilds itself on each change to the sitting, so the
  // providers its count reads are read in its own build.
  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final set = _session.working;
    final count =
        setItemsShown(ref, set, _session.stored)?.length ?? set.itemCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('set-edit-name'),
          controller: _name.controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.equipment_setEdit_nameLabel,
            hintText: l10n.equipment_setEdit_nameHint,
            prefixIcon: const Icon(Icons.folder),
            errorText: setNameValid(set.name)
                ? null
                : l10n.equipment_setEdit_nameValidation,
          ),
        ),
        const SizedBox(height: 16),
        MarkdownNotesField(
          key: const ValueKey('set-edit-description'),
          controller: _description.controller,
          decoration: InputDecoration(
            labelText: l10n.equipment_setEdit_descriptionLabel,
            prefixIcon: const Icon(Icons.description),
            hintText: l10n.equipment_setEdit_descriptionHint,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('set-edit-default'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.equipment_setEdit_defaultSwitch_title),
          subtitle: Text(l10n.equipment_setEdit_defaultSwitch_subtitle),
          value: set.isDefault,
          onChanged: (v) => _session.set(setDefaultField, v),
        ),
        SwitchListTile(
          key: const ValueKey('set-edit-auto-apply'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.equipment_setEdit_computerAutoApplySwitch_title),
          subtitle: Text(
            l10n.equipment_setEdit_computerAutoApplySwitch_subtitle,
          ),
          value: set.autoApplyOnComputerImport,
          onChanged: (v) => _session.set(setAutoApplyField, v),
        ),
        const SizedBox(height: 4),
        // Calculated, so read only here as on the page.
        Text(
          count == 1
              ? l10n.equipment_sets_itemCountSingular(count)
              : l10n.equipment_sets_itemCountPlural(count),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// The Figure card: whether the page draws the set's gear on a diver.
class EquipmentSetFigureEditor extends StatelessWidget {
  const EquipmentSetFigureEditor({super.key, required this.session});

  final EditSession<EquipmentSet> session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => SwitchListTile(
      key: const ValueKey('set-edit-show-figure'),
      contentPadding: EdgeInsets.zero,
      title: Text(context.l10n.equipment_setEdit_figureSwitch_title),
      subtitle: Text(context.l10n.equipment_setEdit_figureSwitch_subtitle),
      value: session.working.showFigure,
      onChanged: (v) => session.set(setShowFigureField, v),
    ),
  );
}

/// The Bundle card: the sets it includes, its weight presets and its
/// cylinder configurations, as the form edited them.
class EquipmentSetBundleEditor extends StatelessWidget {
  const EquipmentSetBundleEditor({super.key, required this.session});

  final EditSession<EquipmentSet> session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final set = session.working;
      return SetBundleSections(
        setId: set.id,
        diverId: set.diverId,
        ownGearIds: set.equipmentIds.toSet(),
        values: bundleListsOf(session),
        onChanged: (lists) => setBundleLists(session, lists),
      );
    },
  );
}

/// The Geofences card, as the form edited them.
class EquipmentSetGeofencesEditor extends StatelessWidget {
  const EquipmentSetGeofencesEditor({super.key, required this.session});

  final EditSession<EquipmentSet> session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => SetGeofencesEditor(
      fences: session.valueOf(setGeofencesField).held,
      setId: session.stored.id,
      onChanged: (fences) =>
          session.set(setGeofencesField, geofencesEdited(session, fences)),
    ),
  );
}
