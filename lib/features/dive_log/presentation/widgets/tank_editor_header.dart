import 'package:flutter/material.dart';

/// One button of the cylinder editor's header.
class TankHeaderAction {
  const TankHeaderAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  /// On the icon button, or on the menu item once folded.
  final Key key;
  final IconData icon;

  /// The tooltip of the button and the text of the menu item.
  final String label;
  final VoidCallback onPressed;

  /// Drawn in the error colour (remove).
  final bool destructive;
}

/// The cylinder editor's header: [leading], the [title] over the
/// [subtitle], and the [actions] as icon buttons. When the title and the
/// buttons do not fit on one line, as on a phone inside the Cylinders card,
/// the buttons fold into one overflow menu so the title keeps its line
/// (issue #4962).
class TankEditorHeader extends StatelessWidget {
  const TankEditorHeader({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final List<TankHeaderAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w500,
    );
    return Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textWidth = [
                _widthOf(context, title, titleStyle),
                _widthOf(context, subtitle, subtitleStyle),
              ].reduce((a, b) => a > b ? a : b);
              final buttonWidth =
                  kMinInteractiveDimension +
                  theme.visualDensity.baseSizeAdjustment.dx;
              // A lone action stays a button: the menu would take the same
              // room and only add a tap.
              final folds =
                  actions.length > 1 &&
                  textWidth + actions.length * buttonWidth >
                      constraints.maxWidth;
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Two lines, so a large text size wraps the title
                        // at a word rather than cutting it short.
                        Text(
                          title,
                          style: titleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: subtitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (folds)
                    _menu(context, theme)
                  else
                    for (final action in actions)
                      IconButton(
                        key: action.key,
                        icon: Icon(action.icon),
                        color: action.destructive
                            ? theme.colorScheme.error
                            : null,
                        tooltip: action.label,
                        onPressed: action.onPressed,
                      ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _menu(BuildContext context, ThemeData theme) {
    // Each item carries its own action: the items are built when the menu
    // opens, but the picked value reaches a later build of this header, whose
    // actions may have changed (the "My cylinders" one appears once the
    // diver's gear loads), so an index could run a different action.
    return PopupMenuButton<TankHeaderAction>(
      key: const Key('tank-actions-menu'),
      icon: const Icon(Icons.more_vert),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: (action) => action.onPressed(),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem<TankHeaderAction>(
            key: action.key,
            value: action,
            child: Row(
              children: [
                Icon(
                  action.icon,
                  color: action.destructive ? theme.colorScheme.error : null,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    action.label,
                    style: action.destructive
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The width [text] takes on one line in [style] at the text scale.
  static double _widthOf(BuildContext context, String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
