import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a modal dialog for entering a BLE PIN code.
///
/// Returns the entered PIN string, or null if cancelled.
Future<String?> showPinCodeDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _PinCodeDialog(),
  );
}

/// Handles the PIN code request flow for download pages.
///
/// Shows the PIN dialog and submits the result to the notifier.
/// If cancelled, submits an empty string to abort the download.
Future<void> handlePinCodeRequest(
  BuildContext context,
  Future<void> Function(String) submitPinCode,
) async {
  final pin = await showPinCodeDialog(context);
  if (pin != null && pin.isNotEmpty) {
    await submitPinCode(pin);
  } else {
    // User cancelled -- submit empty string to signal cancellation.
    await submitPinCode('');
  }
}

class _PinCodeDialog extends StatefulWidget {
  const _PinCodeDialog();

  @override
  State<_PinCodeDialog> createState() => _PinCodeDialogState();
}

class _PinCodeDialogState extends State<_PinCodeDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Autofocus the text field after the dialog animates in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PIN Code Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter the code displayed on your dive computer.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'PIN Code',
              hintText: '000000',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _controller.text.isNotEmpty ? _submit : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  void _submit() {
    if (_controller.text.isNotEmpty) {
      Navigator.of(context).pop(_controller.text);
    }
  }
}
