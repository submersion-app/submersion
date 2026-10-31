import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// A scenario's replay or re-plan mode, in the words the Dive Lab uses.
final ConflictEnumLabeler scenarioModeLabeler = enumLabeler(
  ScenarioMode.values,
  (l, v) => switch (v) {
    ScenarioMode.replay => l.diveLab_mode_replay,
    ScenarioMode.replan => l.diveLab_mode_replan,
  },
);

/// Saved Dive Lab scenarios. `name` and `notes` mean what they do everywhere
/// and need nothing here. `mode` does need an entry: the shared one reads a
/// dive plan's breathing mode, which a stored `replay` is not.
final Map<String, ConflictField> diveLabOverrides = {
  'diveScenarios.branchSeconds': ConflictField(
    (l) => l.diveLab_branch_label,
    FieldKind.durationSeconds,
  ),
  'diveScenarios.mode': ConflictField(
    (l) => l.settings_conflict_field_scenarioMode,
    FieldKind.enumValue,
    enumLabel: scenarioModeLabeler,
  ),
  'diveScenarios.interventionsJson': ConflictField(
    (l) => l.diveLab_interventions_label,
    FieldKind.opaque,
  ),
};
