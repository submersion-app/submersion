import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog for entering a PIN code for dive computer authentication.
///
/// Used by Aqualung/Pelagic devices that require PIN-based pairing.
/// The device displays the PIN code on its screen, and the user must
/// enter it here to authenticate.
class PinEntryDialog extends StatefulWidget {
  /// The name of the device requesting the PIN.
  final String? deviceName;

  const PinEntryDialog({
    super.key,
    this.deviceName,
  });

  /// Shows the PIN entry dialog and returns the entered PIN.
  ///
  /// Returns null if the user cancels the dialog.
  static Future<String?> show(BuildContext context, {String? deviceName}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinEntryDialog(deviceName: deviceName),
    );
  }

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPinChanged(String value) {
    setState(() {
      // PIN is typically 4-6 digits
      _isValid = value.length >= 4 && value.length <= 6;
    });
  }

  void _onSubmit() {
    if (_isValid) {
      Navigator.of(context).pop(_pinController.text);
    }
  }

  void _onCancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(
        Icons.pin,
        size: 48,
        color: colorScheme.primary,
      ),
      title: const Text('Enter PIN Code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.deviceName != null
                ? 'Check your ${widget.deviceName} display for the PIN code.'
                : 'Check your dive computer display for the PIN code.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pinController,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '----',
              hintStyle: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: 8,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: _onPinChanged,
            onSubmitted: (_) => _onSubmit(),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 4-6 digit PIN shown on your device',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValid ? _onSubmit : null,
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
