import 'package:flutter/material.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

/// One colour per kind, taken from the destination accents so every theme
/// preset and both brightnesses are covered. Kind colour is data encoding,
/// not chrome, so the diver's accent toggles do not apply here.
class ConnectionKindColors {
  const ConnectionKindColors(this._colors, this.fallback);

  final Map<ConnectionKind, Color> _colors;
  final Color fallback;

  factory ConnectionKindColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        theme.extension<FeatureAccentColors>() ??
        (theme.brightness == Brightness.dark
            ? FeatureAccentColors.dark
            : FeatureAccentColors.light);
    final fallback = palette.of('connections') ?? theme.colorScheme.primary;
    return ConnectionKindColors({
      for (final kind in ConnectionKind.values)
        if (kind.accentFeatureId != null &&
            palette.of(kind.accentFeatureId!) != null)
          kind: palette.of(kind.accentFeatureId!)!,
    }, fallback);
  }

  Color colorFor(ConnectionKind kind) => _colors[kind] ?? fallback;
}
