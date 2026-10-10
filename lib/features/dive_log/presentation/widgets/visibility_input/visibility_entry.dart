import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Which visibility input the edit form shows (issue #3226).
enum VisibilityInputMode { range, precise }

/// A dive's visibility as stored: at most one of a measured distance, a
/// range, or a pre-v144 bucket (issue #3226).
class StoredVisibility {
  final double? meters;
  final VisibilityRange? range;
  final Visibility? legacy;

  const StoredVisibility({this.meters, this.range, this.legacy});

  static const none = StoredVisibility();

  /// [dive]'s stored shape; [Visibility.unknown] counts as no bucket.
  factory StoredVisibility.of(Dive dive) => StoredVisibility(
    meters: dive.visibilityMeters,
    range: dive.visibilityRange,
    legacy: dive.visibility == Visibility.unknown ? null : dive.visibility,
  );

  bool get isEmpty => meters == null && range == null && legacy == null;

  /// The mode a dive opens in: the shape it was saved in. A legacy bucket
  /// is a range of sorts, so it opens in Range. Null for no visibility, so
  /// the caller falls back to the remembered mode.
  VisibilityInputMode? get naturalMode {
    if (meters != null) return VisibilityInputMode.precise;
    if (range != null || legacy != null) return VisibilityInputMode.range;
    return null;
  }

  /// The mode to remember after saving this: only a new value counts, never
  /// a legacy bucket carried through.
  VisibilityInputMode? get modeToRemember {
    if (meters != null) return VisibilityInputMode.precise;
    if (range != null) return VisibilityInputMode.range;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is StoredVisibility &&
      other.meters == meters &&
      other.range == range &&
      other.legacy == legacy;

  @override
  int get hashCode => Object.hash(meters, range, legacy);

  @override
  String toString() => 'StoredVisibility($meters, $range, $legacy)';
}

/// What a save writes for the visibility input.
///
/// Until the diver touches the input (types a number or taps a chip) the
/// dive keeps exactly what it had: re-saving to fix the notes must not
/// round a measurement or rewrite a range under a changed scale. Once
/// touched, only the active mode's value is saved, and an empty active mode
/// saves no visibility.
StoredVisibility resolveVisibilityEntry({
  required VisibilityInputMode mode,
  required double? preciseMeters,
  required VisibilityBand? band,
  required bool touched,
  required StoredVisibility original,
  required VisibilityScale scale,
}) {
  if (!touched) return original;
  if (mode == VisibilityInputMode.precise && preciseMeters != null) {
    return StoredVisibility(meters: preciseMeters);
  }
  if (mode == VisibilityInputMode.range && band != null) {
    return StoredVisibility(range: scale.rangeFor(band));
  }
  return StoredVisibility.none;
}

/// The chip shown selected: the diver's pick once touched, else the band
/// whose range equals the stored range on the current scale. Derived at
/// build time so it follows the scale once settings finish loading.
VisibilityBand? effectiveVisibilityBand({
  required VisibilityBand? band,
  required bool touched,
  required StoredVisibility original,
  required VisibilityScale scale,
}) {
  if (touched) return band;
  final range = original.range;
  return range == null ? null : scale.bandMatching(range);
}

/// The caption under the visibility input: the band a typed number falls
/// in, the range a picked chip saves, or, before the diver touches the
/// input, the stored range or legacy bucket it will keep.
String? visibilityEntryCaption({
  required VisibilityInputMode mode,
  required double? preciseMeters,
  required VisibilityBand? band,
  required bool touched,
  required StoredVisibility original,
  required VisibilityScale scale,
  required AppLocalizations l10n,
  required UnitFormatter units,
}) {
  switch (mode) {
    case VisibilityInputMode.precise:
      if (preciseMeters != null) {
        return visibilityBandName(scale.bandFor(preciseMeters), l10n);
      }
    case VisibilityInputMode.range:
      if (band != null) {
        return formatVisibilityRange(scale.rangeFor(band), l10n, units);
      }
  }
  if (touched) return null;
  if (original.range case final range?) {
    return formatVisibilityRange(range, l10n, units);
  }
  if (original.legacy case final legacy?) {
    return formatLegacyVisibilityBand(legacy, l10n, units);
  }
  return null;
}
