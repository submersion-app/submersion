import 'package:flutter/material.dart';

/// Muted explanatory text under a [FormOverline], aligned with its label:
/// says what a sub-list is for when that is not obvious from its name.
class FormCaption extends StatelessWidget {
  const FormCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
