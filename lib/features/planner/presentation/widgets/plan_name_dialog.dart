import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Prompt for a dive plan name, seeded with [initialName].
///
/// Resolves to the trimmed entered name, or `null` when the diver cancels or
/// dismisses the dialog. Confirm stays disabled while the trimmed field is
/// empty, so an empty name can never be returned.
Future<String?> showPlanNameDialog(
  BuildContext context, {
  required String initialName,
  required String title,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PlanNameDialog(initialName: initialName, title: title),
  );
}

class _PlanNameDialog extends StatefulWidget {
  const _PlanNameDialog({required this.initialName, required this.title});

  final String initialName;
  final String title;

  @override
  State<_PlanNameDialog> createState() => _PlanNameDialogState();
}

class _PlanNameDialogState extends State<_PlanNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: context.l10n.divePlanner_field_planName,
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _confirm,
          child: Text(context.l10n.common_action_save),
        ),
      ],
    );
  }

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }
}
