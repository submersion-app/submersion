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
  const TitleWithSubtitle({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleIndent = 0,
  });

  final Widget title;

  /// Pre-localized, so this shared widget never resolves l10n itself.
  final SubtitleText? subtitle;

  /// Space before the subtitle, for a [title] whose text starts in from its
  /// own edge (a name inside a pill), so the two lines still start together.
  final double subtitleIndent;

  /// The height a subtitle line showing [text] takes, at [textScaler] or
  /// else the context's text scale.
  ///
  /// For a host with a fixed height, such as an app bar's toolbar, which
  /// clips a title column taller than itself instead of reporting it. An app
  /// bar clamps its title's text scale, so a host measuring from outside it
  /// passes the clamped scaler.
  ///
  /// [text] is the subtitle itself, or a string in its script: a line drawn
  /// in a fallback font (Arabic, Hebrew) can stand a pixel taller than the
  /// primary font's, so a placeholder such as a space under-measures it.
  static double subtitleLineHeight(
    BuildContext context, {
    required String text,
    TextScaler? textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(_style(context)),
      ),
      textDirection: Directionality.of(context),
      textScaler: textScaler ?? MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  static TextStyle? _style(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    if (subtitle == null) return title;
    final style = _style(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        Padding(
          padding: EdgeInsetsDirectional.only(start: subtitleIndent),
          child: LayoutBuilder(
            builder: (context, constraints) => Text(
              _fitting(context, subtitle, style, constraints.maxWidth),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
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
      // The rendered Text resolves font fallback by locale; measure the same.
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final fits = painter.width <= maxWidth;
    painter.dispose();
    return fits ? subtitle.full : compact;
  }
}
