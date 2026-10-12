import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_label.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/swatch_name.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A stored profile colour (an ARGB int, as text) as "Cyan (#00ACC1)".
///
/// Matched against the palette rather than parsed, so form-code number
/// parsing stays in `readNumber` alone; a value off the palette (a newer
/// build's swatch, a corrupt row) returns null and the dialog prints it as
/// stored.
String? profileColorLabeler(AppLocalizations l10n, String stored) {
  for (final swatch in profileMetricSwatches) {
    final argb = swatch.toARGB32();
    if (stored != '$argb') continue;
    final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '${swatchName(l10n, swatch)} (#${rgb.toUpperCase()})';
  }
  return null;
}

/// One conflict-dialog field per `diver_settings.profile_color_*` column.
final Map<String, ConflictField> profileColorConflictFields = {
  for (final metric in ProfileMetric.values)
    metric.settingsKey: ConflictField(
      (l) =>
          l.settings_conflict_field_profileColor(profileMetricLabel(l, metric)),
      FieldKind.enumValue,
      enumLabel: profileColorLabeler,
    ),
};
