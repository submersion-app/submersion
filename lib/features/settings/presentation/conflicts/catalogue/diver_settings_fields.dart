import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Conflict labels and value kinds for the diver's settings (#694). Generated from a
/// reviewed column list; the coverage guard in
/// test/features/settings/presentation/conflicts/ keeps it complete.
final Map<String, ConflictField> diverSettingsFields = {
  'accentListIcons': ConflictField(
    (l) => l.settings_conflict_field_accentListIcons,
    FieldKind.boolean,
  ),
  'accentNavIcons': ConflictField(
    (l) => l.settings_conflict_field_accentNavIcons,
    FieldKind.boolean,
  ),
  'accentSectionHeaders': ConflictField(
    (l) => l.settings_conflict_field_accentSectionHeaders,
    FieldKind.boolean,
  ),
  'altitudeUnit': ConflictField(
    (l) => l.settings_conflict_field_altitudeUnit,
    FieldKind.enumValue,
    enumLabel: altitudeUnitLabeler,
  ),
  'applyDefaultTankToImports': ConflictField(
    (l) => l.settings_conflict_field_applyDefaultTankToImports,
    FieldKind.boolean,
  ),
  'ascentGasSet': ConflictField(
    (l) => l.settings_conflict_field_ascentGasSet,
    FieldKind.number,
  ),
  'ascentRateCritical': ConflictField(
    (l) => l.settings_conflict_field_ascentRateCritical,
    FieldKind.ascentRate,
  ),
  'ascentRateWarning': ConflictField(
    (l) => l.settings_conflict_field_ascentRateWarning,
    FieldKind.ascentRate,
  ),
  'autoTagImports': ConflictField(
    (l) => l.settings_conflict_field_autoTagImports,
    FieldKind.boolean,
  ),
  'buddyListViewMode': ConflictField(
    (l) => l.settings_conflict_field_buddyListViewMode,
    FieldKind.enumValue,
    enumLabel: listViewModeLabeler,
  ),
  'cardColorAttribute': ConflictField(
    (l) => l.settings_appearance_cardColorAttribute,
    FieldKind.enumValue,
    enumLabel: cardColorAttributeLabeler,
  ),
  'cardColorGradientEnd': ConflictField(
    (l) => l.settings_conflict_field_cardColorGradientEnd,
    FieldKind.opaque,
  ),
  'cardColorGradientPreset': ConflictField(
    (l) => l.settings_conflict_field_cardColorGradientPreset,
    FieldKind.shortText,
  ),
  'cardColorGradientStart': ConflictField(
    (l) => l.settings_conflict_field_cardColorGradientStart,
    FieldKind.opaque,
  ),
  'ccrDiluentModPpO2': ConflictField(
    (l) => l.settings_conflict_field_ccrDiluentModPpO2,
    FieldKind.partialPressure,
  ),
  'ccrSetpointHigh': ConflictField(
    (l) => l.settings_conflict_field_ccrSetpointHigh,
    FieldKind.partialPressure,
  ),
  'ccrSetpointLow': ConflictField(
    (l) => l.settings_conflict_field_ccrSetpointLow,
    FieldKind.partialPressure,
  ),
  'certificationListViewMode': ConflictField(
    (l) => l.settings_appearance_listView_certifications,
    FieldKind.enumValue,
    enumLabel: listViewModeLabeler,
  ),
  'cnsCalculationMethod': ConflictField(
    (l) => l.settings_decompression_cnsMethodTitle,
    FieldKind.enumValue,
    enumLabel: cnsCalculationMethodLabeler,
  ),
  'cnsWarningThreshold': ConflictField(
    (l) => l.settings_conflict_field_cnsWarningThreshold,
    FieldKind.percent,
  ),
  'coldWaterThresholdC': ConflictField(
    (l) => l.settings_conflict_field_coldWaterThresholdC,
    FieldKind.temperature,
  ),
  'conditionDisabledRules': ConflictField(
    (l) => l.settings_conflict_field_conditionDisabledRules,
    FieldKind.opaque,
  ),
  'conditionEngineEnabled': ConflictField(
    (l) => l.settings_conflict_field_conditionEngineEnabled,
    FieldKind.boolean,
  ),
  'coordinateFormat': ConflictField(
    (l) => l.settings_conflict_field_coordinateFormat,
    FieldKind.enumValue,
    enumLabel: coordinateFormatLabeler,
  ),
  'courseListViewMode': ConflictField(
    (l) => l.settings_appearance_listView_courses,
    FieldKind.enumValue,
    enumLabel: listViewModeLabeler,
  ),
  'dateFormat': ConflictField(
    (l) => l.settings_conflict_field_dateFormat,
    FieldKind.enumValue,
    enumLabel: dateFormatLabeler,
  ),
  'decoStopIncrement': ConflictField(
    (l) => l.settings_conflict_field_decoStopIncrement,
    FieldKind.depth,
  ),
  'deepDiveThresholdM': ConflictField(
    (l) => l.settings_conflict_field_deepDiveThresholdM,
    FieldKind.depth,
  ),
  'defaultCeilingSource': ConflictField(
    (l) => l.settings_conflict_field_defaultCeilingSource,
    FieldKind.number,
  ),
  'defaultCnsSource': ConflictField(
    (l) => l.settings_conflict_field_defaultCnsSource,
    FieldKind.number,
  ),
  'defaultDecoStopSource': ConflictField(
    (l) => l.settings_conflict_field_defaultDecoStopSource,
    FieldKind.number,
  ),
  'defaultDiveType': ConflictField(
    (l) => l.settings_conflict_field_defaultDiveType,
    FieldKind.shortText,
  ),
  'defaultGtrSource': ConflictField(
    (l) => l.settings_conflict_field_defaultGtrSource,
    FieldKind.number,
  ),
  'defaultNdlSource': ConflictField(
    (l) => l.settings_conflict_field_defaultNdlSource,
    FieldKind.number,
  ),
  'defaultPlannerWaterType': ConflictField(
    (l) => l.settings_conflict_field_defaultPlannerWaterType,
    FieldKind.enumValue,
    enumLabel: plannerWaterTypeLabeler,
  ),
  'defaultRightAxisMetric': ConflictField(
    (l) => l.settings_conflict_field_defaultRightAxisMetric,
    FieldKind.enumValue,
    enumLabel: profileRightAxisMetricLabeler,
  ),
  'defaultShowAscentRateLine': ConflictField(
    (l) => l.settings_conflict_field_defaultShowAscentRateLine,
    FieldKind.boolean,
  ),
  'defaultShowCns': ConflictField(
    (l) => l.settings_conflict_field_defaultShowCns,
    FieldKind.boolean,
  ),
  'defaultShowEstimatedTankPressure': ConflictField(
    (l) => l.settings_conflict_field_defaultShowEstimatedTankPressure,
    FieldKind.boolean,
  ),
  'defaultShowEvents': ConflictField(
    (l) => l.settings_conflict_field_defaultShowEvents,
    FieldKind.boolean,
  ),
  'defaultShowLateGasSwitches': ConflictField(
    (l) => l.settings_conflict_field_defaultShowLateGasSwitches,
    FieldKind.boolean,
  ),
  'defaultShowGasDensity': ConflictField(
    (l) => l.settings_conflict_field_defaultShowGasDensity,
    FieldKind.boolean,
  ),
  'defaultShowGasSwitchMarkers': ConflictField(
    (l) => l.settings_conflict_field_defaultShowGasSwitchMarkers,
    FieldKind.boolean,
  ),
  'defaultShowGasTimeline': ConflictField(
    (l) => l.settings_conflict_field_defaultShowGasTimeline,
    FieldKind.boolean,
  ),
  'defaultShowGf': ConflictField(
    (l) => l.settings_conflict_field_defaultShowGf,
    FieldKind.boolean,
  ),
  'defaultShowGtr': ConflictField(
    (l) => l.settings_conflict_field_defaultShowGtr,
    FieldKind.boolean,
  ),
  'defaultShowHeartRate': ConflictField(
    (l) => l.settings_conflict_field_defaultShowHeartRate,
    FieldKind.boolean,
  ),
  'defaultShowMeanDepth': ConflictField(
    (l) => l.settings_conflict_field_defaultShowMeanDepth,
    FieldKind.boolean,
  ),
  'defaultShowO2CellMv': ConflictField(
    (l) => l.settings_conflict_field_defaultShowO2CellMv,
    FieldKind.boolean,
  ),
  'defaultShowOtu': ConflictField(
    (l) => l.settings_conflict_field_defaultShowOtu,
    FieldKind.boolean,
  ),
  'defaultShowPhotoMarkers': ConflictField(
    (l) => l.settings_conflict_field_defaultShowPhotoMarkers,
    FieldKind.boolean,
  ),
  'defaultShowPpHe': ConflictField(
    (l) => l.settings_conflict_field_defaultShowPpHe,
    FieldKind.boolean,
  ),
  'defaultShowPpN2': ConflictField(
    (l) => l.settings_conflict_field_defaultShowPpN2,
    FieldKind.boolean,
  ),
  'defaultShowPpO2': ConflictField(
    (l) => l.settings_conflict_field_defaultShowPpO2,
    FieldKind.boolean,
  ),
  'defaultShowPressure': ConflictField(
    (l) => l.settings_conflict_field_defaultShowPressure,
    FieldKind.boolean,
  ),
  'defaultShowSac': ConflictField(
    (l) => l.settings_conflict_field_defaultShowSac,
    FieldKind.boolean,
  ),
  'defaultShowSurfaceGf': ConflictField(
    (l) => l.settings_conflict_field_defaultShowSurfaceGf,
    FieldKind.boolean,
  ),
  'defaultShowTemperature': ConflictField(
    (l) => l.settings_conflict_field_defaultShowTemperature,
    FieldKind.boolean,
  ),
  'defaultShowTts': ConflictField(
    (l) => l.settings_conflict_field_defaultShowTts,
    FieldKind.boolean,
  ),
  'defaultStartPressure': ConflictField(
    (l) => l.settings_conflict_field_defaultStartPressure,
    FieldKind.pressure,
  ),
  'defaultTankPreset': ConflictField(
    (l) => l.settings_conflict_field_defaultTankPreset,
    FieldKind.shortText,
  ),
  'defaultTankVolume': ConflictField(
    (l) => l.settings_conflict_field_defaultTankVolume,
    FieldKind.volume,
  ),
  'defaultTtsSource': ConflictField(
    (l) => l.settings_conflict_field_defaultTtsSource,
    FieldKind.number,
  ),
  'depthUnit': ConflictField(
    (l) => l.settings_conflict_field_depthUnit,
    FieldKind.enumValue,
    enumLabel: depthUnitLabeler,
  ),
  'distanceUnit': ConflictField(
    (l) => l.settings_conflict_field_distanceUnit,
    FieldKind.enumValue,
    enumLabel: distanceUnitLabeler,
  ),
  'diveCenterListViewMode': ConflictField(
    (l) => l.settings_conflict_field_diveCenterListViewMode,
    FieldKind.enumValue,
    enumLabel: listViewModeLabeler,
  ),
  'diveDetailLayout': ConflictField(
    (l) => l.settings_conflict_field_diveDetailLayout,
    FieldKind.enumValue,
    enumLabel: diveDetailLayoutLabeler,
  ),
  'diveDetailSections': ConflictField(
    (l) => l.settings_conflict_field_diveDetailSections,
    FieldKind.opaque,
  ),
  'diveListViewMode': ConflictField(
    (l) => l.settings_conflict_field_diveListViewMode,
    FieldKind.enumValue,
    enumLabel: listViewModeLabeler,
  ),
  'emergencyRegion': ConflictField(
    (l) => l.settings_conflict_field_emergencyRegion,
    FieldKind.shortText,
  ),
  'endLimit': ConflictField(
    (l) => l.settings_conflict_field_endLimit,
    FieldKind.depth,
  ),
  'equipmentListViewMode': ConflictField(
    (l) => l.settings_conflict_field_equipmentListViewMode,
    FieldKind.enumValue,
    enumLabel: listViewModeLabeler,
  ),
  'gasConsumptionDisplay': ConflictField(
    (l) => l.settings_conflict_field_gasConsumptionDisplay,
    FieldKind.enumValue,
    enumLabel: gasConsumptionDisplayLabeler,
  ),
  'gasModel': ConflictField(
    (l) => l.settings_units_gasModel,
    FieldKind.enumValue,
    enumLabel: gasModelLabeler,
  ),
  'groupTripsInDiveList': ConflictField(
    (l) => l.settings_conflict_field_groupTripsInDiveList,
    FieldKind.boolean,
  ),
  'gtrReservePressure': ConflictField(
    (l) => l.settings_conflict_field_gtrReservePressure,
    FieldKind.pressure,
  ),
  'hiddenChamberIds': ConflictField(
    (l) => l.settings_conflict_field_hiddenChamberIds,
    FieldKind.opaque,
  ),
  'hiddenTankPresetIds': ConflictField(
    (l) => l.settings_conflict_field_hiddenTankPresetIds,
    FieldKind.opaque,
  ),
  'highO2ThresholdPercent': ConflictField(
    (l) => l.settings_conflict_field_highO2ThresholdPercent,
    FieldKind.percent,
  ),
  'insightsMutedObservationRules': ConflictField(
    (l) => l.settings_conflict_field_insightsMutedObservationRules,
    FieldKind.opaque,
  ),
  'locale': ConflictField(
    (l) => l.settings_conflict_field_locale,
    FieldKind.shortText,
  ),
  'mapStyle': ConflictField(
    (l) => l.settings_appearance_mapStyle,
    FieldKind.enumValue,
    enumLabel: mapStyleLabeler,
  ),
  'noFlyPreset': ConflictField(
    (l) => l.settings_conflict_field_noFlyPreset,
    FieldKind.enumValue,
    enumLabel: noFlyPresetLabeler,
  ),
  'notificationsEnabled': ConflictField(
    (l) => l.settings_conflict_field_notificationsEnabled,
    FieldKind.boolean,
  ),
  'placeNameLanguage': ConflictField(
    (l) => l.settings_conflict_field_placeNameLanguage,
    FieldKind.shortText,
  ),
  'ppO2MaxDeco': ConflictField(
    (l) => l.settings_conflict_field_ppO2MaxDeco,
    FieldKind.partialPressure,
  ),
  'ppO2MaxWorking': ConflictField(
    (l) => l.settings_conflict_field_ppO2MaxWorking,
    FieldKind.partialPressure,
  ),
  'pressureUnit': ConflictField(
    (l) => l.settings_conflict_field_pressureUnit,
    FieldKind.enumValue,
    enumLabel: pressureUnitLabeler,
  ),
  'profileMetricsFollowViewport': ConflictField(
    (l) => l.settings_appearance_metricsFollowViewport,
    FieldKind.boolean,
  ),
  'pscrRatio': ConflictField(
    (l) => l.plannerCanvas_pscr_ratio,
    FieldKind.number,
  ),
  'reminderTime': ConflictField(
    (l) => l.settings_conflict_field_reminderTime,
    FieldKind.shortText,
  ),
  'safetyReviewDisabledRules': ConflictField(
    (l) => l.settings_conflict_field_safetyReviewDisabledRules,
    FieldKind.opaque,
  ),
  'safetyReviewEnabled': ConflictField(
    (l) => l.settings_conflict_field_safetyReviewEnabled,
    FieldKind.boolean,
  ),
  'seascapeAppearance': ConflictField(
    (l) => l.settings_conflict_field_seascapeAppearance,
    FieldKind.opaque,
  ),
  'seascapeVerticalExaggerationOverrides': ConflictField(
    (l) => l.settings_conflict_field_seascapeVerticalExaggerationOverrides,
    FieldKind.opaque,
  ),
  'serviceReminderDays': ConflictField(
    (l) => l.settings_conflict_field_serviceReminderDays,
    FieldKind.opaque,
  ),
  'showAscentRateColors': ConflictField(
    (l) => l.settings_conflict_field_showAscentRateColors,
    FieldKind.boolean,
  ),
  'showCeilingOnProfile': ConflictField(
    (l) => l.settings_conflict_field_showCeilingOnProfile,
    FieldKind.boolean,
  ),
  'showDataSourceBadges': ConflictField(
    (l) => l.settings_conflict_field_showDataSourceBadges,
    FieldKind.boolean,
  ),
  'showDecoStopsOnProfile': ConflictField(
    (l) => l.settings_conflict_field_showDecoStopsOnProfile,
    FieldKind.boolean,
  ),
  'showDepthColoredDiveCards': ConflictField(
    (l) => l.settings_conflict_field_showDepthColoredDiveCards,
    FieldKind.boolean,
  ),
  'showDetailsPaneBuddies': ConflictField(
    (l) => l.settings_conflict_field_showDetailsPaneBuddies,
    FieldKind.boolean,
  ),
  'showDetailsPaneCertifications': ConflictField(
    (l) => l.settings_conflict_field_showDetailsPaneCertifications,
    FieldKind.boolean,
  ),
  'showDetailsPaneCourses': ConflictField(
    (l) => l.settings_conflict_field_showDetailsPaneCourses,
    FieldKind.boolean,
  ),
  'showDetailsPaneDiveCenters': ConflictField(
    (l) => l.settings_conflict_field_showDetailsPaneDiveCenters,
    FieldKind.boolean,
  ),
  'showDetailsPaneDives': ConflictField(
    (l) => l.settings_conflict_field_showDetailsPaneDives,
    FieldKind.boolean,
  ),
  'showDetailsPaneEquipment': ConflictField(
    (l) => l.settings_conflict_field_showDetailsPaneEquipment,
    FieldKind.boolean,
  ),
  'showDetailsPaneSites': ConflictField(
    (l) => l.settings_conflict_field_showDetailsPaneSites,
    FieldKind.boolean,
  ),
  'showDetailsPaneTrips': ConflictField(
    (l) => l.settings_conflict_field_showDetailsPaneTrips,
    FieldKind.boolean,
  ),
  'showDiveFigure': ConflictField(
    (l) => l.settings_conflict_field_showDiveFigure,
    FieldKind.boolean,
  ),
  'showMapBackgroundOnDiveCards': ConflictField(
    (l) => l.settings_conflict_field_showMapBackgroundOnDiveCards,
    FieldKind.boolean,
  ),
  'showMapBackgroundOnSiteCards': ConflictField(
    (l) => l.settings_conflict_field_showMapBackgroundOnSiteCards,
    FieldKind.boolean,
  ),
  'showMaxDepthMarker': ConflictField(
    (l) => l.settings_conflict_field_showMaxDepthMarker,
    FieldKind.boolean,
  ),
  'showNdlOnProfile': ConflictField(
    (l) => l.settings_conflict_field_showNdlOnProfile,
    FieldKind.boolean,
  ),
  'showPressureThresholdMarkers': ConflictField(
    (l) => l.settings_conflict_field_showPressureThresholdMarkers,
    FieldKind.boolean,
  ),
  'showProfilePanelInTableView': ConflictField(
    (l) => l.settings_conflict_field_showProfilePanelInTableView,
    FieldKind.boolean,
  ),
  'siteDetailLayout': ConflictField(
    (l) => l.settings_conflict_field_siteDetailLayout,
    FieldKind.enumValue,
    enumLabel: diveDetailLayoutLabeler,
  ),
  'siteDetailSections': ConflictField(
    (l) => l.settings_conflict_field_siteDetailSections,
    FieldKind.opaque,
  ),
  'siteListViewMode': ConflictField(
    (l) => l.settings_conflict_field_siteListViewMode,
    FieldKind.enumValue,
    enumLabel: listViewModeLabeler,
  ),
  'siteMatchSensitivity': ConflictField(
    (l) => l.settings_siteMatch_title,
    FieldKind.enumValue,
    enumLabel: siteMatchSensitivityLabeler,
  ),
  'temperatureUnit': ConflictField(
    (l) => l.settings_conflict_field_temperatureUnit,
    FieldKind.enumValue,
    enumLabel: temperatureUnitLabeler,
  ),
  'themeMode': ConflictField(
    (l) => l.settings_conflict_field_themeMode,
    FieldKind.enumValue,
    enumLabel: themeModeLabeler,
  ),
  'themePreset': ConflictField(
    (l) => l.settings_conflict_field_themePreset,
    FieldKind.shortText,
  ),
  'timeFormat': ConflictField(
    (l) => l.settings_conflict_field_timeFormat,
    FieldKind.enumValue,
    enumLabel: timeFormatLabeler,
  ),
  'tissueColorScheme': ConflictField(
    (l) => l.settings_conflict_field_tissueColorScheme,
    FieldKind.enumValue,
    enumLabel: tissueColorSchemeLabeler,
  ),
  'tissueVizMode': ConflictField(
    (l) => l.settings_conflict_field_tissueVizMode,
    FieldKind.enumValue,
    enumLabel: tissueVizModeLabeler,
  ),
  'trimTankPressureAtSurfacing': ConflictField(
    (l) => l.settings_conflict_field_trimTankPressureAtSurfacing,
    FieldKind.boolean,
  ),
  'tripListViewMode': ConflictField(
    (l) => l.settings_conflict_field_tripListViewMode,
    FieldKind.enumValue,
    enumLabel: listViewModeLabeler,
  ),
  'tripServiceLeadDays': ConflictField(
    (l) => l.settings_conflict_field_tripServiceLeadDays,
    FieldKind.number,
  ),
  'useDiveComputerCnsData': ConflictField(
    (l) => l.settings_conflict_field_useDiveComputerCnsData,
    FieldKind.boolean,
  ),
  'visibilityScaleExcellentM': ConflictField(
    (l) => l.settings_conflict_field_visibilityScaleExcellentM,
    FieldKind.distance,
  ),
  'visibilityScaleGoodM': ConflictField(
    (l) => l.settings_conflict_field_visibilityScaleGoodM,
    FieldKind.distance,
  ),
  'visibilityScaleModerateM': ConflictField(
    (l) => l.settings_conflict_field_visibilityScaleModerateM,
    FieldKind.distance,
  ),
  'visibilityScalePreset': ConflictField(
    (l) => l.settings_visibilityScale_title,
    FieldKind.enumValue,
    enumLabel: visibilityScalePresetLabeler,
  ),
  'volumeUnit': ConflictField(
    (l) => l.settings_conflict_field_volumeUnit,
    FieldKind.enumValue,
    enumLabel: volumeUnitLabeler,
  ),
  'weightUnit': ConflictField(
    (l) => l.settings_conflict_field_weightUnit,
    FieldKind.enumValue,
    enumLabel: weightUnitLabeler,
  ),
};

/// Columns whose meaning depends on the entity, keyed `entity.column`.
final Map<String, ConflictField> diverSettingsOverrides = {};
