import 'package:flutter/material.dart';

/// A text action for [AppBar.actions] that stays visible on every theme.
///
/// A bare [TextButton] takes its foreground from `colorScheme.primary`,
/// which some full themes (Tropical, Console) set to the same color as the
/// app bar background, rendering the label invisible (#736). This widget
/// pins the foreground to the app bar's own foreground color instead.
class AppBarTextAction extends StatelessWidget {
  const AppBarTextAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // AppBar wraps its whole toolbar, actions included, in a DefaultTextStyle
    // whose color resolves AppBar.foregroundColor, AppBarTheme.foregroundColor
    // and the Material default in that order, so it is the one channel that
    // tracks a per-app-bar override. The surrounding IconTheme is not usable
    // here: it carries the actions icon color, which Material 3 defaults to the
    // de-emphasized onSurfaceVariant rather than the toolbar foreground. The
    // theme fallbacks below only apply when this widget is used outside an
    // app bar, or under a toolbar text style that leaves the color unset.
    final foreground =
        DefaultTextStyle.of(context).style.color ??
        theme.appBarTheme.foregroundColor ??
        theme.colorScheme.onSurface;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: foreground),
      child: Text(label),
    );
  }
}
