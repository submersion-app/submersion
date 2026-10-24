import 'package:flutter/material.dart';

/// Confirms an action that cannot be undone by having the diver type a word
/// (issue #3482): the confirm button stays disabled until the field holds
/// [word], surrounding spaces forgiven. [word] is localized by the caller,
/// so the comparison works in every locale.
class TypedWordConfirmDialog extends StatefulWidget {
  const TypedWordConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.word,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String word;
  final String hint;
  final String confirmLabel;

  /// True only when the diver typed the word and confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String word,
    required String hint,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => TypedWordConfirmDialog(
          title: title,
          body: body,
          word: word,
          hint: hint,
          confirmLabel: confirmLabel,
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
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.body),
          const SizedBox(height: 16),
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
