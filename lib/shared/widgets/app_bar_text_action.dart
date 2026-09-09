import 'package:flutter/material.dart';

/// A text action for [AppBar.actions] that stays visible on every theme.
///
/// A bare [TextButton] takes its foreground from `colorScheme.primary`,
/// which some full themes (Tropical, Console) set to the same color as the
/// app bar background, rendering the label invisible (#736, and again #1231
/// on the checklist editors). This widget pins the foreground to the app
/// bar's own foreground color instead.
///
/// `test/shared/widgets/app_bar_text_action_adoption_test.dart` keeps every
/// app bar text action on this widget, so the defect cannot come back on a
/// page nobody thought to check.
class AppBarTextAction extends StatelessWidget {
  const AppBarTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;

  /// Null disables the action. The disabled label is pinned to the same app
  /// bar foreground at Material's disabled opacity rather than left to the
  /// theme's `onSurface`-based default, which is what turns a saving-in-
  /// progress Save into dark-on-dark under the Console app bar.
  final VoidCallback? onPressed;

  /// Optional leading icon, for actions that carry one (a confirm check, say).
  final Widget? icon;

  /// Swaps the label for a progress indicator in the same foreground color,
  /// for pages that report an in-flight save on the action itself. [label]
  /// still names the action for assistive technology.
  final bool busy;

  /// Material's disabled foreground opacity for text buttons.
  static const double _disabledOpacity = 0.38;

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

    final style = TextButton.styleFrom(
      foregroundColor: foreground,
      disabledForegroundColor: foreground.withValues(alpha: _disabledOpacity),
    );

    if (busy) {
      return TextButton(
        onPressed: onPressed,
        style: style,
        child: Semantics(
          label: label,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          ),
        ),
      );
    }

    if (icon != null) {
      return TextButton.icon(
        onPressed: onPressed,
        style: style,
        icon: icon,
        label: Text(label),
      );
    }

    return TextButton(onPressed: onPressed, style: style, child: Text(label));
  }
}
