import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Stands in for one reef part while its source has not answered yet.
///
/// Keeps the part's icon and title, so the section holds its shape and the
/// finished row replaces this one in place.
class ReefCheckingRow extends StatelessWidget {
  final IconData icon;
  final String title;

  const ReefCheckingRow({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(context.l10n.reef_section_checking),
      trailing: const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      dense: true,
    );
  }
}

/// Fetches one failed reef part again.
class ReefRetryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ReefRetryButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(context.l10n.common_action_retry),
    );
  }
}
