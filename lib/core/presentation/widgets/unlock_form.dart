import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Password + optional-biometric unlock form. Hosted both by the startup
/// lock screen (inside the splash MaterialApp, which carries the
/// localization delegates) and by the re-lock overlay inside the main app,
/// so `context.l10n` resolves in both hosts.
class UnlockForm extends StatefulWidget {
  final Future<bool> Function(String secret) onSubmitSecret;
  final Future<bool> Function()? onBiometric;
  final bool autoFireBiometric;
  final Widget? footer;

  const UnlockForm({
    super.key,
    required this.onSubmitSecret,
    required this.onBiometric,
    this.autoFireBiometric = true,
    this.footer,
  });

  @override
  State<UnlockForm> createState() => _UnlockFormState();
}

class _UnlockFormState extends State<UnlockForm> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoFireBiometric && widget.onBiometric != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onBiometric!();
      // On success the host tears this widget down; on failure fall back to
      // the password field silently (the OS already showed its own error UI).
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _showError = false;
    });
    try {
      final ok = await widget.onSubmitSecret(_controller.text);
      if (!ok && mounted) setState(() => _showError = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.l10n.settings_security_password,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (_showError) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.lock_incorrectPassword,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(context.l10n.settings_cloudSync_encryption_unlock),
        ),
        if (widget.onBiometric != null) ...[
          const SizedBox(height: 12),
          IconButton(
            icon: const Icon(Icons.fingerprint, size: 36),
            onPressed: _busy ? null : _tryBiometric,
            tooltip: context.l10n.settings_security_biometrics,
          ),
        ],
        if (widget.footer != null) ...[
          const SizedBox(height: 24),
          widget.footer!,
        ],
      ],
    );
  }
}
