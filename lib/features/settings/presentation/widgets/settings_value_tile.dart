import 'package:flutter/material.dart';

/// A settings row that shows its current value on the right, followed by a
/// chevron, and opens a picker when tapped.
///
/// [ListTile] gives `trailing` as much width as it asks for and leaves the
/// title and subtitle only what remains. A long value (a translated preset
/// name, for example) would then squeeze the description down to a character
/// per line (issue #2919). The value here may take at most
/// [maxValueWidthFraction] of the row and wraps onto a second line past that.
class SettingsValueTile extends StatelessWidget {
  const SettingsValueTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onTap,
  });

  /// The largest share of the row's width the value and chevron may take.
  static const double maxValueWidthFraction = 0.4;

  final String title;
  final String? subtitle;
  final String value;
  final VoidCallback onTap;

  /// The most lines the value wraps onto when there is height for them.
  static const int _maxValueLines = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.primary,
    );
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * maxValueWidthFraction,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: _linesThatFit(
                    context,
                    valueStyle,
                    constraints.maxHeight,
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
      onTap: onTap,
    );
  }

  /// ListTile caps `trailing` at a fixed height (56 px), so at a large text
  /// scale a second line would paint over the next row. Wrap only onto the
  /// lines that fit, and always allow one.
  static int _linesThatFit(
    BuildContext context,
    TextStyle? style,
    double maxHeight,
  ) {
    if (!maxHeight.isFinite) return _maxValueLines;
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final lineHeight = painter.preferredLineHeight;
    painter.dispose();
    return (maxHeight / lineHeight).floor().clamp(1, _maxValueLines);
  }
}
