import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/insights/domain/suit_type.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A suit type as the Suit Type chart and the Focus "Suit" factor show it
/// (issue #4490): "Drysuit", or "Wetsuit · 5 mm full" with a missing
/// thickness or style left out ("Wetsuit · shorty", "Wetsuit").
String suitTypeLabel(SuitType type, AppLocalizations l10n) {
  if (type.isDrysuit) return EquipmentType.drysuit.localizedName(l10n);
  final text = type.thicknessText;
  final thickness = text == null ? null : localiseDecimalText(text);
  final style = switch (type.style) {
    null => null,
    final key => _styleWord(key, l10n),
  };
  return switch ((thickness, style)) {
    (final String mm, final String style) =>
      l10n.insights_suitType_wetsuitThicknessStyle(mm, style),
    (final String mm, null) => l10n.insights_suitType_wetsuitThickness(mm),
    (null, final String style) => l10n.insights_suitType_wetsuitStyle(style),
    (null, null) => EquipmentType.wetsuit.localizedName(l10n),
  };
}

/// The style as a word that follows the thickness ("full", not the
/// standalone "Full suit"); a key outside the catalog shows as stored.
String _styleWord(String key, AppLocalizations l10n) => switch (key) {
  'full' => l10n.insights_suitType_style_full,
  'shorty' => l10n.insights_suitType_style_shorty,
  'two_piece' => l10n.insights_suitType_style_twoPiece,
  'semi_dry' => l10n.insights_suitType_style_semiDry,
  _ => key,
};
