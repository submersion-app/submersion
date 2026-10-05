import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/presentation/certification_agency_display.dart';
import 'package:submersion/features/certifications/presentation/certification_level_display.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

// Labelers for the enums of certifications, courses, dive plans and pre-dive
// checklists.

final ConflictEnumLabeler certificationAgencyLabeler = enumLabeler(
  CertificationAgency.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler certificationLevelLabeler = enumLabeler(
  CertificationLevel.values,
  (l, v) => v.localizedName(l),
);

/// A plan's breathing mode shares its words with a logged dive's mode; only
/// the passive SCR has no logged-dive counterpart.
final ConflictEnumLabeler planModeLabeler = enumLabeler(
  PlanMode.values,
  (l, v) => switch (v) {
    PlanMode.oc => l.enum_diveMode_oc,
    PlanMode.ccr => l.enum_diveMode_ccr,
    PlanMode.scr => l.enum_diveMode_scr,
    PlanMode.pscr => l.enum_planMode_pscr,
  },
);

/// The planner's own words for the turn rule.
final ConflictEnumLabeler turnPressureRuleLabeler = enumLabeler(
  TurnPressureRule.values,
  (l, v) => switch (v) {
    TurnPressureRule.allUsable => l.plannerCanvas_turnRule_allUsable,
    TurnPressureRule.halves => l.plannerCanvas_turnRule_halves,
    TurnPressureRule.thirds => l.plannerCanvas_turnRule_thirds,
    TurnPressureRule.custom => l.plannerCanvas_turnRule_custom,
  },
);

final ConflictEnumLabeler missionEnvironmentLabeler = enumLabeler(
  MissionEnvironment.values,
  (l, v) => switch (v) {
    MissionEnvironment.overhead => l.enum_missionEnvironment_overhead,
    MissionEnvironment.openWater => l.enum_missionEnvironment_openWater,
  },
);

final ConflictEnumLabeler requirementKindLabeler = enumLabeler(
  RequirementKind.values,
  (l, v) => switch (v) {
    RequirementKind.dive => l.enum_requirementKind_dive,
    RequirementKind.checklist => l.enum_requirementKind_checklist,
  },
);

final ConflictEnumLabeler preDiveSessionStatusLabeler = enumLabeler(
  PreDiveSessionStatus.values,
  (l, v) => switch (v) {
    PreDiveSessionStatus.inProgress => l.enum_preDiveSessionStatus_inProgress,
    PreDiveSessionStatus.completed => l.enum_preDiveSessionStatus_completed,
    PreDiveSessionStatus.aborted => l.enum_preDiveSessionStatus_aborted,
  },
);

final ConflictEnumLabeler preDiveItemStateLabeler = enumLabeler(
  PreDiveItemState.values,
  (l, v) => switch (v) {
    PreDiveItemState.pending => l.enum_preDiveItemState_pending,
    PreDiveItemState.done => l.enum_preDiveItemState_done,
    PreDiveItemState.skipped => l.enum_preDiveItemState_skipped,
    PreDiveItemState.flagged => l.enum_preDiveItemState_flagged,
  },
);

final ConflictEnumLabeler preDiveItemTypeLabeler = enumLabeler(
  PreDiveItemType.values,
  (l, v) => switch (v) {
    PreDiveItemType.check => l.enum_preDiveItemType_check,
    PreDiveItemType.value => l.enum_preDiveItemType_value,
    PreDiveItemType.equipmentSet => l.enum_preDiveItemType_equipmentSet,
    PreDiveItemType.equipment => l.enum_preDiveItemType_equipment,
    PreDiveItemType.cellLinearity => l.enum_preDiveItemType_cellLinearity,
  },
);
