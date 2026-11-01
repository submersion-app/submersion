import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/database.dart' show DiverSetting;
import 'package:submersion/core/services/sync/device_local_fields.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// A diver's full profile, medical and insurance details included. `list_divers`
/// stays the short view; this one is read only when an agent asks for it. The
/// photo is bytes and the buddy card share is a device setting, so neither is
/// here.
Map<String, Object?> diverRecordDocument(Diver d) => {
  'id': d.id,
  'name': d.name,
  'email': d.email,
  'phone': d.phone,
  'social_handle': d.socialHandle,
  'photo_path': d.photoPath,
  'emergency_contact': _contact(d.emergencyContact),
  'emergency_contact_2': _contact(d.emergencyContact2),
  'medical_notes': d.medicalNotes,
  'blood_type': d.bloodType,
  'allergies': d.allergies,
  'medications': d.medications,
  'medical_clearance_expiry_date': calendarDate(d.medicalClearanceExpiryDate),
  'insurance': {
    'provider': d.insurance.provider,
    'policy_number': d.insurance.policyNumber,
    'expiry_date': calendarDate(d.insurance.expiryDate),
    'emergency_phone': d.insurance.emergencyPhone,
    'phone': d.insurance.phone,
  },
  'notes': d.notes,
  'is_default': d.isDefault,
  'prior_dive_count': d.priorDiveCount,
  'prior_dive_time_s': d.priorDiveTimeSeconds,
  'diving_since_date': calendarDate(d.divingSince),
};

Map<String, Object?> _contact(EmergencyContact c) => {
  'name': c.name,
  'phone': c.phone,
  'relation': c.relation,
};

/// Settings columns holding a measure, and the key that names its unit.
const kSettingUnitKeys = <String, String>{
  'default_tank_volume': 'default_tank_volume_l',
  'default_start_pressure': 'default_start_pressure_bar',
  'pp_o2_max_working': 'pp_o2_max_working_bar',
  'pp_o2_max_deco': 'pp_o2_max_deco_bar',
  'pp_o2_deco_band1': 'pp_o2_deco_band1_bar',
  'pp_o2_deco_band2': 'pp_o2_deco_band2_bar',
  'pp_o2_deco_band3': 'pp_o2_deco_band3_bar',
  'max_o2_depth_meters': 'max_o2_depth_m',
  'ccr_setpoint_low': 'ccr_setpoint_low_bar',
  'ccr_setpoint_high': 'ccr_setpoint_high_bar',
  'ccr_diluent_mod_pp_o2': 'ccr_diluent_mod_pp_o2_bar',
  'ascent_rate_warning': 'ascent_rate_warning_m_min',
  'ascent_rate_critical': 'ascent_rate_critical_m_min',
  'last_stop_depth': 'last_stop_depth_m',
  'deco_stop_increment': 'deco_stop_increment_m',
  'end_limit': 'end_limit_m',
  'gtr_reserve_pressure': 'gtr_reserve_pressure_bar',
  'planner_descent_rate': 'planner_descent_rate_m_min',
  'planner_ascent_rate': 'planner_ascent_rate_m_min',
  'planner_intermediate_ascent_rate': 'planner_intermediate_ascent_rate_m_min',
  'planner_shallow_ascent_rate': 'planner_shallow_ascent_rate_m_min',
  'planner_final_ascent_rate': 'planner_final_ascent_rate_m_min',
  'planner_sac_bottom': 'planner_sac_bottom_l_min',
  'planner_sac_deco': 'planner_sac_deco_l_min',
  'planner_best_mix_end_meters': 'planner_best_mix_end_m',
  'planner_deviation_depth_delta': 'planner_deviation_depth_delta_m',
  'planner_walk_speed_mps': 'planner_walk_speed_m_s',
  'planner_reserve_pressure': 'planner_reserve_pressure_bar',
};

/// Real columns that carry no unit to name, or already name it.
const kUnitlessSettings = <String>{
  'cold_water_threshold_c',
  'deep_dive_threshold_m',
  'high_o2_threshold_percent',
  'planner_battery_reserve_fraction',
  'planner_buddy_factor',
  'planner_hypercapnia_factor',
  'planner_sac_stressed_factor',
  'planner_turn_pressure_fraction',
  'pscr_ratio',
  'visibility_scale_excellent_m',
  'visibility_scale_good_m',
  'visibility_scale_moderate_m',
};

/// One profile's settings.
///
/// The one document built from a Drift row, on purpose. The table has over
/// two hundred columns and no domain shape of its own, so a hand-kept mapper
/// would fall behind each new setting, while this one cannot. What a row must
/// not show is taken out here, and a guard test makes every new real column
/// declare its unit.
Map<String, Object?> settingsDocument(DiverSetting row) {
  final local = deviceLocalSyncColumns['diverSettings'] ?? const <String>{};
  return {
    for (final MapEntry(:key, :value) in row.toJson().entries)
      if (!local.contains(key) &&
          key != 'createdAt' &&
          key != 'updatedAt' &&
          !key.toLowerCase().endsWith('hlc'))
        _settingKey(key): value,
  };
}

String _settingKey(String jsonKey) {
  final column = changeLogSqlName(jsonKey);
  return kSettingUnitKeys[column] ?? column;
}
