import 'package:flutter/material.dart';

/// Editable field for the import batch tag.
///
/// Displays a text field with a tag icon and clear button. The batch tag
/// is applied to all imported dives for easy filtering later.
class BatchTagField extends StatefulWidget {
  const BatchTagField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final String? initialValue;
  final ValueChanged<String?> onChanged;

  @override
  State<BatchTagField> createState() => _BatchTagFieldState();
}

class _BatchTagFieldState extends State<BatchTagField> {
  late final TextEditingController _controller;
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _isEnabled = widget.initialValue != null && widget.initialValue!.isNotEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label_outline, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Import Tag',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Switch.adaptive(
              value: _isEnabled,
              onChanged: (enabled) {
                setState(() {
                  _isEnabled = enabled;
                });
                widget.onChanged(enabled ? _controller.text : null);
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tag all imported dives for easy filtering',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (_isEnabled) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'e.g., MacDive Import 2026-02-09',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Clear tag',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              ),
            ),
            onChanged: widget.onChanged,
          ),
        ],
      ],
    );
  }
}
