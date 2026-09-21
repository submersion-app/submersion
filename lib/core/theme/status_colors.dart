import 'package:flutter/material.dart';

/// One severity's colors: a [container] fill with its [onContainer] label
/// and [outline] edge for filled surfaces (chips, banners, avatars), plus an
/// [accent] for marks drawn straight onto the page (status dots, due labels)
/// and an [onAccent] for glyphs drawn on top of a solid accent badge.
///
/// [onAccent] is its own slot rather than a reuse of [container] because
/// [accent] swaps sides between modes: dark on a light page, light on a dark
/// one. The color that reads on top of it is therefore near-white in light
/// and near-black in dark, which no other slot tracks.
@immutable
class StatusSwatch {
  const StatusSwatch({
    required this.container,
    required this.onContainer,
    required this.outline,
    required this.accent,
    required this.onAccent,
  });

  final Color container;
  final Color onContainer;
  final Color outline;
  final Color accent;
  final Color onAccent;

  static StatusSwatch lerp(StatusSwatch a, StatusSwatch b, double t) {
    return StatusSwatch(
      container: Color.lerp(a.container, b.container, t)!,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      outline: Color.lerp(a.outline, b.outline, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StatusSwatch &&
      other.container == container &&
      other.onContainer == onContainer &&
      other.outline == outline &&
      other.accent == accent &&
      other.onAccent == onAccent;

  @override
  int get hashCode =>
      Object.hash(container, onContainer, outline, accent, onAccent);
}

/// Semantic status colors (overdue, due soon, OK) exposed as a
/// [ThemeExtension], so they resolve against the active brightness and
/// animate across theme changes.
///
/// These are fixed hues rather than ColorScheme roles on purpose. `tertiary`
/// is a hue rotation of the seed, which made "due soon" lavender under the
/// ocean-blue preset; and the hand-built presets set no tertiary at all, so
/// it fell back to `secondary` and a due chip matched an OK chip. Red, amber
/// and green read the same under every preset.
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.alert,
    required this.warn,
    required this.ok,
  });

  /// Overdue, expired, or otherwise needing action now.
  final StatusSwatch alert;

  /// Due soon: worth attention before the next dive.
  final StatusSwatch warn;

  /// In date and good to go.
  final StatusSwatch ok;

  /// Light containers are solid fills, not tints. The pastel palette they
  /// replace sat about 1.05:1 against the page, so a status chip read as a
  /// smudge while the same chip in dark mode sat at 1.55:1 and read as a
  /// block. Reversing the label out of a saturated fill buys the separation
  /// a light page cannot get from a tint.
  static const StatusColors light = StatusColors(
    alert: StatusSwatch(
      container: Color(0xFFC62828),
      onContainer: Color(0xFFFFFFFF),
      outline: Color(0xFFA81F1F),
      accent: Color(0xFFC62828),
      onAccent: Color(0xFFFFFFFF),
    ),
    // Amber is the hue that goes illegible first on a light surface. Its
    // accent sits well past the Material 800 shade to hold 4.5:1 on every
    // preset's page color, and its container keeps a near-black label:
    // white text would force the fill down to a brown, which then reads as
    // a third red alongside the alert chips.
    warn: StatusSwatch(
      container: Color(0xFFF0A81E),
      onContainer: Color(0xFF3A2200),
      outline: Color(0xFFC9880A),
      accent: Color(0xFF955300),
      onAccent: Color(0xFFFFFFFF),
    ),
    ok: StatusSwatch(
      container: Color(0xFF256D2B),
      onContainer: Color(0xFFFFFFFF),
      outline: Color(0xFF1D5722),
      accent: Color(0xFF256D2B),
      onAccent: Color(0xFFFFFFFF),
    ),
  );

  /// Dark is unchanged. Its containers were already deep fills, which is the
  /// look light is now catching up to, and each [StatusSwatch.onAccent] holds
  /// the container value the avatar glyph was already painted with before
  /// that pairing had a slot of its own.
  static const StatusColors dark = StatusColors(
    // The established dark overdue chip, kept as is: its saturated fill is
    // already the strongest mark on a dark surface.
    alert: StatusSwatch(
      container: Color(0xFF93000A),
      onContainer: Color(0xFFFFDAD6),
      outline: Color(0xFFC4453D),
      accent: Color(0xFFFF8A80),
      onAccent: Color(0xFF93000A),
    ),
    warn: StatusSwatch(
      container: Color(0xFF4A3300),
      onContainer: Color(0xFFFFDE9E),
      outline: Color(0xFF7A5A10),
      accent: Color(0xFFFFB74D),
      onAccent: Color(0xFF4A3300),
    ),
    ok: StatusSwatch(
      container: Color(0xFF193D27),
      onContainer: Color(0xFFB7EBC6),
      outline: Color(0xFF3A6B4A),
      accent: Color(0xFF81C784),
      onAccent: Color(0xFF193D27),
    ),
  );

  /// The active theme's palette. Falls back to the constant for the theme's
  /// brightness, so a bare ThemeData (widget tests, previews) still gets
  /// status colors instead of a null check at every call site.
  static StatusColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<StatusColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  StatusColors copyWith({
    StatusSwatch? alert,
    StatusSwatch? warn,
    StatusSwatch? ok,
  }) {
    return StatusColors(
      alert: alert ?? this.alert,
      warn: warn ?? this.warn,
      ok: ok ?? this.ok,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      alert: StatusSwatch.lerp(alert, other.alert, t),
      warn: StatusSwatch.lerp(warn, other.warn, t),
      ok: StatusSwatch.lerp(ok, other.ok, t),
    );
  }
}
