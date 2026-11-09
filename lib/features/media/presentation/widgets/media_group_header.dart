import 'dart:math' as math;

import 'package:flutter/material.dart';

/// [dive] is every by-dive mode group header: a dive's, and since issue #4149
/// a site's and an equipment item's. [section] heads a run of by-dive groups
/// of one kind (issue #4224): the site pictures after the dives, the
/// equipment pictures after them, and Unlinked last.
enum MediaGroupHeaderKind { month, day, dive, section }

/// One header in the grouped gallery. Everything that sets a header's height
/// comes from here, for [MediaGroupHeader] to draw and
/// [MediaGroupHeaderMeasurer] to measure, so the two cannot drift: the grid
/// needs every header's height before it builds any of them.
class MediaGroupHeaderSpec {
  const MediaGroupHeaderSpec({
    required this.kind,
    required this.label,
    this.route,
    this.hint,
    this.icon,
  });

  final MediaGroupHeaderKind kind;
  final String label;

  /// Drawn before a [MediaGroupHeaderKind.section] label; ignored otherwise.
  final IconData? icon;

  /// Where this header goes, if it goes anywhere right now: the dive, site
  /// or equipment item its group belongs to. Null while a selection is in
  /// progress, as well as for the Unlinked group.
  final String? route;

  /// What a screen reader says a tap does, such as "Open this site".
  final String? hint;

  bool get navigable => route != null;

  /// 48 is Material's tap-target floor.
  double get minHeight => navigable ? 48 : 0;

  static const double sectionIconSize = 18;
  static const double sectionIconGap = 8;
  static const double sectionRuleGap = 4;
  static const double sectionRuleThickness = 1;

  bool get _hasIcon => kind == MediaGroupHeaderKind.section && icon != null;

  /// Width the icon takes from the label, so the measurer wraps the label
  /// where the painted one wraps.
  double get leadingWidth => _hasIcon ? sectionIconSize + sectionIconGap : 0;

  /// The icon's height, the floor under a one-line label's.
  double get leadingHeight => _hasIcon ? sectionIconSize : 0;

  /// The rule under a section label and the gap above it.
  double get ruleExtent => kind == MediaGroupHeaderKind.section
      ? sectionRuleGap + sectionRuleThickness
      : 0;

  EdgeInsets get padding => switch (kind) {
    MediaGroupHeaderKind.month => const EdgeInsets.fromLTRB(12, 16, 12, 4),
    MediaGroupHeaderKind.day => const EdgeInsets.fromLTRB(12, 8, 12, 4),
    MediaGroupHeaderKind.dive => const EdgeInsets.fromLTRB(12, 12, 12, 4),
    MediaGroupHeaderKind.section => const EdgeInsets.fromLTRB(12, 20, 12, 2),
  };

  static TextStyle? themeStyleOf(
    MediaGroupHeaderKind kind,
    TextTheme textTheme,
  ) => switch (kind) {
    MediaGroupHeaderKind.day => textTheme.labelLarge,
    MediaGroupHeaderKind.section => textTheme.titleSmall,
    MediaGroupHeaderKind.month ||
    MediaGroupHeaderKind.dive => textTheme.titleMedium,
  };
}

/// A month, day or dive heading over a group of thumbnails. A navigable one
/// is the view's only route to its dive, site or equipment item.
class MediaGroupHeader extends StatelessWidget {
  const MediaGroupHeader({super.key, required this.spec, required this.onTap});

  final MediaGroupHeaderSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = MediaGroupHeaderSpec.themeStyleOf(spec.kind, theme.textTheme);
    if (spec.kind == MediaGroupHeaderKind.section) {
      return _section(theme.colorScheme.primary, style);
    }
    final text = Text(spec.label, style: style);
    if (!spec.navigable) return Padding(padding: spec.padding, child: text);
    // No label here: the Text below already gives the merged node its
    // label, and naming it twice made a screen reader read it twice.
    return Semantics(
      button: true,
      hint: spec.hint,
      child: InkWell(
        onTap: onTap,
        // Padding inside the InkWell so it contributes to the hit box.
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: spec.minHeight),
          child: Padding(
            padding: spec.padding,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: text,
            ),
          ),
        ),
      ),
    );
  }
}

extension on MediaGroupHeader {
  /// A section heading: accent label after its icon, a thin accent rule
  /// under both. Never a button. Every extent here is one the spec states,
  /// so [MediaGroupHeaderMeasurer] measures what this draws.
  Widget _section(Color accent, TextStyle? style) {
    final icon = spec.icon;
    return Padding(
      padding: spec.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: MediaGroupHeaderSpec.sectionIconSize,
                  color: accent,
                ),
                const SizedBox(width: MediaGroupHeaderSpec.sectionIconGap),
              ],
              Expanded(
                child: Text(spec.label, style: style?.copyWith(color: accent)),
              ),
            ],
          ),
          const SizedBox(height: MediaGroupHeaderSpec.sectionRuleGap),
          SizedBox(
            height: MediaGroupHeaderSpec.sectionRuleThickness,
            child: ColoredBox(color: accent),
          ),
        ],
      ),
    );
  }
}

/// Works out a [MediaGroupHeader]'s height without building it, from what a
/// `Text` would resolve in the same place.
///
/// A label's natural width does not depend on the pane, so it is measured once:
/// a label that fits takes its one-line height, and dragging a pane wider or
/// narrower lays out only the labels that wrap.
class MediaGroupHeaderMeasurer {
  MediaGroupHeaderMeasurer._({
    required Map<MediaGroupHeaderKind, TextStyle> styles,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required Locale? locale,
    required TextHeightBehavior? textHeightBehavior,
  }) : _styles = styles,
       _textScaler = textScaler,
       _textDirection = textDirection,
       _locale = locale,
       _textHeightBehavior = textHeightBehavior;

  factory MediaGroupHeaderMeasurer.of(BuildContext context) {
    final inherited = DefaultTextStyle.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bold = MediaQuery.boldTextOf(context);
    final lineHeight = MediaQuery.maybeLineHeightScaleFactorOverrideOf(context);
    final letterSpacing = MediaQuery.maybeLetterSpacingOverrideOf(context);
    final wordSpacing = MediaQuery.maybeWordSpacingOverrideOf(context);
    TextStyle resolve(MediaGroupHeaderKind kind) {
      final style = inherited.style.merge(
        MediaGroupHeaderSpec.themeStyleOf(kind, textTheme),
      );
      return (bold
              ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
              : style)
          // The platform's text spacing settings, last, as `Text` applies them.
          .merge(
            TextStyle(
              height: lineHeight,
              letterSpacing: letterSpacing,
              wordSpacing: wordSpacing,
            ),
          );
    }

    return MediaGroupHeaderMeasurer._(
      styles: {
        for (final kind in MediaGroupHeaderKind.values) kind: resolve(kind),
      },
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      textHeightBehavior:
          inherited.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
    );
  }

  final Map<MediaGroupHeaderKind, TextStyle> _styles;
  final TextScaler _textScaler;
  final TextDirection _textDirection;
  final Locale? _locale;
  final TextHeightBehavior? _textHeightBehavior;

  final _natural =
      <(MediaGroupHeaderKind, String), ({double width, double height})>{};
  final _wrapped = <(MediaGroupHeaderKind, String), double>{};
  double? _wrappedAt;

  /// How many text layouts this has done, for tests of the cache.
  @visibleForTesting
  int layouts = 0;

  /// Whether this measures the same way as [other], so its cache still holds.
  bool matches(MediaGroupHeaderMeasurer other) =>
      other._textScaler == _textScaler &&
      other._textDirection == _textDirection &&
      other._locale == _locale &&
      other._textHeightBehavior == _textHeightBehavior &&
      MediaGroupHeaderKind.values.every(
        (kind) => other._styles[kind] == _styles[kind],
      );

  /// The height of [spec]'s header in a pane [paneWidth] wide.
  double extentOf(MediaGroupHeaderSpec spec, double paneWidth) {
    final textHeight = _textHeight(
      spec.kind,
      spec.label,
      math.max(0, paneWidth - spec.padding.horizontal - spec.leadingWidth),
    );
    final content = math.max(textHeight, spec.leadingHeight) + spec.ruleExtent;
    return math.max(spec.minHeight, content + spec.padding.vertical);
  }

  double _textHeight(
    MediaGroupHeaderKind kind,
    String label,
    double available,
  ) {
    final key = (kind, label);
    final natural = _natural[key] ??= _layOut(kind, label, double.infinity);
    if (natural.width <= available) return natural.height;
    if (_wrappedAt != available) {
      _wrapped.clear();
      _wrappedAt = available;
    }
    return _wrapped[key] ??= _layOut(kind, label, available).height;
  }

  ({double width, double height}) _layOut(
    MediaGroupHeaderKind kind,
    String label,
    double maxWidth,
  ) {
    layouts++;
    final painter = TextPainter(
      text: TextSpan(text: label, style: _styles[kind]),
      textDirection: _textDirection,
      textScaler: _textScaler,
      locale: _locale,
      textHeightBehavior: _textHeightBehavior,
    )..layout(maxWidth: maxWidth);
    final size = (width: painter.maxIntrinsicWidth, height: painter.height);
    painter.dispose();
    return size;
  }
}
