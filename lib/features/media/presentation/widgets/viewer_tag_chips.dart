import 'package:flutter/material.dart';

/// The look of the tag chips in the media viewer's bottom panel (issue
/// #4921): small and translucent, so a row of people and species reads as
/// a caption over the picture rather than a bar of buttons across it.
///
/// [theme] carries what a [ChipTheme] can. The chips take [density] and
/// [iconSize] themselves, as they set both explicitly elsewhere.
abstract final class ViewerTagChips {
  /// The label's size.
  static const double fontSize = 12;

  /// The size of a chip's leading icon and of the pin after a suggestion.
  static const double iconSize = 14;

  /// As small as a chip draws.
  static const VisualDensity density = VisualDensity(
    horizontal: VisualDensity.minimumDensity,
    vertical: VisualDensity.minimumDensity,
  );

  /// A tag's fill: a dark wash (35% black) the picture shows through.
  static const Color fill = Color(0x59000000);

  /// A tag's fill under the pointer or a press (50% black).
  static const Color fillActive = Color(0x80000000);

  /// The hairline round a tag, and a suggestion's outline (32% white).
  static const Color outline = Color(0x52FFFFFF);

  /// The label and icon colour (90% white).
  static const Color foreground = Color(0xE6FFFFFF);

  /// A suggestion's fill: none, so it reads apart from a tag, with a faint
  /// light wash under the pointer or a press.
  static final WidgetStateProperty<Color> suggestionColor =
      WidgetStateProperty.resolveWith(
        (states) =>
            _active(states) ? const Color(0x1AFFFFFF) : Colors.transparent,
      );

  static final WidgetStateProperty<Color> _tagColor =
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
  static Widget theme(BuildContext context, {required Widget child}) {
    final base = Theme.of(context).textTheme.labelMedium ?? const TextStyle();
    return ChipTheme(
      data: ChipTheme.of(context).copyWith(
        color: _tagColor,
        side: const BorderSide(color: outline, width: 0.5),
        labelStyle: base.copyWith(fontSize: fontSize, color: foreground),
        iconTheme: const IconThemeData(color: foreground, size: iconSize),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: child,
    );
  }
}
