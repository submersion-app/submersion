import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks for a component's role ("Primary second stage"). Returns the trimmed
/// text on Save (empty clears the role) and null on Cancel. [suggestions]
/// are roles already used on other assemblies, offered as chips.
Future<String?> showComponentRoleDialog(
  BuildContext context, {
  required String initial,
  required List<String> suggestions,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _ComponentRoleDialog(initial: initial, suggestions: suggestions),
  );
}

class _ComponentRoleDialog extends StatefulWidget {
  final String initial;
  final List<String> suggestions;

  const _ComponentRoleDialog({
    required this.initial,
    required this.suggestions,
  });

  @override
  State<_ComponentRoleDialog> createState() => _ComponentRoleDialogState();
}

class _ComponentRoleDialogState extends State<_ComponentRoleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.equipment_components_roleDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.equipment_components_role,
              hintText: l10n.equipment_components_roleHint,
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          if (widget.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final role in widget.suggestions)
                  ActionChip(
                    label: Text(role),
                    onPressed: () => setState(() {
                      _controller.text = role;
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
