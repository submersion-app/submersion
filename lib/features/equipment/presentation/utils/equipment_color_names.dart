import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name a diver and a screen reader know an item colour by: the
/// palette colour's localized name, or the code itself for a colour from
/// outside the palette (an import or a peer can write any `#RRGGBB`).
String equipmentColorName(AppLocalizations l10n, String hex) {
  final code = normalizeEquipmentColor(hex) ?? hex;
  return switch (code) {
    '#EF4444' => l10n.equipment_color_red,
    '#F97316' => l10n.equipment_color_orange,
    '#F59E0B' => l10n.equipment_color_amber,
    '#EAB308' => l10n.equipment_color_yellow,
    '#84CC16' => l10n.equipment_color_lime,
    '#22C55E' => l10n.equipment_color_green,
    '#10B981' => l10n.equipment_color_emerald,
    '#14B8A6' => l10n.equipment_color_teal,
    '#06B6D4' => l10n.equipment_color_cyan,
    '#0EA5E9' => l10n.equipment_color_sky,
    '#3B82F6' => l10n.equipment_color_blue,
    '#6366F1' => l10n.equipment_color_indigo,
    '#8B5CF6' => l10n.equipment_color_violet,
    '#A855F7' => l10n.equipment_color_purple,
    '#D946EF' => l10n.equipment_color_fuchsia,
    '#EC4899' => l10n.equipment_color_pink,
    '#F43F5E' => l10n.equipment_color_rose,
    '#78716C' => l10n.equipment_color_stone,
    '#71717A' => l10n.equipment_color_zinc,
    '#64748B' => l10n.equipment_color_slate,
    _ => code,
  };
}
