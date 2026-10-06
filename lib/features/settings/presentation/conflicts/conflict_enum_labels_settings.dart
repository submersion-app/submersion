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
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/helpers/site_attachment_labels.dart';
import 'package:submersion/features/media/presentation/match_confidence_display.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_panel.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/format_enum_display.dart';
import 'package:submersion/features/settings/presentation/widgets/coordinate_format_picker.dart';
import 'package:submersion/features/settings/presentation/widgets/visibility_scale_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Labelers for the diver's settings and the media library. Each reads the
// way the settings screen offering the choice reads.

// Units are offered by their symbol, which no locale translates.
final ConflictEnumLabeler depthUnitLabeler = enumLabeler(
  DepthUnit.values,
  (l, v) => v.symbol,
);
final ConflictEnumLabeler distanceUnitLabeler = enumLabeler(
  DistanceUnit.values,
  (l, v) => v.symbol,
);
final ConflictEnumLabeler pressureUnitLabeler = enumLabeler(
  PressureUnit.values,
  (l, v) => v.symbol,
);
final ConflictEnumLabeler temperatureUnitLabeler = enumLabeler(
  TemperatureUnit.values,
  (l, v) => v.symbol,
);
final ConflictEnumLabeler volumeUnitLabeler = enumLabeler(
  VolumeUnit.values,
  (l, v) => v.symbol,
);
final ConflictEnumLabeler weightUnitLabeler = enumLabeler(
  WeightUnit.values,
  (l, v) => v.symbol,
);
final ConflictEnumLabeler altitudeUnitLabeler = enumLabeler(
  AltitudeUnit.values,
  (l, v) => v.symbol,
);

/// A date pattern ("MM/DD/YYYY") is offered as the pattern itself.
final ConflictEnumLabeler dateFormatLabeler = enumLabeler(
  DateFormatPreference.values,
  (l, v) => v.displayName,
);

final ConflictEnumLabeler timeFormatLabeler = enumLabeler(
  TimeFormat.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler listViewModeLabeler = enumLabeler(
  ListViewMode.values,
  (l, v) => switch (v) {
    ListViewMode.detailed => l.enum_listViewMode_detailed,
    ListViewMode.compact => l.enum_listViewMode_compact,
    ListViewMode.dense => l.enum_listViewMode_dense,
    ListViewMode.table => l.enum_listViewMode_table,
  },
);

final ConflictEnumLabeler diveDetailLayoutLabeler = enumLabeler(
  DiveDetailLayout.values,
  (l, v) => switch (v) {
    DiveDetailLayout.detailed => l.diveDetailLayout_detailed,
    DiveDetailLayout.list => l.diveDetailLayout_list,
  },
);

final ConflictEnumLabeler cardColorAttributeLabeler = enumLabeler(
  CardColorAttribute.values,
  (l, v) => switch (v) {
    CardColorAttribute.none => l.settings_appearance_cardColorAttribute_none,
    CardColorAttribute.depth => l.settings_appearance_cardColorAttribute_depth,
    CardColorAttribute.duration =>
      l.settings_appearance_cardColorAttribute_duration,
    CardColorAttribute.temperature =>
      l.settings_appearance_cardColorAttribute_temperature,
  },
);

final ConflictEnumLabeler mapStyleLabeler = enumLabeler(
  MapStyle.values,
  (l, v) => switch (v) {
    MapStyle.openStreetMap => l.settings_appearance_mapStyle_openStreetMap,
    MapStyle.openTopoMap => l.settings_appearance_mapStyle_openTopoMap,
    MapStyle.esriSatellite => l.settings_appearance_mapStyle_esriSatellite,
  },
);

final ConflictEnumLabeler cnsCalculationMethodLabeler = enumLabeler(
  CnsCalculationMethod.values,
  (l, v) => switch (v) {
    CnsCalculationMethod.classic => l.settings_decompression_cnsMethodClassic,
    CnsCalculationMethod.shearwater =>
      l.settings_decompression_cnsMethodShearwater,
    CnsCalculationMethod.subsurface =>
      l.settings_decompression_cnsMethodSubsurface,
  },
);

final ConflictEnumLabeler noFlyPresetLabeler = enumLabeler(
  NoFlyPreset.values,
  (l, v) => switch (v) {
    NoFlyPreset.standard => l.safetySettings_noFlyPreset_standard,
    NoFlyPreset.strict => l.safetySettings_noFlyPreset_strict,
  },
);

final ConflictEnumLabeler siteMatchSensitivityLabeler = enumLabeler(
  SiteMatchSensitivity.values,
  (l, v) => switch (v) {
    SiteMatchSensitivity.strict => l.settings_siteMatch_strict,
    SiteMatchSensitivity.balanced => l.settings_siteMatch_balanced,
    SiteMatchSensitivity.relaxed => l.settings_siteMatch_relaxed,
  },
);

final ConflictEnumLabeler gasModelLabeler = enumLabeler(
  GasModel.values,
  (l, v) => switch (v) {
    GasModel.ideal => l.settings_units_gasModel_ideal,
    GasModel.real => l.settings_units_gasModel_real,
  },
);

final ConflictEnumLabeler gasConsumptionDisplayLabeler = enumLabeler(
  GasConsumptionDisplay.values,
  (l, v) => switch (v) {
    GasConsumptionDisplay.sac => l.gasConsumption_sac,
    GasConsumptionDisplay.rmv => l.gasConsumption_rmv,
    GasConsumptionDisplay.both => l.settings_units_gasConsumption_both,
  },
);

final ConflictEnumLabeler plannerWaterTypeLabeler = enumLabeler(
  PlannerWaterType.values,
  (l, v) => switch (v) {
    PlannerWaterType.salt => WaterType.salt.localizedName(l),
    PlannerWaterType.fresh => WaterType.fresh.localizedName(l),
    PlannerWaterType.custom => l.decoCalculator_waterType_custom,
  },
);

final ConflictEnumLabeler profileRightAxisMetricLabeler = enumLabeler(
  ProfileRightAxisMetric.values,
  (l, v) => switch (v) {
    ProfileRightAxisMetric.temperature => l.enum_profileMetric_temperature,
    ProfileRightAxisMetric.pressure => l.enum_profileMetric_pressure,
    ProfileRightAxisMetric.heartRate => l.enum_profileMetric_heartRate,
    ProfileRightAxisMetric.sac => l.enum_profileMetric_sacRate,
    ProfileRightAxisMetric.ascentRate => l.enum_profileMetric_ascentRate,
    ProfileRightAxisMetric.ndl => l.enum_profileMetric_ndl,
    ProfileRightAxisMetric.ppO2 => l.enum_profileMetric_ppO2,
    ProfileRightAxisMetric.ppN2 => l.enum_profileMetric_ppN2,
    ProfileRightAxisMetric.ppHe => l.enum_profileMetric_ppHe,
    ProfileRightAxisMetric.gasDensity => l.enum_profileMetric_gasDensity,
    ProfileRightAxisMetric.gf => l.enum_profileMetric_gf,
    ProfileRightAxisMetric.surfaceGf => l.enum_profileMetric_surfaceGf,
    ProfileRightAxisMetric.meanDepth => l.enum_profileMetric_meanDepth,
    ProfileRightAxisMetric.tts => l.enum_profileMetric_tts,
    ProfileRightAxisMetric.gtr => l.enum_profileMetric_gtr,
    ProfileRightAxisMetric.cns => l.enum_profileMetric_cns,
    ProfileRightAxisMetric.otu => l.enum_profileMetric_otu,
    ProfileRightAxisMetric.o2CellMv => l.enum_profileMetric_o2CellMv,
  },
);

final ConflictEnumLabeler visibilityScalePresetLabeler = enumLabeler(
  VisibilityScalePreset.values,
  (l, v) => visibilityPresetLabel(l, v),
);

final ConflictEnumLabeler coordinateFormatLabeler = enumLabeler(
  CoordinateFormat.values,
  (l, v) => coordinateFormatLabel(l, v),
);

final ConflictEnumLabeler tissueColorSchemeLabeler = enumLabeler(
  TissueColorScheme.values,
  (l, v) => switch (v) {
    TissueColorScheme.classic => l.enum_tissueColorScheme_classic,
    TissueColorScheme.thermal => l.enum_tissueColorScheme_thermal,
  },
);

final ConflictEnumLabeler tissueVizModeLabeler = enumLabeler(
  TissueVizMode.values,
  (l, v) => switch (v) {
    TissueVizMode.heatMap => l.enum_tissueVizMode_heatMap,
    TissueVizMode.stackedArea => l.enum_tissueVizMode_stackedArea,
  },
);

final ConflictEnumLabeler manifestFormatLabeler = enumLabeler(
  ManifestFormat.values,
  (l, v) => switch (v) {
    ManifestFormat.atom => l.enum_manifestFormat_atom,
    ManifestFormat.json => l.enum_manifestFormat_json,
    ManifestFormat.csv => l.enum_manifestFormat_csv,
  },
);

final ConflictEnumLabeler matchConfidenceLabeler = enumLabeler(
  MatchConfidence.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler mediaSourceTypeLabeler = enumLabeler(
  MediaSourceType.values,
  (l, v) => sourceTypeLabel(l, v),
);

/// A site attachment's category (issue #1039), stored by key.
final ConflictEnumLabeler siteAttachmentCategoryLabeler = enumLabeler(
  SiteAttachmentCategory.values,
  (l, v) => v.label(l),
  storedAs: (v) => v.storageKey,
);

/// A site attachment's size override (issue #1039), stored by key.
final ConflictEnumLabeler attachmentDisplaySizeLabeler = enumLabeler(
  AttachmentDisplaySize.values,
  (l, v) => v.label(l),
  storedAs: (v) => v.storageKey,
);

/// The theme mode is stored as the word, not an enum name.
String? themeModeLabeler(AppLocalizations l10n, String stored) =>
    switch (stored) {
      'light' => l10n.settings_appearance_theme_light,
      'dark' => l10n.settings_appearance_theme_dark,
      'system' => l10n.settings_appearance_theme_system,
      _ => null,
    };
