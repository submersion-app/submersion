import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

enum MediaGroupHeaderKind { month, day, dive }

/// One header in the grouped gallery. Everything that sets a header's height
/// comes from here, for [MediaGroupHeader] to draw and
/// [MediaGroupHeaderMeasurer] to measure, so the two cannot drift: the grid
/// needs every header's height before it builds any of them.
class MediaGroupHeaderSpec {
  const MediaGroupHeaderSpec({
    required this.kind,
    required this.label,
    this.diveId,
  });

  final MediaGroupHeaderKind kind;
  final String label;

  /// The dive this header opens, if it opens one right now: null while a
  /// selection is in progress, as well as for the Unlinked group.
  final String? diveId;

  bool get navigable => diveId != null;

  /// 48 is Material's tap-target floor.
  double get minHeight => navigable ? 48 : 0;

  EdgeInsets get padding => switch (kind) {
    MediaGroupHeaderKind.month => const EdgeInsets.fromLTRB(12, 16, 12, 4),
    MediaGroupHeaderKind.day => const EdgeInsets.fromLTRB(12, 8, 12, 4),
    MediaGroupHeaderKind.dive => const EdgeInsets.fromLTRB(12, 12, 12, 4),
  };

  static TextStyle? themeStyleOf(
    MediaGroupHeaderKind kind,
    TextTheme textTheme,
  ) => switch (kind) {
    MediaGroupHeaderKind.day => textTheme.labelLarge,
    MediaGroupHeaderKind.month ||
    MediaGroupHeaderKind.dive => textTheme.titleMedium,
  };
}

/// A month, day or dive heading over a group of thumbnails. A navigable one
/// is the view's only route to its dive.
class MediaGroupHeader extends StatelessWidget {
  const MediaGroupHeader({super.key, required this.spec, required this.onTap});

  final MediaGroupHeaderSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      spec.label,
      style: MediaGroupHeaderSpec.themeStyleOf(
        spec.kind,
        Theme.of(context).textTheme,
      ),
    );
    if (!spec.navigable) return Padding(padding: spec.padding, child: text);
    return Semantics(
      button: true,
      label: spec.label,
      hint: context.l10n.media_library_diveHeaderHint,
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
      math.max(0, paneWidth - spec.padding.horizontal),
    );
    return math.max(spec.minHeight, textHeight + spec.padding.vertical);
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
