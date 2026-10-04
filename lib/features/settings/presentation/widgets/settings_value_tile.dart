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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
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
}
