import 'package:flutter/widgets.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every label the conflict dialog can show resolves to text. The coverage
/// guard only proves each synced column has an entry; this calls each entry,
/// so a label pointing at an empty string, or an enum value with no label,
/// fails here rather than in front of a diver.
void main() {
  late AppLocalizations en;
  late AppLocalizations de;
  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    de = await AppLocalizations.delegate.load(const Locale('de'));
  });

  test('every catalogued field has a label in every tested locale', () {
    final fields = {...conflictFieldCatalogue, ...conflictFieldOverrides};
    for (final MapEntry(key: column, value: field) in fields.entries) {
      for (final l10n in [en, de]) {
        expect(field.label(l10n).trim(), isNotEmpty, reason: column);
      }
      if (field.kind == FieldKind.enumValue) {
        expect(field.enumLabel, isNotNull, reason: '$column has no labeler');
      }
    }
  });

  test('every enum labeler names every value of its enum', () {
    final labelers = <(ConflictEnumLabeler, List<Enum>)>[
      (entryMethodLabeler, EntryMethod.values),
      (visibilityLabeler, Visibility.values),
      (waterTypeLabeler, WaterType.values),
      (currentDirectionLabeler, CurrentDirection.values),
      (currentStrengthLabeler, CurrentStrength.values),
      (cloudCoverLabeler, CloudCover.values),
      (precipitationLabeler, Precipitation.values),
      (diveModeLabeler, DiveMode.values),
      (scrTypeLabeler, ScrType.values),
      (tankRoleLabeler, TankRole.values),
      (tankMaterialLabeler, TankMaterial.values),
      (weightTypeLabeler, WeightType.values),
      (profileEventTypeLabeler, ProfileEventType.values),
      (incidentCategoryLabeler, IncidentCategory.values),
      (incidentSeverityLabeler, IncidentSeverity.values),
      (weightingFeedbackLabeler, WeightingFeedback.values),
      (eventSeverityLabeler, EventSeverity.values),
      (eventSourceLabeler, EventSource.values),
      (tankRoleSourceLabeler, TankRoleSource.values),
      (weatherSourceLabeler, WeatherSource.values),
      (qualityCategoryLabeler, QualityCategory.values),
      (qualitySeverityLabeler, QualitySeverity.values),
      (qualityStatusLabeler, QualityStatus.values),
      (safetySeverityLabeler, SafetySeverity.values),
      (equipmentStatusLabeler, EquipmentStatus.values),
      (observationStatusLabeler, ObservationStatus.values),
      (serviceCategoryLabeler, ServiceCategory.values),
      (conditionSeverityLabeler, ConditionSeverity.values),
      (fillSourceLabeler, FillSource.values),
      (ownershipEventKindLabeler, EquipmentOwnershipEventKind.values),
      (certificationAgencyLabeler, CertificationAgency.values),
      (certificationLevelLabeler, CertificationLevel.values),
      (planModeLabeler, PlanMode.values),
      (turnPressureRuleLabeler, TurnPressureRule.values),
      (missionEnvironmentLabeler, MissionEnvironment.values),
      (requirementKindLabeler, RequirementKind.values),
      (preDiveSessionStatusLabeler, PreDiveSessionStatus.values),
      (preDiveItemStateLabeler, PreDiveItemState.values),
      (preDiveItemTypeLabeler, PreDiveItemType.values),
      (depthUnitLabeler, DepthUnit.values),
      (pressureUnitLabeler, PressureUnit.values),
      (temperatureUnitLabeler, TemperatureUnit.values),
      (volumeUnitLabeler, VolumeUnit.values),
      (weightUnitLabeler, WeightUnit.values),
      (altitudeUnitLabeler, AltitudeUnit.values),
      (dateFormatLabeler, DateFormatPreference.values),
      (timeFormatLabeler, TimeFormat.values),
      (listViewModeLabeler, ListViewMode.values),
      (diveDetailLayoutLabeler, DiveDetailLayout.values),
      (cardColorAttributeLabeler, CardColorAttribute.values),
      (mapStyleLabeler, MapStyle.values),
      (cnsCalculationMethodLabeler, CnsCalculationMethod.values),
      (noFlyPresetLabeler, NoFlyPreset.values),
      (siteMatchSensitivityLabeler, SiteMatchSensitivity.values),
      (gasModelLabeler, GasModel.values),
      (gasConsumptionDisplayLabeler, GasConsumptionDisplay.values),
      (plannerWaterTypeLabeler, PlannerWaterType.values),
      (profileRightAxisMetricLabeler, ProfileRightAxisMetric.values),
      (visibilityScalePresetLabeler, VisibilityScalePreset.values),
      (coordinateFormatLabeler, CoordinateFormat.values),
      (tissueColorSchemeLabeler, TissueColorScheme.values),
      (tissueVizModeLabeler, TissueVizMode.values),
      (manifestFormatLabeler, ManifestFormat.values),
      (matchConfidenceLabeler, MatchConfidence.values),
      (mediaSourceTypeLabeler, MediaSourceType.values),
      (speciesCategoryLabeler, SpeciesCategory.values),
      (siteDifficultyLabeler, SiteDifficulty.values),
      (tideStateLabeler, TideState.values),
      (equipmentTypeLabeler, EquipmentType.values),
      (dayTypeLabeler, DayType.values),
      (tripTypeLabeler, TripType.values),
      (rentalVerdictLabeler, RentalVerdict.values),
      (tripCylinderEventKindLabeler, TripCylinderEventKind.values),
    ];
    for (final (labeler, values) in labelers) {
      for (final value in values) {
        for (final l10n in [en, de]) {
          expect(
            labeler(l10n, value.name)?.trim(),
            isNotEmpty,
            reason: '${value.runtimeType}.${value.name}',
          );
        }
      }
    }
  });

  test('the string-keyed labelers name every stored value', () {
    for (final mode in ['light', 'dark', 'system']) {
      expect(themeModeLabeler(en, mode), isNotEmpty);
    }
    expect(siteFeatureTypeLabeler(en, 'wreck'), isNotEmpty);
  });
}
