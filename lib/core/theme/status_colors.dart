import 'package:flutter/material.dart';

/// One severity's colors: a tinted [container] with its [onContainer] label
/// and [outline] edge for filled surfaces (chips, banners, avatars), plus an
/// [accent] for marks drawn straight onto the page (status dots, due labels).
@immutable
class StatusSwatch {
  const StatusSwatch({
    required this.container,
    required this.onContainer,
    required this.outline,
    required this.accent,
  });

  final Color container;
  final Color onContainer;
  final Color outline;
  final Color accent;

  static StatusSwatch lerp(StatusSwatch a, StatusSwatch b, double t) {
    return StatusSwatch(
      container: Color.lerp(a.container, b.container, t)!,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      outline: Color.lerp(a.outline, b.outline, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StatusSwatch &&
      other.container == container &&
      other.onContainer == onContainer &&
      other.outline == outline &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(container, onContainer, outline, accent);
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

  static const StatusColors light = StatusColors(
    alert: StatusSwatch(
      container: Color(0xFFFDE3E1),
      onContainer: Color(0xFFA01D1D),
      outline: Color(0xFFE8A6A1),
      accent: Color(0xFFC62828),
    ),
    // Amber is the hue that goes illegible first on a light surface, so its
    // accent sits well past the Material 800 shade to hold 4.5:1 on every
    // preset's page color.
    warn: StatusSwatch(
      container: Color(0xFFFFEDC2),
      onContainer: Color(0xFF7A4500),
      outline: Color(0xFFE9BE62),
      accent: Color(0xFF955300),
    ),
    ok: StatusSwatch(
      container: Color(0xFFDCF2E3),
      onContainer: Color(0xFF1C5E34),
      outline: Color(0xFF9ACFAB),
      accent: Color(0xFF256D2B),
    ),
  );

  static const StatusColors dark = StatusColors(
    // The established dark overdue chip, kept as is: its saturated fill is
    // already the strongest mark on a dark surface.
    alert: StatusSwatch(
      container: Color(0xFF93000A),
      onContainer: Color(0xFFFFDAD6),
      outline: Color(0xFFC4453D),
      accent: Color(0xFFFF8A80),
    ),
    warn: StatusSwatch(
      container: Color(0xFF4A3300),
      onContainer: Color(0xFFFFDE9E),
      outline: Color(0xFF7A5A10),
      accent: Color(0xFFFFB74D),
    ),
    ok: StatusSwatch(
      container: Color(0xFF193D27),
      onContainer: Color(0xFFB7EBC6),
      outline: Color(0xFF3A6B4A),
      accent: Color(0xFF81C784),
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
