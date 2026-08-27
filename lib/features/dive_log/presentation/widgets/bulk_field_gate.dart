import 'package:flutter/material.dart';

/// Wraps an edit-form field with a leading "apply this field?" checkbox.
/// When [enabled] is false the field is dimmed and non-interactive — the
/// "leave this field alone across the selected dives" state.
class BulkFieldGate extends StatelessWidget {
  const BulkFieldGate({
    super.key,
    required this.enabled,
    required this.onChanged,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(value: enabled, onChanged: (v) => onChanged(v ?? false)),
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: enabled ? 1.0 : 0.4,
            child: IgnorePointer(ignoring: !enabled, child: child),
          ),
        ),
      ],
    );
  }
}
