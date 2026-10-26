import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The layout the download step's terminal views share: an icon in a
/// circle, a title, a body, an optional action and Done.
class DcMessageLayout extends StatelessWidget {
  const DcMessageLayout({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionIcon,
    this.actionLabel,
    this.onAction,
    required this.onDone,
    this.bodyIsError = false,
  });

  final IconData icon;
  final String title;
  final String body;

  /// The one action besides Done; with no [onAction] only Done shows.
  final IconData? actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDone;

  /// Whether [body] reports a problem, and is drawn in the error colour.
  final bool bodyIsError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondaryContainer,
              ),
              child: Icon(
                icon,
                size: 64,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: bodyIsError
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (onAction != null) ...[
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel ?? ''),
              ),
              const SizedBox(height: 12),
            ],
            TextButton(
              onPressed: onDone,
              child: Text(context.l10n.universalImport_action_done),
            ),
          ],
        ),
      ),
    );
  }
}
