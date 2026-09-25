import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/domain/figure_palette.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';

/// The palette for the current theme.
///
/// The mannequin is a blend of `onSurface` over `surface`, walked up until
/// it stands 1.6:1 off both the page surface and the container tint a card
/// sits on. Gear greys are fixed. The disc uses `primary` with whichever of
/// `onPrimary`, black or white reads on it.
FigurePalette figurePaletteFor(ColorScheme scheme) {
  final body = _bodyTone(scheme);
  final shade = Color.alphaBlend(scheme.surface.withValues(alpha: 0.35), body);
  final onDisc = EquipmentSectionColors.readableOn(scheme.primary, [
    scheme.onPrimary,
  ]);
  return FigurePalette(
    body: body.toARGB32(),
    bodyShade: shade.toARGB32(),
    gearDark: FigurePalette.light.gearDark,
    gearLight: FigurePalette.light.gearLight,
    metal: FigurePalette.light.metal,
    outline: FigurePalette.light.outline,
    disc: scheme.primary.toARGB32(),
    onDisc: onDisc.toARGB32(),
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
