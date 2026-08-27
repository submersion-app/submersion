import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized display name for an [IncidentCategory].
///
/// The exhaustive switch is compiler-checked, so a new [IncidentCategory]
/// value forces a corresponding localized string here.
String incidentCategoryLabel(AppLocalizations l10n, IncidentCategory c) {
  return switch (c) {
    IncidentCategory.buoyancy => l10n.incidentCategory_buoyancy,
    IncidentCategory.gasSupply => l10n.incidentCategory_gasSupply,
    IncidentCategory.equipment => l10n.incidentCategory_equipment,
    IncidentCategory.buddySeparation => l10n.incidentCategory_buddySeparation,
    IncidentCategory.marineLife => l10n.incidentCategory_marineLife,
    IncidentCategory.boatSurface => l10n.incidentCategory_boatSurface,
    IncidentCategory.medical => l10n.incidentCategory_medical,
    IncidentCategory.planning => l10n.incidentCategory_planning,
    IncidentCategory.other => l10n.incidentCategory_other,
  };
}

/// Localized display name for an [IncidentSeverity].
String incidentSeverityLabel(AppLocalizations l10n, IncidentSeverity s) {
  return switch (s) {
    IncidentSeverity.minor => l10n.incidentEdit_severity_minor,
    IncidentSeverity.moderate => l10n.incidentEdit_severity_moderate,
    IncidentSeverity.serious => l10n.incidentEdit_severity_serious,
  };
}
