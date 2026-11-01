import 'package:submersion/core/database/database.dart' show DiveProfileEvent;
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    show GeoPoint;
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

const kProfileDefaultLimit = 500;
const kProfileMaxLimit = 2000;

/// The full agent-facing document for one dive. Metric, unit-named keys,
/// wall-clock UTC dates as ISO 8601. Child blocks are added by their loaders
/// in `dive_records.dart`, only when a caller asks for them.
Map<String, Object?> diveDocument(Dive dive) {
  final site = dive.site;
  return <String, Object?>{
    'id': dive.id,
    'diver_id': dive.diverId,
    'dive_number': dive.diveNumber,
    'name': dive.name,
    'date_time': wallClock(dive.dateTime),
    'entry_time': wallClockOrNull(dive.entryTime),
    'exit_time': wallClockOrNull(dive.exitTime),
    'bottom_time_s': dive.bottomTime?.inSeconds,
    'runtime_s': dive.runtime?.inSeconds,
    'surface_interval_s': dive.surfaceInterval?.inSeconds,
    'max_depth_m': dive.maxDepth,
    'avg_depth_m': dive.avgDepth,
    'water_temp_c': dive.waterTemp,
    'air_temp_c': dive.airTemp,
    'visibility': dive.visibility?.name,
    'visibility_m': dive.visibilityMeters,
    'visibility_min_m': dive.visibilityMinMeters,
    'visibility_max_m': dive.visibilityMaxMeters,
    'rating': dive.rating,
    'notes': dive.notes,
    'dive_mode': dive.diveMode.name,
    'is_planned': dive.isPlanned,
    'is_favorite': dive.isFavorite,
    'excluded_from_stats': dive.excludedFromStats,
    'excluded_from_gas_stats': dive.excludedFromGasStats,
    'entry_location': _point(dive.entryLocation),
    'exit_location': _point(dive.exitLocation),
    'site': site == null
        ? null
        : {
            'id': site.id,
            'name': site.name,
            'country': site.country,
            'region': site.region,
            'latitude': site.location?.latitude,
            'longitude': site.location?.longitude,
          },
    'trip': dive.tripId == null
        ? null
        : {'id': dive.tripId, 'name': dive.trip?.name},
    'dive_center': dive.diveCenter == null
        ? null
        : {'id': dive.diveCenter!.id, 'name': dive.diveCenter!.name},
    'outing_id': dive.outingId,
    'dive_type_ids': dive.diveTypeIds,
    'diver_role_ids': dive.diverRoleIds,
    'course_ids': dive.courseIds,
    'buddy': dive.buddy,
    'dive_master': dive.diveMaster,
    'dive_operator': dive.diveOperator,
    'boat_name': dive.boatName,
    'boat_captain': dive.boatCaptain,
    'current_direction': dive.currentDirection?.name,
    'current_strength': dive.currentStrength?.name,
    'swell_height_m': dive.swellHeight,
    'surface_conditions': dive.surfaceConditions,
    'entry_method': dive.entryMethod?.name,
    'exit_method': dive.exitMethod?.name,
    'water_type': dive.waterType?.name,
    'altitude_m': dive.altitude,
    'surface_pressure_bar': dive.surfacePressure,
    'gf_low': dive.gradientFactorLow,
    'gf_high': dive.gradientFactorHigh,
    'deco_algorithm': dive.decoAlgorithm,
    'deco_conservatism': dive.decoConservatism,
    'computer_id': dive.computerId,
    'dive_computer_model': dive.diveComputerModel,
    'dive_computer_serial': dive.diveComputerSerial,
    'dive_computer_firmware': dive.diveComputerFirmware,
    'weight_kg': dive.weightAmount,
    'weight_type': dive.weightType?.name,
    'weighting_feedback': dive.weightingFeedback?.name,
    'weighting_feedback_kg': dive.weightingFeedbackKg,
    'setpoint_low_bar': dive.setpointLow,
    'setpoint_high_bar': dive.setpointHigh,
    'setpoint_deco_bar': dive.setpointDeco,
    'scr_type': dive.scrType?.name,
    'scr_injection_rate_l_min': dive.scrInjectionRate,
    'scr_addition_ratio': dive.scrAdditionRatio,
    'scr_orifice_size': dive.scrOrificeSize,
    'assumed_vo2_l_min': dive.assumedVo2,
    'diluent_o2_fraction': _fraction(dive.diluentGas?.o2),
    'diluent_he_fraction': _fraction(dive.diluentGas?.he),
    'loop_o2_min_percent': dive.loopO2Min,
    'loop_o2_max_percent': dive.loopO2Max,
    'loop_o2_avg_percent': dive.loopO2Avg,
    'loop_volume_l': dive.loopVolume,
    'scrubber': dive.scrubber == null
        ? null
        : {
            'type': dive.scrubber!.type,
            'rated_minutes': dive.scrubber!.ratedMinutes,
            'remaining_minutes': dive.scrubber!.remainingMinutes,
          },
    'wind_speed_m_s': dive.windSpeed,
    'wind_direction': dive.windDirection?.name,
    'cloud_cover': dive.cloudCover?.name,
    'precipitation': dive.precipitation?.name,
    'humidity_percent': dive.humidity,
    'weather_description': dive.weatherDescription,
    'weather_code': dive.weatherCode,
    'weather_source': dive.weatherSource?.name,
    'weather_fetched_at': instant(dive.weatherFetchedAt),
    'import_source': dive.importSource,
    'import_id': dive.importId,
  };
}

Map<String, Object?>? _point(GeoPoint? point) => point == null
    ? null
    : {'latitude': point.latitude, 'longitude': point.longitude};

double? _fraction(double? percent) => percent == null ? null : percent / 100;

/// One tank; [diveId] is set when the tank is read as a record of its own.
Map<String, Object?> diveTankDocument(DiveTank t, {String? diveId}) => {
  'id': t.id,
  'dive_id': ?diveId,
  'name': t.name,
  'volume_l': t.volume,
  'working_pressure_bar': t.workingPressure,
  'start_pressure_bar': t.startPressure,
  'end_pressure_bar': t.endPressure,
  'o2_fraction': t.gasMix.o2 / 100,
  'he_fraction': t.gasMix.he / 100,
  'role': t.role.name,
  'material': t.material?.name,
  'order': t.order,
  'preset_name': t.presetName,
  'computer_id': t.computerId,
  'transmitter_serial': t.transmitterSerial,
  'regulator_equipment_id': t.regulatorEquipmentId,
  'equipment_id': t.equipmentId,
  'trip_cylinder_id': t.tripCylinderId,
  'usage_duration_s': t.usageDuration?.inSeconds,
  'deco_switch_depth_m': t.decoSwitchDepth,
  'is_travel_gas': t.isTravelGas,
};

Map<String, Object?> diveWeightDocument(DiveWeight w) => {
  'id': w.id,
  'dive_id': w.diveId,
  'type': w.weightType.name,
  'amount_kg': w.amountKg,
  'label': w.label,
  'notes': w.notes,
};

Map<String, Object?> diveBuddyDocument(BuddyWithRole b) => {
  'id': b.buddy.id,
  'name': b.buddy.name,
  'roles': [for (final r in b.roles) r.name],
};

Map<String, Object?> sightingDocument(Sighting s) => {
  'id': s.id,
  'dive_id': s.diveId,
  'species_id': s.speciesId,
  'species_name': s.speciesName,
  'count': s.count,
  'notes': s.notes,
};

Map<String, Object?> diveCustomFieldDocument(
  DiveCustomField f, {
  required String diveId,
}) => {
  'id': f.id,
  'dive_id': diveId,
  'key': f.key,
  'value': f.value,
  'sort_order': f.sortOrder,
};

Map<String, Object?> gasSwitchDocument(GasSwitchWithTank s) => {
  'id': s.gasSwitch.id,
  'dive_id': s.gasSwitch.diveId,
  't_s': s.gasSwitch.timestamp,
  'tank_id': s.gasSwitch.tankId,
  'tank_name': s.tankName,
  'depth_m': s.gasSwitch.depth,
  'o2_fraction': s.o2Fraction,
  'he_fraction': s.heFraction,
  'computer_id': s.gasSwitch.computerId,
};

Map<String, Object?> diveEventDocument(DiveProfileEvent e) => {
  'id': e.id,
  'dive_id': e.diveId,
  't_s': e.timestamp,
  'type': e.eventType,
  'severity': e.severity,
  'description': e.description,
  'depth_m': e.depth,
  'value': e.value,
  'tank_id': e.tankId,
  'source': e.source,
  'computer_id': e.computerId,
};

Map<String, Object?> diveGearDocument(GearLink g) => {
  'equipment_id': g.item.id,
  'name': g.item.name,
  'type': g.item.type.name,
  'via_equipment_id': g.viaEquipmentId,
  'via_set_id': g.viaSetId,
};

Map<String, Object?> diveDataSourceDocument(DiveDataSource s) => {
  'id': s.id,
  'dive_id': s.diveId,
  'computer_id': s.computerId,
  'is_primary': s.isPrimary,
  'computer_model': s.computerModel,
  'computer_name': s.computerName,
  'computer_serial': s.computerSerial,
  'source_format': s.sourceFormat,
  'source_file_name': s.sourceFileName,
  'max_depth_m': s.maxDepth,
  'avg_depth_m': s.avgDepth,
  'duration_s': s.duration,
  'water_temp_c': s.waterTemp,
  'entry_time': wallClockOrNull(s.entryTime),
  'exit_time': wallClockOrNull(s.exitTime),
  'max_ascent_rate_m_min': s.maxAscentRate,
  'max_descent_rate_m_min': s.maxDescentRate,
  'surface_interval_s': s.surfaceInterval,
  'cns_percent': s.cns,
  'otu': s.otu,
  'deco_algorithm': s.decoAlgorithm,
  'gf_low': s.gradientFactorLow,
  'gf_high': s.gradientFactorHigh,
  'imported_at': instant(s.importedAt),
};

Map<String, Object?> diveScenarioDocument(DiveScenario s) => {
  'id': s.id,
  'dive_id': s.diveId,
  'name': s.name,
  'notes': s.notes,
  'branch_s': s.branchSeconds,
  'mode': s.mode.name,
  'interventions': [for (final i in s.interventions) interventionToJson(i)],
};

Map<String, Object?> diveProfileDocument(
  List<DiveProfilePoint> profile,
  int offset,
  int limit,
) {
  final page = profile.skip(offset).take(limit);
  return {
    'offset': offset,
    'limit': limit,
    'total': profile.length,
    'samples': [
      for (final p in page)
        {
          't_s': p.timestamp,
          'depth_m': p.depth,
          'temperature_c': p.temperature,
        },
    ],
  };
}
