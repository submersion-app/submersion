import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/domain/tag_palette.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name a diver and a screen reader know a palette colour by: the hue's
/// name, with "light" or "dark" for the shades either side of it (issue
/// #4384). The hue names are the equipment colour names, which already cover
/// the base palette in every language.
String tagColorName(AppLocalizations l10n, TagPaletteEntry entry) {
  final hue = equipmentColorName(l10n, TagColors.predefined[entry.hue]);
  return switch (entry.shade) {
    TagShade.light => l10n.tags_color_shadeLight(hue),
    TagShade.base => hue,
    TagShade.dark => l10n.tags_color_shadeDark(hue),
  };
}
