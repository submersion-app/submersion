import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Full-width append action inside a section body: "+ Add tank".
/// One of the two sanctioned in-section action patterns (the other is
/// [FormOverlineAction]-style overline-docked text buttons).
class FormAppendRow extends StatelessWidget {
  const FormAppendRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: FormStyle.rowPadding,
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: accent),
          ],
        ),
      ),
    );
  }
}
