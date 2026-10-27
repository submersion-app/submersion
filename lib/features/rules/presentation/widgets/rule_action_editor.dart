import 'package:flutter/material.dart';

import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/built_ins/visible_built_ins.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/presentation/query_ref_picker_sheet.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_editor.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_field_value.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/domain/rule_value_kind.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_action_picker_sheet.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_value_input.dart';
import 'package:submersion/features/settings/presentation/providers/hidden_built_ins_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

/// Opens the right editor for [t] and returns the finished action, or null
/// when the diver backs out. [initial] prefills it when editing.
Future<RuleAction?> editRuleAction(
  BuildContext context,
  WidgetRef ref,
  RuleActionTemplate t, {
  RuleAction? initial,
}) async {
  if (t.diveCollection != null || t.siteCollection != null) {
    return _editMembership(context, ref, t, initial);
  }
  if (t.diveField != null && diveFieldRefSubject(t.diveField!) != null) {
    return _editRefField(context, ref, t.diveField!, initial);
  }
  if (t.diveField == null && t.siteField == null) {
    final text = await _editText(
      context,
      t.label(context.l10n),
      switch (initial) {
        AppendDiveNotesAction(:final text) => text,
        AppendSiteDescriptionAction(:final text) => text,
        _ => '',
      },
    );
    if (text == null) return null;
    return t.subject == RuleSubject.dives
        ? AppendDiveNotesAction(text)
        : AppendSiteDescriptionAction(text);
  }
  return showDialog<RuleAction>(
    context: context,
    builder: (_) => _ValueDialog(template: t, initial: initial),
  );
}

Future<RuleAction?> _editMembership(
  BuildContext context,
  WidgetRef ref,
  RuleActionTemplate t,
  RuleAction? initial,
) async {
  final l10n = context.l10n;
  final subject = t.diveCollection != null
      ? diveCollectionSubject(t.diveCollection!)
      : siteCollectionSubject(t.siteCollection!);
  final editor = readQueryEditorContext(context, ref, diveQueryEntity);
  final current = switch (initial) {
    DiveMembershipAction(:final ids) => ids,
    SiteMembershipAction(:final ids) => ids,
    _ => const <String>[],
  };
  final picked = await showQueryRefMultiPicker(
    context,
    editor: editor,
    kind: subject,
    title: t.label(l10n),
    searchHint: l10n.query_editor_pickRefSearch,
    doneLabel: l10n.common_action_done,
    selected: [
      for (final id in current)
        RefValue(id, _labelOf(editor.names, subject, id)),
    ],
  );
  if (picked == null || picked.isEmpty || !context.mounted) return null;
  final ids = [for (final r in picked) r.id];
  if (t.siteCollection != null) {
    return SiteMembershipAction(t.siteCollection!, t.mode!, ids);
  }
  String? role;
  if (t.diveCollection == DiveCollection.buddies &&
      t.mode == MembershipMode.add) {
    role = await _pickRole(
      context,
      ref,
      (initial as DiveMembershipAction?)?.buddyRoleId,
    );
    if (role == null) return null;
  }
  return DiveMembershipAction(
    t.diveCollection!,
    t.mode!,
    ids,
    buddyRoleId: role,
  );
}

Future<String?> _pickRole(
  BuildContext context,
  WidgetRef ref,
  String? current,
) async {
  // Built-in roles the diver hid stay out, as in every role picker (#401),
  // unless the action already uses one.
  final hidden = ref.read(hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles));
  final roles = visibleBuiltIns(
    await ref.read(allDiveRolesProvider.future),
    hidden,
    isBuiltIn: (r) => r.isBuiltIn,
    idOf: (r) => r.id,
    keep: [current],
  );
  if (!context.mounted) return null;
  final l10n = context.l10n;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(l10n.rules_actionEditor_role),
      children: [
        for (final r in roles)
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(r.id),
            child: Text(
              r.localizedName(l10n),
              style: r.id == (current ?? DiveRole.buddyId)
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
      ],
    ),
  );
}

Future<RuleAction?> _editRefField(
  BuildContext context,
  WidgetRef ref,
  BulkField field,
  RuleAction? initial,
) async {
  final l10n = context.l10n;
  final key = diveFieldValueKeys(field).first;
  final current = (initial as SetDiveFieldAction?)?.values[key] as String?;
  final picked = await showQueryRefPicker(
    context,
    editor: readQueryEditorContext(context, ref, diveQueryEntity),
    kind: diveFieldRefSubject(field)!,
    title: l10n.rules_actionEditor_choose(ruleDiveFieldLabel(l10n, field)),
    searchHint: l10n.query_editor_pickRefSearch,
    selected: current == null ? null : RefValue(current, current),
  );
  if (picked == null) return null;
  return SetDiveFieldAction(field, {key: picked.id});
}

Future<String?> _editText(BuildContext context, String title, String text) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(title: title, text: text),
    );

/// The append text, its controller owned (and disposed) by the dialog so a
/// rebuild while it is open keeps what the diver typed.
class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.text});

  final String title;
  final String text;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: MarkdownNotesField(
      key: const ValueKey('rule_value_append'),
      controller: _controller,
      autofocus: true,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: context.l10n.rules_actionEditor_text,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.common_action_cancel),
      ),
      FilledButton(
        key: const ValueKey('rule_action_ok'),
        onPressed: () {
          final value = _controller.text.trim();
          Navigator.of(context).pop(value.isEmpty ? null : value);
        },
        child: Text(context.l10n.common_action_ok),
      ),
    ],
  );
}

/// The value of a set-field action: one input, or two for the diluent.
class _ValueDialog extends ConsumerStatefulWidget {
  const _ValueDialog({required this.template, this.initial});

  final RuleActionTemplate template;
  final RuleAction? initial;

  @override
  ConsumerState<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends ConsumerState<_ValueDialog> {
  late Map<String, Object?> _values = switch (widget.initial) {
    SetDiveFieldAction(:final values) => {...values},
    SetSiteFieldAction(:final field, :final value) => {field.name: value},
    _ => {
      if (widget.template.diveField != null &&
          diveFieldKind(widget.template.diveField!) == RuleValueKind.boolean)
        widget.template.diveField!.name: true,
    },
  };

  RuleAction? get _action {
    final dive = widget.template.diveField;
    if (dive != null) {
      final keys = diveFieldValueKeys(dive);
      final first = _values[keys.first];
      if (first == null) return null;
      if (dive == BulkField.diluentGas && _values['diluentHe'] == null) {
        return SetDiveFieldAction(dive, {..._values, 'diluentHe': 0});
      }
      return SetDiveFieldAction(dive, {
        for (final k in keys)
          if (_values[k] != null) k: _values[k],
      });
    }
    final site = widget.template.siteField!;
    final v = _values[site.name];
    return v == null ? null : SetSiteFieldAction(site, v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final dive = widget.template.diveField;
    final site = widget.template.siteField;
    Widget input(String key, {String? label, RuleUnit? unit}) => RuleValueInput(
      kind: dive != null ? diveFieldKind(dive) : site!.kind,
      unit: unit ?? (dive != null ? diveFieldUnit(dive) : siteFieldUnit(site!)),
      units: units,
      fieldName: dive?.name ?? site!.name,
      value: _values[key],
      enumValues: dive != null ? diveFieldEnumValues(dive) : site!.enumValues,
      integer: dive != null && diveFieldIsInteger(dive),
      label: label,
      onChanged: (v) => setState(() => _values = {..._values, key: v}),
    );
    return AlertDialog(
      title: Text(widget.template.label(l10n)),
      content: dive == BulkField.diluentGas
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                input('diluentO2', label: l10n.rules_actionEditor_o2),
                input('diluentHe', label: l10n.rules_actionEditor_he),
              ],
            )
          : input(dive != null ? diveFieldValueKeys(dive).first : site!.name),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          key: const ValueKey('rule_action_ok'),
          onPressed: _action == null
              ? null
              : () => Navigator.of(context).pop(_action),
          child: Text(l10n.common_action_ok),
        ),
      ],
    );
  }
}

String _labelOf(Object names, QuerySubject subject, String id) =>
    names is NameIndex ? names.labelOf(subject, id) ?? id : id;
