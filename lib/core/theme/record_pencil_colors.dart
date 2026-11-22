import 'package:flutter/material.dart';

/// The colours of the pencil that opens a card on an unlocked record page
/// (issue #4527): a filled [fill] disc with an [onFill] glyph and an
/// [outline] ring. The dot that marks a card's unsaved changes wears the
/// same fill and ring, so the two read as one editing colour.
///
/// Fixed hues rather than ColorScheme roles on purpose, as with
/// StatusColors. Every role the presets offer is a shade of the page's own
/// accent, so a pencil drawn in one of them blended into the cards around
/// it and divers had to hunt for it. Amber yellow is a warm hue far from
/// every preset's primary, and it reads the same under each of them. It is
/// a brighter, yellower amber than StatusColors' "due soon" accent.
@immutable
class RecordPencilColors extends ThemeExtension<RecordPencilColors> {
  const RecordPencilColors({
    required this.fill,
    required this.onFill,
    required this.outline,
  });

  /// The disc behind the glyph.
  final Color fill;

  /// The pencil glyph drawn on [fill].
  final Color onFill;

  /// The disc's ring.
  final Color outline;

  /// Yellow is bright but barely darker than a light card, so the ring is a
  /// deep gold that gives the disc (and the dot) an edge at 3:1 or better
  /// on every preset's card.
  static const RecordPencilColors light = RecordPencilColors(
    fill: Color(0xFFFFC107),
    onFill: Color(0xFF3A2A00),
    outline: Color(0xFF7A5200),
  );

  /// On a dark card the yellow itself stands far off the surface, so the
  /// ring is the fill and draws no edge of its own.
  static const RecordPencilColors dark = RecordPencilColors(
    fill: Color(0xFFFFCA28),
    onFill: Color(0xFF3A2A00),
    outline: Color(0xFFFFCA28),
  );

  /// The active theme's pencil colours. Falls back to the constant for the
  /// theme's brightness, so a bare ThemeData (widget tests, previews) still
  /// draws the amber yellow pencil.
  static RecordPencilColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<RecordPencilColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  RecordPencilColors copyWith({Color? fill, Color? onFill, Color? outline}) {
    return RecordPencilColors(
      fill: fill ?? this.fill,
      onFill: onFill ?? this.onFill,
      outline: outline ?? this.outline,
    );
  }

  @override
  RecordPencilColors lerp(ThemeExtension<RecordPencilColors>? other, double t) {
    if (other is! RecordPencilColors) return this;
    return RecordPencilColors(
      fill: Color.lerp(fill, other.fill, t)!,
      onFill: Color.lerp(onFill, other.onFill, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecordPencilColors &&
      other.fill == fill &&
      other.onFill == onFill &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(fill, onFill, outline);
}
