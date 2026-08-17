import 'package:submersion/features/wrecks/domain/entities/wreck.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for the wreck vocabularies.
///
/// Each helper takes the RAW stored string: a name this build does not
/// know (written by a newer version, or by a future external source) is
/// shown as-is rather than vanishing from the UI. Null yields the empty
/// string so callers can concatenate without a null check.
String wreckVesselTypeLabel(AppLocalizations l10n, String? raw) {
  if (raw == null) return '';
  return switch (WreckVesselType.values.asNameMap()[raw]) {
    WreckVesselType.ship => l10n.wrecks_type_ship,
    WreckVesselType.aircraft => l10n.wrecks_type_aircraft,
    WreckVesselType.other => l10n.wrecks_type_other,
    null => raw,
  };
}

String wreckCauseLabel(AppLocalizations l10n, String? raw) {
  if (raw == null) return '';
  return switch (WreckCause.values.asNameMap()[raw]) {
    WreckCause.foundered => l10n.wrecks_cause_foundered,
    WreckCause.collision => l10n.wrecks_cause_collision,
    WreckCause.grounding => l10n.wrecks_cause_grounding,
    WreckCause.scuttled => l10n.wrecks_cause_scuttled,
    WreckCause.war => l10n.wrecks_cause_war,
    WreckCause.fire => l10n.wrecks_cause_fire,
    WreckCause.unknown => l10n.wrecks_cause_unknown,
    null => raw,
  };
}

String wreckConditionLabel(AppLocalizations l10n, String? raw) {
  if (raw == null) return '';
  return switch (WreckCondition.values.asNameMap()[raw]) {
    WreckCondition.intact => l10n.wrecks_condition_intact,
    WreckCondition.broken => l10n.wrecks_condition_broken,
    WreckCondition.debris => l10n.wrecks_condition_debris,
    null => raw,
  };
}

String wreckProtectionLabel(AppLocalizations l10n, String? raw) {
  if (raw == null) return '';
  return switch (WreckProtection.values.asNameMap()[raw]) {
    WreckProtection.none => l10n.wrecks_protection_none,
    WreckProtection.permitRequired => l10n.wrecks_protection_permitRequired,
    WreckProtection.protected => l10n.wrecks_protection_protected,
    WreckProtection.warGrave => l10n.wrecks_protection_warGrave,
    null => raw,
  };
}

/// A depth or length in meters rendered in the diver's unit, or the empty
/// string when the value is unknown.
String wreckMeasure(double? meters, double unitInMeters, String symbol) {
  if (meters == null) return '';
  final v = meters / unitInMeters;
  final text = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '$text $symbol';
}
