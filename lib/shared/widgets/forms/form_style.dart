import 'package:flutter/material.dart';

/// Design tokens for the shared form system. Values match the header-in-card
/// design-freeze mockup (docs/superpowers/specs/assets/
/// 2026-07-17-edit-form-chrome-redesign-mockup.html); tune here, never inline.
abstract final class FormStyle {
  /// Corner radius of section groups and collapsed bars.
  static const double groupRadius = 13;

  /// Padding inside a label/value row.
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 11,
  );

  /// Padding around a hero stat strip.
  static const EdgeInsets heroPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  );

  /// Vertical gap between consecutive sections.
  static const double sectionGap = 14;

  /// Horizontal page padding around the whole form.
  static const EdgeInsets pagePadding = EdgeInsets.all(16);

  /// Tonal background of group surfaces and collapsed bars.
  static Color groupColor(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerLow;

  /// Hairline divider color between rows.
  static Color dividerColor(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  /// Big number in a hero stat cell.
  ///
  /// Pass [dense] for nested contexts (e.g. tank cards) where the value
  /// shares a narrower cell and the full-size number would overflow.
  static TextStyle heroValueStyle(BuildContext context, {bool dense = false}) {
    final theme = Theme.of(context);
    final base = dense
        ? theme.textTheme.titleMedium!
        : theme.textTheme.titleLarge!;
    return base.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: dense ? -0.3 : -0.5,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Small unit suffix inside a hero value (" m", " min").
  static TextStyle heroUnitStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Uppercase micro-label under a hero value.
  static TextStyle heroLabelStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelSmall!.copyWith(
      fontSize: 9,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Padding of the header row inside a section card.
  static const EdgeInsets headerPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  );

  /// Section title inside the card header.
  static TextStyle sectionTitleStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleMedium!.copyWith(
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Sub-header overline inside a section body (TANKS, EQUIPMENT, WEATHER).
  static TextStyle overlineStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelSmall!.copyWith(
      fontSize: 10.5,
      letterSpacing: 0.9,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Hairline border around section cards (light-theme discernibility).
  static Color cardBorderColor(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  /// Fainter color for empty-invitation text in a collapsed header.
  static Color invitationColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
}
