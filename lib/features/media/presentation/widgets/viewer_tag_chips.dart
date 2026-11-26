import 'package:flutter/material.dart';

/// The look of the tag chips in the media viewer's bottom panel (issue
/// #4921): small and translucent, so a row of people and species reads as
/// a caption over the picture rather than a bar of buttons across it.
///
/// [theme] carries what a [ChipTheme] can. The chips take [density] and
/// [iconSize] themselves, as they set both explicitly elsewhere.
abstract final class ViewerTagChips {
  /// The label's size.
  static const double fontSize = 11;

  /// The size of a chip's leading icon and of the pin after a suggestion.
  static const double iconSize = 12;

  /// As small as a chip draws.
  static const VisualDensity density = VisualDensity(
    horizontal: VisualDensity.minimumDensity,
    vertical: VisualDensity.minimumDensity,
  );

  /// Every chip's fill: a dark wash (50% black) the picture shows
  /// through, dark enough that the label reads over bright reef or sand.
  /// Suggestions take it too: on a locked photo, as the viewer opens,
  /// they are inert, and an unfilled chip's label is lost on a light
  /// picture. The "+" and the score set them apart from tags.
  static const Color fill = Color(0x80000000);

  /// The fill under the pointer or a press (65% black).
  static const Color fillActive = Color(0xA6000000);

  /// The hairline round a tag, and a suggestion's outline (32% white).
  static const Color outline = Color(0x52FFFFFF);

  /// The label and icon colour (90% white), on a chip that does nothing
  /// as on one that answers a tap, so neither is ever hard to read.
  static const Color foreground = Color(0xE6FFFFFF);

  static final WidgetStateProperty<Color> _fillColor =
      WidgetStateProperty.resolveWith(
        (states) => _active(states) ? fillActive : fill,
      );

  static bool _active(Set<WidgetState> states) =>
      states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.pressed) ||
      states.contains(WidgetState.focused);

  /// [child]'s chips in the viewer's style. A chip given its own colour
  /// passes by the hover wash a theme colour would bring, so the active
  /// states are part of the colour itself.
  ///
  /// A chip paints its colour over a [Material] of its own, in the theme's
  /// canvas colour: near white in the light theme, which made a tag's dark
  /// wash an opaque grey and a suggestion a white bar its white label
  /// vanished into. The canvas is cleared here, so the picture shows
  /// through.
  static Widget theme(BuildContext context, {required Widget child}) {
    final appTheme = Theme.of(context);
    final base = appTheme.textTheme.labelMedium ?? const TextStyle();
    final chips = ChipTheme(
      data: ChipTheme.of(context).copyWith(
        color: _fillColor,
        side: const BorderSide(color: outline, width: 0.5),
        labelStyle: base.copyWith(fontSize: fontSize, color: foreground),
        iconTheme: const IconThemeData(color: foreground, size: iconSize),
        // The icon in a box its own size, not one as tall as the chip.
        avatarBoxConstraints: const BoxConstraints.tightFor(
          width: iconSize + 2,
          height: iconSize,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 3),
      ),
      child: child,
    );
    return Theme(
      data: appTheme.copyWith(canvasColor: Colors.transparent),
      child: chips,
    );
  }
}
