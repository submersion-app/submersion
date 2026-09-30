import 'package:flutter/material.dart';

/// A header [title] with an optional muted [subtitle] line stacked under it,
/// such as a list's entry count ("34 of 812 dives").
///
/// The subtitle is a single line that ellipsises, like every header title, so
/// a narrow pane never grows the bar by more than that one line. A null
/// [subtitle] returns [title] untouched.
class TitleWithSubtitle extends StatelessWidget {
  const TitleWithSubtitle({super.key, required this.title, this.subtitle});

  final Widget title;

  /// Pre-localized, so this shared widget never resolves l10n itself.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    if (subtitle == null) return title;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ],
    );
  }
}
