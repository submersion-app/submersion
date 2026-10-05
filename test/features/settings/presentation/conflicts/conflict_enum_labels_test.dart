import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('labels a stored enum name with the app label', () {
    expect(entryMethodLabeler(l10n, 'boat'), l10n.enum_entryMethod_boat);
    expect(visibilityLabeler(l10n, 'good'), l10n.enum_visibility_good);
    expect(waterTypeLabeler(l10n, 'salt'), l10n.enum_waterType_salt);
    expect(
      currentStrengthLabeler(l10n, 'strong'),
      l10n.enum_currentStrength_strong,
    );
  });

  test('dive log enums reuse the labels the dive screens show', () {
    expect(diveModeLabeler(l10n, 'ccr'), l10n.enum_diveMode_ccr);
    expect(scrTypeLabeler(l10n, 'pascr'), l10n.enum_scrType_pascr);
    expect(tankRoleLabeler(l10n, 'bailout'), l10n.enum_tankRole_bailout);
    expect(tankMaterialLabeler(l10n, 'steel'), l10n.enum_tankMaterial_steel);
    expect(weightTypeLabeler(l10n, 'belt'), l10n.enum_weightType_belt);
    expect(
      profileEventTypeLabeler(l10n, 'ascentStart'),
      l10n.enum_profileEvent_ascentStart,
    );
    expect(
      weightingFeedbackLabeler(l10n, 'overweighted'),
      l10n.diveLog_edit_weightFeedback_over,
    );
    expect(
      incidentCategoryLabeler(l10n, 'buoyancy'),
      l10n.incidentCategory_buoyancy,
    );
    expect(
      incidentSeverityLabeler(l10n, 'serious'),
      l10n.incidentEdit_severity_serious,
    );
  });

  test('dive log enums without a screen label get their own', () {
    expect(eventSeverityLabeler(l10n, 'info'), 'Info');
    expect(eventSeverityLabeler(l10n, 'alert'), l10n.enum_eventSeverity_alert);
    expect(eventSourceLabeler(l10n, 'user'), 'Added by you');
    expect(tankRoleSourceLabeler(l10n, 'transmitterName'), 'Transmitter name');
    expect(weatherSourceLabeler(l10n, 'openMeteo'), 'Open-Meteo');
    expect(qualityCategoryLabeler(l10n, 'duplicate'), 'Duplicate');
    expect(qualitySeverityLabeler(l10n, 'critical'), 'Critical');
    expect(qualityStatusLabeler(l10n, 'dismissed'), 'Dismissed');
    expect(safetySeverityLabeler(l10n, 'significant'), 'Significant');
  });

  test('site and trip enums reuse the labels their screens show', () {
    expect(
      speciesCategoryLabeler(l10n, 'fish'),
      l10n.enum_speciesCategory_fish,
    );
    expect(
      siteDifficultyLabeler(l10n, 'beginner'),
      l10n.diveSites_difficulty_beginner,
    );
    expect(tideStateLabeler(l10n, 'rising'), l10n.enum_tideState_rising);
    expect(dayTypeLabeler(l10n, 'seaDay'), l10n.trips_dayType_seaDay);
    expect(
      equipmentTypeLabeler(l10n, 'regulator'),
      l10n.enum_equipmentType_regulator,
    );
    expect(tripTypeLabeler(l10n, 'liveaboard'), l10n.trips_type_liveaboard);
    expect(siteFeatureTypeLabeler(l10n, 'wreck'), l10n.siteFeature_type_wreck);
    expect(
      rentalVerdictLabeler(l10n, 'avoid'),
      l10n.diveCenters_rental_verdictAvoid,
    );
    expect(tripCylinderEventKindLabeler(l10n, 'fill'), 'Fill');
  });

  test('equipment enums reuse the labels the equipment screens show', () {
    expect(
      equipmentStatusLabeler(l10n, 'active'),
      l10n.enum_equipmentStatus_active,
    );
    expect(
      observationStatusLabeler(l10n, 'ok'),
      l10n.equipmentObservation_status_ok,
    );
    expect(
      serviceCategoryLabeler(l10n, 'annual'),
      l10n.equipment_serviceCategory_annual,
    );
    expect(
      conditionSeverityLabeler(l10n, 'caution'),
      l10n.enum_safetySeverity_caution,
    );
  });

  test('equipment enums without a screen label get their own', () {
    expect(fillSourceLabeler(l10n, 'qr'), 'QR code');
    expect(ownershipEventKindLabeler(l10n, 'transferred'), 'Transferred');
  });

  test('returns null for a value this build does not know', () {
    expect(entryMethodLabeler(l10n, 'jetpack'), isNull);
    expect(entryMethodLabeler(l10n, ''), isNull);
  });

  test('storedAs maps an enum stored by code rather than by name', () {
    final labeler = enumLabeler<_Mode>(
      _Mode.values,
      (l, m) => m.name.toUpperCase(),
      storedAs: (m) => m.code,
    );
    expect(labeler(l10n, 'oc'), 'OPEN');
    expect(labeler(l10n, 'open'), isNull);
  });
}

enum _Mode {
  open('oc');

  const _Mode(this.code);
  final String code;
}
