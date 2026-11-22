import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/query/presentation/dive_query_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Input collected by the add/edit requirement sheet. The caller owns the
/// repository write.
class RequirementDraft {
  final String name;
  final RequirementKind kind;
  final int targetCount;

  /// The rebreather of a [RequirementKind.ccrHours] draft; null is any.
  final String? equipmentId;

  /// The dive query of a [RequirementKind.diveQuery] draft.
  final String? queryJson;

  const RequirementDraft({
    required this.name,
    required this.kind,
    required this.targetCount,
    this.equipmentId,
    this.queryJson,
  });
}

/// Bottom sheet to create or edit a requirement. Returns null on cancel.
Future<RequirementDraft?> showAddRequirementSheet(
  BuildContext context, {
  CourseRequirement? existing,
}) {
  return showModalBottomSheet<RequirementDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AddRequirementSheet(existing: existing),
  );
}

class _AddRequirementSheet extends ConsumerStatefulWidget {
  const _AddRequirementSheet({this.existing});

  final CourseRequirement? existing;

  @override
  ConsumerState<_AddRequirementSheet> createState() =>
      _AddRequirementSheetState();
}

class _AddRequirementSheetState extends ConsumerState<_AddRequirementSheet> {
  late final TextEditingController _nameController;
  late RequirementKind _kind;
  late final TextEditingController _targetController;
  int? get _targetCount => int.tryParse(_targetController.text);
  String? _equipmentId;
  QueryNode? _query;
  bool _queryValid = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _kind = widget.existing?.kind ?? RequirementKind.dive;
    _targetController = TextEditingController(
      text: '${widget.existing?.targetCount ?? 1}',
    );
    _equipmentId = widget.existing?.equipmentId;
    _query = courseRequirementQuery(widget.existing?.queryJson);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_kind == RequirementKind.checklist) return true;
    if ((_targetCount ?? 0) < 1) return false;
    final query = _query;
    return _kind != RequirementKind.diveQuery ||
        (_queryValid && query != null && isValidCourseRequirementQuery(query));
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || !_canSave) return;
    Navigator.of(context).pop(
      RequirementDraft(
        name: name,
        kind: _kind,
        targetCount: _kind == RequirementKind.checklist ? 1 : _targetCount!,
        equipmentId: _kind == RequirementKind.ccrHours ? _equipmentId : null,
        queryJson: _kind == RequirementKind.diveQuery && _query != null
            ? jsonEncode(queryNodeToJson(_query!))
            : null,
      ),
    );
  }

  String _kindLabel(RequirementKind kind) {
    final l10n = context.l10n;
    return switch (kind) {
      RequirementKind.dive => l10n.courses_requirement_kind_dive,
      RequirementKind.checklist => l10n.courses_requirement_kind_checklist,
      RequirementKind.ccrHours => l10n.courses_requirement_kind_ccrHours,
      RequirementKind.diveQuery => l10n.courses_requirement_kind_diveQuery,
    };
  }

  String _targetLabel() {
    final l10n = context.l10n;
    return _kind == RequirementKind.ccrHours
        ? l10n.courses_requirement_field_targetHours
        : l10n.courses_requirement_field_targetCount;
  }

  Widget _rebreatherPicker() {
    final l10n = context.l10n;
    final items = ref.watch(allEquipmentProvider).value ?? const [];
    final rebreathers = [
      for (final item in items)
        if (item.type == EquipmentType.rebreather) item,
    ];
    final known = rebreathers.any((e) => e.id == _equipmentId);
    return DropdownButtonFormField<String>(
      initialValue: _equipmentId ?? '',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.courses_requirement_field_rebreather,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<String>(
          value: '',
          child: Text(l10n.courses_requirement_anyRebreather),
        ),
        for (final item in rebreathers)
          DropdownMenuItem<String>(value: item.id, child: Text(item.name)),
        // An item removed since the requirement was saved stays selectable,
        // so the sheet can show it rather than quietly widen to any unit.
        if (_equipmentId != null && !known)
          DropdownMenuItem<String>(
            value: _equipmentId,
            child: Text(l10n.courses_requirement_rebreatherRemoved),
          ),
      ],
      onChanged: (value) =>
          setState(() => _equipmentId = value == '' ? null : value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null
                ? l10n.courses_action_addRequirement
                : l10n.courses_action_editRequirement,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.courses_requirement_field_name,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in RequirementKind.values)
                ChoiceChip(
                  label: Text(_kindLabel(kind)),
                  selected: _kind == kind,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _kind = kind;
                      _queryValid = true;
                    });
                  },
                ),
            ],
          ),
          if (_kind != RequirementKind.checklist) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _targetController,
              decoration: InputDecoration(
                labelText: _targetLabel(),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_kind == RequirementKind.ccrHours) ...[
            const SizedBox(height: 16),
            _rebreatherPicker(),
          ],
          if (_kind == RequirementKind.diveQuery) ...[
            const SizedBox(height: 16),
            Text(
              l10n.courses_requirement_field_query,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            DiveQueryEditor(
              value: _query,
              onChanged: (node) => setState(() => _query = node),
              onValidityChanged: (valid) {
                if (mounted && valid != _queryValid) {
                  setState(() => _queryValid = valid);
                }
              },
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      ),
    );
  }
}
