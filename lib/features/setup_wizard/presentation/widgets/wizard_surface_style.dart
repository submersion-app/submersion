import 'package:flutter/material.dart';

/// Shared translucency/shape constants for the setup wizard's surfaces.
///
/// Centralised so the main card panel and every clickable selection card (fork
/// choices, existing-data sources, cloud providers) tune from one place and
/// read as the same "glass" floating over the ocean background — instead of a
/// mix of hard-coded alphas scattered across steps.
class WizardSurfaceStyle {
  const WizardSurfaceStyle._();

  /// Translucent fill for the wizard's main card panel.
  static Color panel(ThemeData theme) =>
      theme.colorScheme.surface.withValues(alpha: 0.2);

  /// Medium-translucent fill for a selection card: clearly visible over the
  /// bright ocean without the heavy opaque-dark look of a default [Card].
  static Color optionFill(ThemeData theme) =>
      theme.colorScheme.onSurface.withValues(alpha: 0.1);

  /// Rounded outline with a faint translucent border for a selection card.
  static ShapeBorder optionShape(ThemeData theme) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.16),
    ),
  );
}
