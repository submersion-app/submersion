import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The finding a list tile badges for an item: its worst undismissed
/// caution or significant finding.
typedef ConditionBadge = ({ConditionSeverity severity, ConditionRuleId rule});

/// Worst badge-worthy finding per item, in ONE read for the whole list
/// (condition phase 4b). Info findings never badge. The master toggle
/// and the disabled rules apply here, at display time, like everywhere
/// else: rules keep computing, the map just goes quiet.
final conditionBadgeProvider = FutureProvider<Map<String, ConditionBadge>>((
  ref,
) async {
  final (enabled, disabled) = ref.watch(
    settingsProvider.select(
      (s) => (s.conditionEngineEnabled, s.conditionDisabledRules),
    ),
  );
  final findings = ref.watch(equipmentFindingsRepositoryProvider);
  ref.invalidateSelfWhen(findings.watchChanges());
  ref.invalidateSelfWhen(
    ref.watch(equipmentRepositoryProvider).watchEquipmentChanges(),
  );
  if (!enabled) return const {};
  final out = <String, ConditionBadge>{};
  for (final f in await findings.getAllUndismissed()) {
    if (f.severity == ConditionSeverity.info) continue;
    if (disabled.contains(f.ruleId.dbValue)) continue;
    final current = out[f.equipmentId];
    if (current == null || f.severity.index > current.severity.index) {
      out[f.equipmentId] = (severity: f.severity, rule: f.ruleId);
    }
  }
  return out;
});

enum BadgeSource { clock, finding }

/// Which of the two a tile shows: overdue clock, then significant
/// finding, then due-soon clock, then caution finding. Null when neither
/// says anything (an ok clock is nothing).
BadgeSource? pickBadgeSource({
  required ServiceClockSeverity? clockSeverity,
  required ConditionBadge? finding,
}) {
  final clockRank = switch (clockSeverity) {
    ServiceClockSeverity.overdue => 4,
    ServiceClockSeverity.dueSoon => 2,
    ServiceClockSeverity.ok || null => 0,
  };
  final findingRank = switch (finding?.severity) {
    ConditionSeverity.significant => 3,
    ConditionSeverity.caution => 1,
    ConditionSeverity.info || null => 0,
  };
  if (clockRank == 0 && findingRank == 0) return null;
  return clockRank > findingRank ? BadgeSource.clock : BadgeSource.finding;
}
