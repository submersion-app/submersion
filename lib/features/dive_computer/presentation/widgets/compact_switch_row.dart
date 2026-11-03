import 'package:flutter/material.dart';

/// One minor setting on a single line (issue #4005): icon, title, an info
/// icon that opens the explanation as a tap-triggered tooltip, and the
/// switch. For a setting that does not earn a two-line `SwitchListTile`.
class CompactSwitchRow extends StatelessWidget {
  const CompactSwitchRow({
    super.key,
    required this.switchKey,
    required this.icon,
    required this.title,
    required this.explanation,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final IconData icon;
  final String title;
  final String explanation;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // Merged so a screen reader names the switch, as `SwitchListTile` does.
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            // Wraps rather than cutting off: several languages need two
            // lines on a phone, and the title is all the row says.
            Expanded(child: Text(title)),
            Tooltip(
              message: explanation,
              triggerMode: TooltipTriggerMode.tap,
              // A plain Icon, not an IconButton: Tooltip's own tap recognizer
              // and an IconButton's InkResponse both enter the same gesture
              // arena for the same pointer, and the IconButton wins it - the
              // tooltip never opens. Sized to roughly match an IconButton's
              // tap target.
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Switch(key: switchKey, value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
