import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/condition_finding_text.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The unit the exposure ranking card is showing.
final exposureRankingUnitProvider = StateProvider<ExposureUnit>(
  (ref) => ExposureUnit.hours,
);

/// Active items ranked by their total in the chosen unit, through the
/// same samples and classifier the item page uses, so the two never
/// disagree. `count` is the rounded total (what the row prints), `value`
/// the exact one, and `subtitle` states the dive count behind it, since a
/// total means little without the n it was gathered over.
final exposureRankingProvider = FutureProvider<List<RankingItem>>((ref) async {
  final unit = ref.watch(exposureRankingUnitProvider);
  final repository = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
  );
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final l10n = ref.watch(appLocalizationsProvider);
  final items = await repository.getActiveEquipment(diverId: diverId);
  final out = <RankingItem>[];
  for (final item in items) {
    final inputs = await ref.watch(
      equipmentExposureInputsProvider(item.id).future,
    );
    if (inputs == null || inputs.samples.isEmpty) continue;
    var total = 0.0;
    for (final sample in inputs.samples) {
      total += inputs.classifier.contribution(sample, unit);
    }
    if (total <= 0) continue;
    out.add(
      RankingItem(
        id: item.id,
        name: item.name,
        count: total.round(),
        value: total,
        subtitle: l10n.equipmentCondition_exposure_dives(inputs.samples.length),
      ),
    );
  }
  out.sort((a, b) => b.value!.compareTo(a.value!));
  return out;
});

/// Undismissed findings per rule after the display filters, worst-first
/// by count. The id is the rule's dbValue so a row can be traced.
final findingsByRuleProvider = FutureProvider<List<RankingItem>>((ref) async {
  final (enabled, disabled) = ref.watch(
    settingsProvider.select(
      (s) => (s.conditionEngineEnabled, s.conditionDisabledRules),
    ),
  );
  final findings = ref.watch(equipmentFindingsRepositoryProvider);
  ref.invalidateSelfWhen(findings.watchChanges());
  if (!enabled) return const [];
  final l10n = ref.watch(appLocalizationsProvider);
  final counts = <ConditionRuleId, int>{};
  for (final f in await findings.getAllUndismissed()) {
    if (disabled.contains(f.ruleId.dbValue)) continue;
    counts[f.ruleId] = (counts[f.ruleId] ?? 0) + 1;
  }
  final out = [
    for (final e in counts.entries)
      RankingItem(
        id: e.key.dbValue,
        name: conditionFindingShortLabel(e.key, l10n),
        count: e.value,
      ),
  ];
  out.sort((a, b) => b.count.compareTo(a.count));
  return out;
});

/// Issue check-in tags by how often the diver reported them.
final issueTagRankingProvider = FutureProvider<List<RankingItem>>((ref) async {
  final observations = ref.watch(equipmentObservationRepositoryProvider);
  ref.invalidateSelfWhen(observations.watchChanges());
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final l10n = ref.watch(appLocalizationsProvider);
  final counts = <ObservationTag, int>{};
  for (final o in await observations.getAll(diverId: diverId)) {
    if (o.status != ObservationStatus.issue) continue;
    for (final tag in o.issueTags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final out = [
    for (final e in counts.entries)
      RankingItem(
        id: e.key.dbValue,
        name: e.key.localizedName(l10n),
        count: e.value,
      ),
  ];
  out.sort((a, b) => b.count.compareTo(a.count));
  return out;
});

/// The localizations for the active locale, for providers that name
/// rows (a ranking card cannot rename its rows at render time).
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final tag = ref.watch(settingsProvider.select((s) => s.locale));
  return l10nForLocaleTag(tag);
});
