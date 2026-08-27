import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// On-screen rendering of a dive's visibility.
///
/// Two shapes exist because two kinds of data exist. A dive logged from v144
/// carries a measured distance, so it can be shown as a distance plus the
/// adjective the diver's calibration assigns. A dive logged earlier carries
/// only a coarse bucket, so it can only be shown as the range that bucket
/// covers.
///
/// The enum `displayName` values remain the locale-independent strings used
/// for data interchange; everything here honours the active locale and the
/// diver's unit settings.

/// Parses a visibility entry field into meters, or null when the text is
/// empty, unparseable, or negative.
///
/// Never coerces a bad value to zero. Text that fails to parse (stray
/// characters) means visibility is unknown, not that the diver measured zero
/// visibility; persisting 0 would record a measurement nobody took and bin the
/// dive into the worst band.
///
/// A decimal comma is read, not rejected: it is what the diver's own locale
/// displays, and treating "12,5" as unknown discarded the entry (#1091).
double? parseVisibilityInput(String text, UnitFormatter units) {
  final parsed = parseUserDecimal(text);
  if (parsed == null || parsed < 0) return null;
  return units.depthToMeters(parsed);
}

/// Localized name for a calibrated band.
String visibilityBandName(VisibilityBand band, AppLocalizations l10n) =>
    switch (band) {
      VisibilityBand.excellent => l10n.enum_visibilityBand_excellent,
      VisibilityBand.good => l10n.enum_visibilityBand_good,
      VisibilityBand.moderate => l10n.enum_visibilityBand_moderate,
      VisibilityBand.poor => l10n.enum_visibilityBand_poor,
    };

/// Renders a measured distance together with the adjective [scale] assigns it,
/// for example "20ft · Excellent".
///
/// [meters] is the stored metric value; [units] converts it for display. The
/// band is always decided on the metric value, so switching units never
/// changes the adjective.
String formatMeasuredVisibility(
  double meters,
  VisibilityScale scale,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  final distance = units.formatDistance(meters);
  final band = visibilityBandName(scale.bandFor(meters), l10n);
  return '$distance · $band';
}

/// Turns a statistics distribution key into display text.
///
/// The repository emits stable keys rather than display text: a calibrated
/// band yields its [VisibilityBand] name, and a pre-v144 dive yields
/// `legacy_<bucket>`. A legacy key renders as the range that bucket covers,
/// marked as pre-measurement, so it is never mistaken for a calibrated
/// reading.
///
/// An unrecognized key can only come from a repository bug, so it is surfaced
/// verbatim. Falling back to a real band would label unknown data as a
/// legitimate result and hide the defect.
String visibilityDistributionLabel(
  String key,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  const legacyPrefix = 'legacy_';
  if (key.startsWith(legacyPrefix)) {
    final name = key.substring(legacyPrefix.length);
    final bucket = Visibility.values.where((v) => v.name == name).firstOrNull;
    final band = bucket == null
        ? null
        : formatLegacyVisibilityBand(bucket, l10n, units);
    return l10n.statistics_conditions_visibility_legacySuffix(band ?? name);
  }
  final band = VisibilityBand.values.where((b) => b.name == key).firstOrNull;
  return band == null ? key : visibilityBandName(band, l10n);
}

/// Renders a pre-v144 bucket as the distance range it actually means, for
/// example "5-15m".
///
/// Deliberately never returns an adjective. The stored bucket only tells us
/// the dive fell somewhere in this range, so applying the diver's calibration
/// would assert something we cannot know. Returns null for
/// [Visibility.unknown], which carries no range at all.
String? formatLegacyVisibilityBand(
  Visibility legacy,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  final min = legacy.bandMinM;
  final max = legacy.bandMaxM;
  if (min == null && max == null) return null;

  final unit = units.depthSymbol;
  String value(double meters) => units.convertDepth(meters).toStringAsFixed(0);

  if (min == null) return l10n.visibility_range_under(value(max!), unit);
  if (max == null) return l10n.visibility_range_over(value(min), unit);
  return l10n.visibility_range_between(value(min), value(max), unit);
}
