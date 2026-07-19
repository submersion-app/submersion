import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

/// Input collected by the add/edit requirement sheet. The caller owns the
/// repository write.
class RequirementDraft {
  final String name;
  final RequirementKind kind;
  final int targetCount;

  const RequirementDraft({
    required this.name,
    required this.kind,
    required this.targetCount,
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
    builder: (context) => _AddRequirementSheet(existing: existing),
  );
}

class _AddRequirementSheet extends StatefulWidget {
  const _AddRequirementSheet({this.existing});

  final CourseRequirement? existing;

  @override
  State<_AddRequirementSheet> createState() => _AddRequirementSheetState();
}

class _AddRequirementSheetState extends State<_AddRequirementSheet> {
  late final TextEditingController _nameController;
  late RequirementKind _kind;
  late int _targetCount;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _kind = widget.existing?.kind ?? RequirementKind.dive;
    _targetCount = widget.existing?.targetCount ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(
      context,
    ).pop(RequirementDraft(name: name, kind: _kind, targetCount: _targetCount));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
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
          SegmentedButton<RequirementKind>(
            segments: [
              ButtonSegment(
                value: RequirementKind.dive,
                label: Text(l10n.courses_requirement_kind_dive),
              ),
              ButtonSegment(
                value: RequirementKind.checklist,
                label: Text(l10n.courses_requirement_kind_checklist),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (selection) {
              setState(() => _kind = selection.single);
            },
          ),
          if (_kind == RequirementKind.dive) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.courses_requirement_field_targetCount),
                ),
                IconButton(
                  onPressed: _targetCount > 1
                      ? () => setState(() => _targetCount--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_targetCount'),
                IconButton(
                  onPressed: () => setState(() => _targetCount++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      ),
    );
  }
}
