import 'package:flutter/material.dart';

import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Asks for a group size outside the sentence's preset choices. Returns the
/// number, or null when dismissed.
Future<int?> showFocusCountDialog(
  BuildContext context, {
  required int initial,
}) => showDialog<int>(
  context: context,
  builder: (_) => _FocusCountDialog(initial: initial),
);

class _FocusCountDialog extends StatefulWidget {
  const _FocusCountDialog({required this.initial});

  final int initial;

  @override
  State<_FocusCountDialog> createState() => _FocusCountDialogState();
}

class _FocusCountDialogState extends State<_FocusCountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initial}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final read = readNumber(
      _controller.text,
      integer: true,
      allowNegative: false,
    );
    final n = read is NumberValue ? read.value.toInt() : null;
    if (n == null ||
        n < FocusSelection.minCount ||
        n > FocusSelection.maxCount) {
      setState(() => _error = context.l10n.insights_focus_count_error);
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.insights_focus_count_dialogTitle),
      content: TextField(
        key: const ValueKey('focus-count-custom-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.insights_focus_count_label,
          errorText: _error,
          errorMaxLines: 3,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(material.okButtonLabel)),
      ],
    );
  }
}
