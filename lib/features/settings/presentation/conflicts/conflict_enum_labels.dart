import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_mode_label.dart';
import 'package:submersion/features/dive_log/presentation/formatters/profile_event_label.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/formatters/incident_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

export 'conflict_enum_labels_equipment.dart';
export 'conflict_enum_labels_people.dart';
export 'conflict_enum_labels_settings.dart';
export 'conflict_enum_labels_sites.dart';

/// Builds a labeler for an enum stored by name (or by [storedAs]). An unknown
/// stored value yields null so the formatter prints it as stored: a newer
/// peer may write a value this build has never heard of.
ConflictEnumLabeler enumLabeler<T extends Enum>(
  List<T> values,
  String Function(AppLocalizations l10n, T value) label, {
  String Function(T value)? storedAs,
}) {
  final byStored = {for (final v in values) (storedAs?.call(v) ?? v.name): v};
  return (l10n, stored) {
    final value = byStored[stored];
    return value == null ? null : label(l10n, value);
  };
}

final ConflictEnumLabeler entryMethodLabeler = enumLabeler(
  EntryMethod.values,
  (l, v) => v.localizedName(l),
);

/// The pre-v144 visibility bucket, still on dives logged before measured
/// visibility.
final ConflictEnumLabeler visibilityLabeler = enumLabeler(
  Visibility.values,
  (l, v) => visibilityName(v, l),
);

final ConflictEnumLabeler waterTypeLabeler = enumLabeler(
  WaterType.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler currentDirectionLabeler = enumLabeler(
  CurrentDirection.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler currentStrengthLabeler = enumLabeler(
  CurrentStrength.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler cloudCoverLabeler = enumLabeler(
  CloudCover.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler precipitationLabeler = enumLabeler(
  Precipitation.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler diveModeLabeler = enumLabeler(
  DiveMode.values,
  (l, v) => diveModeLabel(l, v),
);

final ConflictEnumLabeler scrTypeLabeler = enumLabeler(
  ScrType.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler tankRoleLabeler = enumLabeler(
  TankRole.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler tankMaterialLabeler = enumLabeler(
  TankMaterial.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler weightTypeLabeler = enumLabeler(
  WeightType.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler profileEventTypeLabeler = enumLabeler(
  ProfileEventType.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler incidentCategoryLabeler = enumLabeler(
  IncidentCategory.values,
  (l, v) => incidentCategoryLabel(l, v),
);

final ConflictEnumLabeler incidentSeverityLabeler = enumLabeler(
  IncidentSeverity.values,
  (l, v) => incidentSeverityLabel(l, v),
);

/// The words the dive edit form offers for this choice.
final ConflictEnumLabeler weightingFeedbackLabeler = enumLabeler(
  WeightingFeedback.values,
  (l, v) => switch (v) {
    WeightingFeedback.correct => l.diveLog_edit_weightFeedback_correct,
    WeightingFeedback.overweighted => l.diveLog_edit_weightFeedback_over,
    WeightingFeedback.underweighted => l.diveLog_edit_weightFeedback_under,
  },
);

final ConflictEnumLabeler eventSeverityLabeler = enumLabeler(
  EventSeverity.values,
  (l, v) => switch (v) {
    EventSeverity.info => l.enum_eventSeverity_info,
    EventSeverity.warning => l.enum_eventSeverity_warning,
    EventSeverity.alert => l.enum_eventSeverity_alert,
  },
);

final ConflictEnumLabeler eventSourceLabeler = enumLabeler(
  EventSource.values,
  (l, v) => switch (v) {
    EventSource.imported => l.enum_eventSource_imported,
    EventSource.computed => l.enum_eventSource_computed,
    EventSource.user => l.enum_eventSource_user,
  },
);

final ConflictEnumLabeler tankRoleSourceLabeler = enumLabeler(
  TankRoleSource.values,
  (l, v) => switch (v) {
    TankRoleSource.transmitterName => l.enum_tankRoleSource_transmitterName,
  },
);

final ConflictEnumLabeler weatherSourceLabeler = enumLabeler(
  WeatherSource.values,
  (l, v) => switch (v) {
    WeatherSource.manual => l.enum_weatherSource_manual,
    WeatherSource.openMeteo => l.enum_weatherSource_openMeteo,
  },
);

final ConflictEnumLabeler qualityCategoryLabeler = enumLabeler(
  QualityCategory.values,
  (l, v) => switch (v) {
    QualityCategory.time => l.enum_qualityCategory_time,
    QualityCategory.profile => l.enum_qualityCategory_profile,
    QualityCategory.temperature => l.enum_qualityCategory_temperature,
    QualityCategory.pressure => l.enum_qualityCategory_pressure,
    QualityCategory.gas => l.enum_qualityCategory_gas,
    QualityCategory.tank => l.enum_qualityCategory_tank,
    QualityCategory.source => l.enum_qualityCategory_source,
    QualityCategory.duplicate => l.enum_qualityCategory_duplicate,
  },
);

final ConflictEnumLabeler qualitySeverityLabeler = enumLabeler(
  QualitySeverity.values,
  (l, v) => switch (v) {
    QualitySeverity.info => l.enum_qualitySeverity_info,
    QualitySeverity.warning => l.enum_qualitySeverity_warning,
    QualitySeverity.critical => l.enum_qualitySeverity_critical,
  },
);

final ConflictEnumLabeler qualityStatusLabeler = enumLabeler(
  QualityStatus.values,
  (l, v) => switch (v) {
    QualityStatus.open => l.enum_qualityStatus_open,
    QualityStatus.dismissed => l.enum_qualityStatus_dismissed,
    QualityStatus.resolved => l.enum_qualityStatus_resolved,
  },
);

final ConflictEnumLabeler safetySeverityLabeler = enumLabeler(
  SafetySeverity.values,
  (l, v) => switch (v) {
    SafetySeverity.info => l.enum_safetySeverity_info,
    SafetySeverity.caution => l.enum_safetySeverity_caution,
    SafetySeverity.significant => l.enum_safetySeverity_significant,
  },
);
