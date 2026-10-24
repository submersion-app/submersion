import 'package:flutter/material.dart';

/// Confirms an action that cannot be undone by having the diver type a word
/// (issue #3482): the confirm button stays disabled until the field holds
/// [word], surrounding spaces forgiven. [word] is localized by the caller,
/// so the comparison works in every locale: comparing against a hardcoded
/// English word once made a reset dialog impossible to confirm in seven.
class TypedWordConfirmDialog extends StatefulWidget {
  const TypedWordConfirmDialog({
    super.key,
    required this.title,
    required this.paragraphs,
    required this.word,
    required this.hint,
    required this.confirmLabel,
    this.warning = false,
  });

  final String title;

  /// What confirming does, one paragraph each.
  final List<String> paragraphs;
  final String word;
  final String hint;
  final String confirmLabel;

  /// Shows a warning mark beside the title.
  final bool warning;

  /// True only when the diver typed the word and confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required List<String> paragraphs,
    required String word,
    required String hint,
    required String confirmLabel,
    bool warning = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => TypedWordConfirmDialog(
          title: title,
          paragraphs: paragraphs,
          word: word,
          hint: hint,
          confirmLabel: confirmLabel,
          warning: warning,
        ),
      ) ??
      false;

  @override
  State<TypedWordConfirmDialog> createState() => _TypedWordConfirmDialogState();
}

class _TypedWordConfirmDialogState extends State<TypedWordConfirmDialog> {
  final _controller = TextEditingController();
  bool _typed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final typed = _controller.text.trim() == widget.word;
      if (typed != _typed) setState(() => _typed = typed);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: widget.warning
          ? Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.title)),
              ],
            )
          : Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final paragraph in widget.paragraphs) ...[
              Text(paragraph, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: _typed ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
