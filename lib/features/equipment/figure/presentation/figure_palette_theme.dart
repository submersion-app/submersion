import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/domain/figure_palette.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';

/// The palette for the current theme.
///
/// The mannequin is a blend of `onSurface` over `surface`, walked up until
/// it stands 1.6:1 off both the page surface and the container tint a card
/// sits on. Gear greys are fixed. The number badge uses `primary` with whichever of
/// `onPrimary`, black or white reads on it.
FigurePalette figurePaletteFor(ColorScheme scheme) {
  final body = _bodyTone(scheme);
  final shade = Color.alphaBlend(scheme.surface.withValues(alpha: 0.35), body);
  final onBadge = EquipmentSectionColors.readableOn(scheme.primary, [
    scheme.onPrimary,
  ]);
  return FigurePalette(
    body: body.toARGB32(),
    bodyShade: shade.toARGB32(),
    gearDark: FigurePalette.light.gearDark,
    gearLight: FigurePalette.light.gearLight,
    metal: FigurePalette.light.metal,
    outline: FigurePalette.light.outline,
    badge: scheme.primary.toARGB32(),
    onBadge: onBadge.toARGB32(),
  );
}

/// Walks the blend up until the body stands off both surfaces and the fixed
/// dark gear grey still reads on it; on a dark scheme that second condition
/// is what lifts the body above the gear.
Color _bodyTone(ColorScheme scheme) {
  final gearDark = Color(FigurePalette.light.gearDark);
  for (var percent = 12; percent <= 100; percent += 2) {
    final blend = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: percent / 100),
      scheme.surface,
    );
    final offSurfaces = [
      scheme.surface,
      scheme.surfaceContainer,
    ].every((s) => contrastRatio(blend, s) >= 1.6);
    if (offSurfaces && contrastRatio(gearDark, blend) >= 2.0) return blend;
  }
  return scheme.onSurface;
}

/// The fill and text colours of a flashed legend row or tray tile.
class FigureHighlight {
  const FigureHighlight({required this.fill, required this.onFill});

  final Color fill;
  final Color onFill;
}

/// The flash for [scheme], derived by contrast rather than taken from
/// `primaryContainer`: four of the five presets leave that role unset, so
/// Flutter falls back to `primary` and a row filled with it hid its own
/// title. The fill is the faintest blend of `primary` over the card surface
/// that still stands off both the card and the page; the text is whichever
/// of `onSurface`, black or white reads on it.
FigureHighlight figureHighlightFor(ColorScheme scheme) {
  final card = scheme.surfaceContainerLow;
  var fill = scheme.primary;
  for (var percent = 16; percent <= 100; percent += 2) {
    final blend = Color.alphaBlend(
      scheme.primary.withValues(alpha: percent / 100),
      card,
    );
    final standsOff = [
      card,
      scheme.surface,
    ].every((s) => contrastRatio(blend, s) >= 1.25);
    if (standsOff) {
      fill = blend;
      break;
    }
  }
  return FigureHighlight(
    fill: fill,
    onFill: EquipmentSectionColors.readableOn(fill, [scheme.onSurface]),
  );
}

/// The fill and text of a name pill or tray tile, derived by contrast:
/// four of the five presets leave `surfaceContainerHighest` unset, so it
/// falls back to `surface` and a pill would vanish into the page. The fill
/// is the faintest blend of `onSurface` over the card that stands off it.
FigureHighlight figurePillFor(ColorScheme scheme) {
  final card = scheme.surfaceContainerLow;
  var fill = scheme.onSurface;
  for (var percent = 4; percent <= 60; percent += 2) {
    final blend = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: percent / 100),
      card,
    );
    if (contrastRatio(blend, card) >= 1.15) {
      fill = blend;
      break;
    }
  }
  return FigureHighlight(
    fill: fill,
    onFill: EquipmentSectionColors.readableOn(fill, [scheme.onSurface]),
  );
}
