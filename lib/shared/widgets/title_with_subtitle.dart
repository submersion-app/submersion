import 'package:flutter/material.dart';

import 'package:submersion/shared/models/subtitle_text.dart';

/// A header [title] with an optional muted [subtitle] line stacked under it,
/// such as a list's entry count ("34 of 812 dives").
///
/// The subtitle is a single line. When its full form would not fit the width
/// the header gives it, it switches to [SubtitleText.compact] ("34 of 812")
/// rather than ellipsising; without a compact form it ellipsises like every
/// header title. A null [subtitle] returns [title] untouched.
class TitleWithSubtitle extends StatelessWidget {
  const TitleWithSubtitle({super.key, required this.title, this.subtitle});

  final Widget title;

  /// Pre-localized, so this shared widget never resolves l10n itself.
  final SubtitleText? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    if (subtitle == null) return title;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        LayoutBuilder(
          builder: (context, constraints) => Text(
            _fitting(context, subtitle, style, constraints.maxWidth),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }

  /// [subtitle]'s full form if it fits [maxWidth] in [style], else its
  /// compact form when it has one.
  static String _fitting(
    BuildContext context,
    SubtitleText subtitle,
    TextStyle? style,
    double maxWidth,
  ) {
    final compact = subtitle.compact;
    if (compact == null || maxWidth.isInfinite) return subtitle.full;
    final painter = TextPainter(
      text: TextSpan(
        text: subtitle.full,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final fits = painter.width <= maxWidth;
    painter.dispose();
    return fits ? subtitle.full : compact;
  }
}
