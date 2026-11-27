import 'package:flutter/material.dart';

/// Muted explanatory line beside a field: the shared FormCaption style,
/// without its overline indent, since these sit flush with the fields.
class TransmitterFieldNote extends StatelessWidget {
  const TransmitterFieldNote(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 2),
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
